import 'dart:developer';
import 'dart:math' hide log;

import '../../../core/config/api_config.dart';
import '../../../data/models/models.dart';
import 'auth_api.dart';
import 'registered_user_store.dart';

/// 认证服务
///
/// 支持两种模式（通过 `ApiConfig.useMockAuth` 控制）：
///
/// **Mock 模式**：
/// 本地生成随机验证码、本地存储用户，无需后端即可运行。
/// 验证码会以「演示验证码：xxxxxx」的形式在 UI 提示。
///
/// **真实 API 模式**（`USE_MOCK_AUTH=false`）：
/// 通过 `AuthApi` 调用后端 `/users/send-sms`、`/users/sms-login` 等接口。
///
/// 接入方式：
/// ```powershell
/// flutter run --dart-define=USE_MOCK_AUTH=false --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// ```
class AuthService {
  const AuthService();

  /// 是否处于 Mock 模式
  bool get _isMock => ApiConfig.useMockAuth;

  /// 清理过期验证码，避免 _pending Map 无限增长
  void _purgeExpired() {
    final now = DateTime.now();
    _pending.removeWhere((_, v) => now.isAfter(v.expiresAt));
  }

  /// 向手机号下发验证码
  ///
  /// Mock 模式：返回本地随机 6 位码，UI 会提示用户。
  /// 真实模式：调用后端 `/users/send-sms`，验证码由后端真实发送到手机。
  Future<({String code, String? error})> requestCode(String phone) async {
    if (_isMock) return _mockRequestCode(phone);
    return _realRequestCode(phone);
  }

  Future<({String code, String? error})> _mockRequestCode(String phone) {
    _purgeExpired(); // 每次请求前顺手清理过期条目
    final p = phone.trim();
    if (!_isValidPhone(p)) {
      return Future.value((code: '', error: '请输入有效的手机号'));
    }
    final code = _randomCode();
    _pending[p] = _PendingCode(
      code: code,
      expiresAt: DateTime.now().add(_codeTtl),
    );
    return Future.value((code: code, error: null));
  }

  Future<({String code, String? error})> _realRequestCode(String phone) async {
    final api = AuthApi();
    final result = await api.sendSms(phone);
    return switch (result) {
      SmsSendOk() => (code: '', error: null),
      SmsSendFail(:final message) => (code: '', error: message),
    };
  }

  /// 校验手机号验证码
  ///
  /// Mock 模式：校验本地缓存。
  /// 真实模式：验证码由后端校验，前端无需此方法。
  bool verifyCode(String phone, String code) {
    if (_isMock) {
      return _mockVerifyCode(phone, code);
    }
    // 真实模式下，验证码由后端校验，前端不保存验证码状态
    return true;
  }

  bool _mockVerifyCode(String phone, String code) {
    final p = phone.trim();
    final pending = _pending[p];
    if (pending == null) return false;
    if (DateTime.now().isAfter(pending.expiresAt)) {
      _pending.remove(p);
      return false;
    }
    return pending.code == code.trim();
  }

  /// 注册
  ///
  /// Mock 模式：本地存储用户到 SharedPreferences。
  /// 真实模式：调用后端 `/users/register`。
  Future<({UserModel? user, String? error})> register({
    required String phone,
    required String code,
    required String username,
    required String password,
    required UserRole role,
  }) async {
    if (_isMock) {
      return _mockRegister(phone, code, username, password, role);
    }
    return _realRegister(phone, code, username, password, role);
  }

  Future<({UserModel? user, String? error})> _mockRegister(
    String phone,
    String code,
    String username,
    String password,
    UserRole role,
  ) async {
    if (!_mockVerifyCode(phone, code)) {
      return (user: null, error: '验证码错误、已过期或未获取');
    }
    final store = RegisteredUserStore();
    if (await store.existsByUsername(username.trim())) {
      return (user: null, error: '该用户名已被注册，请更换');
    }
    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch,
      username: username.trim(),
      realName: username.trim(),
      role: role,
      password: password,
      contact: phone.trim(),
      needsProfileCompletion: false,
    );
    await store.save(user);
    _pending.remove(phone.trim());
    return (user: user, error: null);
  }

  Future<({UserModel? user, String? error})> _realRegister(
    String phone,
    String code,
    String username,
    String password,
    UserRole role,
  ) async {
    final api = AuthApi();
    final result = await api.register(
      phone: phone,
      code: code,
      username: username,
      password: password,
      role: role,
    );
    return switch (result) {
      RegisterOk(:final user) => (user: user, error: null),
      RegisterFail(:final message) => (user: null, error: message),
    };
  }

  /// 更新个人资料
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_isMock) return true;
    final authApi = AuthApi();
    final resp = await authApi.updateProfile(data);
    if (!resp.isSuccess) {
      log('updateProfile failed: ${resp.message}', name: 'auth_service');
      return false;
    }
    return true;
  }

  /// 账号密码登录
  ///
  /// Mock 模式：全部放行，任意账号密码均可登录。
  /// 真实模式：调用后端 `/users/password-login`。
  Future<({UserModel? user, String? error})> loginByPassword({
    required String account,
    required String password,
    required UserRole role,
  }) async {
    if (_isMock) {
      return _mockLoginByPassword(account, password, role);
    }
    return _realLoginByPassword(account, password, role);
  }

  Future<({UserModel? user, String? error})> _mockLoginByPassword(
    String account,
    String password,
    UserRole role,
  ) async {
    final a = account.trim();
    if (a.isEmpty || password.isEmpty) {
      return (user: null, error: '请输入账号和密码');
    }
    final store = RegisteredUserStore();
    UserModel? user = await store.findByUsername(a);
    user ??= await store.findByContact(a);
    if (user != null) {
      return (user: user.copyWith(role: role), error: null);
    }
    return (
      user: UserModel(
        id: DateTime.now().millisecondsSinceEpoch,
        username: a,
        realName: a,
        role: role,
        password: password,
        contact: '',
        needsProfileCompletion: false,
      ),
      error: null,
    );
  }

  Future<({UserModel? user, String? error})> _realLoginByPassword(
    String account,
    String password,
    UserRole role,
  ) async {
    final api = AuthApi();
    final result = await api.loginByPassword(
      account: account,
      password: password,
      role: role,
    );
    return switch (result) {
      PasswordLoginOk(:final user) => (user: user, error: null),
      PasswordLoginFail(:final message) => (user: null, error: message),
    };
  }

  /// 验证码登录
  ///
  /// Mock 模式：全部放行，任意验证码均可登录。
  /// 真实模式：调用后端 `/users/sms-login`。
  Future<({UserModel? user, String? error})> loginByCode({
    required String phone,
    required String code,
    required UserRole role,
  }) async {
    if (_isMock) {
      return _mockLoginByCode(phone, code, role);
    }
    return _realLoginByCode(phone, code, role);
  }

  Future<({UserModel? user, String? error})> _mockLoginByCode(
    String phone,
    String code,
    UserRole role,
  ) async {
    final p = phone.trim();
    if (p.isEmpty) {
      return (user: null, error: '请输入手机号');
    }
    final store = RegisteredUserStore();
    UserModel? user = await store.findByContact(p);
    if (user != null) {
      return (user: user.copyWith(role: role), error: null);
    }
    return (
      user: UserModel(
        id: DateTime.now().millisecondsSinceEpoch,
        username: p,
        realName: p,
        role: role,
        password: '',
        contact: p,
        needsProfileCompletion: false,
      ),
      error: null,
    );
  }

  Future<({UserModel? user, String? error})> _realLoginByCode(
    String phone,
    String code,
    UserRole role,
  ) async {
    final api = AuthApi();
    final result = await api.loginBySms(phone, code, role: role);
    return switch (result) {
      SmsLoginOk(:final user) => (user: user, error: null),
      SmsLoginFail(:final message) => (user: null, error: message),
    };
  }
}

class _PendingCode {
  const _PendingCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

final Map<String, _PendingCode> _pending = {};
const Duration _codeTtl = Duration(minutes: 5);

String _randomCode() {
  final r = Random();
  return (100000 + r.nextInt(900000)).toString();
}

bool _isValidPhone(String phone) => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);