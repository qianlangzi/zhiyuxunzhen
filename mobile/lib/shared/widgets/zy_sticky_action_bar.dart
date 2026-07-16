import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// 底部固定操作区：病例详情和表单使用
class ZyStickyActionBar extends StatelessWidget {
  const ZyStickyActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        elevation: 2,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: child,
        ),
      );
}
