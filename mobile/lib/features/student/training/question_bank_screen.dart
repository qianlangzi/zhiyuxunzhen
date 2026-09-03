import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import 'answered_question_store.dart';
import 'question_practice_screen.dart';

/// 题库浏览/列表行模型（扁平化后交给 ListView.builder 按需构建）
sealed class _BankRow {}

class _GroupHeaderRow extends _BankRow {
  final String department;
  final int count;
  final bool collapsed;
  _GroupHeaderRow(this.department, this.count, this.collapsed);
}

class _QuestionRow extends _BankRow {
  final int indexInGroup;
  final Map<String, dynamic> question;
  _QuestionRow(this.indexInGroup, this.question);
}

class _ExpandRow extends _BankRow {
  final String department;
  final int rest;
  _ExpandRow(this.department, this.rest);
}

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  static const int _pageSize = 20;

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  final ScrollController _scroll = ScrollController();

  /// 已加载的全部题目（追加累积）
  List<Map<String, dynamic>> _items = [];
  /// 扁平化的渲染行序列（分组头 + 题目），每次 setState 后重建
  List<_BankRow> _rows = [];
  int _pageNum = 1;
  int _total = 0;

  String? _department;
  String? _knowledgeTag;
  int? _difficulty;
  String? _questionType;

  /// 筛选栏展开状态。
  ///
  /// 此前筛选栏 [_buildFilterBar] 写好了却从未挂到页面上，筛选字段
  /// [_department]/[_difficulty]/[_questionType] 只在拉取接口时生效，
  /// 用户实际无法修改筛选条件，等于「筛选功能不存在」。
  bool _showFilters = false;

  List<String> _departments = [];
  List<String> _knowledgeTags = [];
  final Set<String> _collapsedGroups = <String>{};

  /// 本地「已做」题目 id（与作答记录/续接同一事实源）
  Set<int> _answered = <int>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _answered = await AnsweredQuestionStore.load();
      if (mounted) setState(() {});
      _loadFirst();
      _loadFilters();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// 滚动接近底部时自动加载下一页
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadFilters() async {
    final service = StudentService();
    final results = await Future.wait([
      service.getQuestionDepartments(),
      service.getQuestionKnowledgeTags(),
    ]);
    if (!mounted) return;
    setState(() {
      _departments = (results[0] ?? []).cast<String>();
      _knowledgeTags = (results[1] ?? []).cast<String>();
    });
  }

  /// 首屏 / 筛选变更 / 下拉刷新：重置后加载第一页
  Future<void> _loadFirst({bool jumpToTop = true}) async {
    if (jumpToTop && _scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _initialLoading = true);
    final data = await StudentService().getQuestions(
      pageNum: 1,
      pageSize: _pageSize,
      department: _department,
      knowledgeTag: _knowledgeTag,
      difficulty: _difficulty,
      questionType: _questionType,
    );
    final list =
        (data?['list'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    setState(() {
      _pageNum = 1;
      _items = list;
      _total = total;
      _hasMore = _items.length < _total;
      _initialLoading = false;
      _loadingMore = false;
      _rebuildRows();
    });
    // 首屏内容不足一屏高度时（无滚动条）自动补拉下一页，保证无限滚动成立
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasMore && _scroll.hasClients) {
        final pos = _scroll.position;
        if (pos.maxScrollExtent - pos.pixels < 1) _loadMore();
      }
    });
  }

  /// 下拉刷新入口
  Future<void> _refresh() => _loadFirst(jumpToTop: false);

  /// 追加加载下一页（infinite scroll）
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    final next = _pageNum + 1;
    final data = await StudentService().getQuestions(
      pageNum: next,
      pageSize: _pageSize,
      department: _department,
      knowledgeTag: _knowledgeTag,
      difficulty: _difficulty,
      questionType: _questionType,
    );
    final list =
        (data?['list'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final total = (data?['total'] as num?)?.toInt() ?? _total;
    if (!mounted) return;
    setState(() {
      _pageNum = next;
      _items = [..._items, ...list];
      _total = total;
      _hasMore = _items.length < _total;
      _loadingMore = false;
      _rebuildRows();
    });
  }

  Future<void> _applyFilters() => _loadFirst();

  /// 依据已加载题目重建扁平行序列（按科室分组 + 折叠态应用）
  void _rebuildRows() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final q in _items) {
      final dept = (q['department'] as String?)?.trim();
      groups
          .putIfAbsent(dept?.isNotEmpty == true ? dept! : '综合', () => [])
          .add(q);
    }
    final rows = <_BankRow>[];
    groups.forEach((dept, list) {
      final collapsed = _collapsedGroups.contains(dept);
      rows.add(_GroupHeaderRow(dept, list.length, collapsed));
      final visible = collapsed ? list.take(2).toList() : list;
      for (var i = 0; i < visible.length; i++) {
        rows.add(_QuestionRow(i, visible[i]));
      }
      if (collapsed && list.length > 2) {
        rows.add(_ExpandRow(dept, list.length - 2));
      }
    });
    _rows = rows;
  }

  void _openPractice() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuestionPracticeScreen(
        title: '题库作答',
        department: _department,
        knowledgeTag: _knowledgeTag,
        difficulty: _difficulty,
        questionType: _questionType,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '浏览题库',
              onBack: () => Navigator.of(context).maybePop(),
              action: AppIconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _showFilters
                      ? AppColors.primaryOf(context)
                      : AppColors.text3Of(context),
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ),
            if (_showFilters)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  physics: const ClampingScrollPhysics(),
                  child: _buildFilterBar(),
                ),
              ),
            Expanded(
              child: _initialLoading && _items.isEmpty
                  ? _buildSkeleton()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 92 + bottomInset),
                        itemCount: _rows.length + 1, // 末尾 + 加载/到底占位
                        itemBuilder: (context, index) {
                          if (index == _rows.length) {
                            return _buildFooter();
                          }
                          return _buildRow(_rows[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      // 底部固定悬浮“开始作答”按钮，不遮挡列表最后一项（列表已预留底部 padding）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPractice,
        elevation: 6,
        backgroundColor: AppColors.primaryOf(context),
        foregroundColor: AppColors.onPrimaryOf(context),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('开始作答',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimaryOf(context))),
      ),
    );
  }

  // ---------- 列表行渲染 ----------
  Widget _buildRow(_BankRow row) {
    return switch (row) {
      _GroupHeaderRow(:final department, :final count, :final collapsed) =>
          _buildGroupHeader(department, count, collapsed),
      _ExpandRow(:final department, :final rest) => _buildExpand(department, rest),
      _QuestionRow(:final indexInGroup, :final question) =>
          _questionTile(indexInGroup, question),
    };
  }

  Widget _buildGroupHeader(String dept, int count, bool collapsed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() {
                if (collapsed) {
                  _collapsedGroups.remove(dept);
                } else {
                  _collapsedGroups.add(dept);
                }
                _rebuildRows();
              }),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                child: Row(children: [
                  Expanded(
                      child: Text(dept,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOf(context)))),
                  MonoText('$count 题',
                      fontSize: 10, color: AppColors.text4Of(context)),
                  const SizedBox(width: 6),
                  Icon(
                      collapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      size: 18,
                      color: AppColors.text3Of(context)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpand(String dept, int rest) {
    return TextButton.icon(
      onPressed: () => setState(() {
        _collapsedGroups.remove(dept);
        _rebuildRows();
      }),
      icon: const Icon(Icons.unfold_more_rounded, size: 16),
      label: Text('展开其余 $rest 题'),
    );
  }

  /// 列表尾部：加载中 / 到底提示
  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (!_hasMore && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: MonoText('已加载全部 $_total 题',
              fontSize: 10, color: AppColors.text4Of(context)),
        ),
      );
    }
    // 有更多但尚未触发加载时的兜底占位
    return const SizedBox(height: 24);
  }

  // ---------- 筛选栏 ----------
  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterRow('科室', _departments, (v) {
          setState(() {
            _department = v;
            _knowledgeTag = null;
          });
          _applyFilters();
        }, _department),
        const SizedBox(height: 6),
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
        _filterRow('题型', ['单选', '多选', '判断', '填空'], (v) {
          setState(() => _questionType = switch (v) {
                '单选' => 'single_choice',
                '多选' => 'multiple_choice',
                '判断' => 'judgment',
                '填空' => 'fill_blank',
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
      _ => null,
    };
  }

  Widget _filterRow(String label, List<String> options, ValueChanged<String> onSelect, String? current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: MonoText(label, fontSize: 11, color: AppColors.text4Of(context)),
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
              ...options.map((opt) =>
                  _filterChip(opt, current == opt, () => onSelect(opt))),
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

  // ---------- 首屏骨架屏 ----------
  Widget _buildSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: const [
        AppListSkeleton(rows: 5),
      ],
    );
  }

  // ---------- 题目卡片 ----------
  Widget _questionTile(int index, Map<String, dynamic> q) {
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel =
        difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final type = q['questionType'] as String? ?? 'single_choice';
    final typeLabel = switch (type) {
      'multiple_choice' => '多选',
      'fill_blank' => '填空',
      'judgment' => '判断',
      _ => '单选',
    };
    final title = q['title'] as String? ?? '';
    final questionNo = q['questionNo'] as String? ?? '';
    final qid = (q['id'] as num?)?.toInt() ?? -1;
    final done = qid >= 0 && _answered.contains(qid);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuestionPracticeScreen(
          title: '题目作答',
          department: _department,
          knowledgeTag: _knowledgeTag,
          difficulty: _difficulty,
          questionType: _questionType,
        ),
      )),
      child: PressableScale(
          child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(
              top: BorderSide(color: AppColors.ruleSoftOf(context)),
              left: const BorderSide(color: Colors.transparent),
              right: const BorderSide(color: Colors.transparent),
              bottom: const BorderSide(color: Colors.transparent),
            )),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 28,
            child: MonoText(
              questionNo.isNotEmpty ? questionNo : '${index + 1}.',
              fontSize: 12,
              color: AppColors.primaryOf(context),
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOf(context)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.library_books_outlined,
                        size: 11, color: AppColors.text4Of(context)),
                    const SizedBox(width: 4),
                    MonoText(typeLabel,
                        fontSize: 10, color: AppColors.text4Of(context)),
                    const SizedBox(width: 8),
                    Icon(Icons.tune_rounded,
                        size: 11, color: AppColors.text4Of(context)),
                    const SizedBox(width: 4),
                    MonoText(difficultyLabel,
                        fontSize: 10, color: AppColors.text4Of(context)),
                    if (done) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded,
                          size: 11, color: AppColors.primaryOf(context)),
                      const SizedBox(width: 4),
                      MonoText('已做',
                          fontSize: 10,
                          color: AppColors.primaryOf(context),
                          weight: FontWeight.w600),
                    ],
                  ],
                ),
              ])),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: done
                ? AppColors.primaryOf(context)
                : AppColors.text3Of(context),
          ),
        ]),
      )),
    );
  }
}
