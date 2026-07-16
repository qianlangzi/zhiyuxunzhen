import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

class CasesListPage extends ConsumerStatefulWidget {
  const CasesListPage({super.key});

  @override
  ConsumerState<CasesListPage> createState() => _CasesListPageState();
}

class _CasesListPageState extends ConsumerState<CasesListPage> {
  final TextEditingController _queryCtrl = TextEditingController();
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
    _queryCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _queryCtrl.clear();
    setState(() {
      _query = '';
      _department = '全部';
    });
  }

  List<CaseModel> get _visible {
    final CaseRepository repo = ref.read(caseRepositoryProvider);
    final List<CaseModel> all = repo.all();
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
    final List<CaseModel> visible = _visible;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ZyPageHead(
              kicker: '病例库',
              title: '选择临床训练病例',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: TextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: '搜索病例、症状或诊断',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _DepartmentUnderlineFilter(
              departments: _departments,
              value: _department,
              onChanged: (String value) => setState(() => _department = value),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ZyEmptyState(
                title: '没有找到匹配病例',
                detail: '换一个症状、诊断名称或科室试试。',
                actionLabel: '清除筛选',
                onAction: _clearFilters,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding, 0, AppDimens.pagePadding, 120),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(height: 1, color: AppColors.line),
                itemBuilder: (BuildContext context, int index) {
                  return _CaseRow(caseItem: visible[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DepartmentUnderlineFilter extends StatelessWidget {
  const _DepartmentUnderlineFilter({
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.pagePadding,
        ),
        itemCount: departments.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppDimens.grid4),
        itemBuilder: (BuildContext context, int index) {
          final String dept = departments[index];
          final bool active = dept == value;
          return InkWell(
            onTap: () => onChanged(dept),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.grid2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppColors.brand : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                dept,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.brand : AppColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/student/case/${caseItem.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.grid4,
          horizontal: AppDimens.grid2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${caseItem.department} · ${caseItem.difficulty} · ${caseItem.duration}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (caseItem.certified) ...<Widget>[
                  const SizedBox(width: AppDimens.grid2),
                  const Icon(Icons.verified_rounded,
                      size: 16, color: AppColors.brand),
                ],
              ],
            ),
            const SizedBox(height: AppDimens.grid2),
            Text(
              caseItem.title,
              style: AppTextStyles.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              caseItem.chief,
              style: AppTextStyles.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
