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
/// ## 播放策略（2026-09 拍板）
/// **只在用户首次使用 App 时自动播放一轮**（速览 → 当前 Tab 引导 →
/// 首启会话内各二级页引导）。任何一条引导「播完或跳过」都会写入全局
/// 开关 [ _autoDisabled ]，此后**所有自动引导永久静默**——
/// 不管是新 Tab、新二级页还是重启 App，都不再弹；
/// 唯一的再入口是「设置 / 我的」页里的手动重看（[replay]）。
///
/// 已看过明细存 SharedPreferences（key: guide_completed_tours_v1），
/// 全局开关存 guide_auto_disabled_v1。
///
/// ## 曾经踩过的坑（勿回退）
/// 1. **必须在判空前 `await ensureLoaded()`**。否则冷启动读盘还没回来，
///    `_done` 是空的，已经看过引导的老用户会被再播一遍。
/// 2. **延迟回调里不能复用旧的 tabId**。用户可能在 520ms 等待期内切走，
///    于是播错 Tab 的引导。统一改由 [bindTabResolver] 实时取当前 Tab。
/// 3. **finish 后立刻 await 写盘**，不能 fire-and-forget。
/// 4. **老用户兼容**：读盘时只要 `_done` 非空就视为老用户，直接置位
///    全局开关——保证升级到本版本的存量用户不再被弹任何引导。
class GuideController extends StateNotifier<GuideState> {
  GuideController() : super(const GuideState()) {
    _initFuture = _load();
  }

  static const _prefsKey = 'guide_completed_tours_v1';
  static const _autoDisabledKey = 'guide_auto_disabled_v1';

  final Set<String> _done = {};
  bool _autoDisabled = false;
  late final Future<void> _initFuture;
  GuideRole? _role;

  /// 由 [GuideHost] 注册，用于实时取当前所在 Tab
  String? Function()? _tabResolver;

  int _tabToken = 0;
  int _pageToken = 0;

  Future<void> ensureLoaded() => _initFuture;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      if (list != null) _done.addAll(list);
      // 老用户（看过任意一条引导）直接全局静默，升级不干扰
      _autoDisabled =
          prefs.getBool(_autoDisabledKey) ?? _done.isNotEmpty;
    } catch (_) {
      // 读盘失败按「没看过」处理，最坏多播一次，不影响主流程
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _done.toList());
      await prefs.setBool(_autoDisabledKey, _autoDisabled);
    } catch (_) {}
  }

  void bindTabResolver(String? Function() resolver) =>
      _tabResolver = resolver;

  void unbindTabResolver() => _tabResolver = null;

  /// 进入某个 Tab 时调用（自动播放入口，受全局开关约束）
  ///
  /// 首启会话内：未看过速览 → 先播速览，速览正常走完再播本 Tab 引导；
  /// 点「跳过」则本轮全部取消，且此后永久静默。
  Future<void> enterTab(GuideRole role, String tabId) async {
    final token = ++_tabToken;
    await ensureLoaded();
    if (!mounted || token != _tabToken) return;
    if (_autoDisabled) return;

    _role = role;
    if (state.active) return;

    final intro = GuideTours.introOf(role);
    if (intro != null && !_done.contains(intro.id)) {
      state = GuideState(tour: intro);
      return;
    }
    _startTab(role, tabId);
  }

  /// 进入某个二级页面时调用（页面在 initState / 数据就绪后触发）
  ///
  /// 与 Tab 引导互斥：若正在播，本次静默跳过（未标 done，下次进页还会再触发）。
  /// 延迟由 [schedulePageEnter] 包一层，给页面首帧渲染留时间；
  /// 即使锚点还没渲染出来，遮罩层每帧重测，锚点出现后洞会自动浮现。
  void schedulePageEnter(String pageId,
      {Duration delay = const Duration(milliseconds: 900)}) {
    final token = ++_pageToken;
    Future<void>.delayed(delay, () async {
      if (!mounted || token != _pageToken) return;
      await enterPage(pageId);
    });
  }

  Future<void> enterPage(String pageId) async {
    await ensureLoaded();
    if (!mounted || state.active) return;
    // 全局开关已置位（首启轮播完/跳过）→ 二级页引导也永久静默
    if (_autoDisabled) return;
    final tour = GuideTours.pageOf(pageId);
    if (tour == null || _done.contains(tour.id)) return;
    state = GuideState(tour: tour);
  }

  void _startTab(GuideRole role, String tabId) {
    if (state.active) return;
    final tour = GuideTours.of(role, tabId);
    // 已看过 → 永久静默；该 Tab 没配引导 → 不打扰
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
      // 只有「开屏速览」走完才衔接 Tab 引导；页面引导走完就地结束
      finish(continuePending: tour.intro);
    }
  }

  /// 跳过：本轮取消，后续 Tab 引导也不再播（跳过 = 不想被打扰）
  void skip() => finish(continuePending: false);

  /// 结束当前引导
  ///
  /// [continuePending] 为 true 时，速览结束后会继续播「当前所在 Tab」的引导
  /// （仅首启会话内有效）；Tab 由 resolver 实时取，避免用户中途切 Tab 导致播错。
  ///
  /// **任何一条引导播完或跳过都会置位全局开关**：此后所有自动引导永久静默，
  /// 只有「设置 / 我的」里的手动重看才会再来一轮。
  Future<void> finish({required bool continuePending}) async {
    final tour = state.tour;
    final id = tour?.id;
    final role = _role;
    state = const GuideState();
    if (id == null) return;

    _done.add(id);
    // 全局一次性开关：首启轮结束后不再自动打扰（含跳过的情况）
    _autoDisabled = true;

    // 跳过开屏速览 = 连本轮 Tab 引导一起视为已读。
    if (!continuePending && tour!.intro && role != null) {
      final tabId = _tabResolver?.call();
      final tabTour = tabId == null ? null : GuideTours.of(role, tabId);
      if (tabTour != null) _done.add(tabTour.id);
    }

    await _persist();
    if (!mounted) return;

    if (continuePending && role != null) {
      Future<void>.delayed(const Duration(milliseconds: 480), () {
        if (!mounted) return;
        final tabId = _tabResolver?.call();
        if (tabId == null) return;
        // 首启会话的续播：直接走内部 _startTab，绕过全局开关检查
        _startTab(role, tabId);
      });
    }
  }

  /// 手动重看（设置 / 我的页入口）：清空该角色的完成记录与全局开关，
  /// 从速览重新开始一轮；本轮走完（或跳过）后再次全局静默。
  ///
  /// 注意：记录被清空后，只有用户完整看完（或跳过）才会重新写回，
  /// 中途杀掉 App 下次仍会重播，这是有意为之。
  Future<void> replay(GuideRole role) async {
    state = const GuideState();
    final prefix = role == GuideRole.student ? 'student_' : 'teacher_';
    _done.removeWhere((id) => id.startsWith(prefix));
    _autoDisabled = false;
    await _persist();

    _role = role;
    final intro = GuideTours.introOf(role);
    if (intro != null) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (mounted) state = GuideState(tour: intro);
    }
  }

  /// 是否已看过（供外部判断）
  bool isDone(String id) => _done.contains(id);
}

final guideControllerProvider =
    StateNotifierProvider<GuideController, GuideState>(
  (ref) => GuideController(),
);
