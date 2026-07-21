import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../models/user_model.dart';
import '../sources/api_client.dart';
import '../sources/api_exception.dart';
import '../sources/mock_data.dart';
import '../sources/token_store.dart';

class AuthRepository {
  AuthRepository(this._prefs, this._dio, this._tokenStore);

  final SharedPreferences _prefs;
  final Dio _dio;
  final TokenStore _tokenStore;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    if (AppConfig.mockEnabled) {
      return _mockLogin(username: username, password: password);
    }
    return _remoteLogin(
      path: '/api/v1/auth/login/password',
      body: <String, dynamic>{'username': username, 'password': password},
    );
  }

  Future<RegistrationResult> register({
    required String username,
    required String password,
    required String realName,
    required String phone,
    required String code,
    required int role,
    String? certificateNo,
    String? department,
  }) async {
    if (AppConfig.mockEnabled) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (username == 'student01' || username == 'teacher01') {
        throw AuthException('账号已存在');
      }
      return RegistrationResult(
        userId: 99,
        username: username,
        role: role,
        auditStatus: role == AppConfig.roleTeacher ? 1 : 0,
        message: role == AppConfig.roleTeacher
            ? '教师注册申请已提交，请等待管理员审核后登录'
            : '注册成功，请使用新账号登录',
      );
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/auth/register',
        data: <String, dynamic>{
          'username': username,
          'password': password,
          'realName': realName,
          'phone': phone,
          'code': code,
          'role': role,
          if (certificateNo != null) 'certificateNo': certificateNo,
          if (department != null) 'department': department,
        },
      );
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      return RegistrationResult(
        userId: _readInt(data, 'userId'),
        username: requireString(data, 'username'),
        role: _readInt(data, 'role'),
        auditStatus: _readInt(data, 'auditStatus'),
        message: requireString(data, 'message'),
      );
    } catch (error) {
      throw AuthException(mapDioException(error).message);
    }
  }

  Future<String?> requestSmsCode(String phone) async {
    if (AppConfig.mockEnabled) return '123456';
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/auth/sms-code',
        data: <String, dynamic>{'phone': phone},
      );
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      return data['devCode']?.toString();
    } catch (error) {
      throw AuthException(mapDioException(error).message);
    }
  }

  Future<LoginResult> loginWithSms({
    required String phone,
    required String code,
  }) {
    if (AppConfig.mockEnabled) {
      final String username =
          phone == '18500000001' ? 'teacher01' : 'student01';
      return _mockLogin(username: username, password: '123456');
    }
    return _remoteLogin(
      path: '/api/v1/auth/login/sms',
      body: <String, dynamic>{'phone': phone, 'code': code},
    );
  }

  Future<LoginResult> _remoteLogin({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    try {
      final Response<dynamic> response =
          await _dio.post<dynamic>(path, data: body);
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      final String token = requireString(data, 'token');
      final String refreshToken = requireString(data, 'refreshToken');
      final int role = _readInt(data, 'role');
      if (role != AppConfig.roleStudent && role != AppConfig.roleTeacher) {
        throw const ApiException(
          message: '当前账号请使用 Web 管理端登录',
          kind: ApiErrorKind.forbidden,
        );
      }
      await _tokenStore.writeTokens(
        accessToken: token,
        refreshToken: refreshToken,
      );
      final UserModel user = await _fetchCurrentUser();
      await _saveSnapshot(user);
      return LoginResult(
          token: token, username: user.username, role: user.role);
    } catch (error) {
      await _tokenStore.clear();
      throw AuthException(mapDioException(error).message);
    }
  }

  Future<UserModel?> restore() async {
    if (AppConfig.mockEnabled) return current();
    final String? token = await _tokenStore.readAccessToken();
    if (token == null || token.isEmpty) {
      await _clearSnapshot();
      return null;
    }
    try {
      final UserModel user = await _fetchCurrentUser();
      await _saveSnapshot(user);
      return user;
    } catch (error) {
      await _tokenStore.clear();
      await _clearSnapshot();
      throw AuthException(mapDioException(error).message);
    }
  }

  Future<UserModel> _fetchCurrentUser() async {
    final Response<dynamic> response =
        await _dio.get<dynamic>('/api/v1/auth/me');
    final Map<String, dynamic> data = unwrapEnvelope(response.data);
    final int role = _readInt(data, 'role');
    if (role != AppConfig.roleStudent && role != AppConfig.roleTeacher) {
      throw const ApiException(
        message: '当前账号请使用 Web 管理端登录',
        kind: ApiErrorKind.forbidden,
      );
    }
    final int auditStatus =
        data['auditStatus'] is num ? (data['auditStatus'] as num).toInt() : 0;
    return UserModel(
      id: _readInt(data, 'id'),
      username: requireString(data, 'username'),
      displayName: data['realName']?.toString().trim().isNotEmpty == true
          ? data['realName'].toString()
          : requireString(data, 'username'),
      role: role,
      avatarUrl: data['avatar']?.toString(),
      credentialStatus:
          role == AppConfig.roleTeacher ? _auditStatusLabel(auditStatus) : null,
    );
  }

  Future<void> logout() async {
    if (!AppConfig.mockEnabled) {
      try {
        await _dio.post<dynamic>('/api/v1/auth/logout');
      } catch (_) {
        // 服务不可用也必须允许本地退出。
      }
    }
    if (!AppConfig.mockEnabled) await _tokenStore.clear();
    await _clearSnapshot();
  }

  UserModel? current() {
    final String? username = _prefs.getString(AppConfig.kUsername);
    final int? role = _prefs.getInt(AppConfig.kRole);
    final int? id = _prefs.getInt(AppConfig.kUserId) ??
        (username == null ? null : MockData.userFor(username)?.id);
    if (username == null || role == null || id == null) return null;
    return UserModel(
      id: id,
      username: username,
      displayName: _prefs.getString(AppConfig.kDisplayName) ?? username,
      role: role,
    );
  }

  Future<LoginResult> _mockLogin({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!MockData.verifyDemo(username, password)) {
      throw AuthException('账号或密码错误，演示账号见登录页');
    }
    final UserModel? user = MockData.userFor(username);
    if (user == null || (!user.isStudent && !user.isTeacher)) {
      throw AuthException('当前账号请使用 Web 管理端登录');
    }
    await _prefs.setString(AppConfig.kToken, 'mock-$username-token');
    await _saveSnapshot(user);
    return LoginResult(
      token: 'mock-$username-token',
      username: username,
      role: user.role,
    );
  }

  Future<void> _saveSnapshot(UserModel user) async {
    await _prefs.setInt(AppConfig.kUserId, user.id);
    await _prefs.setString(AppConfig.kUsername, user.username);
    await _prefs.setString(AppConfig.kDisplayName, user.displayName);
    await _prefs.setInt(AppConfig.kRole, user.role);
  }

  Future<void> _clearSnapshot() async {
    await _prefs.remove(AppConfig.kUserId);
    await _prefs.remove(AppConfig.kUsername);
    await _prefs.remove(AppConfig.kDisplayName);
    await _prefs.remove(AppConfig.kRole);
  }

  int _readInt(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];
    if (value is num) return value.toInt();
    throw ApiException(
      message: '服务端字段 $key 缺失',
      kind: ApiErrorKind.contract,
    );
  }

  String _auditStatusLabel(int status) {
    return switch (status) {
      1 => '待审核',
      2 => '已认证',
      3 => '未通过',
      _ => '未提交',
    };
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) {
  throw UnimplementedError('必须在 main.dart 中通过 ProviderScope.overrides 注入');
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(sharedPreferencesProvider),
    ref.watch(dioProvider),
    ref.watch(tokenStoreProvider),
  );
});
