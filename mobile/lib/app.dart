import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/common/guide/guide_overlay.dart';
import 'features/common/settings/settings_provider.dart';
import 'routes/app_router.dart';

/// 报告条目: P2 #12 — ConsumerStatefulWidget + WidgetsBindingObserver
/// 监听 AppLifecycleState，在后台/前台切换时管理资源
///
/// 另负责「深色模式 · 自动」的时间调度：每分钟检查一次当前是否处于夜间，
/// 跨过 18:00 / 6:00 时重建主题，使全 App（不只首页）统一切换深浅色。
class ZhiyuApp extends ConsumerStatefulWidget {
  const ZhiyuApp({super.key});

  @override
  ConsumerState<ZhiyuApp> createState() => _ZhiyuAppState();
}

class _ZhiyuAppState extends ConsumerState<ZhiyuApp> with WidgetsBindingObserver {
  Timer? _autoThemeTimer;
  late bool _isNightNow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isNightNow = isNightTime(DateTime.now());
    // 每分钟检查一次：跨过 18:00 / 6:00 时切换主题。
    // 只在「夜间状态真的变了」才 setState，避免无谓重建。
    _autoThemeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _syncNightState();
    });
  }

  @override
  void dispose() {
    _autoThemeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 重新计算夜间状态，变化时才触发重建
  void _syncNightState() {
    final night = isNightTime(DateTime.now());
    if (night != _isNightNow && mounted) {
      setState(() => _isNightNow = night);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        // app 进入后台：可暂停动画、保存草稿等
        // 当前无长驻动画需要暂停；接入后端后在此断开/挂起连接
        break;
      case AppLifecycleState.resumed:
        // app 回到前台：刷新数据、重连网络
        // 接入后端后在此触发重连
        // 后台期间 Timer 可能被系统节流甚至暂停，回到前台立刻重算夜间状态，
        // 避免「App 挂着过了 18:00，回来主题还是浅色」。
        _syncNightState();
        break;
      case AppLifecycleState.detached:
        // app 被销毁：最终持久化
        // SharedPreferences 写入已在各 _save() 方法中完成
        break;
      default:
        break;
    }
  }

  /// 把设置项解析成 Flutter 的 [ThemeMode]
  ThemeMode _resolveThemeMode(DarkModeSetting setting) => switch (setting) {
        DarkModeSetting.light => ThemeMode.light,
        DarkModeSetting.dark => ThemeMode.dark,
        DarkModeSetting.auto => _isNightNow ? ThemeMode.dark : ThemeMode.light,
      };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: '智愈寻真',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(settings.themePreset, false),
      darkTheme: AppTheme.of(settings.themePreset, true),
      themeMode: _resolveThemeMode(settings.darkModeSetting),
      // 深浅主题切换的平滑过渡（色板已实现 lerp，Material 会插值所有语义色 + extension）
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOutCubic,
      routerConfig: ref.watch(routerProvider),
      // 在此用 MediaQuery 覆盖全局 textScaler，实现「文字大小」设置。
      // 新手指引遮罩层挂在最外层：这样 push 出去的二级页也会被覆盖，
      // 高亮定位不会受页面层级影响。
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.textScale),
        ),
        // Stack 默认给非定位子组件「松约束」，导航器拿不到紧约束会塌缩，
        // 因此显式用 SizedBox.expand 把路由页撑满；引导层静止时是 zero-size，
        // 不会拦截任何点击。
        child: Stack(
          children: [
            SizedBox.expand(child: child),
            const GuideOverlay(),
          ],
        ),
      ),
    );
  }
}
