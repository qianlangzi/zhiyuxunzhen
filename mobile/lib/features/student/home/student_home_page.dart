import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);
    final LearningRepository learningRepo =
        ref.watch(learningRepositoryProvider);
    final List<CaseModel> cases = caseRepo.all();
    final List<MistakeItem> mistakes = learningRepo.mistakes();
    final CaseModel daily = caseRepo.daily();
    final int pendingCount =
        mistakes.where((MistakeItem item) => !item.reviewed).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ZyPageHead(
              kicker: '今天的训练',
              title: '从一个病例继续',
              subtitle: '完成问诊、检查决策和诊断推理。',
            ),
          ),
          SliverToBoxAdapter(child: _ContinueTraining(caseItem: daily)),
          SliverToBoxAdapter(
            child: _StudentTodoList(pendingCount: pendingCount),
          ),
          SliverToBoxAdapter(
            child: _RecentTrainingList(cases: cases.take(2).toList()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }
}

class _ContinueTraining extends StatelessWidget {
  const _ContinueTraining({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: ZyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ZyChip('每日一练'),
            const SizedBox(height: 14),
            Text(caseItem.title, style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              caseItem.summary ?? caseItem.chief,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go('/student/case/${caseItem.id}'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('继续训练'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTodoList extends StatelessWidget {
  const _StudentTodoList({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '今日待办'),
          ZyListTile(
            leading: const Icon(Icons.history_edu_rounded,
                color: Color(0xFF5F9CA5), size: 22),
            title: '待复盘',
            subtitle: pendingCount > 0 ? '还有 $pendingCount 条待复盘' : '今日已清空',
            onTap: () => context.go('/student/mistakes'),
          ),
          ZyListTile(
            leading: const Icon(Icons.library_books_rounded,
                color: Color(0xFF5F9CA5), size: 22),
            title: '浏览全部病例',
            subtitle: '心肺消化多系统训练',
            onTap: () => context.go('/student/cases'),
          ),
        ],
      ),
    );
  }
}

class _RecentTrainingList extends StatelessWidget {
  const _RecentTrainingList({required this.cases});

  final List<CaseModel> cases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZySectionHeader(
            title: '最近训练',
            actionLabel: '查看全部',
            onAction: () => context.go('/student/cases'),
          ),
          for (final CaseModel item in cases)
            ZyListTile(
              title: item.title,
              subtitle:
                  '${item.department} · ${item.difficulty} · ${item.duration}',
              onTap: () => context.go('/student/case/${item.id}'),
            ),
        ],
      ),
    );
  }
}
