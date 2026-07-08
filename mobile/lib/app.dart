import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'routes/app_router.dart';

class ZhiyuApp extends ConsumerStatefulWidget {
  const ZhiyuApp({super.key});

  @override
  ConsumerState<ZhiyuApp> createState() => _ZhiyuAppState();
}

class _ZhiyuAppState extends ConsumerState<ZhiyuApp> {
  late final _router = AppRouter(ref).router;

  @override
  void initState() {
    super.initState();
    // 锁定竖屏，符合手机学习场景
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    // 沉浸式状态栏：浅色背景配深色图标
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 监听登录态，路由守卫会响应变化
    ref.watch(authControllerProvider);

    return MaterialApp.router(
      title: '智愈寻真',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
