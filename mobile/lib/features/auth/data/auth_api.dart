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
  const SmsLoginOk(this.user, {this.token});

  /// 后端返回的用户信息
  final UserModel user;

  /// 可选的 JWT / session token（后端若返回则保存，后续请求带在 Header 里）
  final String? token;
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
  const PasswordLoginOk(this.user, {this.token});
  final UserModel user;
  final String? token;
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
  const RegisterOk(this.user, {this.token});

  final UserModel user;

  /// 学生注册成功后后端直接返回的 token（请为空则需手动登录，如教师待审核）
  final String? token;
}

class RegisterFail extends RegisterResult {
  const RegisterFail(this.message);
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
      final code = data['code'] ?? 0;
      if (code != 0) return null;
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
      final code = data['code'] ?? data['error_code'] ?? 0;
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

      final code = data['code'] ?? data['error_code'] ?? 0;
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
      if (parsed.token != null) ApiClient.setToken(parsed.token);
      return SmsLoginOk(parsed.user, token: parsed.token);
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
      final code = data['code'] ?? data['error_code'] ?? 0;
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
      if (parsed.token != null) ApiClient.setToken(parsed.token);
      return PasswordLoginOk(parsed.user, token: parsed.token);
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
      final code = data['code'] ?? data['error_code'] ?? 0;
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
      // 学生注册成功后后端返回 token，拿到后立即写入，供主页直接使用
      if (parsed.token != null && parsed.token!.isNotEmpty) {
        ApiClient.setToken(parsed.token);
      }
      return RegisterOk(parsed.user, token: parsed.token);
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
      final code = data['code'] ?? 0;
      if (code != 0) {
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

  bool _isSuccessCode(dynamic code) {
    if (code == null) return true; // 无 code 字段时默认成功
    if (code is int) return code == 0 || code == 200;
    if (code is String) return code == '0' || code == '200' || code == 'ok';
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
      DioExceptionType.badResponse => '服务器响应异常：${e.response?.statusCode}',
      _ => e.message ?? '$action失败',
    };
  }
}

/// 解析后端登录响应，兼容多种常见 JSON 结构
///
/// 1. { token, refreshToken, userId, username, realName, role, ... }  ← 后端 LoginResponse 平铺格式
/// 2. { token, user: { ... } }
/// 3. { accessToken, user: { ... } }
/// 4. { data: { token, user } }
/// 5. 直接把 user 对象放在 payload 根上
/// 6. JWT 字符串（纯 token）
({UserModel user, String? token})? _parseLoginPayload(
  dynamic payload, {
  required String phone,
  UserRole? role,
}) {
  if (payload is String && payload.isNotEmpty) {
    // 简单 JWT 字符串识别：三段 base64 用 . 分隔
    if (payload.split('.').length == 3) {
      return (
        user: _fallbackUser(phone, role: role),
        token: payload,
      );
    }
    return null;
  }
  if (payload is! Map<String, dynamic>) return null;

  String? token;
  UserModel? user;

  token ??= payload['token']?.toString();
  token ??= payload['accessToken']?.toString();
  token ??= payload['access_token']?.toString();

  // 优先尝试后端 LoginResponse 平铺格式：{ userId, username, realName, role, ... }
  if (payload.containsKey('userId') || payload.containsKey('user_id')) {
    final id = (payload['userId'] ?? payload['user_id'] ?? 0) as int;
    final username = (payload['username'] ?? phone) as String;
    final realName = (payload['realName'] ?? payload['real_name'] ?? username) as String;
    final roleVal = payload['role'] as int?;
    final auditStatus = (payload['auditStatus'] ?? payload['audit_status'] ?? 0) as int;
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

  // 若后端没返回完整 user，则把 phone/role 组合成兜底用户，并标记需完善资料
  user ??= _fallbackUser(phone, role: role, needsCompletion: true);

  return (user: user, token: token);
}

UserModel _fallbackUser(
  String phone, {
  UserRole? role,
  bool needsCompletion = true,
}) {
  return UserModel(
    id: DateTime.now().millisecondsSinceEpoch,
    username: phone,
    realName: '',
    role: role ?? UserRole.student,
    needsProfileCompletion: needsCompletion,
  );
}
