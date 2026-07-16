import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 病例广场：搜索 + 列表 + 单一引用动作
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
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ZyPageHead(
              kicker: '病例广场',
              title: '引用共享训练病例',
              subtitle: '从广场引用已验证的病例到你的病例库。',
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
                  hintText: '搜索病例、作者或科室',
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
                detail: '换一个关键词或科室试试。',
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
                  return _MarketRow(
                    item: visible[index],
                    referenced: _referenced.contains(visible[index].title),
                    onReference: () => _reference(visible[index]),
                  );
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

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.item,
    required this.referenced,
    required this.onReference,
  });

  final MarketCaseModel item;
  final bool referenced;
  final VoidCallback onReference;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppDimens.grid4, horizontal: AppDimens.grid2),
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
                    Text(item.title, style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(
                      '${item.author} · ${item.department}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (item.certified)
                ZyChip('已认证', tone: ZyChipTone.success)
              else
                ZyChip('未认证', tone: ZyChipTone.neutral),
            ],
          ),
          const SizedBox(height: AppDimens.grid2),
          Text(
            '${Formatters.difficultyLabel(item.difficulty)} · 评分 ${item.rating.toStringAsFixed(1)} · ${item.referenceCount} 次引用',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppDimens.grid3),
          Align(
            alignment: Alignment.centerLeft,
            child: referenced
                ? FilledButton.tonal(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                          AppDimens.touchTarget, AppDimens.touchTarget),
                    ),
                    child: const Text('已引用'),
                  )
                : FilledButton(
                    onPressed: onReference,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                          AppDimens.touchTarget, AppDimens.touchTarget),
                    ),
                    child: const Text('引用病例'),
                  ),
          ),
        ],
      ),
    );
  }
}
