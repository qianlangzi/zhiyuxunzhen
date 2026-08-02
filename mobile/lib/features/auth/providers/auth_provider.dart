import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';

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
}

/// 认证状态管理
class AuthNotifier extends StateNotifier<AuthState> {
  static const _userKey = 'auth_user';

  /// 报告条目: P0 #1 — 初始态设为 isLoading=true，路由 redirect 放行
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _initFuture = _loadUser();
  }

  late final Future<void> _initFuture;

  /// 等待初始化完成（供 main() 预热调用，避免 redirect 竞态）。
  /// 报告条目: P0 #1
  Future<void> ensureInitialized() => _initFuture;

  /// 从本地缓存恢复登录用户
  ///
  /// 加载完成后必须将 [AuthState.isLoading] 置为 false，
  /// 否则路由 redirect 会一直认为「加载中」而放行到 /login。
  /// 报告条目: P0 #1
  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        state = const AuthState(); // isLoading 默认 false
        return;
      }
      final user = UserModel.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      state = AuthState(user: user); // isLoading 默认 false
    } catch (e) {
      log('恢复本地用户失败: $e', name: 'auth');
      state = const AuthState(); // 异常时也标记加载完成
    }
  }

  /// 将用户数据持久化到本地
  Future<void> _saveUser(UserModel? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user == null) {
        await prefs.remove(_userKey);
        return;
      }
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      log('保存本地用户失败: $e', name: 'auth');
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
  /// 与 [loginAsStudent]/[loginAsTeacher] 的区别在于用户来自真实流程而非内置 mock。
  ///
  /// 报告条目: P2 #3 — 改为 async，await _saveUser 防止登录态丢失
  Future<void> loginWith(UserModel user) async {
    state = AuthState(user: user);
    await _saveUser(user);
  }

  /// 保存编辑后的个人资料，并持久化到本地
  Future<void> updateProfile(UserModel updated) async {
    state = AuthState(user: updated);
    await _saveUser(updated);
  }

  /// 退出登录：清空本地用户态，并让生物识别快速登录失效
  Future<void> logout() async {
    state = const AuthState();
    await _saveUser(null);
    try {
      const secure = FlutterSecureStorage();
      await secure.delete(key: SecureKeys.biometricRole);
    } catch (e) {
      log('清除生物识别标记失败: $e', name: 'auth');
    }
  }

  /// 报告条目: P2 #11 — 覆写 dispose 作为扩展点
  @override
  void dispose() {
    // 当前无需显式释放资源；未来若持有 StreamSubscription / Timer 等在此释放
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
