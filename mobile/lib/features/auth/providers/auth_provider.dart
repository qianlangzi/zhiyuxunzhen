import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/api_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../data/auth_service.dart';

/// 认证状态
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;
  bool get isStudent => user?.role == UserRole.student;
  bool get isTeacher => user?.role == UserRole.teacher;

  /// 是否需要强制改密（来自后端 LoginResponse.mustChangePassword / UserInfoVO.mustChangePassword）
  bool get mustChangePassword => user?.mustChangePassword ?? false;
}

/// 认证状态管理
///
/// 会话安全设计（复审 P0 全部修复）：
/// - 所有会话写入（login/change/logout）统一通过 [ApiClient.setSession] /
///   [ApiClient.setSessionIfCurrent] / [ApiClient.clearSession] 在互斥锁内原子完成。
/// - **CAS 在锁内执行（P0-3 修复）**：[changePassword] 使用 [ApiClient.setSessionIfCurrent]，
///   gen+userId CAS 校验在锁内完成，消除「锁外 CAS 通过 → 排队期间新会话提交 →
///   旧操作在锁内覆盖新会话」的 TOCTOU。Future 链保证不同时写，锁内 CAS 保证
///   排队操作仍属于当前会话。
/// - 1001 触发的自动登出使用 [ApiClient.clearSessionIfCurrent]，防止迟到 1001
///   在排队期间清除新会话的 token。
/// - [_saveUser] 持久化失败抛异常（不吞），且检查 SharedPreferences 返回值（High-3）。
/// - [loginWith] 先持久化 user 再更新 state（High-2），避免「内存已认证但本地未保存」。
class AuthNotifier extends StateNotifier<AuthState> {
  static const _userKey = 'auth_user';
  final _auth = const AuthService();

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _initFuture = _loadUser();
  }

  late final Future<void> _initFuture;

  /// 等待初始化完成（供 main() 预热调用，避免 redirect 竞态）
  Future<void> ensureInitialized() => _initFuture;

  /// 从本地缓存恢复登录用户
  ///
  /// 1. 先从 flutter_secure_storage 恢复 access token 到 ApiClient
  /// 2. 恢复用户态后做成套性检查：user + access token + refresh token 三者必须同时存在，
  ///    缺失任一则视为不完整会话，全部清除（防止 user-only 或 token-only 状态）
  /// 3. 冷启动无 user 但 token 存在（token-only）→ 清除 token
  /// 4. 注册会话失效回调（1001/1002/401 → logout）
  /// 5. 注册强制改密回调（2015 → 本地 mustChangePassword=true + 持久化 + 触发路由重定向）
  ///
  /// P0-4 修复：新增 JWT subject 与 user.id 一致性校验 + _currentUserId 恢复。
  /// 旧实现只检查三项是否存在，不验证 JWT subject 与 user.id 的对应关系，
  /// 导致进程在写完 B token、写 B user 前终止后重启，可能恢复为「界面 A、API 身份 B」。
  /// 且未恢复 _currentUserId，导致后续 setSessionIfCurrent 的 userId CAS 始终失败。
  Future<void> _loadUser() async {
    // 注册会话失效回调：ApiClient 检测到 1001/1002/401 时触发本地登出
    // P0-3 修复：1001 触发的登出使用 clearSessionIfCurrent（CAS），防止迟到 1001 清除新会话
    ApiClient.onSessionExpired = (_) {
      _handleAutoLogout();
    };

    // 注册强制改密回调：ApiClient 检测到 2015 时转为本地 mustChangePassword=true
    ApiClient.onPasswordChangeRequired = () {
      markMustChangePassword();
    };

    // 1. 先恢复 JWT 到 ApiClient 内存，确保后续请求带 Authorization 头
    await ApiClient.init();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userKey);

      // 冷启动无 user 但 token 可能存在（token-only 会话）→ 清除 token
      if (jsonStr == null || jsonStr.isEmpty) {
        final accessToken = await ApiClient.readAccessToken();
        if (accessToken != null) {
          log('检测到 token-only 会话（有 token 无 user），清除残留 token', name: 'auth');
          await ApiClient.clearSession();
        }
        state = const AuthState();
        return;
      }

      final user = UserModel.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      // 成套性检查：user 存在但 access/refresh token 缺失 → 不完整会话，全部清除
      final accessToken = await ApiClient.readAccessToken();
      final refreshToken = await ApiClient.readRefreshToken();
      if (accessToken == null || refreshToken == null) {
        log('会话不完整: user 存在但 token 缺失 (access=${accessToken != null}, refresh=${refreshToken != null})，清除全部', name: 'auth');
        await _saveUser(null);
        await ApiClient.clearSession();
        state = const AuthState();
        return;
      }

      // P0-4 修复：验证 JWT subject 与 user.id 一致，防止跨账号身份混淆
      // 场景：进程在写完 B token、写 B user 前终止 → 重启后 user=A 但 token=B
      // Mock 模式使用占位 token（非 JWT），跳过 subject 校验
      if (!ApiConfig.useMockAuth) {
        final jwtUserId = _decodeJwtSubject(accessToken);
        if (jwtUserId == null || jwtUserId != user.id) {
          log('JWT subject 与 user.id 不一致: jwt=$jwtUserId user=${user.id}，清除会话', name: 'auth');
          await _saveUser(null);
          await ApiClient.clearSession();
          state = const AuthState();
          return;
        }
      }

      // P0-4 修复：恢复 _currentUserId，使后续 setSessionIfCurrent 的 userId CAS 正常工作
      ApiClient.restoreUserId(user.id);

      state = AuthState(user: user);
    } catch (e) {
      log('恢复本地用户失败: $e', name: 'auth');
      state = const AuthState();
    }
  }

  /// 解码 JWT payload 中的 subject（userId）
  ///
  /// JWT 格式：header.payload.signature
  /// payload 是 base64url 编码的 JSON，sub 字段为 userId（字符串或整数）。
  /// 解码失败返回 null（调用方视为身份不匹配，清除会话）。
  static int? _decodeJwtSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // base64url → base64
      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      // 补齐 padding
      while (payload.length % 4 != 0) payload += '=';
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final sub = json['sub'];
      if (sub is int) return sub;
      if (sub is String) return int.tryParse(sub);
      return null;
    } catch (e) {
      log('解码 JWT subject 失败: $e', name: 'auth');
      return null;
    }
  }

  /// 1001/401 触发的自动登出：使用 CAS 防止迟到响应清除新会话
  ///
  /// 场景：请求 A 发出 → 1001 响应排队 → 用户重新登录 →
  ///   1001 触发的 clearSession 排在新登录后面 → 清除新会话的 token。
  /// 防护：clearSessionIfCurrent 检查 gen，若期间发生了新登录（gen 变化），跳过清除。
  ///
  /// P1-3 修复：旧实现在 CAS 成功前先清空 AuthState，若 CAS 失败（会话已变更），
  /// state 已被清空但新会话仍有效 → UI 显示未登录但 API 有 token。
  /// 修复：先执行 CAS，仅在 CAS 通过后才清空 state。
  Future<void> _handleAutoLogout() async {
    final genAtTrigger = ApiClient.sessionGeneration;
    // CAS：仅当 gen 未变时才清除 token（防止迟到 1001 清除新会话）
    final cleared = await ApiClient.clearSessionIfCurrent(expectedGen: genAtTrigger);
    if (cleared) {
      state = const AuthState();
    }
  }

  /// 将用户数据持久化到本地
  ///
  /// High-3 修复：检查 SharedPreferences 的返回值，setString/remove 返回 false
  /// 表示持久化失败（磁盘满、权限问题等），此时抛异常让调用方感知并回滚。
  Future<void> _saveUser(UserModel? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      final ok = await prefs.remove(_userKey);
      if (!ok) {
        throw Exception('无法清除本地用户数据');
      }
      return;
    }
    final ok = await prefs.setString(_userKey, jsonEncode(user.toJson()));
    if (!ok) {
      throw Exception('无法保存本地用户数据');
    }
  }

  /// 报告条目: P2 #3 — 改为 async，await _saveUser 防止登录态丢失
  Future<void> loginAsStudent() async {
    final user = UserModel.mockStudent();
    state = AuthState(user: user);
    await _saveUser(user);
  }

  /// 报告条目: P2 #3
  Future<void> loginAsTeacher() async {
    final user = UserModel.mockTeacher();
    state = AuthState(user: user);
    await _saveUser(user);
  }

  /// 以指定用户建立会话（注册 / 验证码登录 / 密码登录 通用入口）。
  ///
  /// P0 原子会话提交：通过 [ApiClient.setSession] 在互斥锁内一次性写入 access + refresh
  /// token，消除分两次写入的 TOCTOU 窗口。
  ///
  /// P0-4 修复：真实模式严格要求完整 token 对（access + refresh）。
  /// 缺失任一 token 时抛异常，不保存 user、不进入认证状态。
  /// 旧实现允许 null token 跳过 setSession 但仍保存 user → 无 Authorization 头的
  /// 认证状态，后端可能返回错误或使用默认身份，是身份混淆的根源。
  ///
  /// High-2 修复：先持久化 user，再更新内存 state。若 _saveUser 失败，
  /// state 不会被更新为新用户，避免出现「内存已认证但本地未保存」的半成品状态。
  /// setSession 持久化失败时抛异常，此方法不吞异常，让调用方感知失败并回滚 UI 状态。
  Future<void> loginWith(
    UserModel user, {
    String? token,
    String? refreshToken,
  }) async {
    // P0-4 修复：缺失 token 对时直接抛异常，不保存 user、不进入认证状态
    if (token == null || refreshToken == null) {
      throw Exception('登录凭证不完整：缺失 access token 或 refresh token');
    }
    // 1. 原子写入 token（setSession 在互斥锁内写 access+refresh，递增 generation 一次）
    //    持久化失败时抛异常，不保存 user，避免半成品会话
    await ApiClient.setSession(
      access: token,
      refresh: refreshToken,
      userId: user.id,
    ); // may throw
    // 2. High-2 修复：先持久化 user，再更新内存 state
    //    若 _saveUser 失败，state 仍为旧值，调用方 catch 后 clearSession 清理 token
    await _saveUser(user); // may throw (High-3: 检查返回值)
    // 3. 持久化全部成功后，更新内存 state（UI 显示新用户）
    state = AuthState(user: user);
  }

  /// 保存编辑后的个人资料，并持久化到本地
  Future<void> updateProfile(UserModel updated) async {
    state = AuthState(user: updated);
    await _saveUser(updated);
  }

  /// 收到 2015 PASSWORD_CHANGE_REQUIRED 时，将本地用户态标记为需要改密
  ///
  /// 场景：服务端 mustChangePassword=true 但本地缓存为 false（状态漂移），
  /// 业务接口持续返回 2015。转为本地 mustChangePassword=true 并持久化，
  /// 触发 GoRouter refreshListenable 重定向到 /change-password。
  Future<void> markMustChangePassword() async {
    final user = state.user;
    if (user == null || user.mustChangePassword) return;
    final updated = user.copyWith(mustChangePassword: true);
    state = AuthState(user: updated);
    await _saveUser(updated);
    log('收到 2015，已标记本地 mustChangePassword=true', name: 'auth');
  }

  /// 修改密码（锁内 CAS + 原子 token 替换）
  ///
  /// P0-3 修复：CAS 在 [ApiClient.setSessionIfCurrent] 的锁内执行，
  /// 不是锁外。旧实现在锁外检查 gen+userId，排队期间新会话可提交，
  /// 旧操作在锁内仍会覆盖新会话。现在 CAS 移入锁内：
  ///   1. 快照 (gen, userId) —— 在锁外仅用于日志和返回值
  ///   2. 调用 setSessionIfCurrent(expectedGen, expectedUserId, ...)
  ///   3. setSessionIfCurrent 在锁内：若 gen 或 userId 已变 → 返回 false → 丢弃
  ///   4. 若返回 true → token 已在锁内原子写入
  ///
  /// 这消除了：
  ///   - 改密迟到响应覆盖新登录（跨账号串号）
  ///   - 1001 触发的 clearSession 排队后，迟到改密 setSession 复活凭证
  Future<({bool ok, String? error})> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    // 1. 快照请求发起时的 (generation, userId) —— 传给 setSessionIfCurrent 做锁内 CAS
    final genAtRequest = ApiClient.sessionGeneration;
    final userIdAtRequest = ApiClient.currentUserId;

    // 2. 调用 AuthService.changePassword（AuthApi 不持久化，仅返回新凭证）
    final result = await _auth.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (!result.ok || result.token == null || result.refreshToken == null) {
      return (ok: false, error: result.error ?? '改密失败');
    }

    // 3. 锁内 CAS + 原子写入：setSessionIfCurrent 在互斥锁内同时校验 gen+userId
    //    并写入 access+refresh。若排队期间发生了 login/logout（gen 或 userId 变化），
    //    CAS 失败，返回 false，调用方丢弃响应——不会覆盖新会话。
    try {
      final committed = await ApiClient.setSessionIfCurrent(
        expectedGen: genAtRequest,
        expectedUserId: userIdAtRequest,
        access: result.token!,
        refresh: result.refreshToken!,
      );
      if (!committed) {
        log('改密响应迟到，锁内 CAS 失败 (gen $genAtRequest→${ApiClient.sessionGeneration}, '
            'userId $userIdAtRequest→${ApiClient.currentUserId})，丢弃新 token', name: 'auth');
        return (ok: false, error: '会话已变更，请重新登录后修改密码');
      }
    } catch (e) {
      log('改密后持久化新 token 失败: $e', name: 'auth');
      return (ok: false, error: '凭证保存失败，请重新登录');
    }

    // 4. 仅更新 mustChangePassword 字段，不覆盖完整本地资料
    await clearMustChangePassword();
    return (ok: true, error: null);
  }

  /// 改密成功后清除强制改密标记
  ///
  /// 仅更新现有 user 的 mustChangePassword=false，不替换整个 user 对象。
  /// 调用时机：[changePassword] 返回成功后自动调用。
  Future<void> clearMustChangePassword() async {
    final user = state.user;
    if (user == null || !user.mustChangePassword) return;
    final updated = user.copyWith(mustChangePassword: false);
    state = AuthState(user: updated);
    await _saveUser(updated);
  }

  /// 退出登录：原子清空本地用户态、JWT 凭证与生物识别标记
  ///
  /// 用户主动登出使用无条件 [ApiClient.clearSession]——用户明确要求登出，
  /// 无论会话状态如何都应清除。这是安全的，因为：
  ///   - [changePassword] 使用 [ApiClient.setSessionIfCurrent]（锁内 CAS），
  ///     logout 的 clearSession 递增 gen 后，排队的迟到改密 setSessionIfCurrent
  ///     会在锁内 CAS 失败（gen 不匹配），不会复活凭证。
  ///   - 1001 触发的自动登出使用 [ApiClient.clearSessionIfCurrent]（锁内 CAS），
  ///     防止迟到 1001 清除新会话。
  ///
  /// 顺序：清 state → clearSession（递增 gen）→ saveUser(null) → 删生物识别标记。
  /// clearSession 递增 gen 后，在途的迟到响应都会被 ApiClient 忽略。
  Future<void> logout() async {
    // 1. 同步清空 state（UI 立即响应，不等待 IO）
    state = const AuthState();
    // 2. 原子清除 token（互斥锁内删 access+refresh，递增 gen 一次）
    await ApiClient.clearSession();
    // 3. 移除持久化 user（best-effort，失败不阻塞——token 已清，重启后仍是未登录）
    try {
      await _saveUser(null);
    } catch (e) {
      log('logout 清除持久化 user 失败（不阻塞，token 已清）: $e', name: 'auth');
    }
    // 4. 清除生物识别标记（best-effort）
    try {
      const secure = FlutterSecureStorage();
      await secure.delete(key: SecureKeys.biometricRole);
    } catch (e) {
      log('清除生物识别标记失败: $e', name: 'auth');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// 认证 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// 当前用户
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
