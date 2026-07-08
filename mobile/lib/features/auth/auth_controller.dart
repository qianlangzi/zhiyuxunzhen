import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

/// 登录态
class AuthState {
  const AuthState({
    this.user,
    this.loading = false,
    this.error,
  });

  final UserModel? user;
  final bool loading;
  final String? error;

  bool get isLoggedIn => user != null;
  bool get isStudent => user?.isStudent ?? false;
  bool get isTeacher => user?.isTeacher ?? false;

  AuthState copyWith({
    UserModel? user,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(AuthState(user: _repo.current()));

  final AuthRepository _repo;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.login(username: username, password: password);
      final UserModel? user = _repo.current();
      state = AuthState(user: user, loading: false);
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: '登录失败：$e');
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// AuthController Provider
final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
        (StateNotifierProviderRef<AuthController, AuthState> ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// 便捷角色判断
final Provider<bool> isStudentProvider = Provider<bool>((ProviderRef<bool> ref) {
  return ref.watch(authControllerProvider).isStudent;
});

final Provider<bool> isTeacherProvider = Provider<bool>((ProviderRef<bool> ref) {
  return ref.watch(authControllerProvider).isTeacher;
});

/// 路由守卫使用：返回当前角色，未登录返回 -1
final Provider<int> currentRoleProvider = Provider<int>((ProviderRef<int> ref) {
  final int? role = ref.watch(authControllerProvider).user?.role;
  if (role == null) return -1;
  if (role != AppConfig.roleStudent && role != AppConfig.roleTeacher) return -1;
  return role;
});
