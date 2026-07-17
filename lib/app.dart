import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'routes/app_router.dart';

class ZhiYuApp extends ConsumerStatefulWidget {
  const ZhiYuApp({super.key});

  @override
  ConsumerState<ZhiYuApp> createState() => _ZhiYuAppState();
}

class _ZhiYuAppState extends ConsumerState<ZhiYuApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).tryAutoLogin());
  }

  @override
  Widget build(BuildContext context) {
    final router = createRouter(ref);

    return MaterialApp.router(
      title: '智愈寻真',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
