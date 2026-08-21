import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_preset.dart';
import '../../../data/models/models.dart';

/// 应用设置项
///
/// 与 [AuthNotifier] 保持一致：使用 SharedPreferences 本地持久化，
/// 用户无需联网即可保留偏好，符合「离线优先」的移动体验要求。
class AppSettings {
  final bool pushNotifications;
  final bool trainingReminder;
  final bool soundEnabled;
  final bool offlineCache;
  final bool wifiAutoDownload;
  final bool biometricLogin;
  final bool darkMode;
  final bool agreedToTerms;
  final ThemePreset themePreset;

  const AppSettings({
    this.pushNotifications = true,
    this.trainingReminder = true,
    this.soundEnabled = true,
    this.offlineCache = true,
    this.wifiAutoDownload = false,
    this.biometricLogin = false,
    this.darkMode = false,
    this.agreedToTerms = false,
    this.themePreset = ThemePreset.herb,
  });

  AppSettings copyWith({
    bool? pushNotifications,
    bool? trainingReminder,
    bool? soundEnabled,
    bool? offlineCache,
    bool? wifiAutoDownload,
    bool? biometricLogin,
    bool? darkMode,
    bool? agreedToTerms,
    ThemePreset? themePreset,
  }) {
    return AppSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      trainingReminder: trainingReminder ?? this.trainingReminder,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      offlineCache: offlineCache ?? this.offlineCache,
      wifiAutoDownload: wifiAutoDownload ?? this.wifiAutoDownload,
      biometricLogin: biometricLogin ?? this.biometricLogin,
      darkMode: darkMode ?? this.darkMode,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      themePreset: themePreset ?? this.themePreset,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushNotifications': pushNotifications,
        'trainingReminder': trainingReminder,
        'soundEnabled': soundEnabled,
        'offlineCache': offlineCache,
        'wifiAutoDownload': wifiAutoDownload,
        'biometricLogin': biometricLogin,
        'darkMode': darkMode,
        'agreedToTerms': agreedToTerms,
        'themePreset': themePreset.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        pushNotifications: json['pushNotifications'] as bool? ?? true,
        trainingReminder: json['trainingReminder'] as bool? ?? true,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        offlineCache: json['offlineCache'] as bool? ?? true,
        wifiAutoDownload: json['wifiAutoDownload'] as bool? ?? false,
        biometricLogin: json['biometricLogin'] as bool? ?? false,
        darkMode: json['darkMode'] as bool? ?? false,
        agreedToTerms: json['agreedToTerms'] as bool? ?? false,
        themePreset: ThemePreset.values.firstWhere(
          (t) => t.name == json['themePreset'],
          orElse: () => ThemePreset.herb,
        ),
      );
}

/// 设置状态管理（本地持久化）
class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _key = 'app_settings';

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// 报告条目: P1 #2 — 存储初始化 Future，供 main() 预热
  SettingsNotifier() : super(const AppSettings()) {
    _initFuture = _load();
  }

  late final Future<void> _initFuture;

  /// 等待设置加载完成（供 main() 预热调用，避免主题闪烁）。
  /// 报告条目: P1 #2
  Future<void> ensureLoaded() => _initFuture;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      log('读取设置失败: $e', name: 'settings');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (e) {
      log('保存设置失败: $e', name: 'settings');
    }
  }

  /// 整体替换设置并持久化
  void update(AppSettings next) {
    state = next;
    _save();
  }

  /// 记录用户是否已阅读并同意用户协议与隐私政策
  void setAgreedToTerms(bool agreed) {
    if (state.agreedToTerms == agreed) return;
    update(state.copyWith(agreedToTerms: agreed));
  }

  /// 开启 / 关闭生物识别登录。
  ///
  /// 开启前需先做一次性「本人在场」验证（指纹 / Face ID），验证通过才允许开启，
  /// 并把当前角色写入 [FlutterSecureStorage]，供登录页快速登录使用；
  /// 关闭时清除该标记。返回是否成功（设备不支持或验证失败返回 false）。
  Future<bool> setBiometricLogin(bool enabled, UserRole? role) async {
    if (!enabled) {
      try {
        await _secure.delete(key: SecureKeys.biometricRole);
      } catch (e) {
        log('清除生物识别标记失败: $e', name: 'settings');
      }
      update(state.copyWith(biometricLogin: false));
      return true;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final didAuth = await _auth.authenticate(
        localizedReason: '验证身份以开启生物识别登录',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!didAuth) return false;

      if (role != null) {
        await _secure.write(
          key: SecureKeys.biometricRole,
          value: role == UserRole.student ? 'student' : 'teacher',
        );
      }
      update(state.copyWith(biometricLogin: true));
      return true;
    } catch (e) {
      log('开启生物识别失败: $e', name: 'settings');
      return false;
    }
  }

  /// 读取已开启生物识别登录的角色，未开启返回 null
  Future<UserRole?> getBiometricRole() async {
    try {
      final v = await _secure.read(key: SecureKeys.biometricRole);
      if (v == 'student') return UserRole.student;
      if (v == 'teacher') return UserRole.teacher;
    } catch (e) {
      log('读取生物识别标记失败: $e', name: 'settings');
    }
    return null;
  }

  /// 清除本地缓存（应用临时目录），返回清理的字节数
  Future<int> clearCache() async {
    var total = 0;
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              total += await entity.length();
              await entity.delete();
            } catch (_) {
              // 忽略单个文件删除失败
            }
          }
        }
      }
    } catch (e) {
      log('清除缓存失败: $e', name: 'settings');
    }
    return total;
  }

  /// 报告条目: P2 #11 — 覆写 dispose 作为扩展点
  @override
  void dispose() {
    // 当前无需显式释放 LocalAuthentication / FlutterSecureStorage（平台单例）
    // 未来若添加 StreamSubscription / Timer / Dio 等资源，在此释放
    super.dispose();
  }
}

/// 设置 Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
