import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/student_api.dart';

/// AI 学伴语气档位（用户设置，仅学伴链路生效，标准 SP 问诊 AI 不受影响）
enum CompanionTone {
  warm('warm', '温暖鼓励'),
  strict('strict', '严谨专业'),
  lively('lively', '活泼轻松'),
  concise('concise', '简洁高效');

  const CompanionTone(this.key, this.label);

  /// 后端存储键
  final String key;

  /// 设置页展示名
  final String label;

  static CompanionTone fromKey(String? key) =>
      values.firstWhere((e) => e.key == key, orElse: () => CompanionTone.warm);
}

/// AI 学伴偏好状态（服务端持久化 user_preference，多端一致）
class AiCompanionPrefs {
  final CompanionTone tone;
  final bool memoryEnabled;
  final bool loading;

  const AiCompanionPrefs({
    this.tone = CompanionTone.warm,
    this.memoryEnabled = true,
    this.loading = true,
  });

  AiCompanionPrefs copyWith({
    CompanionTone? tone,
    bool? memoryEnabled,
    bool? loading,
  }) {
    return AiCompanionPrefs(
      tone: tone ?? this.tone,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      loading: loading ?? this.loading,
    );
  }
}

/// AI 学伴偏好状态管理：进入设置页时拉取服务端偏好，修改即时 PUT
class AiCompanionPrefsNotifier extends StateNotifier<AiCompanionPrefs> {
  AiCompanionPrefsNotifier(this._api) : super(const AiCompanionPrefs());

  final StudentApi _api;
  bool _loaded = false;

  /// 拉取服务端偏好（仅成功时覆盖；失败保持默认，不打断设置页）
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final resp = await _api.getCompanionPreferences();
    final data = resp.data;
    if (resp.code == 0 && data != null) {
      state = AiCompanionPrefs(
        tone: CompanionTone.fromKey(data['aiTone'] as String?),
        memoryEnabled: data['aiMemoryEnabled'] as bool? ?? true,
        loading: false,
      );
    } else {
      state = state.copyWith(loading: false);
    }
  }

  /// 切换语气档位（乐观更新 + 服务端同步）
  Future<void> setTone(CompanionTone tone) async {
    if (state.tone == tone) return;
    state = state.copyWith(tone: tone);
    await _api.updateCompanionPreferences(aiTone: tone.key);
  }

  /// 切换记忆开关（乐观更新 + 服务端同步）
  Future<void> setMemoryEnabled(bool enabled) async {
    if (state.memoryEnabled == enabled) return;
    state = state.copyWith(memoryEnabled: enabled);
    await _api.updateCompanionPreferences(aiMemoryEnabled: enabled);
  }
}

final aiCompanionPrefsProvider =
    StateNotifierProvider<AiCompanionPrefsNotifier, AiCompanionPrefs>((ref) {
  return AiCompanionPrefsNotifier(StudentApi());
});
