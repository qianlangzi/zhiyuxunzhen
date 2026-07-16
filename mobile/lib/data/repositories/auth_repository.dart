import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../models/user_model.dart';
import '../sources/mock_data.dart';

/// 登录 / 登录态持久化
class AuthRepository {
  AuthRepository(this._prefs);

  final SharedPreferences _prefs;

  /// 登录：当前阶段使用 mock 校验
  /// 后续接入：dio.post('/v1/user/login', {username, password})
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    // 模拟网络延迟
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final bool ok = MockData.verifyDemo(username, password);
    if (!ok) {
      throw AuthException('账号或密码错误，演示账号见登录页');
    }

    final UserModel? user = MockData.userFor(username);
    if (user == null) {
      throw AuthException('账号未识别');
    }

    if (user.role != AppConfig.roleStudent &&
        user.role != AppConfig.roleTeacher) {
      throw AuthException('当前账号需使用 Web 管理端登录');
    }

    final String token = 'mock-${username}-token';
    await _prefs.setString(AppConfig.kToken, token);
    await _prefs.setString(AppConfig.kUsername, username);
    await _prefs.setInt(AppConfig.kRole, user.role);

    return LoginResult(token: token, username: username, role: user.role);
  }

  Future<void> logout() async {
    await _prefs.remove(AppConfig.kToken);
    await _prefs.remove(AppConfig.kUsername);
    await _prefs.remove(AppConfig.kRole);
  }

  UserModel? current() {
    final String? token = _prefs.getString(AppConfig.kToken);
    final String? username = _prefs.getString(AppConfig.kUsername);
    final int? role = _prefs.getInt(AppConfig.kRole);
    if (token == null || username == null || role == null) return null;
    return MockData.userFor(username) ??
        UserModel(
          id: username.hashCode,
          username: username,
          displayName: username,
          role: role,
        );
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((ProviderRef<SharedPreferences> ref) {
  throw UnimplementedError('必须在 main.dart 中通过 ProviderScope.overrides 注入');
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ProviderRef<AuthRepository> ref) {
  return AuthRepository(ref.watch(sharedPreferencesProvider));
});
