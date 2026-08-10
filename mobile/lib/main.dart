import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/api_config.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/common/settings/settings_provider.dart';

/// 全局渲染异常兜底页：任何 widget 在 build 期间抛异常时，
/// 显示可读错误信息而非「无提示空白」或整页红屏崩溃。
/// release 下只给友好提示，debug 下展示异常详情便于定位真机问题。
Widget _buildErrorScreen(FlutterErrorDetails details) {
  final isRelease = const bool.fromEnvironment('dart.vm.product');
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 46),
                const SizedBox(height: 18),
                const Text(
                  '页面渲染出现异常',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                if (!isRelease)
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                  )
                else
                  const Text(
                    '请重启应用或联系开发人员。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 报告条目: P0 #1+#6 — 异步 main()，预热关键 Provider 避免初始化竞态
void main() async {
  // 确保 Flutter 引擎初始化（异步 main() 必须调用）
  WidgetsFlutterBinding.ensureInitialized();

  // Issue1 P0：release 构建禁止启用 USE_MOCK_AUTH=true，
  // 防止误配置导致登录/改密退化为本地直接成功（绕过后端安全边界）
  if (kReleaseMode && ApiConfig.useMockAuth) {
    throw StateError(
      'Release 构建禁止启用 USE_MOCK_AUTH，请检查 --dart-define 配置。'
      '安全敏感操作必须走真实后端校验。',
    );
  }

  ErrorWidget.builder = _buildErrorScreen;

  // 创建 ProviderContainer 并预热 authProvider + settingsProvider，
  // 确保用户态和主题在 runApp 前加载完毕，消除 redirect 竞态和主题闪烁
  final container = ProviderContainer();
  await container.read(authProvider.notifier).ensureInitialized();
  await container.read(settingsProvider.notifier).ensureLoaded();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZhiyuApp(),
    ),
  );
}
