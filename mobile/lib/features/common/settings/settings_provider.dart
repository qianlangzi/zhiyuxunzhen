import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme_preset.dart';

/// 全局文字大小档位
///
/// 用于 [settings_screen] 的「文字大小」选择与 [ZhiyuApp] 的全局缩放。
/// textScaleFactor 作为 [TextScaler.linear] 的系数应用到整个应用。
class TextScale {
  TextScale._();

  static const double small = 0.9;
  static const double normal = 1.0;
  static const double large = 1.15;
  static const double xlarge = 1.3;

  /// 档位列表及展示名（供设置页分段选择）
  static const List<(double, String)> options = [
    (small, '小'),
    (normal, '标准'),
    (large, '大'),
    (xlarge, '特大'),
  ];
}

/// 深色模式策略
///
/// 原来是 `bool darkMode`（开/关），主题与「系统时间」完全脱钩，导致：
/// 用户关着开关、凌晨打开 App 时，学生端首页按时间切了夜景，
/// 但其余页面仍走 lightPalette（米白底 + 深墨字）—— 首页与二级页严重割裂。
///
/// 改为三态后，[auto] 会让 **整个 App** 在夜间自动切到 darkPalette，
/// 所有页面文字自动变成近白色（darkText #EDF1EF，对比度约 16:1），
/// 无需逐页适配。
enum DarkModeSetting {
  light('浅色', '始终使用浅色主题'),
  dark('深色', '始终使用深色主题'),
  auto('自动', '18:00 至次日 6:00 自动切换深色');

  const DarkModeSetting(this.label, this.desc);

  /// 设置页展示名
  final String label;

  /// 设置页说明
  final String desc;
}

/// 判断某时刻是否处于夜间时段（18:00 ~ 次日 6:00）
///
/// 抽成顶层函数，供 [ZhiyuApp]（主题调度）与学生端首页（夜景图）共用，
/// 保证「主题切换」与「首页夜景」的判定口径完全一致。
bool isNightTime(DateTime now) {
  final hour = now.hour;
  return hour >= 18 || hour < 6;
}

/// 应用设置项
///
/// 与 [AuthNotifier] 保持一致：使用 SharedPreferences 本地持久化，
/// 用户无需联网即可保留偏好，符合「离线优先」的移动体验要求。
class AppSettings {
  final double textScale;
  final DarkModeSetting darkModeSetting;
  final bool agreedToTerms;
  final ThemePreset themePreset;

  const AppSettings({
    this.textScale = TextScale.normal,
    this.darkModeSetting = DarkModeSetting.auto,
    this.agreedToTerms = false,
    this.themePreset = ThemePreset.herb,
  });

  AppSettings copyWith({
    double? textScale,
    DarkModeSetting? darkModeSetting,
    bool? agreedToTerms,
    ThemePreset? themePreset,
  }) {
    return AppSettings(
      textScale: textScale ?? this.textScale,
      darkModeSetting: darkModeSetting ?? this.darkModeSetting,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      themePreset: themePreset ?? this.themePreset,
    );
  }

  Map<String, dynamic> toJson() => {
        'textScale': textScale,
        'darkModeSetting': darkModeSetting.name,
        'agreedToTerms': agreedToTerms,
        'themePreset': themePreset.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        textScale: (json['textScale'] as num?)?.toDouble() ?? TextScale.normal,
        darkModeSetting: _parseDarkModeSetting(json),
        agreedToTerms: json['agreedToTerms'] as bool? ?? false,
        themePreset: ThemePreset.values.firstWhere(
          (t) => t.name == json['themePreset'],
          orElse: () => ThemePreset.herb,
        ),
      );

  /// 旧版存 `darkMode: bool`，新版存 `darkModeSetting: 'light'|'dark'|'auto'`
  ///
  /// 迁移策略：
  /// - 旧值 `true`  → [DarkModeSetting.dark]（原本就是深色，保持不变）
  /// - 旧值 `false` → [DarkModeSetting.auto]
  ///
  /// 关于 `false` 迁移到 [auto] 而不是 [light]：
  /// 本 App 尚未正式发布，「老数据」只存在于开发/测试设备上。让这些设备
  /// 升级后直接体验到「夜间自动变深色」，比保守维持浅色更有价值；
  /// 白天打开依然是浅色，不会有突兀变化。
  /// 若日后需要严格保守迁移，把下面的 [DarkModeSetting.auto] 改成
  /// [DarkModeSetting.light] 即可。
  static DarkModeSetting _parseDarkModeSetting(Map<String, dynamic> json) {
    final name = json['darkModeSetting'] as String?;
    if (name != null) {
      return DarkModeSetting.values.firstWhere(
        (e) => e.name == name,
        orElse: () => DarkModeSetting.auto,
      );
    }
    return json['darkMode'] as bool? ?? false
        ? DarkModeSetting.dark
        : DarkModeSetting.auto;
  }
}

/// 设置状态管理（本地持久化）
class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _key = 'app_settings';

  SettingsNotifier() : super(const AppSettings()) {
    _initFuture = _load();
  }

  late final Future<void> _initFuture;

  /// 等待设置加载完成（供 main() 预热调用，避免主题闪烁）。
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
}

/// 设置 Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});