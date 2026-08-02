import 'dart:math';

import '../../../data/models/models.dart';
import 'registered_user_store.dart';

/// 本地演示用认证服务
///
/// 实现「手机号验证码」真实闸门：下发**随机 6 位码**（5 分钟时效），注册 / 验证码登录
/// 必须校验一致，错码、过期码、未获取码一律拦截。
///
/// ⚠️ 当前为演示实现：验证码不会真正发到手机，UI 会以「演示验证码：xxxxxx」提示用户。
/// 接入真实后端时，只需把本文件中的 [requestCode] / [verifyCode] / [register] /
/// [loginByPassword] / [loginByCode] 替换为对 [AuthApi]（62.234.12.214:8883）的调用即可，
/// 上层 UI 无需改动。
class AuthService {
  const AuthService();

  static const Duration _codeTtl = Duration(minutes: 5);
  static final Map<String, _PendingCode> _pending = {};

  /// 报告条目: P3 #4 — 主动清理过期验证码，避免 _pending Map 无限增长
  void _purgeExpired() {
    final now = DateTime.now();
    _pending.removeWhere((_, v) => now.isAfter(v.expiresAt));
  }

  /// 向手机号下发验证码（演示：返回真实随机码，由 UI 提示用户）
  ///
  /// 返回 `(code, error)`：error 非空表示失败（如手机号非法）。
  ({String code, String? error}) requestCode(String phone) {
    _purgeExpired(); // 报告条目: P3 #4 — 每次请求前顺手清理过期条目
    final p = phone.trim();
    if (!_isValidPhone(p)) {
      return (code: '', error: '请输入有效的手机号');
    }
    final code = _randomCode();
    _pending[p] = _PendingCode(
      code: code,
      expiresAt: DateTime.now().add(_codeTtl),
    );
    return (code: code, error: null);
  }

  /// 校验手机号验证码（错误 / 过期 / 未获取均返回 false）
  bool verifyCode(String phone, String code) {
    final p = phone.trim();
    final pending = _pending[p];
    if (pending == null) return false;
    if (DateTime.now().isAfter(pending.expiresAt)) {
      _pending.remove(p);
      return false;
    }
    return pending.code == code.trim();
  }

  /// 注册：必须已通过手机号验证码校验
  ///
  /// 返回 `(user, error)`：error 非空表示失败（验证码错误 / 用户名已存在）。
  Future<({UserModel? user, String? error})> register({
    required String phone,
    required String code,
    required String username,
    required String password,
    required UserRole role,
  }) async {
    if (!verifyCode(phone, code)) {
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

  /// 账号密码登录（account 可为用户名或手机号）
  ///
  /// ⚠️ 测试模式：全部放行，任意账号密码均可登录。
  /// 恢复正式逻辑时，将下方直接 return 的代码替换为注释中的原始逻辑即可。
  Future<({UserModel? user, String? error})> loginByPassword({
    required String account,
    required String password,
    required UserRole role,
  }) async {
    final a = account.trim();
    if (a.isEmpty || password.isEmpty) {
      return (user: null, error: '请输入账号和密码');
    }
    // 先查已注册用户，命中则用真实数据（密码不校验）
    final store = RegisteredUserStore();
    UserModel? user = await store.findByUsername(a);
    user ??= await store.findByContact(a);
    if (user != null) {
      // 已注册用户：不校验密码，直接放行，但角色跟所选身份走
      return (user: user.copyWith(role: role), error: null);
    }
    // 未注册用户：即时创建临时账号，全部放行
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

    // ── 原始正式逻辑（恢复时取消注释）──
    // final store = RegisteredUserStore();
    // UserModel? user = await store.findByUsername(a);
    // user ??= await store.findByContact(a);
    // if (user == null) return (user: null, error: '账号不存在，请先注册');
    // if (user.password != password) {
    //   return (user: null, error: '密码错误');
    // }
    // return (user: user, error: null);
  }

  /// 验证码登录（手机号 + 码）
  ///
  /// ⚠️ 测试模式：全部放行，任意验证码均可登录。
  /// 恢复正式逻辑时，将下方直接 return 的代码替换为注释中的原始逻辑即可。
  Future<({UserModel? user, String? error})> loginByCode({
    required String phone,
    required String code,
    required UserRole role,
  }) async {
    final p = phone.trim();
    if (p.isEmpty) {
      return (user: null, error: '请输入手机号');
    }
    // 先查已注册用户，命中则用真实数据（验证码不校验）
    final store = RegisteredUserStore();
    UserModel? user = await store.findByContact(p);
    if (user != null) {
      return (user: user.copyWith(role: role), error: null);
    }
    // 未注册手机号：即时创建临时账号，全部放行
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

    // ── 原始正式逻辑（恢复时取消注释）──
    // if (!verifyCode(phone, code)) {
    //   return (user: null, error: '验证码错误、已过期或未获取');
    // }
    // final store = RegisteredUserStore();
    // final user = await store.findByContact(phone.trim());
    // if (user == null) {
    //   return (user: null, error: '该手机号尚未注册');
    // }
    // _pending.remove(phone.trim());
    // return (user: user, error: null);
  }
}

class _PendingCode {
  const _PendingCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

String _randomCode() {
  final r = Random();
  return (100000 + r.nextInt(900000)).toString();
}

bool _isValidPhone(String phone) => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
