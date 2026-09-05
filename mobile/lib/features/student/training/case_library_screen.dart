import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../common/data/case_market_api.dart';
import 'case_market_item.dart';

/// 独立病例库页（训练中心 · 库房）
///
/// 承载「浏览 / 查找病例」的完整能力：搜索（标题/患者画像/知识点，服务端模糊）+
/// 排序 + 科室 / 难度筛选 + 分页。与训练中心的枢纽入口解耦，解决数据量增长后的展示压力。
///
/// 科室筛选项由后端 `/case-market/departments` 动态下发（教师创建病例时可自由
/// 填写科室，无法预知全集，硬编码会导致新增科室永远筛不到）。
class CaseLibraryScreen extends ConsumerStatefulWidget {
  const CaseLibraryScreen({super.key});

  @override
  ConsumerState<CaseLibraryScreen> createState() => _CaseLibraryScreenState();
}

class _CaseLibraryScreenState extends ConsumerState<CaseLibraryScreen> {
  static const _difficulties = ['全部', '简单', '标准', '困难'];

  /// 排序选项：label -> (sortBy, order)
  static const _sorts = <String, (String, String)>{
    '最新': ('createdAt', 'desc'),
    '评分': ('rating', 'desc'),
    '最热': ('reference', 'desc'),
  };

  /// 科室选项：首位固定「全部」，其余由后端动态下发
  List<String> _departments = const ['全部'];

  int _deptIdx = 0;
  int _diffIdx = 0;
  String _sortKey = '最新';
  String _query = '';

  /// 科室 / 难度筛选是否展开（默认收起，保持页面简约）
  bool _showFilters = false;

  final _searchCtl = TextEditingController();
  Timer? _searchDebounce;

  List<CaseMarketItem> _list = [];
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
      _loadDepartments();
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

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 240) _loadMore();
  }

  /// 拉取动态科室列表；失败时静默降级为仅「全部」，不影响主流程
  Future<void> _loadDepartments() async {
    final resp = await CaseMarketApi().getDepartments();
    if (!mounted || !resp.isSuccess || resp.data == null) return;
    final depts = resp.data!
        .map((e) => e.toString().trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    setState(() {
      _departments = ['全部', ...depts];
      _deptIdx = 0; // 科室全集变化后重置选中，避免索引越界
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
            .map((e) => CaseMarketItem.fromJson(e as Map<String, dynamic>))
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
            .map((e) => CaseMarketItem.fromJson(e as Map<String, dynamic>))
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
    final (sortBy, order) = _sorts[_sortKey]!;
    return CaseMarketApi().getCaseList(
      pageNum: pageNum,
      pageSize: _pageSize,
      department: _deptIdx == 0 ? null : _departments[_deptIdx],
      difficulty: _diffIdx == 0 ? null : _diffIdx,
      keyword: _query.trim().isEmpty ? null : _query.trim(),
      sortBy: sortBy,
      order: order,
    );
  }

  /// 搜索输入：400ms 防抖后走服务端搜索（原为纯客户端过滤，只能命中已加载页）
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

  /// 进入病例问诊
  ///
  /// 交互约定（2026-09-02 会话持久化改造）：
  /// - 未做过 / 进行中：进入问诊室。进行中由服务端 start() 复用原会话续聊，
  ///   聊天页会自动加载历史聊天记录；
  /// - 已完成 / 评估异常：主入口先看上次 OSCE 报告（历史可见）；想再练一次走卡片上的「再练一次」。
  Future<void> _startCase(CaseMarketItem c) async {
    if (!mounted) return;
    if (c.hasReport && c.lastSessionId != null) {
      context.pushNamed(
        RouteNames.osceResult,
        queryParameters: {'sessionId': c.lastSessionId.toString()},
      );
      return;
    }
    context.pushNamed(
      RouteNames.chat,
      queryParameters: {'caseId': c.id.toString()},
    );
  }

  /// 重新开一次问诊（已完成病例再练一遍 → 服务端会新建会话）
  Future<void> _retryCase(CaseMarketItem c) async {
    if (!mounted) return;
    context.pushNamed(
      RouteNames.chat,
      queryParameters: {'caseId': c.id.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '病例库'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: _buildSearchBar(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildFilterBar(context),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: _showFilters
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
                      child: Column(
                        children: [
                          _buildDeptRow(),
                          _buildDifficultyRow(),
                        ],
                      ),
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
                                return _caseCard(visible[i]);
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
      hintText: '搜索标题 / 症状 / 知识点',
      onChanged: _onSearchChanged,
      onClear: () {
        _searchDebounce?.cancel();
        setState(() => _query = '');
        _reload();
      },
    );
  }

  // ---------- 筛选 ----------
  /// 顶部单行：排序 chips + 筛选展开切换（科室/难度默认收起）
  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _chips(
            keys: _sorts.keys.toList(),
            isActive: (label) => label == _sortKey,
            onTap: (label) {
              _sortKey = label;
              _reload();
            },
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _showFilters = !_showFilters),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: _showFilters
                  ? AppColors.primaryOf(context)
                  : AppColors.surfaceOf(context),
              border: Border.all(
                color: _showFilters
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceEdgeOf(context),
              ),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color: _showFilters
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text3Of(context),
                ),
                const SizedBox(width: 4),
                Text(
                  '筛选',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _showFilters ? FontWeight.w600 : FontWeight.w500,
                    color: _showFilters
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

  Widget _buildDeptRow() {
    return _chips(
      keys: _departments,
      isActive: (label) => _departments[_deptIdx] == label,
      onTap: (label) {
        _deptIdx = _departments.indexOf(label);
        _onFilterChanged();
      },
    );
  }

  Widget _buildDifficultyRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _chips(
        keys: _difficulties,
        isActive: (label) => _difficulties[_diffIdx] == label,
        onTap: (label) {
          _diffIdx = _difficulties.indexOf(label);
          _onFilterChanged();
        },
      ),
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
          _hasMore ? '已加载 $count 例 · 上滑继续' : '— 已展示全部 —',
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
          Icon(Icons.search_off, size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('暂无符合条件病例',
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

  Widget _caseCard(CaseMarketItem c) {
    final dept = _deptStyleOf(c.department);
    final diffColor = _difficultyColorOf(c.difficulty);
    return AppPressable(
      onTap: () => _startCase(c),
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
            // 科室标识：语义图标 + 软色圆底（按科室区分，一眼可辨）
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: dept.bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(dept.icon, size: 25, color: dept.fg),
            ),
            const SizedBox(width: 13),
            // 内容
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
                          c.department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: dept.fg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          c.difficultyLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: kCjkMonoFallback,
                            fontWeight: FontWeight.w600,
                            color: diffColor,
                          ),
                        ),
                      ),
                      if (c.ongoing) ...[
                        const SizedBox(width: 6),
                        _statusChip('进行中', AppColors.amberOf(context),
                            Icons.hourglass_top_rounded),
                      ] else if (c.lastSessionStatus == 1) ...[
                        const SizedBox(width: 6),
                        _statusChip('已完成', AppColors.primaryOf(context),
                            Icons.check_circle_outline_rounded),
                      ] else if (c.lastSessionStatus == 2) ...[
                        const SizedBox(width: 6),
                        _statusChip('待重试', AppColors.vermilionOf(context),
                            Icons.refresh_rounded),
                      ],
                      const Spacer(),
                      MonoText('引用 ${c.referenceCount}',
                          fontSize: 11, color: AppColors.text4Of(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 病号=题号：学生端主文案只显示「科室 · No.xx」，不暴露具体病名防剧透
                      Flexible(
                        child: Text(
                          c.caseNoLabel.isEmpty
                              ? '临床问诊训练'
                              : '病例 ${c.caseNoLabel}',
                          maxLines: 1,
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
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textOf(context),
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (c.hasReport) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _retryCase(c),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOf(context)
                                  .withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                color: AppColors.primaryOf(context)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text('再练一次',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryOf(context),
                                )),
                          ),
                        ),
                      ],
                    ],
                  ),
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

  /// 列表卡片状态小圆签：进行中 / 已完成 / 待重试
  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }

  /// 难度标签色：简单=靛蓝 / 标准=主绿 / 困难=朱砂
  Color _difficultyColorOf(int difficulty) {
    switch (difficulty) {
      case 1:
        return AppColors.indigoOf(context);
      case 3:
        return AppColors.vermilionOf(context);
      default:
        return AppColors.primaryOf(context);
    }
  }

  /// 科室标识：语义图标 + 软色圆底 + 前景色
  ///
  /// 用「关键词包含」而非全等匹配，兼容「心血管内科」「肾内科」等带后缀的
  /// 科室名；未命中时回落到通用病历夹图标。配色取自主题语义软色，随主题
  /// 预设与深色模式自动切换，不写死色值。
  ({IconData icon, Color bg, Color fg}) _deptStyleOf(String dept) {
    final vBg = AppColors.vermilionSoftOf(context);
    final vFg = AppColors.vermilionOf(context);
    final iBg = AppColors.indigoSoftOf(context);
    final iFg = AppColors.indigoOf(context);
    final aBg = AppColors.amberSoftOf(context);
    final aFg = AppColors.amberOf(context);
    final mBg = AppColors.mossTintOf(context);
    final mFg = AppColors.primaryOf(context);
    final nBg = AppColors.ruleSoftOf(context);
    final nFg = AppColors.text3Of(context);

    bool hit(Iterable<String> keys) => keys.any(dept.contains);

    if (hit(const ['血液'])) {
      return (icon: Icons.bloodtype_outlined, bg: vBg, fg: vFg);
    }
    if (hit(const ['心血管', '心脏', '高血压', '循环'])) {
      return (icon: Icons.monitor_heart_outlined, bg: vBg, fg: vFg);
    }
    if (hit(const ['呼吸', '肺', '气道', '哮喘'])) {
      return (icon: Icons.air, bg: iBg, fg: iFg);
    }
    if (hit(const ['肾', '泌尿', '透析'])) {
      return (icon: Icons.water_drop_outlined, bg: iBg, fg: iFg);
    }
    if (hit(const ['消化', '胃肠', '胃', '肠', '肝胆', '肝', '胰', '食管'])) {
      return (icon: Icons.set_meal_outlined, bg: aBg, fg: aFg);
    }
    if (hit(const ['内分泌', '代谢', '糖尿病', '甲状腺', '垂体', '肾上腺'])) {
      return (icon: Icons.monitor_weight_outlined, bg: mBg, fg: mFg);
    }
    if (hit(const ['神经', '脑', '卒中', '癫痫', '精神', '心理'])) {
      return (icon: Icons.psychology_outlined, bg: iBg, fg: iFg);
    }
    if (hit(const ['骨', '关节', '创伤', '脊柱', '风湿', '运动'])) {
      return (icon: Icons.personal_injury_outlined, bg: aBg, fg: aFg);
    }
    if (hit(const ['感染', '传染', '发热', '结核', '病毒', '细菌'])) {
      return (icon: Icons.coronavirus_outlined, bg: vBg, fg: vFg);
    }
    if (hit(const ['免疫', '过敏', '风湿免疫'])) {
      return (icon: Icons.vaccines_outlined, bg: mBg, fg: mFg);
    }
    if (hit(const ['肿瘤', '癌', '白血病', '淋巴'])) {
      return (icon: Icons.healing_outlined, bg: vBg, fg: vFg);
    }
    if (hit(const ['妇产', '妊娠', '妇科', '产科'])) {
      return (icon: Icons.pregnant_woman_outlined, bg: vBg, fg: vFg);
    }
    if (hit(const ['儿科', '儿童', '新生儿'])) {
      return (icon: Icons.child_care_outlined, bg: mBg, fg: mFg);
    }
    if (hit(const ['老年', '全科', '康复'])) {
      return (icon: Icons.elderly_outlined, bg: mBg, fg: mFg);
    }
    if (hit(const ['急诊', '重症', '急救', '中毒'])) {
      return (icon: Icons.local_hospital_outlined, bg: vBg, fg: vFg);
    }
    return (icon: Icons.medical_services_outlined, bg: nBg, fg: nFg);
  }
}
