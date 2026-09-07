import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guide_models.dart';
import 'guide_tours.dart';

/// 角色：决定播放哪一套引导
enum GuideRole { student, teacher }

/// 引导状态
@immutable
class GuideState {
  const GuideState({this.tour, this.step = 0});

  final GuideTour? tour;
  final int step;

  bool get active => tour != null;

  GuideStep? get current =>
      tour == null ? null : tour!.steps[step.clamp(0, tour!.steps.length - 1)];
}

/// 新手指引控制器
///
/// 已完成记录存 SharedPreferences（key: guide_completed_tours_v1），
/// 每条引导只播一次；「我的 → 新手指引」可重置后重播。
class GuideController extends StateNotifier<GuideState> {
  GuideController() : super(const GuideState()) {
    _initFuture = _load();
  }

  static const _prefsKey = 'guide_completed_tours_v1';

  final Set<String> _done = {};
  late final Future<void> _initFuture;
  GuideRole? _role;
  String? _pendingTab;

  /// 供 main() 预热，避免首帧读盘竞态（不 await 也不会出错）
  Future<void> ensureLoaded() => _initFuture;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      if (list != null) _done.addAll(list);
    } catch (_) {
      // 读盘失败按「全部未看过」处理，最多是多播一次引导，不影响主流程
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _done.toList());
    } catch (_) {}
  }

  /// 进入某个 Tab 时调用：首次会先播「隐藏手势速览」，速览结束再播本 Tab 引导
  void enterTab(GuideRole role, String tabId) {
    _role = role;
    if (state.active) return;
    final intro = GuideTours.introOf(role);
    if (intro != null && !_done.contains(intro.id)) {
      _pendingTab = tabId;
      state = GuideState(tour: intro);
      return;
    }
    _startTab(role, tabId);
  }

  void _startTab(GuideRole role, String tabId) {
    final tour = GuideTours.of(role, tabId);
    if (tour == null || _done.contains(tour.id)) return;
    state = GuideState(tour: tour);
  }

  /// 下一步（最后一步时自动结束）
  void next() {
    final tour = state.tour;
    if (tour == null) return;
    if (state.step + 1 < tour.steps.length) {
      state = GuideState(tour: tour, step: state.step + 1);
    } else {
      finish();
    }
  }

  /// 结束当前引导（点「跳过」或最后一步「知道了」）
  void finish() {
    final id = state.tour?.id;
    state = const GuideState();
    if (id != null) {
      _done.add(id);
      _persist();
    }
    final pending = _pendingTab;
    final role = _role;
    _pendingTab = null;
    if (pending != null && role != null) {
      // 速览结束 → 稍等一拍再播当前 Tab 的引导，让页面先稳住
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) _startTab(role, pending);
      });
    }
  }

  /// 跳过：连本轮待播的 Tab 引导一起取消（跳过 = 不再打扰）
  void skip() {
    _pendingTab = null;
    finish();
  }

  /// 重看：清空该角色的完成记录，并从「隐藏手势速览」开始
  ///
  /// [tabId] 非空时，速览结束后紧接着播这个 Tab 的引导。
  Future<void> replay(GuideRole role, {String? tabId}) async {
    state = const GuideState();
    final prefix = role == GuideRole.student ? 'student_' : 'teacher_';
    _done.removeWhere((id) => id.startsWith(prefix));
    await _persist();
    _role = role;
    _pendingTab = tabId;
    final intro = GuideTours.introOf(role);
    if (intro != null) {
      // 等一帧，避免与上一个动画抢帧导致高亮位置测量不准
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (mounted) state = GuideState(tour: intro);
    }
  }

  /// 是否已看过（供外部判断，如「新手指引」入口的角标）
  bool isDone(String id) => _done.contains(id);
}

final guideControllerProvider =
    StateNotifierProvider<GuideController, GuideState>(
  (ref) => GuideController(),
);
