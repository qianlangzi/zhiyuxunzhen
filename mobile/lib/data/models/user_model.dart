/// 用户与角色
import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.orgName,
    this.credentialStatus,
  });

  final int id;
  final String username;
  final String displayName;

  /// 0 学生 / 1 教师 / 其他由 Web 管理端处理
  final int role;
  final String? avatarUrl;
  final String? orgName;
  final String? credentialStatus;

  bool get isStudent => role == 0;
  bool get isTeacher => role == 1;

  String get roleLabel {
    switch (role) {
      case 0:
        return '学生';
      case 1:
        return '教师';
      default:
        return '管理端';
    }
  }
}

/// 登录响应
@immutable
class LoginResult {
  const LoginResult({
    required this.token,
    required this.username,
    required this.role,
  });

  final String token;
  final String username;
  final int role;
}
