import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

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

void main() {
  ErrorWidget.builder = _buildErrorScreen;
  runApp(
    const ProviderScope(
      child: ZhiyuApp(),
    ),
  );
}
