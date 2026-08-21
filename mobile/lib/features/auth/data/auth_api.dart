import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../data/models/models.dart';

/// 图形验证码数据（字母+数字图片，防盗刷）
///
/// 由 `GET /api/v1/auth/captcha` 返回，用户需从 [imageUrl] 处读取验证码图片
/// 并输入识别出的字符，供短信验证码接口防刷校验。
class CaptchaData {
  const CaptchaData({
    required this.captchaId,
    required this.imageUrl,
    required this.expiresIn,
  });

  /// 验证码唯一标识，提交短信接口时回传给后端
  final String captchaId;

  /// 验证码图片地址（`GET /api/v1/auth/captcha/{id}/image`）
  final String imageUrl;

  /// 有效期（秒）
  final int expiresIn;
}

/// 后端认证服务基础配置
///
/// 与截图中一致：App 端只把手机号/验证码发给自有后端，由后端去调用短信服务商。
/// 短信服务商的 key 不进入 App 代码。
class AuthApiConfig {
  const AuthApiConfig._();

  /// 后端 base URL（来自 ApiConfig，可通过 `--dart-define=API_BASE_URL=...` 注入）
  static const String baseUrl = ApiConfig.apiBaseUrl;

  /// 发送短信验证码
  static const String sendSms = '/api/v1/auth/sms-code';

  /// 短信验证码登录（老用户直接登录 / 新用户自动注册）
  static const String smsLogin = '/api/v1/auth/login/sms';

  /// 网络超时时间
  static const Duration timeout = Duration(seconds: 8);

  /// 重发冷却时间（秒）——由后端控制是否可重发，前端仅做 UI 倒计时
  static const int resendCooldownSeconds = 60;
}

/// 短信发送结果
sealed class SmsSendResult {
  const SmsSendResult();
}

class SmsSendOk extends SmsSendResult {
  const SmsSendOk();
}

class SmsSendFail extends SmsSendResult {
  const SmsSendFail(this.message);
  final String message;
}

/// 短信登录结果
sealed class SmsLoginResult {
  const SmsLoginResult();
}

class SmsLoginOk extends SmsLoginResult {
  const SmsLoginOk(this.user, {this.token, this.refreshToken});

  /// 后端返回的用户信息
  final UserModel user;

  /// 可选的 JWT / session token（后端若返回则保存，后续请求带在 Header 里）
  final String? token;

  /// 刷新 token，与 access token 成套持久化
  final String? refreshToken;
}

class SmsLoginFail extends SmsLoginResult {
  const SmsLoginFail(this.message);
  final String message;
}

/// 登录结果
sealed class PasswordLoginResult {
  const PasswordLoginResult();
}

class PasswordLoginOk extends PasswordLoginResult {
  const PasswordLoginOk(this.user, {this.token, this.refreshToken});
  final UserModel user;
  final String? token;
  final String? refreshToken;
}

class PasswordLoginFail extends PasswordLoginResult {
  const PasswordLoginFail(this.message);
  final String message;
}

/// 注册结果
sealed class RegisterResult {
  const RegisterResult();
}

class RegisterOk extends RegisterResult {
  const RegisterOk(this.user, {this.token, this.refreshToken});

  final UserModel user;

  /// 学生注册成功后后端直接返回的凭证对（为空则需手动登录，如教师待审核）。
  /// access+refresh 成对返回，供 AuthNotifier.loginWith 原子持久化。
  final String? token;
  final String? refreshToken;
}

class RegisterFail extends RegisterResult {
  const RegisterFail(this.message);
  final String message;
}

/// 修改密码结果
sealed class ChangePasswordResult {
  const ChangePasswordResult();
}

/// 改密成功：后端签发了新 token（携带递增后的 credentialVersion）。
/// AuthApi 不直接持久化 token，由 AuthNotifier 在代际 CAS 通过后原子替换。
/// 不携带 user：LoginResponse 字段可能少于本地完整资料，只用它覆盖 mustChangePassword
/// 会导致资料丢失；AuthNotifier 仅更新现有 user 的 mustChangePassword 字段。
class ChangePasswordOk extends ChangePasswordResult {
  const ChangePasswordOk({this.token, this.refreshToken});

  /// 新 access token（携带新凭证版本）
  final String? token;

  /// 新 refresh token（携带新凭证版本）
  final String? refreshToken;
}

class ChangePasswordFail extends ChangePasswordResult {
  const ChangePasswordFail(this.message);
  final String message;
}

/// 后端认证 API
///
/// 暴露方法：
/// - [sendSms]      → POST /users/send-sms
/// - [loginBySms]   → POST /users/sms-login
/// - [loginByPassword] → POST /users/password-login
/// - [register]     → POST /users/register
///
/// ⚠️ 密码登录和注册的接口路径/请求体格式为预设值，等你提供接口文档后调整。
class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  /// 报告条目: P3 #5 — 释放底层 HTTP 连接，防止资源泄漏
  /// 接入后端后若注册为 Riverpod Provider，在 ref.onDispose 中调用
  void dispose() {
    _dio.close();
  }

  /// 获取图形验证码（字母+数字图片，防盗刷）
  ///
  /// `GET /api/v1/auth/captcha` → `{code:0, data:{captchaId, expiresIn}}`
  /// 失败返回 null，由调用方决定重试策略。
  Future<CaptchaData?> getCaptcha() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/auth/captcha');
      final data = resp.data;
      if (data == null) return null;
      final code = data['code'];
      // P0-4 修复：严格 fail-closed，缺失 code 视为失败
      if (code is! int || code != 0) return null;
      final payload = data['data'] as Map<String, dynamic>?;
      if (payload == null) return null;
      final captchaId = payload['captchaId'] as String;
      return CaptchaData(
        captchaId: captchaId,
        imageUrl: '${AuthApiConfig.baseUrl}/api/v1/auth/captcha/$captchaId/image',
        expiresIn: payload['expiresIn'] as int? ?? 300,
      );
    } catch (_) {
      return null;
    }
  }

  /// 请求后端发送短信验证码
  ///
  /// 请求体包含手机号与图形验证码校验信息：后端先校验图形验证码，
  /// 通过才发短信。图形验证码校验失败返回 code=2011（CAPTCHA_INVALID）。
  Future<SmsSendResult> sendSms(
    String phone, {
    required String captchaId,
    required String captchaAnswer,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        AuthApiConfig.sendSms,
        data: {
          'phone': phone,
          'captchaId': captchaId,
          'captchaAnswer': captchaAnswer,
        },
      );
      final data = resp.data;
      if (data == null) {
        return const SmsSendFail('短信发送失败：服务端未返回数据');
      }
      // 兼容两种常见返回：{ code: 0, msg: 'ok' } 或 { error_code: 0, reason: 'ok' }
      // P0-4 修复：不默认 ?? 0，缺失 code 时 _isSuccessCode 返回 false（fail-closed）
      final code = data['code'] ?? data['error_code'];
      final msg = data['msg']?.toString() ??
          data['message']?.toString() ??
          data['reason']?.toString() ??
          '短信发送失败';
      if (_isSuccessCode(code)) return const SmsSendOk();
      return SmsSendFail(msg);
    } on DioException catch (e) {
      return SmsSendFail(_mapDioError(e, '短信发送'));
    } catch (e) {
      log('sendSms 异常: $e', name: 'auth_api');
      return SmsSendFail('短信发送失败：$e');
    }
  }

  /// 短信验证码登录
  ///
  /// 老用户：后端返回已有用户信息；新用户：后端自动注册并返回新用户信息。
  /// [role] 在注册流程中传入，方便后端记录角色（后端可忽略）。
  Future<SmsLoginResult> loginBySms(
    String phone,
    String code, {
    UserRole? role,
  }) async {
    final body = <String, dynamic>{'phone': phone, 'code': code};
    if (role != null) body['role'] = role.name;

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        AuthApiConfig.smsLogin,
        data: body,
      );
      final data = resp.data;
      if (data == null) {
        return const SmsLoginFail('登录失败：服务端未返回数据');
      }

      final code = data['code'] ?? data['error_code'];
      final msg = data['msg']?.toString() ??
          data['message']?.toString() ??
          data['reason']?.toString() ??
          '登录失败';
      if (!_isSuccessCode(code)) {
        return SmsLoginFail(msg);
      }

      // 取出业务数据：可能是 response.data 本身，也可能是 data['data']
      final payload = data['data'] ?? data;

      final parsed = _parseLoginPayload(payload, phone: phone, role: role);
      if (parsed == null) {
        return const SmsLoginFail('登录失败：无法解析用户信息');
      }
      // P1：token 不在此处持久化，由 AuthNotifier 在角色校验通过后原子提交，
      // 避免角色不匹配时无效 token 残留在 secure storage
      return SmsLoginOk(parsed.user,
          token: parsed.token, refreshToken: parsed.refreshToken);
    } on DioException catch (e) {
      return SmsLoginFail(_mapDioError(e, '登录'));
    } catch (e) {
      log('loginBySms 异常: $e', name: 'auth_api');
      return SmsLoginFail('登录失败：$e');
    }
  }

  /// 账号密码登录
  ///
  /// ⚠️ 接口路径/请求体为预设值，等你提供接口文档后调整。
  Future<PasswordLoginResult> loginByPassword({
    required String account,
    required String password,
    UserRole? role,
  }) async {
    final body = <String, dynamic>{
      'username': account,
      'password': password,
    };
    if (role != null) body['role'] = role.name;

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login/password',
        data: body,
      );
      final data = resp.data;
      if (data == null) {
        return const PasswordLoginFail('登录失败：服务端未返回数据');
      }
      final code = data['code'] ?? data['error_code'];
      final msg = data['msg']?.toString() ??
          data['message']?.toString() ??
          data['reason']?.toString() ??
          '登录失败';
      if (!_isSuccessCode(code)) {
        return PasswordLoginFail(msg);
      }
      final payload = data['data'] ?? data;
      final parsed = _parseLoginPayload(payload, phone: account, role: role);
      if (parsed == null) {
        return const PasswordLoginFail('登录失败：无法解析用户信息');
      }
      // P1：token 不在此处持久化，由 AuthNotifier 在角色校验通过后原子提交，
      // 避免角色不匹配时无效 token 残留在 secure storage
      return PasswordLoginOk(parsed.user,
          token: parsed.token, refreshToken: parsed.refreshToken);
    } on DioException catch (e) {
      return PasswordLoginFail(_mapDioError(e, '登录'));
    } catch (e) {
      log('loginByPassword 异常: $e', name: 'auth_api');
      return PasswordLoginFail('登录失败：$e');
    }
  }

  /// 注册
  ///
  /// 新增字段：realName（姓名，回退 username）、schoolName、grade、className、
  /// certificateNo、department、teacherCertificateImage（教师资质证书图片路径）。
  /// 仅非空字段会加入请求体。
  Future<RegisterResult> register({
    required String phone,
    required String code,
    required String username,
    required String password,
    UserRole? role,
    String? realName,
    String? schoolName,
    String? grade,
    String? className,
    String? certificateNo,
    String? department,
    String? teacherCertificateImage,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'code': code,
      'username': username,
      'password': password,
      'realName': realName ?? username,
      'role': role?.value ?? 0,
    };
    if (schoolName != null) body['schoolName'] = schoolName;
    if (grade != null) body['grade'] = grade;
    if (className != null) body['className'] = className;
    if (certificateNo != null) body['certificateNo'] = certificateNo;
    if (department != null) body['department'] = department;
    if (teacherCertificateImage != null) {
      body['teacherCertificateImage'] = teacherCertificateImage;
    }

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: body,
      );
      final data = resp.data;
      if (data == null) {
        return const RegisterFail('注册失败：服务端未返回数据');
      }
      final code = data['code'] ?? data['error_code'];
      final msg = data['msg']?.toString() ??
          data['message']?.toString() ??
          data['reason']?.toString() ??
          '注册失败';
      if (!_isSuccessCode(code)) {
        return RegisterFail(msg);
      }
      final payload = data['data'] ?? data;
      final parsed = _parseLoginPayload(payload, phone: phone, role: role);
      if (parsed == null) {
        return const RegisterFail('注册失败：无法解析用户信息');
      }
      // 注册凭证不在此持久化（AuthApi 分层约定）：凭证对上抛给
      // AuthNotifier.loginWith，经角色校验后由 ApiClient.setSession 原子写入
      return RegisterOk(parsed.user,
          token: parsed.token, refreshToken: parsed.refreshToken);
    } on DioException catch (e) {
      return RegisterFail(_mapDioError(e, '注册'));
    } catch (e) {
      log('register 异常: $e', name: 'auth_api');
      return RegisterFail('注册失败：$e');
    }
  }

  /// 更新个人资料
  Future<ApiResponse<Map<String, dynamic>>> updateProfile(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>('/api/v1/auth/me', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapDioError(e, '更新资料'));
    }
  }

  /// 上传教师资质证书
  ///
  /// `POST /api/v1/auth/upload`（multipart/form-data，字段名 `file`）
  /// 仅支持 jpg/jpeg/png/pdf，最大 5MB。
  /// 成功返回 `(url: 路径, error: null)`，失败返回 `(url: null, error: 原因)`。
  Future<({String? url, String? error})> uploadCertificate(File file) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(RegExp(r'[/\\]')).last,
        ),
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/upload',
        data: form,
      );
      final data = resp.data;
      if (data == null) return (url: null, error: '上传失败：服务端未返回数据');
      final code = data['code'];
      // P0-4 修复：严格 fail-closed，缺失 code 视为失败
      if (code is! int || code != 0) {
        final msg = data['message']?.toString() ?? '上传失败';
        return (url: null, error: msg);
      }
      final payload = data['data'] as Map<String, dynamic>?;
      final url = payload?['url']?.toString();
      if (url == null) return (url: null, error: '上传失败：未返回路径');
      return (url: url, error: null);
    } on DioException catch (e) {
      return (url: null, error: _mapDioError(e, '上传'));
    } catch (e) {
      return (url: null, error: '上传失败：$e');
    }
  }

  /// 修改密码
  ///
  /// 对接后端 `PUT /api/v1/auth/password`，请求体 `{oldPassword, newPassword}`，
  /// 响应 `R<LoginResponse>`（code=0 成功，data 含新 access/refresh token）。
  /// 后端业务规则：
  /// - 校验旧密码正确性（错误码 1422 VALIDATION_FAILED + message「原密码不正确」）
  /// - 拒绝新密码与旧密码相同（错误码 2014 PASSWORD_SAME_AS_OLD）
  /// - 强制 8-32 位、字母+数字混合
  /// - CAS 并发控制：旧密码 hash 已被并发请求修改时返回 1422
  ///
  /// 改密成功后：
  /// 1. 后端签发新 token（携带递增后的 credentialVersion）
  /// 2. 本方法仅返回新 token，不直接持久化——由 AuthNotifier 在代际 CAS 通过后原子替换
  /// 3. 不返回 user：LoginResponse 字段可能少于本地完整资料，覆盖会导致资料丢失
  ///
  /// Issue1 P0：安全敏感操作严格要求 code === 0，缺失 code 字段视为失败。
  /// 若响应缺少 token/refreshToken，视为失败（后端必须返回新凭证）。
  Future<ChangePasswordResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/auth/password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      final data = resp.data;
      if (data == null) {
        return const ChangePasswordFail('修改失败：服务端未返回数据');
      }
      final code = data['code'];
      // 严格判断：仅 code === 0 视为成功，缺失或非 0 一律失败
      if (code is! int || code != 0) {
        final msg = data['message']?.toString() ??
            data['msg']?.toString() ??
            '修改失败';
        // 专用错误码给更友好的提示
        if (code == 2014) {
          return const ChangePasswordFail('新密码不能与旧密码相同');
        }
        return ChangePasswordFail(msg);
      }
      // 解析后端返回的新 LoginResponse，仅提取 token/refreshToken
      // 不提取 user：避免用字段较少的 LoginResponse 覆盖完整本地资料
      final payload = data['data'] ?? data;
      final String? newToken = payload['token']?.toString() ??
          payload['accessToken']?.toString();
      final String? newRefresh = payload['refreshToken']?.toString() ??
          payload['refresh_token']?.toString();
      // 改密成功但后端未返回新 token → 视为失败，客户端无法替换旧凭证
      if (newToken == null || newRefresh == null) {
        log('改密成功但响应缺少 token: token=${newToken != null} refresh=${newRefresh != null}', name: 'auth_api');
        return const ChangePasswordFail('改密成功但未返回新凭证，请重新登录');
      }
      return ChangePasswordOk(token: newToken, refreshToken: newRefresh);
    } on DioException catch (e) {
      return ChangePasswordFail(_mapDioError(e, '修改密码'));
    } catch (e) {
      log('changePassword 异常: $e', name: 'auth_api');
      return ChangePasswordFail('修改失败：$e');
    }
  }

  /// P0-4 修复：fail-closed 成功码判断
  /// 缺失 code 字段（null）视为失败，仅 code=0（int）/ '0'（String）视为成功。
  /// 旧实现将 null 视为成功且兼容 200/'ok'，导致后端异常响应被误判为登录成功。
  bool _isSuccessCode(dynamic code) {
    if (code == null) return false;
    if (code is int) return code == 0;
    if (code is String) return code == '0';
    return false;
  }

  String _mapDioError(DioException e, String action) {
    log('$action DioException: ${e.message}', name: 'auth_api');
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '网络超时，请稍后重试',
      DioExceptionType.connectionError => '无法连接服务器，请检查网络',
      // Issue1：HTTP 400/422 等结构化错误应解析后端 message，而非只显示状态码
      DioExceptionType.badResponse => _badResponseMessage(e) ?? '服务器响应异常：${e.response?.statusCode}',
      _ => e.message ?? '$action失败',
    };
  }

  /// 从 DioException 的 response 中提取后端业务 message
  ///
  /// 后端统一返回 `{ code, message, data }`，HTTP 4xx 时 message 字段含可读错误原因。
  /// ApiClient.onResponse 在 code 1001/1002 时 reject 也会带 message。
  String? _badResponseMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? data['msg']?.toString();
    }
    return null;
  }
}

/// 解析后端登录响应，兼容多种常见 JSON 结构
///
/// 1. { token, refreshToken, userId, username, realName, role, ... }  ← 后端 LoginResponse 平铺格式
/// 2. { token, user: { ... } }
/// 3. { accessToken, user: { ... } }
/// 4. { data: { token, user } }
/// 5. 直接把 user 对象放在 payload 根上
///
/// P0-4 修复：移除 _fallbackUser 和纯 JWT 字符串解析。
/// - 纯 JWT 字符串不含用户信息，无法安全构建 user → 返回 null
/// - 后端未返回完整 user 时不再创建兜底用户 → 返回 null
/// 旧实现的 _fallbackUser 用 phone/timestamp 伪造 user，id=0 或 timestamp 可能与
/// 真实用户冲突，且让无 token 的「成功」响应进入认证状态，是身份混淆的根源。
({UserModel user, String? token, String? refreshToken})? _parseLoginPayload(
  dynamic payload, {
  required String phone,
  UserRole? role,
}) {
  // P0-4 修复：纯 JWT 字符串不含用户信息，无法安全构建 user → 返回 null
  if (payload is String) return null;
  if (payload is! Map<String, dynamic>) return null;

  String? token;
  String? refreshToken;
  UserModel? user;

  token ??= payload['token']?.toString();
  token ??= payload['accessToken']?.toString();
  token ??= payload['access_token']?.toString();
  refreshToken ??= payload['refreshToken']?.toString();
  refreshToken ??= payload['refresh_token']?.toString();

  // 优先尝试后端 LoginResponse 平铺格式：{ userId, username, realName, role, ... }
  if (payload.containsKey('userId') || payload.containsKey('user_id')) {
    final id = (payload['userId'] ?? payload['user_id'] ?? 0) as int;
    final username = (payload['username'] ?? phone) as String;
    final realName = (payload['realName'] ?? payload['real_name'] ?? username) as String;
    final roleVal = payload['role'] as int?;
    final auditStatus = (payload['auditStatus'] ?? payload['audit_status'] ?? 0) as int;
    // 后端 LoginResponse 顶层 mustChangePassword：导入学生首次登录为 true
    final mustChange = (payload['mustChangePassword'] as bool?) ??
        (payload['must_change_password'] as bool?) ??
        false;
    user = UserModel(
      id: id,
      username: username,
      realName: realName,
      role: roleVal != null
          ? UserRole.values.firstWhere(
              (e) => e.value == roleVal,
              orElse: () => role ?? UserRole.student,
            )
          : role ?? UserRole.student,
      auditStatus: auditStatus,
      mustChangePassword: mustChange,
    );
  }

  // 尝试嵌套 user 对象格式：{ user: { ... } }
  if (user == null) {
    final userJson = payload['user'] ?? payload['data']?['user'];
    if (userJson is Map<String, dynamic>) {
      try {
        user = UserModel.fromJson(userJson);
      } catch (e) {
        log('解析后端 user 失败: $e', name: 'auth_api');
      }
    }
  }

  // P0-4 修复：无法解析 user 时返回 null，不创建 fallback user
  // 调用方（loginBySms/loginByPassword/register）已处理 null → 返回 Fail
  if (user == null) {
    log('无法从响应中解析 user 信息，拒绝创建兜底用户 (phone=$phone)', name: 'auth_api');
    return null;
  }

  return (user: user, token: token, refreshToken: refreshToken);
}
