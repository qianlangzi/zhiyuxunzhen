import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 学生首页：今日训练 + 热力图 + 待办 + 最近病例
class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);
    final LearningRepository learningRepo = ref.watch(learningRepositoryProvider);
    final List<CaseModel> cases = caseRepo.all();
    final List<HeatmapDay> heatmap = learningRepo.heatmap();
    final List<MistakeItem> mistakes = learningRepo.mistakes();
    final CaseModel daily = caseRepo.daily();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0,
                  AppDimens.pagePadding, AppDimens.grid3),
              child: _buildStatsRow(cases.length, mistakes.length),
            ),
          ),
          SliverToBoxAdapter(
            child: _DailyCaseCard(daily: daily),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: _HeatmapCard(days: heatmap),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: _RecentCasesCard(cases: cases),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.grid8 + AppDimens.grid4)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const ZyPageHead(
      kicker: '今日训练',
      title: '今天继续一段训练',
    );
  }

  Widget _buildStatsRow(int caseCount, int mistakeCount) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ZyStatCard(
            label: '可训练病例',
            value: '$caseCount',
            detail: '覆盖呼吸、心血管、消化系统',
            tone: StatTone.brand,
          ),
        ),
        const SizedBox(width: AppDimens.grid3),
        Expanded(
          child: ZyStatCard(
            label: '错题待巩固',
            value: '$mistakeCount',
            detail: '建议每天复盘 2 个',
          ),
        ),
      ],
    );
  }
}

class _DailyCaseCard extends StatelessWidget {
  const _DailyCaseCard({required this.daily});

  final CaseModel daily;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.grid5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.deep, Color(0xFF0F3D44)],
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          boxShadow: AppColors.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.grid2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.aquaSoft,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: const Text(
                    '每日一例',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.aqua,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.local_fire_department_rounded,
                    size: 18, color: Color(0xFFFFB17A)),
                const SizedBox(width: 4),
                const Text(
                  '连续 12 天',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFB17A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.grid4),
            Text(
              daily.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.deepInk,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppDimens.grid2),
            Text(
              daily.summary ?? daily.chief,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.deepMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppDimens.grid5),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/student/case/${daily.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.aqua,
                      foregroundColor: AppColors.deep,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusPill),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      '开始今日训练',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.days});

  final List<HeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    final List<HeatmapDay> recent = days.length > 70
        ? days.sublist(days.length - 70)
        : days;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: ZyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ZySectionHeader(
              title: '学习热力图',
              actionLabel: '病例库',
              onAction: () => context.go('/student/cases'),
            ),
            const SizedBox(height: AppDimens.grid4),
            _HeatmapGrid(days: recent),
            const SizedBox(height: AppDimens.grid3),
            Row(
              children: <Widget>[
                const Text(
                  '少',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.soft),
                ),
                const SizedBox(width: AppDimens.grid2),
                ...List<Widget>.generate(5, (int i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _colorFor(i),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
                const SizedBox(width: AppDimens.grid2),
                const Text(
                  '多',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.soft),
                ),
                const Spacer(),
                const Text(
                  '最近 10 周',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.soft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(int level) {
    switch (level) {
      case 0:
        return const Color(0x140F766E);
      case 1:
        return const Color(0x380F766E);
      case 2:
        return const Color(0x610F766E);
      case 3:
        return const Color(0x9E0F766E);
      case 4:
      default:
        return AppColors.brand;
    }
  }
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.days});

  final List<HeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    // 按周列展示，每行 7 个
    final int weeks = (days.length / 7).ceil();
    return Column(
      children: List<Widget>.generate(weeks, (int week) {
        final int start = week * 7;
        final int end = start + 7 > days.length ? days.length : start + 7;
        final List<HeatmapDay> row = days.sublist(start, end);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i < row.length
                              ? _colorFor(row[i].value)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Color _colorFor(int level) {
    switch (level) {
      case 0:
        return const Color(0x140F766E);
      case 1:
        return const Color(0x380F766E);
      case 2:
        return const Color(0x610F766E);
      case 3:
        return const Color(0x9E0F766E);
      case 4:
      default:
        return AppColors.brand;
    }
  }
}

class _RecentCasesCard extends StatelessWidget {
  const _RecentCasesCard({required this.cases});

  final List<CaseModel> cases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: ZyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ZySectionHeader(
              title: '最近病例',
              actionLabel: '全部',
              onAction: () => context.go('/student/cases'),
            ),
            const SizedBox(height: AppDimens.grid2),
            ...cases.map<Widget>((CaseModel c) {
              return _RecentCaseRow(caseItem: c);
            }),
          ],
        ),
      ),
    );
  }
}

class _RecentCaseRow extends StatelessWidget {
  const _RecentCaseRow({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    return ZyListTile(
      title: caseItem.title,
      subtitle: '${caseItem.difficulty} · ${caseItem.duration} · ${caseItem.department}',
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded,
            size: 20, color: AppColors.brand),
      ),
      onTap: () => context.go('/student/case/${caseItem.id}'),
      showDivider: false,
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
    );
  }
}