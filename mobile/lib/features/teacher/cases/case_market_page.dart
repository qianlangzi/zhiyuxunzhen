import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 病例广场：搜索、科室筛选与单一引用动作。
class CaseMarketPage extends ConsumerStatefulWidget {
  const CaseMarketPage({super.key});

  @override
  ConsumerState<CaseMarketPage> createState() => _CaseMarketPageState();
}

class _CaseMarketPageState extends ConsumerState<CaseMarketPage> {
  final TextEditingController _queryCtrl = TextEditingController();
  String _query = '';
  String _department = '全部';
  final Set<String> _referenced = <String>{};

  static const List<String> _departments = <String>[
    '全部',
    '心血管',
    '呼吸系统',
    '消化系统',
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

  void _reference(MarketCaseModel item) {
    if (_referenced.contains(item.title)) return;
    setState(() => _referenced.add(item.title));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('病例已加入你的病例库')),
    );
  }

  List<MarketCaseModel> get _visible {
    final CaseRepository repo = ref.read(caseRepositoryProvider);
    final List<MarketCaseModel> all = repo.market();
    final String query = _query.trim().toLowerCase();
    return all.where((MarketCaseModel item) {
      final bool departmentMatches =
          _department == '全部' || item.department.contains(_department);
      final bool queryMatches = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.author.toLowerCase().contains(query) ||
          item.department.toLowerCase().contains(query);
      return departmentMatches && queryMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<MarketCaseModel> visible = _visible;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        key: const ValueKey<String>('case-market-scroll'),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '病例广场',
              identityLabel: '教师工作台 · 共享病例',
              action: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go('/teacher/cases');
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: TextField(
                key: const ValueKey<String>('case-market-search'),
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: '搜索病例',
                  hintText: '按名称、来源或科室检索',
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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid4,
                AppDimens.pagePadding,
                0,
              ),
              child: ClinicalSectionHeader(
                title: '共享病例登记',
                description: '按科室与关键词筛选，点击记录即可引用。',
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ZyEmptyState(
                title: '没有找到匹配病例',
                detail: '换一个关键词或科室试试。',
                actionLabel: '清除筛选',
                onAction: _clearFilters,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid2,
                AppDimens.pagePadding,
                120,
              ),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) => _MarketRow(
                  item: visible[index],
                  referenced: _referenced.contains(visible[index].title),
                  onReference: () => _reference(visible[index]),
                  showDivider: index != visible.length - 1,
                ),
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
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
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
                style: AppTextStyles.bodyStrong.copyWith(
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

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.item,
    required this.referenced,
    required this.onReference,
    required this.showDivider,
  });

  final MarketCaseModel item;
  final bool referenced;
  final VoidCallback onReference;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return ClinicalRecordRow(
      leadingLabel: item.department,
      title: item.title,
      subtitle: '来源：${item.author} · '
          '难度：${Formatters.difficultyLabel(item.difficulty)} · '
          '评分 ${item.rating.toStringAsFixed(1)} · '
          '${item.referenceCount} 次引用 · '
          '${item.certified ? '已认证' : '未认证'}',
      statusLabel: referenced ? '已引用' : '引用病例',
      statusTone: referenced
          ? ClinicalEvidenceTone.success
          : ClinicalEvidenceTone.action,
      onTap: referenced ? null : onReference,
      showDivider: showDivider,
    );
  }
}
