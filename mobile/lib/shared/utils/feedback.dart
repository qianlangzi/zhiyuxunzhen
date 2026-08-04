import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// 全局交互反馈工具：统一 SnackBar / Loading / 确认弹窗，消灭空响应。
class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) {
    _snack(context, message, AppColors.primaryOf(context), Icons.check_circle_outline,
        const Duration(seconds: 2));
  }

  static void error(BuildContext context, String message) {
    _snack(context, message, AppColors.vermilion, Icons.error_outline,
        const Duration(seconds: 3));
  }

  static void info(BuildContext context, String message) {
    _snack(context, message, AppColors.amber, Icons.info_outline,
        const Duration(milliseconds: 2500));
  }

  static void _snack(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
    Duration duration,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final onColor = AppColors.onPrimaryOf(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: 18, color: onColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: onColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      );
  }

  /// 展示加载遮罩，返回关闭函数。
  static VoidCallback showLoading(BuildContext context, {String label = '处理中…'}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryOf(context),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return () {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    };
  }

  /// 二次确认弹窗，返回是否确认。
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
          ),
        ),
        content: Text(
          content,
          style: TextStyle(fontSize: 13, color: AppColors.text2Of(context), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText, style: TextStyle(color: AppColors.text3Of(context))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: danger ? AppColors.vermilion : AppColors.primaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 模拟一次异步网络请求：带延迟与可选随机失败，便于演示加载/错误态。
/// 真实后端接入后，把调用方替换为 dio 请求即可。
Future<T> mockAsync<T>(
  T Function() data, {
  Duration delay = const Duration(milliseconds: 900),
  double failureRate = 0,
}) async {
  await Future.delayed(delay);
  if (failureRate > 0 && (DateTime.now().millisecondsSinceEpoch % 100) / 100 < failureRate) {
    throw Exception('网络异常，请稍后重试');
  }
  return data();
}
