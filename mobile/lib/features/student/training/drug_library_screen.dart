import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 药理分类选项：首位固定「全部」，其余由后端动态下发
  List<String> _categories = const ['全部'];

  /// 生效中的筛选（选中值集合，空 = 该维「全部」）
  Set<String> _selDepts = {};
  Set<String> _selCats = {};

  String _query = '';

  /// 是否有生效中的筛选（科室或药理分类任一非空）
  bool get _hasActiveFilter => _selDepts.isNotEmpty || _selCats.isNotEmpty;

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

  /// 训练中心入口带参：把初始科室 / 分类写入选中集合
  void _preselect() {
    final initDept = widget.initialDepartment?.trim();
    if (initDept != null && initDept.isNotEmpty && _departments.contains(initDept)) {
      _selDepts = {initDept};
    }
    final initCat = widget.initialCategory?.trim();
    if (initCat != null && initCat.isNotEmpty && _categories.contains(initCat)) {
      _selCats = {initCat};
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
      categories: _selCats.isEmpty ? null : _selCats.toList(),
      departments: _selDepts.isEmpty ? null : _selDepts.toList(),
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
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: Row(
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 10),
                  _buildFilterButton(context),
                ],
              ),
            ),
            // 有生效筛选时，以灵动小标签展示当前维度，可单独清除
            if (_hasActiveFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _buildActiveFilterRow(context),
              ),
            const SizedBox(height: 4),
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
    return AppSearchField(
      controller: _searchCtl,
      hintText: '搜索药品名 / 商品名 / 主治',
      onChanged: _onSearchChanged,
      onClear: () {
        _searchDebounce?.cancel();
        setState(() => _query = '');
        _reload();
      },
    );
  }

  // ---------- 筛选 ----------
  /// 常驻「筛选」入口按钮：带生效角标，点击弹起底部筛选面板
  Widget _buildFilterButton(BuildContext context) {
    final active = _hasActiveFilter;
    return AppPressable(
      onTap: _showFilterSheet,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active
              ? AppColors.indigoOf(context)
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active
                ? AppColors.indigoOf(context)
                : AppColors.surfaceEdgeOf(context),
          ),
          boxShadow: active ? null : AppShadow.card(context),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: active
                    ? AppColors.onPrimaryOf(context)
                    : AppColors.text3Of(context),
              ),
            ),
            if (active)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.amberOf(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.surfaceOf(context), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 当前生效筛选标签行（多选：每个选中值一枚标签）：可单独删除 / 一键清除
  Widget _buildActiveFilterRow(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        alignment: AlignmentDirectional.centerStart,
        child: child,
      ),
      child: SingleChildScrollView(
        key: ValueKey('$_selDepts-$_selCats'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final d in _selDepts)
              _activeTag(context, d, () {
                setState(() => _selDepts.remove(d));
                _reload();
              }),
            for (final c in _selCats)
              _activeTag(context, c, () {
                setState(() => _selCats.remove(c));
                _reload();
              }),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selDepts = {};
                  _selCats = {};
                });
                _reload();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '清除',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text3Of(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeTag(BuildContext context, String label, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: AppColors.indigoSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.indigoOf(context),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: AppColors.indigoOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部筛选面板：科室 × 药理分类网格胶囊，「确定」统一生效
  ///
  /// 面板是自包含的 [_DrugFilterSheet]：自己的 context、自己的动画 controller，
  /// 不捕获页面 State 的任何闭包。vsync 用 Navigator（比页面活得久），
  /// 避免「面板退出动画进行中页面被 pop」时 ticker 挂在已销毁的 State 上。
  Future<void> _showFilterSheet() async {
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );
    // 面板只负责采集多选结果，通过 pop 回传选中集合，由页面统一写回并刷新
    final result = await showModalBottomSheet<({Set<String> depts, Set<String> cats})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      // 路由不会释放外部传入的 controller（willDisposeAnimationController=false），
      // 归属 _DrugFilterSheet，由它在自己的 dispose 里统一释放。
      transitionAnimationController: controller,
      builder: (_) => _DrugFilterSheet(
        controller: controller,
        departments: _departments,
        categories: _categories,
        selectedDepts: _selDepts,
        selectedCats: _selCats,
      ),
    );
    if (result == null || !mounted) return;
    // 未变更则直接返回，避免无意义的网络请求
    if (setEquals(result.depts, _selDepts) && setEquals(result.cats, _selCats)) {
      return;
    }
    setState(() {
      _selDepts = result.depts;
      _selCats = result.cats;
    });
    _reload();
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

/// 自包含的底部筛选面板（自持有动画与选中态）
///
/// 设计要点：面板是独立路由层级的子树，**所有 Theme / MediaQuery 取值都用
/// 面板自身的 context**。早前版本把面板做成外层页面 State 的闭包拼装，取色
/// 用了页面 context——面板退出动画逐帧 rebuild，若此时页面被 pop（如连按
/// 两次返回），就会在失活 context 上做依赖查找而整页崩溃。自包含后面板
/// context 随面板生死，与页面完全解耦。
class _DrugFilterSheet extends StatefulWidget {
  const _DrugFilterSheet({
    required this.controller,
    required this.departments,
    required this.categories,
    required this.selectedDepts,
    required this.selectedCats,
  });

  /// 由 [_showFilterSheet] 创建、传入并负责转交归属（路由不释放外部 controller）
  final AnimationController controller;

  final List<String> departments;
  final List<String> categories;

  /// 当前生效的选中值（字符串），面板在其基础上做多选增删
  final Set<String> selectedDepts;
  final Set<String> selectedCats;

  @override
  State<_DrugFilterSheet> createState() => _DrugFilterSheetState();
}

class _DrugFilterSheetState extends State<_DrugFilterSheet> {
  late Set<String> _depts = {...widget.selectedDepts};
  late Set<String> _cats = {...widget.selectedCats};

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  /// 多选切换：点已选 = 灭掉；点未选 = 亮起；点「全部」= 清空该维
  void _toggle(Set<String> set, String value) {
    HapticFeedback.selectionClick();
    setState(() {
      if (value == '全部') {
        set.clear();
      } else {
        set.contains(value) ? set.remove(value) : set.add(value);
      }
    });
  }

  void _confirm() {
    HapticFeedback.lightImpact();
    // 回传选中集合：页面据此写回生效筛选并刷新
    Navigator.pop<({Set<String> depts, Set<String> cats})>(
      context,
      (
        depts: Set<String>.of(_depts),
        cats: Set<String>.of(_cats),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      // 内容层淡入：跟随上滑进度，easeOut 让入场更干脆
      builder: (context, child) => Opacity(
        opacity:
            Curves.easeOut.transform(widget.controller.value.clamp(0.0, 1.0)),
        child: child,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: size.size.height * 0.82),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + size.viewInsets.bottom + size.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽把手
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ruleOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '筛选',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOf(context),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _depts.clear();
                    _cats.clear();
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      '重置',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 中段滚动区：科室 + 药理分类，选项再多也不撑爆屏幕
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetSection(context, '科室', widget.departments, _depts),
                    const SizedBox(height: 22),
                    _sheetSection(
                        context, '药理分类', widget.categories, _cats),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
            // 确定：仅在有变更时写回并刷新
            AppPressable(
              onTap: _confirm,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.indigoOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '确定',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryOf(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 多选分区：标题带「可多选」提示；「全部」选中 = 集合为空
  Widget _sheetSection(
      BuildContext context, String title, List<String> keys, Set<String> sel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textOf(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '可多选',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.text4Of(context),
              ),
            ),
            if (sel.isNotEmpty) ...[
              const Spacer(),
              Text(
                '已选 ${sel.length} 项',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.indigoOf(context),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final key in keys)
              _sheetPill(
                context,
                key,
                key == '全部' ? sel.isEmpty : sel.contains(key),
                () => _toggle(sel, key),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sheetPill(
      BuildContext context, String label, bool active, VoidCallback onTap) {
    return AppPressable(
      onTap: () {
        HapticFeedback.selectionClick(); // 轻触感反馈，选中更「有手感」
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.indigoOf(context)
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active
                ? AppColors.indigoOf(context)
                : AppColors.surfaceEdgeOf(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active
                ? AppColors.onPrimaryOf(context)
                : AppColors.text3Of(context),
          ),
        ),
      ),
    );
  }
}
