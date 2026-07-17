import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';

/// 空状态占位：标题、说明、一个操作
class ZyEmptyState extends StatelessWidget {
  const ZyEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.liveRegion = false,
  }) : assert(
          (actionLabel == null) == (onAction == null),
          'actionLabel and onAction must be provided together.',
        );

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final String semanticsLabel = detail == null ? title : '$title。$detail';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.grid8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                container: true,
                liveRegion: liveRegion,
                label: semanticsLabel,
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 28, color: AppColors.weak),
                      const SizedBox(height: AppDimens.grid3),
                      Text(
                        title,
                        style: AppTextStyles.bodyStrong,
                        textAlign: TextAlign.center,
                      ),
                      if (detail != null) ...<Widget>[
                        const SizedBox(height: AppDimens.grid2),
                        Text(
                          detail!,
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (actionLabel != null) ...<Widget>[
                const SizedBox(height: AppDimens.grid5),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimens.touchTarget,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAction,
                      child: Text(
                        actionLabel!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 错误状态：原因 + 重新加载
class ZyErrorState extends StatelessWidget {
  const ZyErrorState({
    super.key,
    this.title = '暂时无法加载',
    required this.message,
    required this.onRetry,
    this.actionLabel = '重新加载',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => ZyEmptyState(
        icon: Icons.error_outline_rounded,
        title: title,
        detail: message,
        actionLabel: actionLabel,
        onAction: onRetry,
        liveRegion: true,
      );
}
