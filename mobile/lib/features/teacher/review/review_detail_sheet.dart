import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 可拖动批阅详情层
class ReviewDetailSheet extends StatelessWidget {
  const ReviewDetailSheet({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReturn,
  });

  final ReviewItem item;
  final VoidCallback onApprove;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusSheet),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0,
                AppDimens.pagePadding, AppDimens.grid6),
            children: <Widget>[
              const SizedBox(height: AppDimens.grid2),
              Text('批阅详情', style: AppTextStyles.h2),
              const SizedBox(height: AppDimens.grid2),
              Text('${item.student} · ${item.assignment}',
                  style: AppTextStyles.caption),
              const SizedBox(height: AppDimens.grid6),
              const ZySectionHeader(title: '问题证据'),
              const SizedBox(height: AppDimens.grid2),
              Text(item.issue, style: AppTextStyles.body),
              const SizedBox(height: AppDimens.grid6),
              OutlinedButton(
                onPressed: onReturn,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                ),
                child: const Text('退回修改'),
              ),
              const SizedBox(height: AppDimens.grid3),
              FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                ),
                child: const Text('通过'),
              ),
            ],
          ),
        );
      },
    );
  }
}
