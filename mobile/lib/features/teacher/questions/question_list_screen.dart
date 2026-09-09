import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';
import '../../../core/network/page_parser.dart';
import 'question_public_detail_screen.dart';

/// 题目审核状态（后端 adminAuditStatus）
enum QuestionStatus {
  draft('未提交', 0),
  pending('待审核', 1),
  approved('已通过', 2),
  rejected('已驳回', 3);

  const QuestionStatus(this.label, this.code);
  final String label;
  final int code;

  static QuestionStatus fromCode(dynamic code) {
    switch (code) {
      case 1:
        return pending;
      case 2:
        return approved;
      case 3:
        return rejected;
      case 0:
      default:
        return draft;
    }
  }
}

/// 审核状态筛选 chip（null 表示全部）
class _StatusFilter {
  const _StatusFilter(this.label, this.status);
  final String label;
  final int? status;
}

/// 教师端 · 基础题库
///
/// 双 Tab：我的题库（录入 / 提交审核 / 审核状态）+ 全部题库（与学生端浏览
/// 体验一致：筛选 + 搜索 + 分页；教师专属：答案/解析默认展示，可一键隐藏）。
class QuestionListScreen extends ConsumerStatefulWidget {
  const QuestionListScreen({super.key});

  @override
  ConsumerState<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends ConsumerState<QuestionListScreen> {
  static const _filters = [
    _StatusFilter('全部', null),
    _StatusFilter('未提交', 0),
    _StatusFilter('待审核', 1),
    _StatusFilter('已通过', 2),
    _StatusFilter('已驳回', 3),
  ];

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  int? _activeStatus;
  int _scope = 0; // 0=我的题库 1=全部题库

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final Map<String, dynamic>? data = await TeacherService().getMyQuestions(
      pageSize: 100,
      adminAuditStatus: _activeStatus,
    );
    if (!mounted) return;
    setState(() {
      // 后端 PageResult 字段是 list（不是 records），统一走 PageParser 兼容解析
      _list = PageParser.mapListOf(data);
      _isLoading = false;
    });
  }

  void _switchScope(int scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
  }

  void _switchFilter(int? status) {
    if (_activeStatus == status) return;
    setState(() {
      _activeStatus = status;
      _isLoading = true;
    });
    _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    final ok = await AppFeedback.confirm(
      context,
      title: '删除题目',
      content: '确定删除该题目吗？删除后不可恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    final success = await TeacherService().deleteQuestion(id);
    if (!mounted) return;
    if (success) {
      AppFeedback.success(context, '题目已删除');
      _load();
    } else {
      AppFeedback.error(context, '删除失败，请重试');
    }
  }

  Widget _buildStatusTag(BuildContext context, Map<String, dynamic> item) {
    final status = QuestionStatus.fromCode(item['adminAuditStatus']);
    final chipType = switch (status) {
      QuestionStatus.draft => ChipType.default_,
      QuestionStatus.pending => ChipType.amber,
      QuestionStatus.approved => ChipType.moss,
      QuestionStatus.rejected => ChipType.vermilion,
    };
    return AppChip(label: status.label, type: chipType, fontSize: 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '基础题库',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: _scope == 0
                  ? AppIconButton(
                      icon: const Icon(Icons.add, size: 22),
                      onPressed: () async {
                        await context.pushNamed(RouteNames.teacherQuestionEdit, pathParameters: {'id': 'new'});
                        if (mounted) _load();
                      },
                    )
                  : null,
            ),
            _buildScopeBar(context),
            if (_scope == 0) _buildFilterBar(context),
            // IndexedStack 保持两个 Tab 各自的浏览状态（筛选/滚动位置/展开项）
            Expanded(
              child: IndexedStack(
                index: _scope,
                children: [
                  _buildMineList(),
                  const _PublicBankView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 我的题库列表（Tab 0）
  Widget _buildMineList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _list.isEmpty
            ? _buildEmpty(context)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _buildQuestionCard(context, _list[i]),
                ),
              );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: _filters.map((f) {
          final active = _activeStatus == f.status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _switchFilter(f.status),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                  border: Border.all(
                    color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: MonoText(
                  f.label,
                  fontSize: 12,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 双 Tab：我的题库 / 全部题库
  Widget _buildScopeBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: List.generate(2, (i) {
            final active = _scope == i;
            final label = i == 0 ? '我的题库' : '全部题库';
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchScope(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.surfaceOf(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: active ? AppShadow.lifted(context) : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? AppColors.primaryOf(context) : AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Column(
              children: [
                Icon(Icons.queue_play_next_outlined,
                    size: 48, color: AppColors.text4Of(context)),
                const SizedBox(height: 12),
                SerifText(_scope == 0 ? '暂无题目' : '暂无全部题库题目',
                    fontSize: 15, color: AppColors.text2Of(context)),
                const SizedBox(height: 4),
                MonoText(_scope == 0
                    ? '点击右上角 + 录入第一道题目'
                    : '题库暂无已录入的题目',
                    fontSize: 11, color: AppColors.text4Of(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> item) {
    final id = (item['id'] as num).toInt();
    final status = QuestionStatus.fromCode(item['adminAuditStatus']);
    final title = item['title'] as String? ?? '（无题干）';
    final questionType = _questionTypeLabel(item['questionType'] as String?);
    final questionNo = item['questionNo'] as String?;
    final meta = [
      if (questionNo is String && questionNo.isNotEmpty) questionNo,
      if (item['department'] is String && (item['department'] as String).isNotEmpty)
        item['department'],
      if (item['knowledgeTag'] is String && (item['knowledgeTag'] as String).isNotEmpty)
        item['knowledgeTag'],
    ].join(' · ');
    final createdAt = _formatTime(item['createdAt']);
    // 仅"我的题库"中草稿 / 已驳回可删除
    final deletable =
        status == QuestionStatus.draft || status == QuestionStatus.rejected;
    final rejectReason = status == QuestionStatus.rejected
        ? (item['rejectReason'] as String?)
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await context.pushNamed(
          RouteNames.teacherQuestionEdit,
          pathParameters: {'id': '$id'},
        );
        if (mounted) _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusTag(context, item),
                const Spacer(),
                if (deletable)
                  GestureDetector(
                    onTap: () => _delete(item),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 15, color: AppColors.text4Of(context)),
                        const SizedBox(width: 2),
                        MonoText('删除', fontSize: 10, color: AppColors.text4Of(context)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SerifText(title, fontSize: 14, color: AppColors.textOf(context), weight: FontWeight.w600),
            const SizedBox(height: 8),
            MonoText(
              questionType,
              fontSize: 10,
              color: AppColors.primaryOf(context),
            ),
            const SizedBox(height: 4),
            if (meta.isNotEmpty)
              MonoText(meta, fontSize: 10, color: AppColors.text3Of(context)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: MonoText(
                    createdAt,
                    fontSize: 10,
                    color: AppColors.text4Of(context),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.text3Of(context)),
              ],
            ),
            if (rejectReason != null && rejectReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.vermilionSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 13, color: AppColors.vermilionOf(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MonoText(
                        '驳回：$rejectReason',
                        fontSize: 10,
                        color: AppColors.vermilionOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 全部题库视图（Tab 1）：与学生端题库浏览一致的筛选 + 搜索 + 分页，
/// 教师专属：答案/解析默认展示，右上角眼睛按钮全局开关。
class _PublicBankView extends ConsumerStatefulWidget {
  const _PublicBankView();

  @override
  ConsumerState<_PublicBankView> createState() => _PublicBankViewState();
}

class _PublicBankViewState extends ConsumerState<_PublicBankView> {
  /// 大题库下分页拉取，避免一次性捞全量
  static const int _pageSize = 20;

  final _searchCtl = TextEditingController();
  Timer? _debounce;
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _items = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _pageNum = 1;
  int _total = 0;

  /// 加载失败原因（null=无错）。区分「接口/网络失败」与「真的没数据」，
  /// 否则后端不可达时页面只会显示一个误导性的空态（看似空白）。
  String? _error;

  String? _department;
  String? _knowledgeTag;
  int? _difficulty;
  String? _questionType;
  String _keyword = '';

  /// 发布时间排序：desc=最新优先（默认） asc=最早优先
  String _order = 'desc';

  /// 筛选面板展开状态（默认收起，与学生端一致）
  bool _showFilters = false;

  /// 答案/解析展示开关：默认自动显示答案，教师可一键隐藏（授课投屏场景）
  bool _showAnswers = true;

  List<String> _departments = [];
  List<String> _knowledgeTags = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFirst();
      _loadFilterMeta();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) _loadMore();
  }

  /// 筛选项元数据：教师端专用接口（与学生端题库同源数据，带缓存）
  Future<void> _loadFilterMeta() async {
    List<List<String>> results;
    try {
      results = await Future.wait([
        TeacherService().getQuestionDepartments(),
        TeacherService().getQuestionKnowledgeTags(),
      ]);
    } catch (e) {
      // 筛选项加载失败不阻塞主列表，仅静默降级为无筛选项
      debugPrint('loadQuestionFilterMeta error: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _departments = results[0];
      _knowledgeTags = results[1];
    });
  }

  Future<void> _loadFirst({bool jumpToTop = true}) async {
    if (jumpToTop && _scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    Map<String, dynamic>? data;
    try {
      data = await TeacherService().getAllQuestions(
        pageNum: 1,
        pageSize: _pageSize,
        department: _department,
        knowledgeTag: _knowledgeTag,
        difficulty: _difficulty,
        questionType: _questionType,
        keyword: _keyword.trim().isEmpty ? null : _keyword.trim(),
      );
    } catch (e) {
      // 防御性兜底：api 层只捕 DioException，非 JSON 响应（如网关 HTML 错误页）
      // 抛出的 FormatException 等会穿透到这里；不接住就会卡死在加载态（白屏）。
      debugPrint('loadAllQuestions error: $e');
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _error = '网络异常，题目加载失败';
      });
      return;
    }
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _error = '题库加载失败，请检查网络后重试';
      });
      return;
    }
    final list = PageParser.mapListOf(data);
    final total = (data['total'] as num?)?.toInt() ?? 0;
    setState(() {
      _pageNum = 1;
      _items = list;
      _total = total;
      _hasMore = _items.length < _total;
      _initialLoading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    final next = _pageNum + 1;
    Map<String, dynamic>? data;
    try {
      data = await TeacherService().getAllQuestions(
        pageNum: next,
        pageSize: _pageSize,
        department: _department,
        knowledgeTag: _knowledgeTag,
        difficulty: _difficulty,
        questionType: _questionType,
        keyword: _keyword.trim().isEmpty ? null : _keyword.trim(),
        order: _order,
      );
    } catch (e) {
      debugPrint('loadMoreQuestions error: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppFeedback.error(context, '加载更多失败，请重试');
      return;
    }
    if (!mounted) return;
    final list = PageParser.mapListOf(data);
    final total = (data?['total'] as num?)?.toInt() ?? _total;
    setState(() {
      _pageNum = next;
      _items = [..._items, ...list];
      _total = total;
      _hasMore = _items.length < _total;
      _loadingMore = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadFirst();
    });
  }

  void _applyFilters() => _loadFirst();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        // 常显快筛行：发布时间排序 + 科室分类（此前筛选全藏在 tune 面板里，
        // 用户感知不到分类能力，现把最常用的排序/科室平铺出来）
        _buildQuickBar(),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: _showFilters
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _buildFilterPanel(),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: _initialLoading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadFirst(jumpToTop: false),
                  child: _error != null && _items.isEmpty
                      ? _buildError()
                      : _items.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 4, 20, 40),
                              itemCount: _items.length + 1,
                              itemBuilder: (context, i) {
                                if (i == _items.length) return _buildFooter();
                                return _questionCard(_items[i]);
                              },
                            ),
                ),
        ),
      ],
    );
  }

  /// 顶部工具行：搜索框 + 筛选开关 + 答案显隐开关
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: AppSearchField(
              controller: _searchCtl,
              hintText: '搜索题干关键词',
              onChanged: _onSearchChanged,
              onClear: () {
                _debounce?.cancel();
                _keyword = '';
                _loadFirst();
              },
            ),
          ),
          const SizedBox(width: 8),
          _toolButton(
            icon: Icons.tune_rounded,
            active: _showFilters,
            onTap: () => setState(() => _showFilters = !_showFilters),
            tooltip: '筛选',
          ),
          const SizedBox(width: 8),
          _toolButton(
            icon: _showAnswers
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            active: _showAnswers,
            onTap: () => setState(() => _showAnswers = !_showAnswers),
            tooltip: _showAnswers ? '隐藏答案' : '显示答案',
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryOf(context).withValues(alpha: 0.10)
                : AppColors.surfaceOf(context),
            border: Border.all(
              color: active
                  ? AppColors.primaryOf(context)
                  : AppColors.ruleOf(context),
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active
                ? AppColors.primaryOf(context)
                : AppColors.text3Of(context),
          ),
        ),
      ),
    );
  }

  /// 常显快筛行：排序（最新发布/最早发布）+ 科室横向分类 chips
  Widget _buildQuickBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          // 排序切换
          GestureDetector(
            onTap: () {
              setState(() => _order = _order == 'desc' ? 'asc' : 'desc');
              _loadFirst();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border.all(color: AppColors.primaryOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _order == 'desc'
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 13,
                    color: AppColors.primaryOf(context),
                  ),
                  const SizedBox(width: 4),
                  MonoText(
                    _order == 'desc' ? '最新发布' : '最早发布',
                    fontSize: 11,
                    color: AppColors.primaryOf(context),
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 科室分类（横向滚动，服务端过滤）
          Expanded(
            child: _departments.isEmpty
                ? const SizedBox.shrink()
                // 项目统一用 SingleChildScrollView + Row 承载横向分类，而非横向 ListView：
                // 后者放在无高度约束的 Column 里会触发 viewport 无界高度的布局异常，
                // release 下表现为「全部题库」整块白屏、无任何提示。
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_departments.length + 1, (i) {
                        final dept = i == 0 ? null : _departments[i - 1];
                        final active = _department == dept;
                        return GestureDetector(
                          onTap: () {
                            if (_department == dept) return;
                            setState(() {
                              _department = dept;
                              _knowledgeTag = null;
                            });
                            _loadFirst();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primaryOf(context)
                                  : AppColors.surfaceOf(context),
                              border: Border.all(
                                color: active
                                    ? AppColors.primaryOf(context)
                                    : AppColors.ruleOf(context),
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Center(
                              child: Text(
                                dept ?? '全部科室',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: active
                                      ? AppColors.onPrimaryOf(context)
                                      : AppColors.text2Of(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------- 筛选面板（知识点/难度/题型；科室已平铺到快筛行） ----------
  Widget _buildFilterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterRow('知识点', _knowledgeTags, (v) {
          setState(() => _knowledgeTag = v);
          _applyFilters();
        }, _knowledgeTag),
        const SizedBox(height: 6),
        _filterRow('难度', ['简单', '标准', '困难'], (v) {
          setState(() => _difficulty = switch (v) {
                '简单' => 1,
                '困难' => 3,
                _ => 2,
              });
          _applyFilters();
        },
            _difficulty == null
                ? null
                : (_difficulty == 1
                    ? '简单'
                    : (_difficulty == 3 ? '困难' : '标准'))),
        const SizedBox(height: 6),
        _filterRow('题型', ['单选', '多选', '判断', '填空', '简答', '论述'], (v) {
          setState(() => _questionType = switch (v) {
                '单选' => 'single_choice',
                '多选' => 'multiple_choice',
                '判断' => 'judgment',
                '填空' => 'fill_blank',
                '简答' => 'short_answer',
                '论述' => 'essay',
                _ => null,
              });
          _applyFilters();
        }, _typeLabelOf(_questionType)),
      ],
    );
  }

  String? _typeLabelOf(String? type) {
    if (type == null) return null;
    return switch (type) {
      'single_choice' => '单选',
      'multiple_choice' => '多选',
      'judgment' => '判断',
      'fill_blank' => '填空',
      'short_answer' => '简答',
      'essay' => '论述',
      _ => null,
    };
  }

  Widget _filterRow(String label, List<String> options,
      ValueChanged<String> onSelect, String? current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child:
              MonoText(label, fontSize: 11, color: AppColors.text4Of(context)),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('全部', current == null, () {
                setState(() {
                  if (label == '科室') _department = null;
                  if (label == '知识点') _knowledgeTag = null;
                  if (label == '难度') _difficulty = null;
                  if (label == '题型') _questionType = null;
                });
                _applyFilters();
              }),
              ...options
                  .map((opt) => _filterChip(opt, current == opt, () => onSelect(opt))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: PressableScale(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryOf(context)
                : AppColors.surfaceOf(context),
            border: Border.all(
                color: selected
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: kCjkMonoFallback,
              color: selected
                  ? AppColors.onPrimaryOf(context)
                  : AppColors.text2Of(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
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
    if (!_hasMore && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: MonoText('已加载全部 $_total 题',
              fontSize: 11, color: AppColors.text4Of(context)),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  /// 加载失败态：明确告知原因 + 一键重试（下拉刷新同样可用）
  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),
        Icon(Icons.cloud_off_rounded,
            size: 48, color: AppColors.text4Of(context)),
        const SizedBox(height: 12),
        Center(
          child: SerifText(_error ?? '加载失败',
              fontSize: 15, color: AppColors.text2Of(context)),
        ),
        const SizedBox(height: 16),
        Center(
          child: AppGhostButton(
            label: '重新加载',
            icon: const Icon(Icons.refresh_rounded, size: 16),
            onPressed: () => _loadFirst(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.search_off, size: 48, color: AppColors.text4Of(context)),
        const SizedBox(height: 12),
        Center(
          child: SerifText('暂无符合条件的题目',
              fontSize: 15, color: AppColors.text2Of(context)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('换个关键词或筛选条件试试',
              style:
                  TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
        ),
      ],
    );
  }

  // ---------- 题目卡片（题干 + 选项 + 答案/解析；点击进详情子页） ----------
  Widget _questionCard(Map<String, dynamic> q) {
    final difficulty = (q['difficulty'] as num?)?.toInt() ?? 2;
    final difficultyLabel =
        difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final type = q['questionType'] as String? ?? 'single_choice';
    final typeLabel = switch (type) {
      'multiple_choice' => '多选',
      'fill_blank' => '填空',
      'judgment' => '判断',
      'short_answer' => '简答',
      'essay' => '论述',
      _ => '单选',
    };
    final title = q['title'] as String? ?? '';
    final questionNo = q['questionNo'] as String? ?? '';
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final answer = q['answer'] as String? ?? '';
    final explanation = q['explanation'] as String? ?? '';
    final dept = q['department'] as String? ?? '';
    final creator = q['creatorName'] as String? ?? '';
    final createdAt = _formatTime(q['createdAt']);
    final questionId = (q['id'] as num?)?.toInt();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: questionId == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      QuestionPublicDetailScreen(questionId: questionId),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (questionNo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 2),
                    child: MonoText(questionNo,
                        fontSize: 11,
                        color: AppColors.primaryOf(context),
                        weight: FontWeight.w700),
                  ),
                AppChip(label: typeLabel, fontSize: 10),
                const SizedBox(width: 6),
                AppChip(label: difficultyLabel, type: ChipType.amber, fontSize: 10),
                if (dept.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: MonoText(dept,
                        fontSize: 10, color: AppColors.text4Of(context)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AppColors.textOf(context),
              ),
            ),
            if (creator.isNotEmpty || createdAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              MonoText(
                [
                  if (creator.isNotEmpty) '作者 $creator',
                  if (createdAt.isNotEmpty) '发布于 $createdAt',
                ].join(' · '),
                fontSize: 10,
                color: AppColors.text3Of(context),
              ),
            ],
            if (options.isNotEmpty) ...[
              const SizedBox(height: 8),
              // 列表只展示题干/作者等概览，选项与答案解析收进详情子页，
              // 避免整页被平铺的长答案刷屏
              MonoText('点击查看选项与答案解析',
                  fontSize: 10, color: AppColors.text4Of(context)),
            ],
            if (_showAnswers && (answer.isNotEmpty || explanation.isNotEmpty)) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mossTintOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (answer.isNotEmpty)
                      MonoText('答案：$answer',
                          fontSize: 11.5,
                          color: AppColors.primaryOf(context),
                          weight: FontWeight.w600),
                    if (explanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '解析：$explanation',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.55,
                          color: AppColors.text2Of(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 题型中文映射
String _questionTypeLabel(String? type) {
  switch (type) {
    case 'single_choice':
      return '单选题';
    case 'multiple_choice':
      return '多选题';
    case 'judgment':
      return '判断题';
    case 'fill_blank':
      return '填空题';
    case 'essay':
    case 'short_answer':
    case 'subjective':
      return '简答/论述';
    default:
      return type ?? '题型';
  }
}

/// 时间格式化（兼容后端多种时间格式）
String _formatTime(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.isEmpty) return '';
  if (s.contains('T')) {
    return s.replaceFirst('T', ' ').split('.').first;
  }
  return s;
}
