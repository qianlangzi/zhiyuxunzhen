import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

class CasesListPage extends ConsumerStatefulWidget {
  const CasesListPage({super.key});

  @override
  ConsumerState<CasesListPage> createState() => _CasesListPageState();
}

class _CasesListPageState extends ConsumerState<CasesListPage> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';
  String _department = '全部';

  static const List<String> _departments = <String>[
    '全部',
    '心血管',
    '呼吸',
    '消化',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _queryController.clear();
    setState(() {
      _query = '';
      _department = '全部';
    });
  }

  List<CaseModel> _visibleCases(List<CaseModel> all) {
    final String query = _query.trim().toLowerCase();
    return all.where((CaseModel item) {
      final bool departmentMatches =
          _department == '全部' || item.department.contains(_department);
      final bool queryMatches = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.chief.toLowerCase().contains(query) ||
          item.tags.any((String tag) => tag.toLowerCase().contains(query));
      return departmentMatches && queryMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CaseModel>> cases = ref.watch(caseListProvider);
    return cases.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: ZyErrorState(
          title: '病例加载失败',
          message: error.toString(),
          actionLabel: '重新加载',
          onRetry: () => ref.invalidate(caseListProvider),
        ),
      ),
      data: (List<CaseModel> all) => _buildCases(all),
    );
  }

  Widget _buildCases(List<CaseModel> all) {
    final List<CaseModel> visibleCases = _visibleCases(all);

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '病例发现',
              identityLabel: '学生工作区',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid2,
                AppDimens.pagePadding,
                AppDimens.grid3,
              ),
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: '搜索病例',
                  hintText: '输入症状、诊断或训练标签',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _DepartmentFilter(
              departments: _departments,
              value: _department,
              onChanged: (String value) {
                setState(() => _department = value);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid3,
                AppDimens.pagePadding,
                0,
              ),
              child: ClinicalSectionHeader(
                title: '病例记录',
                description: '共 ${visibleCases.length} 条符合条件的训练病例。',
              ),
            ),
          ),
          if (visibleCases.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ZyEmptyState(
                title: '没有找到匹配病例',
                detail: '可以更换关键词或科室后重新查找。',
                actionLabel: '清除筛选',
                onAction: _clearFilters,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                120,
              ),
              sliver: SliverList.builder(
                itemCount: visibleCases.length,
                itemBuilder: (BuildContext context, int index) {
                  final CaseModel item = visibleCases[index];
                  return ClinicalRecordRow(
                    leadingLabel: item.id,
                    title: item.title,
                    subtitle: <String>[
                      item.department,
                      item.difficulty,
                      if (item.chief.isNotEmpty) item.chief,
                    ].where((String value) => value.isNotEmpty).join(' · '),
                    statusLabel: item.certified ? '已认证' : '训练病例',
                    statusTone: item.certified
                        ? ClinicalEvidenceTone.success
                        : ClinicalEvidenceTone.neutral,
                    onTap: () => context.push('/student/case/${item.id}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DepartmentFilter extends StatelessWidget {
  const _DepartmentFilter({
    required this.departments,
    required this.value,
    required this.onChanged,
  });

  final List<String> departments;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
        itemCount: departments.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppDimens.grid4),
        itemBuilder: (BuildContext context, int index) {
          final String department = departments[index];
          final bool selected = department == value;
          return Semantics(
            button: true,
            selected: selected,
            label: '筛选科室：$department',
            child: InkWell(
              onTap: () => onChanged(department),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.grid2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.action : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  department,
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.action : AppColors.graphite,
                    fontWeight: FontWeight.w700,
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
