import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null;
  bool get isStudent => user?.isStudent ?? false;
  bool get isTeacher => user?.isTeacher ?? false;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    // Simulate API call — in production, this uses dio to POST /api/v1/auth/login
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock login: prefix determines role
    if (username.isEmpty || password.isEmpty) {
      state = state.copyWith(isLoading: false, error: '请输入用户名和密码');
      return;
    }

    final isTeacher = username.startsWith('t_');
    final role = isTeacher ? 1 : 0;

    final user = UserModel(
      id: 1,
      username: username,
      realName: isTeacher ? '张教授' : '李同学',
      role: role,
      classId: isTeacher ? null : 2024001,
      auditStatus: isTeacher ? 2 : 0, // teacher auto-passed for demo
      status: 0,
      token: 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
    );

    // Save token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', user.token);
    await prefs.setInt('user_role', user.role);

    state = AuthState(user: user);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    state = const AuthState();
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final role = prefs.getInt('user_role');

    if (token != null && role != null) {
      // In production, validate token with server
      final user = UserModel(
        id: 1,
        username: role == 1 ? 't_teacher' : 'student',
        realName: role == 1 ? '张教授' : '李同学',
        role: role,
        classId: role == 1 ? null : 2024001,
        auditStatus: 2,
        status: 0,
        token: token,
      );
      state = AuthState(user: user);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
