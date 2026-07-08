import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 病例详情：进入问诊室前的概览
class CaseDetailPage extends ConsumerWidget {
  const CaseDetailPage({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository repo = ref.watch(caseRepositoryProvider);
    final CaseModel? caseItem =
        repo.byId(caseId) ?? repo.daily();

    return Scaffold(
      appBar: const ZyAppBar(
        title: '病例概览',
        transparent: true,
      ),
      body: caseItem == null
          ? const ZyEmptyState(title: '病例不存在')
          : CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.pagePadding),
                    child: _buildHero(caseItem),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.pagePadding),
                    child: _buildInfoCard(caseItem),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
                if (caseItem.options.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.pagePadding),
                      child: _buildOptionsCard(caseItem),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.pagePadding),
                    child: _buildCostHint(caseItem),
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimens.grid8 + 80)),
              ],
            ),
      bottomNavigationBar: caseItem == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding, AppDimens.grid2, AppDimens.pagePadding, AppDimens.grid3),
                child: SizedBox(
                  height: AppDimens.buttonHeightLg,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.go('/student/chat?caseId=${caseItem.id}'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    label: const Text('进入问诊室'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHero(CaseModel c) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.grid5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ZyChip(c.department, tone: ZyChipTone.brand),
              const SizedBox(width: 6),
              ZyChip(c.difficulty, tone: ZyChipTone.warning),
              const Spacer(),
              if (c.certified)
                const Icon(Icons.verified_rounded,
                    size: 18, color: AppColors.aqua),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Text(
            c.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppDimens.grid2),
          Text(
            c.chief,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(CaseModel c) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '病例信息'),
          const SizedBox(height: AppDimens.grid3),
          _InfoRow(label: '科室', value: c.department),
          _InfoRow(label: '难度', value: c.difficulty),
          _InfoRow(label: '时长', value: c.duration),
          _InfoRow(label: '参考次数', value: '${c.referenceCount}'),
          _InfoRow(label: '评分', value: c.rating.toStringAsFixed(1)),
          const Divider(),
          const _InfoRow(label: '知识点', value: ''),
          const SizedBox(height: AppDimens.grid2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: c.tags
                .map<Widget>((String t) => ZyChip(t, tone: ZyChipTone.aqua))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard(CaseModel c) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '诊断选项'),
          const SizedBox(height: AppDimens.grid3),
          ...c.options.map<Widget>((String opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.grid2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.grid4,
                  vertical: AppDimens.grid3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x080F766E),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(color: AppColors.line, width: 1),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.lineStrong, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'A',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.grid3),
                    Expanded(
                      child: Text(
                        opt,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (c.requiredExam != null) ...<Widget>[
            const SizedBox(height: AppDimens.grid3),
            Container(
              padding: const EdgeInsets.all(AppDimens.grid3),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppColors.brandStrong),
                  const SizedBox(width: AppDimens.grid2),
                  Expanded(
                    child: Text(
                      '必做检查：${c.requiredExam}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandStrong,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.avoidExam != null) ...<Widget>[
            const SizedBox(height: AppDimens.grid2),
            Container(
              padding: const EdgeInsets.all(AppDimens.grid3),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.block_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: AppDimens.grid2),
                  Expanded(
                    child: Text(
                      '避免检查：${c.avoidExam}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostHint(CaseModel c) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.grid4),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: AppDimens.grid2),
          Expanded(
            child: Text(
              c.source != null
                  ? '出题依据：${c.source}'
                  : '提示：先完成低成本必要检查，再考虑高价影像。',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
                height: 1.6,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
