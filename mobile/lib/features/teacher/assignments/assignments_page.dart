import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 教师作业分发页
class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeachingRepository repo = ref.watch(teachingRepositoryProvider);
    final List<AssignmentModel> assignments = repo.assignments();
    final List<FormatShieldRule> rules = repo.formatRules();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: const ZyPageHead(kicker: '作业分发', title: '查看班级训练任务'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
              child: _buildNewButton(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: const ZySectionHeader(title: '进行中的作业'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding, AppDimens.grid3, AppDimens.pagePadding, AppDimens.grid4),
            sliver: SliverList.separated(
              itemCount: assignments.length,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(height: AppDimens.grid3),
              itemBuilder: (BuildContext context, int index) =>
                  _AssignmentCard(item: assignments[index]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _buildShieldCard(rules),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.grid8 + AppDimens.navBarHeight)),
        ],
      ),
    );
  }

  Widget _buildNewButton() {
    return SizedBox(
      height: AppDimens.buttonHeight,
      child: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('发起新作业'),
      ),
    );
  }

  Widget _buildShieldCard(List<FormatShieldRule> rules) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZySectionHeader(
            title: '格式盾牌',
            actionLabel: '编辑',
            onAction: () {},
          ),
          const SizedBox(height: AppDimens.grid2),
          const Text(
            '提交前的自动校验规则，未通过将被打回。',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimens.grid4),
          ...rules.map((FormatShieldRule r) => _RuleRow(rule: r)),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item});

  final AssignmentModel item;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      padding: const EdgeInsets.all(AppDimens.cardPaddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              ZyChip(item.status, tone: _statusTone(item.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.className} · 截止 ${item.due}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppDimens.grid4),
          Row(
            children: <Widget>[
              const Text(
                '提交进度',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              Text(
                '${item.submitted} / ${item.total}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ZyProgress(value: item.progress, height: 8),
          const SizedBox(height: AppDimens.grid3),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (item.requireRecord)
                ZyChip('需大病历', tone: ZyChipTone.brand),
              ZyChip(item.variable, tone: ZyChipTone.warning),
            ],
          ),
        ],
      ),
    );
  }

  ZyChipTone _statusTone(String status) {
    switch (status) {
      case '进行中':
        return ZyChipTone.brand;
      case 'AI 批阅中':
        return ZyChipTone.aqua;
      case '待复核':
        return ZyChipTone.warning;
      case '已完成':
        return ZyChipTone.success;
      default:
        return ZyChipTone.neutral;
    }
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final FormatShieldRule rule;

  @override
  Widget build(BuildContext context) {
    final ZyChipTone tone;
    final IconData icon;
    switch (rule.state) {
      case '通过':
        tone = ZyChipTone.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case '打回':
        tone = ZyChipTone.danger;
        icon = Icons.block_rounded;
        break;
      case '提示':
      default:
        tone = ZyChipTone.warning;
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.grid3),
      padding: const EdgeInsets.all(AppDimens.grid3),
      decoration: BoxDecoration(
        color: const Color(0x080F766E),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: _iconColor(tone)),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        rule.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    ZyChip(rule.state, tone: tone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rule.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _iconColor(ZyChipTone tone) {
    switch (tone) {
      case ZyChipTone.success:
        return AppColors.brand;
      case ZyChipTone.danger:
        return AppColors.danger;
      case ZyChipTone.warning:
      default:
        return AppColors.warning;
    }
  }
}