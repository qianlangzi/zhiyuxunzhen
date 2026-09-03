import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../common/data/drug_api.dart';
import 'drug_item.dart';

/// 药品库独立页（训练中心 · 药房）
///
/// 承载「浏览 / 查找药品」的完整能力：搜索（通用名 / 商品名 / 适应症，服务端
/// 模糊）+ 药理分类筛选 + 科室筛选 + 分页。与训练中心的入口解耦。
///
/// 筛选维度（科室 × 药理双维）由后端 `/drugs/filters` 动态下发：
/// - 科室列在 drug.department 为逗号分隔多值，后端拆分去重后下发；
/// - 药理分类是种子数据固定全集（相对稳定），同样动态下发避免硬编码。
///
/// 两维可叠加筛选（如「心血管内科 + 他汀类」），默认均不选 = 全量。
class DrugLibraryScreen extends ConsumerStatefulWidget {
  const DrugLibraryScreen({
    super.key,
    this.initialDepartment,
    this.initialCategory,
  });

  /// 训练中心快捷入口预选（如「心血管内科」）
  final String? initialDepartment;

  /// 训练中心快捷入口预选（如「他汀类调脂药」）
  final String? initialCategory;

  @override
  ConsumerState<DrugLibraryScreen> createState() => _DrugLibraryScreenState();
}

class _DrugLibraryScreenState extends ConsumerState<DrugLibraryScreen> {
  /// 科室选项：首位固定「全部」，其余由后端动态下发
  List<String> _departments = const ['全部'];
  int _deptIdx = 0;

  /// 药理分类选项：首位固定「全部」，其余由后端动态下发
  List<String> _categories = const ['全部'];
  int _catIdx = 0;

  String _query = '';

  /// 药理分类筛选是否展开（默认收起，保持页面简约）
  bool _showCategories = false;

  final _searchCtl = TextEditingController();
  Timer? _searchDebounce;

  List<DrugItem> _list = [];
  final ScrollController _scroll = ScrollController();
  static const int _pageSize = 10;
  int _pageNum = 1;
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final hasPreset = (widget.initialDepartment?.trim().isNotEmpty ?? false) ||
        (widget.initialCategory?.trim().isNotEmpty ?? false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasPreset) {
        // 入口带预选：先等筛选维度就绪换算成索引，再按预选条件拉列表，
        // 避免 filters 未返回时以「全部」抢先加载造成结果覆盖。
        _loadFilters().then((_) => _reload());
      } else {
        _reload();
        _loadFilters();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  /// 训练中心入口带参：把初始科室 / 分类换算成对应索引
  void _preselect() {
    final initDept = widget.initialDepartment?.trim();
    if (initDept != null && initDept.isNotEmpty) {
      final i = _departments.indexOf(initDept);
      if (i > 0) _deptIdx = i;
    }
    final initCat = widget.initialCategory?.trim();
    if (initCat != null && initCat.isNotEmpty) {
      final i = _categories.indexOf(initCat);
      if (i > 0) {
        _catIdx = i;
        _showCategories = true; // 分类来自入口预选时自动展开，方便用户感知当前维度
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 240) _loadMore();
  }

  /// 拉取动态筛选维度（科室 / 药理分类）；失败时静默降级为仅「全部」
  Future<void> _loadFilters() async {
    final resp = await DrugApi().getFilters();
    if (!mounted || !resp.isSuccess || resp.data == null) return;
    final depts = (resp.data!['departments'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final cats = (resp.data!['categories'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    setState(() {
      _departments = ['全部', ...depts];
      _categories = ['全部', ...cats];
      _preselect(); // 维度全集就绪后再换算入口预选索引
    });
  }

  Future<void> _reload() async {
    setState(() {
      _pageNum = 1;
      _hasMore = true;
      _isLoadingMore = false;
      _isLoading = true;
    });
    final resp = await _fetch(pageNum: 1);
    if (!mounted) return;
    setState(() {
      if (resp.isSuccess && resp.data != null) {
        final list = resp.data!['list'] as List<dynamic>? ?? [];
        _list = list
            .map((e) => DrugItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _hasMore = list.length >= _pageSize;
      } else {
        _list = [];
        _hasMore = false;
      }
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore || _list.isEmpty) return;
    setState(() => _isLoadingMore = true);
    final resp = await _fetch(pageNum: _pageNum + 1);
    if (!mounted) return;
    setState(() {
      _isLoadingMore = false;
      if (resp.isSuccess && resp.data != null) {
        final next = (resp.data!['list'] as List<dynamic>? ?? [])
            .map((e) => DrugItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (next.isEmpty) {
          _hasMore = false;
          return;
        }
        _list = [..._list, ...next];
        _pageNum += 1;
        _hasMore = next.length >= _pageSize;
      } else {
        _hasMore = false;
      }
    });
  }

  Future<dynamic> _fetch({required int pageNum}) async {
    return DrugApi().getDrugList(
      pageNum: pageNum,
      pageSize: _pageSize,
      category: _catIdx == 0 ? null : _categories[_catIdx],
      department: _deptIdx == 0 ? null : _departments[_deptIdx],
      keyword: _query.trim().isEmpty ? null : _query.trim(),
    );
  }

  /// 搜索输入：400ms 防抖后走服务端搜索
  void _onSearchChanged(String v) {
    _query = v;
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _reload();
    });
  }

  void _onFilterChanged() {
    setState(() {});
    _reload();
  }

  void _openDetail(DrugItem d) {
    if (!mounted) return;
    context.pushNamed(RouteNames.drugDetail, pathParameters: {'id': '${d.id}'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '药品库'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: _buildSearchBar(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildDeptBar(context),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: _showCategories
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
                      child: _buildCategoryRow(),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? _buildSkeleton()
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: Builder(
                        builder: (context) {
                          final visible = _list;
                          final empty = visible.isEmpty;
                          return ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                            itemCount: empty ? 1 : visible.length + 1,
                            itemBuilder: (context, i) {
                              if (empty) return _buildEmpty();
                              if (i < visible.length) {
                                return _drugCard(visible[i]);
                              }
                              return _buildFooter(visible.length);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 搜索 ----------
  Widget _buildSearchBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.surfaceEdgeOf(context),
        ),
        boxShadow: AppShadow.card(context),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: AppColors.text4Of(context)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '搜索药品名 / 商品名 / 主治',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.text4Of(context),
                ),
              ),
              style: TextStyle(fontSize: 13, color: AppColors.textOf(context)),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchDebounce?.cancel();
                _searchCtl.clear();
                setState(() => _query = '');
                _reload();
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.ruleSoftOf(context),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.clear_rounded,
                  size: 14,
                  color: AppColors.text3Of(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 筛选 ----------
  /// 常驻科室行：横向滚动 chips + 右侧「分类」展开按钮（药理分类维度）
  Widget _buildDeptBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _chips(
            keys: _departments,
            isActive: (label) => _departments[_deptIdx] == label,
            onTap: (label) {
              _deptIdx = _departments.indexOf(label);
              _onFilterChanged();
            },
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _showCategories = !_showCategories),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: _showCategories
                  ? AppColors.indigoOf(context)
                  : AppColors.surfaceOf(context),
              border: Border.all(
                color: _showCategories
                    ? AppColors.indigoOf(context)
                    : AppColors.surfaceEdgeOf(context),
              ),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: _showCategories
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text3Of(context),
                ),
                const SizedBox(width: 4),
                Text(
                  _showCategories ? '收起分类' : '药理分类',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _showCategories ? FontWeight.w600 : FontWeight.w500,
                    color: _showCategories
                        ? AppColors.onPrimaryOf(context)
                        : AppColors.text3Of(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow() {
    return _chips(
      keys: _categories,
      isActive: (label) => _categories[_catIdx] == label,
      onTap: (label) {
        _catIdx = _categories.indexOf(label);
        _onFilterChanged();
      },
    );
  }

  Widget _chips({
    required List<String> keys,
    required bool Function(String label) isActive,
    required ValueChanged<String> onTap,
  }) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = keys[i];
          final active = isActive(label);
          return GestureDetector(
            onTap: () => onTap(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceOf(context),
                border: Border.all(
                  color: active
                      ? AppColors.primaryOf(context)
                      : AppColors.surfaceEdgeOf(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text3Of(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- 列表 ----------
  Widget _buildFooter(int count) {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: MonoText(
          _hasMore ? '已收录 $count 种药 · 上滑继续' : '— 已展示全部 —',
          fontSize: 11,
          color: AppColors.text4Of(context),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('暂无符合条件的药品',
              style:
                  TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: AppSkeleton(height: 92, radius: AppRadius.lg),
          ),
      ],
    );
  }

  Widget _drugCard(DrugItem d) {
    final accent = AppColors.indigoOf(context);
    return AppPressable(
      onTap: () => _openDetail(d),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.6)),
          boxShadow: AppShadow.card(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 药丸图标：青蓝圆底，一眼识别为「药」
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.indigoSoftOf(context),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                d.isOtc ? Icons.storefront_outlined : Icons.medication_outlined,
                size: 26,
                color: accent,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          d.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (d.isOtc ? AppColors.amberOf(context)
                                  : AppColors.primaryOf(context))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          d.isOtc ? 'OTC' : '处方药',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: kCjkMonoFallback,
                            fontWeight: FontWeight.w600,
                            color: d.isOtc
                                ? AppColors.amberOf(context)
                                : AppColors.primaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    d.genericName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: const [
                        'Songti SC',
                        'STSong',
                        'Noto Serif CJK SC',
                        'Source Han Serif SC',
                        'sans-serif',
                      ],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                      height: 1.32,
                    ),
                  ),
                  if (d.tradeName.isNotEmpty || d.dosageForm.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (d.tradeName.isNotEmpty) '商品名 ${d.tradeName}',
                        if (d.dosageForm.isNotEmpty) d.dosageForm,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: AppColors.text3Of(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }
}
