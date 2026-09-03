import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/models.dart';

/// 本地已注册用户目录（模拟后端账号库）
///
/// 以手机号（注册时写入 [UserModel.username]）为主键，将用户记录 JSON 持久化到
/// SharedPreferences。真实环境应由后端用户服务托管，此处仅用于前端流程演示，
/// 保证「注册 → 验证码登录 / 密码登录」闭环在本地可运行。
class RegisteredUserStore {
  RegisteredUserStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;
  final Future<SharedPreferences> Function() _getInstance =
      SharedPreferences.getInstance;

  static const String _key = 'registered_users';

  Future<SharedPreferences> get _store async => _prefs ?? await _getInstance();

  Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// 按手机号查找已注册用户（同时匹配 username 或 contact），未找到返回 null
  Future<UserModel?> findByPhone(String phone) => findByContact(phone);

  /// 按手机号（[UserModel.username] 或 [UserModel.contact]）查找已注册用户，
  /// 未找到返回 null。注册后账号可被「验证码登录」以注册手机号定位到。
  Future<UserModel?> findByContact(String phone) async {
    final prefs = await _store;
    final map = _decode(prefs.getString(_key));
    for (final raw in map.values) {
      try {
        final u = UserModel.fromJson(raw as Map<String, dynamic>);
        if (u.username == phone || u.contact == phone) return u;
      } catch (_) {
        // 单条损坏不影响其余
      }
    }
    return null;
  }

  /// 按用户名（注册时写入 [UserModel.username]）查找，未找到返回 null
  Future<UserModel?> findByUsername(String username) async {
    final prefs = await _store;
    final map = _decode(prefs.getString(_key));
    final raw = map[username];
    if (raw == null) return null;
    try {
      return UserModel.fromJson(raw as Map<String, dynamic>);
    } catch (e) {
      log('读取本地用户失败: $e', name: 'user_store');
      return null;
    }
  }

  /// 该用户名是否已注册
  Future<bool> existsByUsername(String username) async =>
      (await findByUsername(username)) != null;

  /// 保存 / 覆盖某手机号对应的用户记录
  Future<void> save(UserModel user) async {
    final prefs = await _store;
    final map = _decode(prefs.getString(_key));
    map[user.username] = user.toJson();
    await prefs.setString(_key, jsonEncode(map));
  }
}
