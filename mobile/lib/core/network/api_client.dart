import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../constants/app_constants.dart';

/// 会话失效原因，便于上层区分处理（直接登出 vs 提示后登出）
enum SessionExpiredReason { unauthorized, tokenExpired }

/// 共享 Dio 实例，带 token 拦截器与安全持久化
///
/// 安全设计（Issue1 P0/P1 + 复审 P0 全部修复）：
/// 1. JWT 存于 `flutter_secure_storage`（Keychain/Keystore），App 重启后可恢复。
/// 2. 统一识别后端 `body.code` 1001/1002 与 HTTP 401，触发会话失效回调。
/// 3. 会话版本号（sessionGeneration）：每次 [setSession]/[clearSession] 递增一次，
///    请求时快照到 options.extra，响应时比较——若版本已变则忽略迟到的 1001/1002/401/2015。
/// 4. **原子会话操作 + 锁内 CAS**：[setSessionIfCurrent] 在互斥锁内同时完成
///    gen+userId CAS 校验与 access+refresh 写入，消除「锁外 CAS 通过 → 排队期间
///    新会话提交 → 旧操作在锁内覆盖新会话」的 TOCTOU。Future 链保证不同时写，
///    锁内 CAS 保证排队操作仍属于当前会话。
/// 5. 2015 PASSWORD_CHANGE_REQUIRED：不登出，转为本地 mustChangePassword=true 回调。
/// 6. single-flight：会话失效处理只触发一次，避免并发请求重复登出/通知。
/// 7. 持久化异常上抛 + **第二枚 token 写失败时回滚第一枚**：setSession 不吞异常，
///    任一写入失败都回滚已写入的 token，让 AuthNotifier 能感知失败并回滚。
class ApiClient {
  ApiClient._();

  static Dio? _instance;
  static const _secure = FlutterSecureStorage();

  /// 内存中的 access token，避免每个请求都读盘
  static String? _token;

  /// 会话版本号：每次 setSession/clearSession 递增，用于检测迟到响应
  static int _sessionGeneration = 0;

  /// 当前会话的 userId 快照，与 sessionGeneration 配合做双重 CAS
  /// （gen 防止同账号内迟到响应，userId 防止跨账号迟到响应）
  static int? _currentUserId;

  /// single-flight：会话失效是否正在处理中
  static bool _sessionExpiredHandling = false;

  /// 会话操作互斥锁链：所有会话写入（setSession/clearSession）串行执行，
  /// 消除「access 写完 / refresh 未写」窗口内另一会话插入导致的跨账号混票。
  /// 实现：每个调用者 await 前一个 future，形成串行链。
  static Future<void> _sessionLockChain = Future<void>.value();

  /// M3 修复：forceLogout 标志键。
  /// clearSession 删除 secure storage 失败时写入 true，冷启动 init() 检测后重试清理，
  /// 防止残留有效 token 在重启后被错误恢复。
  static const String _forceLogoutKey = 'zhiyu_force_logout';

  /// 会话失效回调：由 AuthNotifier 注册，触发后清理本地登录态并跳转登录页
  static void Function(SessionExpiredReason)? onSessionExpired;

  /// 强制改密回调：由 AuthNotifier 注册，收到 2015 时转为本地 mustChangePassword=true
  static void Function()? onPasswordChangeRequired;

  /// 当前会话版本号（供 AuthNotifier 做代际 CAS）
  static int get sessionGeneration => _sessionGeneration;

  /// 当前会话的 userId（供 AuthNotifier 做跨账号 CAS）
  static int? get currentUserId => _currentUserId;

  /// 恢复 _currentUserId（冷启动时由 AuthNotifier 调用）
  ///
  /// P0-4 修复：冷启动时 ApiClient.init() 只恢复 _token，不恢复 _currentUserId。
  /// 导致后续 setSessionIfCurrent 的 userId CAS 始终失败（_currentUserId 始终为 null）。
  /// 此方法仅恢复内存状态，不触碰 secure storage。
  static void restoreUserId(int userId) {
    _currentUserId = userId;
  }

  static Dio get instance {
    if (_instance != null) return _instance!;
    _instance = _create();
    return _instance!;
  }

  /// 原子写入 access + refresh token（用于新登录，无条件）
  ///
  /// 在互斥锁内一次性完成：
  ///   1. 写 access token 到 secure storage
  ///   2. 写 refresh token 到 secure storage（失败时回滚步骤 1）
  ///   3. 更新内存 _token + _currentUserId
  ///   4. 递增 _sessionGeneration（仅一次）
  ///   5. 重置 single-flight
  ///
  /// High-1 修复：若步骤 2 失败，回滚步骤 1（删除已写入的 access token），
  /// 避免出现「有 access 无 refresh」的半成品会话。
  static Future<void> setSession({
    required String access,
    required String refresh,
    int? userId,
  }) async {
    await _withSessionLock(() async {
      // 先写 secure storage，全部成功后再更新内存 + 递增 generation
      try {
        await _secure.write(key: SecureKeys.accessToken, value: access);
      } catch (e) {
        log('setSession 写入 access token 失败: $e', name: 'api_client');
        throw Exception('安全存储写入失败，无法保存登录凭证');
      }
      try {
        await _secure.write(key: SecureKeys.refreshToken, value: refresh);
      } catch (e) {
        // High-1 修复：回滚已写入的 access token，避免半成品会话
        log('setSession 写入 refresh token 失败，回滚 access token: $e', name: 'api_client');
        try {
          await _secure.delete(key: SecureKeys.accessToken);
        } catch (rollbackErr) {
          log('setSession 回滚 access token 也失败: $rollbackErr', name: 'api_client');
        }
        throw Exception('安全存储写入失败，无法保存登录凭证');
      }
      // 全部持久化成功后，原子更新内存状态
      _token = access;
      _currentUserId = userId;
      _sessionGeneration++;
      _sessionExpiredHandling = false;
      // M3 复审 P1-B: 新会话成功后清除旧 forceLogout 标志，防止下次启动误删新 token
      // N1 修复：检查返回值，清墓碑失败时记录告警（概率极低，但后果是下次冷启动误删新 token）
      final cleared = await _setForceLogout(false);
      if (!cleared) {
        log('警告: 新会话已建立但清墓碑失败，下次冷启动可能误删新 token', name: 'api_client');
      }
    });
  }

  /// 原子写入 access + refresh token，带锁内 CAS（用于改密响应，防止迟到覆盖）
  ///
  /// P0-3 修复：CAS 在锁内执行，不是锁外。
  /// 旧实现：锁外检查 gen+userId → 排队 setSession → 锁内写入。
  /// 问题：排队期间新会话提交，旧操作的 gen+userId 在锁外已通过检查，
  ///       锁内仍会覆盖新会话（TOCTOU）。
  /// 修复：gen+userId 检查移入锁内，排队到锁内时再次校验，不匹配则返回 false。
  ///
  /// 返回 true = CAS 通过并已写入；false = 会话已变更，调用方应丢弃响应。
  static Future<bool> setSessionIfCurrent({
    required int expectedGen,
    int? expectedUserId,
    required String access,
    required String refresh,
  }) async {
    return await _withSessionLock(() async {
      // 锁内 CAS：gen+userId 必须与期望值一致才写入
      if (_sessionGeneration != expectedGen) {
        log('setSessionIfCurrent CAS 失败: gen 期望=$expectedGen 实际=$_sessionGeneration',
            name: 'api_client');
        return false;
      }
      if (expectedUserId != null && _currentUserId != expectedUserId) {
        log('setSessionIfCurrent CAS 失败: userId 期望=$expectedUserId 实际=$_currentUserId',
            name: 'api_client');
        return false;
      }
      // CAS 通过，写入新 token（含 High-1 回滚）
      try {
        await _secure.write(key: SecureKeys.accessToken, value: access);
      } catch (e) {
        log('setSessionIfCurrent 写入 access token 失败: $e', name: 'api_client');
        throw Exception('安全存储写入失败，无法保存登录凭证');
      }
      try {
        await _secure.write(key: SecureKeys.refreshToken, value: refresh);
      } catch (e) {
        log('setSessionIfCurrent 写入 refresh token 失败，回滚 access: $e', name: 'api_client');
        try {
          await _secure.delete(key: SecureKeys.accessToken);
        } catch (_) {}
        throw Exception('安全存储写入失败，无法保存登录凭证');
      }
      _token = access;
      _sessionGeneration++;
      _sessionExpiredHandling = false;
      // M3 复审 P1-B: 新会话成功后清除旧 forceLogout 标志
      // N1 修复：检查返回值，清墓碑失败时记录告警
      final cleared = await _setForceLogout(false);
      if (!cleared) {
        log('警告: 改密会话已建立但清墓碑失败，下次冷启动可能误删新 token', name: 'api_client');
      }
      return true;
    });
  }

  /// 原子清除 access + refresh token（用于用户主动登出，无条件）
  ///
  /// best-effort：即使 secure storage 删除失败也不阻塞，因为内存 _token 已清。
  /// 递增 generation 后，任何在途的迟到响应都会被忽略。
  ///
  /// M3 复审 P1-B 修复：正确顺序为「先写墓碑 → 删 token → 成功后清墓碑」。
  /// 旧实现先删 token 后写标志 → 进程中途终止会留下有效 token 且没有标志。
  /// 现在先写 forceLogout=true 墓碑，删除两枚 token 后仅当都成功才清墓碑。
  static Future<void> clearSession() async {
    await _withSessionLock(() async {
      _token = null;
      _currentUserId = null;
      _sessionGeneration++;
      _sessionExpiredHandling = false;
      // Step 1: 先写墓碑，防止进程中途终止留下有效 token 而无标志
      await _setForceLogout(true);
      // Step 2: 删除两枚 token（独立 try-catch，第一枚失败不跳过第二枚）
      bool anyFailure = false;
      try {
        await _secure.delete(key: SecureKeys.accessToken);
      } catch (e) {
        log('clearSession 删除 access token 失败: $e', name: 'api_client');
        anyFailure = true;
      }
      try {
        await _secure.delete(key: SecureKeys.refreshToken);
      } catch (e) {
        log('clearSession 删除 refresh token 失败: $e', name: 'api_client');
        anyFailure = true;
      }
      // Step 3: 仅当两枚 token 都删除成功时才清墓碑
      if (!anyFailure) {
        await _setForceLogout(false);
      }
    });
  }

  /// 原子清除 access + refresh token，带锁内 CAS（用于 1001/401 触发的自动登出）
  ///
  /// 防止迟到的 1001 在排队期间清除新会话的 token。
  /// 返回 true = CAS 通过并已清除；false = 会话已变更，跳过清除。
  static Future<bool> clearSessionIfCurrent({required int expectedGen}) async {
    return await _withSessionLock(() async {
      if (_sessionGeneration != expectedGen) {
        log('clearSessionIfCurrent CAS 失败: gen 期望=$expectedGen 实际=$_sessionGeneration',
            name: 'api_client');
        return false;
      }
      _token = null;
      _currentUserId = null;
      _sessionGeneration++;
      _sessionExpiredHandling = false;
      // M3 复审 P1-B: 先写墓碑
      await _setForceLogout(true);
      bool anyFailure = false;
      // P1-3 修复：两枚 token 独立 try-catch，第一枚删除失败不跳过第二枚
      try {
        await _secure.delete(key: SecureKeys.accessToken);
      } catch (e) {
        log('clearSessionIfCurrent 删除 access token 失败: $e', name: 'api_client');
        anyFailure = true;
      }
      try {
        await _secure.delete(key: SecureKeys.refreshToken);
      } catch (e) {
        log('clearSessionIfCurrent 删除 refresh token 失败: $e', name: 'api_client');
        anyFailure = true;
      }
      // M3 复审 P1-B: 仅当两枚都删除成功时才清墓碑
      if (!anyFailure) {
        await _setForceLogout(false);
      }
      return true;
    });
  }

  /// 会话操作互斥锁：串行化所有 setSession/clearSession 调用
  ///
  /// 实现：每个调用者 await 前一个锁 future，形成串行执行链。
  /// 这确保 setSession(A) 的两次 write 不会被 setSession(B) 插入，
  /// 也不会被 clearSession() 插入——彻底消除 access/refresh 分属不同会话的 TOCTOU。
  static Future<T> _withSessionLock<T>(Future<T> Function() fn) async {
    final prev = _sessionLockChain;
    final completer = Completer<void>();
    _sessionLockChain = completer.future;
    await prev;
    try {
      return await fn();
    } finally {
      completer.complete();
    }
  }

  /// 读取 refresh token（用于 access token 过期后刷新）
  static Future<String?> readRefreshToken() async {
    try {
      return _secure.read(key: SecureKeys.refreshToken);
    } catch (e) {
      log('读取 refresh token 失败: $e', name: 'api_client');
      return null;
    }
  }

  /// 读取 access token（用于启动时成套性检查）
  static Future<String?> readAccessToken() async {
    try {
      return _secure.read(key: SecureKeys.accessToken);
    } catch (e) {
      log('读取 access token 失败: $e', name: 'api_client');
      return null;
    }
  }

  /// 应用启动时调用：从 secure storage 恢复 access token 到内存
  ///
  /// M3 修复：先检查 forceLogout 标志。如果上次 clearSession 删除 secure storage 失败，
  /// 残留 token 会在冷启动时被错误恢复。检测到标志后重试清理，阻止恢复。
  ///
  /// N4 修复：返回 bool 表示是否成功恢复。调用方（_loadUser）应据此决定是否直读
  /// secure storage——未恢复时跳过直读，避免绕过墓碑恢复本应清除的 token。
  static Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_forceLogoutKey) == true) {
        log('检测到 forceLogout 标志，重试清理 secure storage 残留 token', name: 'api_client');
        // M3 复审 P1-B: 删除失败时不清标志，下次冷启动再次重试
        bool anyFailure = false;
        try { await _secure.delete(key: SecureKeys.accessToken); } catch (_) { anyFailure = true; }
        try { await _secure.delete(key: SecureKeys.refreshToken); } catch (_) { anyFailure = true; }
        if (!anyFailure) {
          await prefs.setBool(_forceLogoutKey, false);
        }
        _token = null;
        return false; // 墓碑阻止恢复
      }
    } catch (e) {
      // N2 修复：try 块含 getBool 读 + setBool 写，文案改为"标志处理失败"更准确
      log('forceLogout 标志处理失败: $e', name: 'api_client');
    }
    try {
      _token = await _secure.read(key: SecureKeys.accessToken);
      return _token != null;
    } catch (e) {
      log('恢复 access token 失败: $e', name: 'api_client');
      _token = null;
      return false;
    }
  }

  /// 清除所有认证凭证（兼容旧调用，内部委托 clearSession）
  static Future<void> clearAuth() => clearSession();

  /// M3 修复：写入 forceLogout 标志到 SharedPreferences
  ///
  /// clearSession/clearSessionIfCurrent 删除 secure storage 失败时写入 true，
  /// 冷启动 init() 检测后重试清理。删除全部成功时写入 false。
  /// 返回 setBool 结果，false 表示写入失败。
  static Future<bool> _setForceLogout(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_forceLogoutKey, value);
    } catch (e) {
      log('写入 forceLogout 标志失败: $e', name: 'api_client');
      return false;
    }
  }

  static Dio _create() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        // 快照当前会话版本号，响应时比较以过滤迟到响应
        options.extra['sessionGen'] = _sessionGeneration;
        handler.next(options);
      },
      onResponse: (response, handler) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final code = data['code'];
          if (code is int) {
            // 会话版本号检查：若请求发出后会话已变更（重新登录/登出），
            // 则忽略此迟到响应（1001/1002/2015），不清除/不标记新会话
            final reqGen = response.requestOptions.extra['sessionGen'] as int? ?? 0;
            final isStale = reqGen != _sessionGeneration;

            // 2015：需要改密——不登出，转为本地 mustChangePassword=true
            if (code == 2015) {
              if (isStale) {
                log('忽略迟到的 2015: reqGen=$reqGen curGen=$_sessionGeneration', name: 'api_client');
              } else {
                log('收到 2015 PASSWORD_CHANGE_REQUIRED，转为本地强制改密', name: 'api_client');
                onPasswordChangeRequired?.call();
              }
              handler.reject(DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                message: data['message']?.toString() ?? '需要修改初始密码后才能使用',
              ));
              return;
            }
            if (code == 1001 || code == 1002) {
              if (isStale) {
                log('忽略迟到的 $code: reqGen=$reqGen curGen=$_sessionGeneration', name: 'api_client');
                handler.reject(DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                  message: '过期请求已忽略',
                ));
                return;
              }
              final reason = code == 1001
                  ? SessionExpiredReason.unauthorized
                  : SessionExpiredReason.tokenExpired;
              _handleSessionExpired(reason);
              handler.reject(DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                message: data['message']?.toString() ??
                    (code == 1001 ? '未登录或token无效' : 'token已过期'),
              ));
              return;
            }
          }
        }
        handler.next(response);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          final reqGen = e.requestOptions.extra['sessionGen'] as int? ?? 0;
          if (reqGen == _sessionGeneration) {
            _handleSessionExpired(SessionExpiredReason.unauthorized);
          } else {
            log('忽略迟到的 401: reqGen=$reqGen curGen=$_sessionGeneration', name: 'api_client');
          }
        }
        handler.next(e);
      },
    ));

    return dio;
  }

  /// 触发会话失效回调（由 AuthNotifier 注册为 logout）
  /// single-flight：同一批并发失效只触发一次回调
  static void _handleSessionExpired(SessionExpiredReason reason) {
    if (_sessionExpiredHandling) {
      log('会话失效已在处理中，跳过重复回调: $reason', name: 'api_client');
      return;
    }
    _sessionExpiredHandling = true;
    _token = null;
    log('会话失效: $reason', name: 'api_client');
    onSessionExpired?.call(reason);
  }

  static void dispose() {
    _instance?.close();
    _instance = null;
    _token = null;
    _sessionGeneration = 0;
    _currentUserId = null;
    _sessionExpiredHandling = false;
    onSessionExpired = null;
    onPasswordChangeRequired = null;
  }
}
