import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/common/settings/settings_provider.dart';
import 'routes/app_router.dart';

/// 报告条目: P2 #12 — ConsumerStatefulWidget + WidgetsBindingObserver
/// 监听 AppLifecycleState，在后台/前台切换时管理资源
class ZhiyuApp extends ConsumerStatefulWidget {
  const ZhiyuApp({super.key});

  @override
  ConsumerState<ZhiyuApp> createState() => _ZhiyuAppState();
}

class _ZhiyuAppState extends ConsumerState<ZhiyuApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        break;
      case AppLifecycleState.detached:
        // app 被销毁：最终持久化
        // SharedPreferences 写入已在各 _save() 方法中完成
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(settingsProvider).darkMode;
    return MaterialApp.router(
      title: '智愈寻真',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
