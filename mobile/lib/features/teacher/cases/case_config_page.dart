import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师病例配置页
class CaseConfigPage extends ConsumerStatefulWidget {
  const CaseConfigPage({super.key});

  @override
  ConsumerState<CaseConfigPage> createState() => _CaseConfigPageState();
}

class _CaseConfigPageState extends ConsumerState<CaseConfigPage> {
  String _filter = '全部'; // 全部 / 已认证 / 草稿

  @override
  Widget build(BuildContext context) {
    final CaseRepository repo = ref.watch(caseRepositoryProvider);
    final List<CaseModel> all = repo.all();
    final List<CaseModel> cases = _filter == '全部'
        ? all
        : _filter == '已认证'
            ? all.where((CaseModel c) => c.certified).toList()
            : all.where((CaseModel c) => !c.certified).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _buildHeader(context),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
              child: _buildCreateCard(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: const ZySectionHeader(title: '我配置的病例'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding, AppDimens.grid3, AppDimens.pagePadding, AppDimens.grid8),
            sliver: cases.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppDimens.grid10),
                      child: ZyEmptyState(
                        icon: Icons.description_outlined,
                        title: '当前筛选下暂无病例',
                        detail: '切换筛选或新建一份病例',
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: cases.length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(height: AppDimens.grid3),
                    itemBuilder: (BuildContext context, int index) =>
                        _CaseRow(item: cases[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final List<String> labels = <String>['全部', '已认证', '草稿'];
    return Column(
      children: <Widget>[
        const ZyPageHead(kicker: '病例配置', title: '管理 SP 与训练病例'),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(width: AppDimens.grid2),
              itemBuilder: (BuildContext context, int index) {
                final String label = labels[index];
                final bool active = label == _filter;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _filter = label),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.grid4),
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
                        label,
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
          ),
        ),
      ],
    );
  }

  Widget _buildCreateCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.grid5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.brand, AppColors.brandStrong],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: AppColors.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.aqua),
              SizedBox(width: AppDimens.grid2),
              Text(
                '新建 SP 病例',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xCCFFFFFF),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          const Text(
            '用模板快速生成\n或从零搭建一份病例',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppDimens.grid5),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandStrong,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusPill),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    '新建病例',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.grid3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/teacher/market'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusPill),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 20),
                  label: const Text(
                    '病例广场',
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
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.item});

  final CaseModel item;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.description_outlined,
                size: 22, color: AppColors.brand),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (item.certified)
                      const Icon(Icons.verified_rounded,
                          size: 14, color: AppColors.aqua),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.department} · ${item.difficulty} · ${item.duration}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 20, color: AppColors.brandStrong),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
