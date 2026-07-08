import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 病例列表
class CasesListPage extends ConsumerStatefulWidget {
  const CasesListPage({super.key});

  @override
  ConsumerState<CasesListPage> createState() => _CasesListPageState();
}

class _CasesListPageState extends ConsumerState<CasesListPage> {
  String _department = '全部';

  @override
  Widget build(BuildContext context) {
    final CaseRepository repo = ref.watch(caseRepositoryProvider);
    final List<CaseModel> all = repo.all();
    final List<CaseModel> cases = _department == '全部'
        ? all
        : all.where((CaseModel c) => c.department == _department).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverToBoxAdapter(
            child: _buildDepartmentFilter(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding, AppDimens.grid4, AppDimens.pagePadding, AppDimens.grid8),
            sliver: cases.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppDimens.grid10),
                      child: ZyEmptyState(
                        icon: Icons.layers_outlined,
                        title: '当前科室暂无病例',
                        detail: '试试切换其他科室',
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: cases.length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(height: AppDimens.grid3),
                    itemBuilder: (BuildContext context, int index) {
                      return _CaseCard(caseItem: cases[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const ZyPageHead(
      kicker: '选择病例',
      title: '选择一个模拟病人\n开始训练',
    );
  }

  Widget _buildDepartmentFilter() {
    final List<String> departments = <String>['全部', '呼吸系统', '心血管', '消化系统'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
        itemCount: departments.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppDimens.grid2),
        itemBuilder: (BuildContext context, int index) {
          final String dept = departments[index];
          final bool active = dept == _department;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _department = dept),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.grid4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(
                    color: active ? AppColors.brand : AppColors.line,
                    width: 1,
                  ),
                ),
                child: Text(
                  dept,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      onTap: () => context.go('/student/case/${caseItem.id}'),
      padding: const EdgeInsets.all(AppDimens.cardPaddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          caseItem.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: AppDimens.grid2),
                        if (caseItem.certified)
                          const Icon(Icons.verified_rounded,
                              size: 16, color: AppColors.aqua),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caseItem.chief,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.grid2,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _difficultyBg(caseItem.difficulty),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  Formatters.difficultyLabel(caseItem.difficulty),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _difficultyFg(caseItem.difficulty),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: caseItem.tags
                .map<Widget>((String t) => ZyChip(t, tone: ZyChipTone.neutral))
                .toList(),
          ),
          const SizedBox(height: AppDimens.grid4),
          Row(
            children: <Widget>[
              const Icon(Icons.access_time_rounded,
                  size: 14, color: AppColors.soft),
              const SizedBox(width: 4),
              Text(
                caseItem.duration,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.soft,
                ),
              ),
              const SizedBox(width: AppDimens.grid3),
              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFC47A20)),
              const SizedBox(width: 4),
              Text(
                caseItem.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.soft,
                ),
              ),
              const Spacer(),
              const Text(
                '进入问诊室',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandStrong,
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppColors.brandStrong),
            ],
          ),
        ],
      ),
    );
  }

  Color _difficultyBg(String d) {
    switch (d) {
      case '基础':
        return AppColors.brandSoft;
      case '标准':
        return const Color(0x2414B8A6);
      case '进阶':
        return AppColors.amberSoft;
      case '高阶':
      default:
        return AppColors.dangerSoft;
    }
  }

  Color _difficultyFg(String d) {
    switch (d) {
      case '基础':
        return AppColors.brandStrong;
      case '标准':
        return AppColors.brandStrong;
      case '进阶':
        return AppColors.warning;
      case '高阶':
      default:
        return AppColors.danger;
    }
  }
}
