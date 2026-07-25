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

  AuthNotifier() : super(const AuthState()) {
    _loadUser();
  }

  /// 从本地缓存恢复登录用户
  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userKey);
      if (jsonStr == null || jsonStr.isEmpty) return;
      final user = UserModel.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      state = AuthState(user: user);
    } catch (e) {
      log('恢复本地用户失败: $e', name: 'auth');
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

  void loginAsStudent() {
    final user = UserModel.mockStudent();
    state = AuthState(user: user);
    _saveUser(user);
  }

  void loginAsTeacher() {
    final user = UserModel.mockTeacher();
    state = AuthState(user: user);
    _saveUser(user);
  }

  /// 以指定用户建立会话（注册 / 验证码登录 / 密码登录 通用入口）。
  /// 与 [loginAsStudent]/[loginAsTeacher] 的区别在于用户来自真实流程而非内置 mock。
  void loginWith(UserModel user) {
    state = AuthState(user: user);
    _saveUser(user);
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
}

/// 认证 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// 当前用户
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
