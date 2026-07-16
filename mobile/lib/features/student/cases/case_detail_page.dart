import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

class CaseDetailPage extends ConsumerWidget {
  const CaseDetailPage({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository repo = ref.watch(caseRepositoryProvider);
    final CaseModel? caseItem = repo.byId(caseId);

    if (caseItem == null) {
      return Scaffold(
        appBar: const ZyAppBar(title: '病例详情'),
        body: ZyErrorState(
          message: '病例不存在或已下架',
          onRetry: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      appBar: const ZyAppBar(title: '病例详情'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding, AppDimens.grid2, AppDimens.pagePadding, 120),
        children: <Widget>[
          Text(caseItem.title, style: AppTextStyles.h2),
          const SizedBox(height: AppDimens.grid2),
          Text(caseItem.chief, style: AppTextStyles.body),
          const SizedBox(height: AppDimens.grid6),
          const ZySectionHeader(title: '患者概况'),
          const SizedBox(height: AppDimens.grid2),
          _InfoRow(label: '科室', value: caseItem.department),
          _InfoRow(label: '难度', value: caseItem.difficulty),
          _InfoRow(label: '时长', value: caseItem.duration),
          const SizedBox(height: AppDimens.grid6),
          const ZySectionHeader(title: '训练目标'),
          const SizedBox(height: AppDimens.grid2),
          Wrap(
            spacing: AppDimens.grid2,
            runSpacing: AppDimens.grid2,
            children: caseItem.tags
                .map((String tag) => ZyChip(tag, tone: ZyChipTone.neutral))
                .toList(),
          ),
          if (caseItem.summary != null) ...<Widget>[
            const SizedBox(height: AppDimens.grid6),
            const ZySectionHeader(title: '病例资料'),
            const SizedBox(height: AppDimens.grid2),
            Text(caseItem.summary!, style: AppTextStyles.body),
            if (caseItem.source != null) ...<Widget>[
              const SizedBox(height: AppDimens.grid2),
              Text(
                '来源：${caseItem.source}',
                style: AppTextStyles.caption,
              ),
            ],
          ],
          const SizedBox(height: AppDimens.grid6),
          const ZySectionHeader(title: '训练提示'),
          const SizedBox(height: AppDimens.grid2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.soft),
              const SizedBox(width: AppDimens.grid2),
              Expanded(
                child: Text(
                  caseItem.avoidExam != null
                      ? '避免无指征检查：${caseItem.avoidExam}'
                      : '先完成低成本必要检查，再考虑高价影像。',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: ZyStickyActionBar(
        child: FilledButton.icon(
          onPressed: () => context.push('/student/chat?caseId=${caseItem.id}'),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('开始问诊'),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyStrong)),
        ],
      ),
    );
  }
}
