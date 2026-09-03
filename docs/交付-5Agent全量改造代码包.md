# 智愈寻真 · 5-Agent 全量改造交付包

> 生成日期：2026-08-28　|　Tech Lead 汇总
> 适用：移动端 Flutter(mobile/lib) + 后端 Java(backend/src/main/java) + AI平台(Python, ai/) + 管理端 Vue(front/admin)

## 0. 总览与冲突处理

原始任务中的 React 文件名（QuizList.tsx / TrainingHome.tsx / AIGenerate.tsx / Chat.tsx / ConversationSidebar.tsx）在本项目不存在，已按实际结构映射如下。

| Agent | 职责 | 实际落点文件 |
|---|---|---|
| A | 题库列表性能 | `mobile/lib/features/student/training/question_bank_screen.dart` |
| B | 首页UI与卡片 | `student_case_market_screen.dart`、新组件 `question_bank_card.dart`、`case_library_entry_card.dart`、`question_training_screen.dart` |
| C | AI组卷异步 | 新组件 `paper_config_form.dart`、`paper_exam_screen.dart`、`student_api.dart`、`student_service.dart`、AI `paper_worker.py`、`enums.py`、Java `StudentPaperServiceImpl` |
| D | AI学伴 | `student_api.dart`、`companion_conversation_provider.dart`、`companion_history_drawer.dart`、`companion_screen.dart`、迁移 `V33__companion_conversation.sql` |
| E | 每日一例调度 | `SpCaseConfigMapper.java`、`DailyCaseServiceImpl.java`、迁移 `V34__daily_case_schedule_fields.sql`、可选 `DailyScheduleTimezoneConfig.java`、管理端 `dailyCase.ts` + `DailyCaseSchedule.vue` |

**冲突已解决**
- 迁移号：学伴=**V33**，每日一例字段=**V34**（原 Agent E 建议 V33/V34 二选一，此处定为 V34）。
- `student_api.dart` 被 Agent C 与 Agent D 各自追加方法（C: 组卷任务；D: companion/companionStream），**位于不同方法段落，可直接合并**。

**全局核查结论（重要）**
- Agent A：后端 `StudentQuestionController`/`PracticeQuestionServiceImpl` 已分页（`PageResult` + `list/total`），**后端零改动**，只需重写列表页。
- Agent D：SSE 流式与多模态后端已实现（`ai/app/api/companion.py` + Java `SseEmitter`，前端 dio 原生解析），**缺口是会话历史管理**，需新建会话体系。
- Agent E：病例主表 `sp_case_config`，排期表 `daily_case_schedule`；`spring-boot-starter-data-redis` 已在依赖，`@EnableScheduling` 已开，**无新增依赖**。

---

# Agent A · 题库列表性能优化

### 接口说明
后端已分页（`/api/v1/student/questions?pageNum=&pageSize=` 返回 `{list,total}`），**无需改动**。前端 `StudentApi.getQuestions()` 已传 `pageNum/pageSize`，无需改动。只重写列表页（分页+骨架屏+悬浮按钮）。

### File: e:\zhiyu\mobile\lib\features\student\training\question_bank_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import 'question_practice_screen.dart';

/// 题库浏览/列表行模型（扁平化后交给 ListView.builder 按需构建）
sealed class _BankRow {}

class _GroupHeaderRow extends _BankRow {
  final String department;
  final int count;
  final bool collapsed;
  const _GroupHeaderRow(this.department, this.count, this.collapsed);
}

class _QuestionRow extends _BankRow {
  final int indexInGroup;
  final Map<String, dynamic> question;
  const _QuestionRow(this.indexInGroup, this.question);
}

class _ExpandRow extends _BankRow {
  final String department;
  final int rest;
  const _ExpandRow(this.department, this.rest);
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
  List<Map<String, dynamic>> _items = [];
  List<_BankRow> _rows = [];
  int _pageNum = 1;
  int _total = 0;
  String? _department;
  String? _knowledgeTag;
  int? _difficulty;
  String? _questionType;
  List<String> _departments = [];
  List<String> _knowledgeTags = [];
  final Set<String> _collapsedGroups = <String>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) _loadMore();
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

  Future<void> _loadFirst({bool jumpToTop = true}) async {
    if (jumpToTop && _scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _initialLoading = true);
    final data = await StudentService().getQuestions(
      pageNum: 1, pageSize: _pageSize,
      department: _department, knowledgeTag: _knowledgeTag,
      difficulty: _difficulty, questionType: _questionType,
    );
    final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    setState(() {
      _pageNum = 1; _items = list; _total = total;
      _hasMore = _items.length < _total;
      _initialLoading = false; _loadingMore = false;
      _rebuildRows();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasMore && _scroll.hasClients) {
        final pos = _scroll.position;
        if (pos.maxScrollExtent - pos.pixels < 1) _loadMore();
      }
    });
  }

  Future<void> _refresh() => _loadFirst(jumpToTop: false);

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    final next = _pageNum + 1;
    final data = await StudentService().getQuestions(
      pageNum: next, pageSize: _pageSize,
      department: _department, knowledgeTag: _knowledgeTag,
      difficulty: _difficulty, questionType: _questionType,
    );
    final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (data?['total'] as num?)?.toInt() ?? _total;
    if (!mounted) return;
    setState(() {
      _pageNum = next; _items = [..._items, ...list];
      _total = total; _hasMore = _items.length < _total;
      _loadingMore = false; _rebuildRows();
    });
  }

  Future<void> _applyFilters() => _loadFirst();

  void _rebuildRows() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final q in _items) {
      final dept = (q['department'] as String?)?.trim();
      groups.putIfAbsent(dept?.isNotEmpty == true ? dept! : '综合', () => []).add(q);
    }
    final rows = <_BankRow>[];
    groups.forEach((dept, list) {
      final collapsed = _collapsedGroups.contains(dept);
      rows.add(_GroupHeaderRow(dept, list.length, collapsed));
      final visible = collapsed ? list.take(2).toList() : list;
      for (var i = 0; i < visible.length; i++) rows.add(_QuestionRow(i, visible[i]));
      if (collapsed && list.length > 2) rows.add(_ExpandRow(dept, list.length - 2));
    });
    _rows = rows;
  }

  void _openPractice() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuestionPracticeScreen(
        title: '题库作答', department: _department, knowledgeTag: _knowledgeTag,
        difficulty: _difficulty, questionType: _questionType,
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
            AppBackAppBar(title: '浏览题库', onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _initialLoading && _items.isEmpty
                  ? _buildSkeleton()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 92 + bottomInset),
                        itemCount: _rows.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _rows.length) return _buildFooter();
                          return _buildRow(_rows[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPractice,
        elevation: 6,
        backgroundColor: AppColors.primaryOf(context),
        foregroundColor: AppColors.onPrimaryOf(context),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('开始作答', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: AppColors.onPrimaryOf(context))),
      ),
    );
  }

  Widget _buildRow(_BankRow row) {
    return switch (row) {
      _GroupHeaderRow(:final department, :final count, :final collapsed) =>
        _buildGroupHeader(department, count, collapsed),
      _ExpandRow(:final department, :final rest) => _buildExpand(department, rest),
      _QuestionRow(:final indexInGroup, :final question) => _questionTile(indexInGroup, question),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) { _collapsedGroups.remove(dept); } else { _collapsedGroups.add(dept); }
              _rebuildRows();
            }),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
              child: Row(children: [
                Expanded(child: Text(dept, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textOf(context)))),
                MonoText('$count 题', fontSize: 10, color: AppColors.text4Of(context)),
                const SizedBox(width: 6),
                Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    size: 18, color: AppColors.text3Of(context)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildExpand(String dept, int rest) {
    return TextButton.icon(
      onPressed: () => setState(() { _collapsedGroups.remove(dept); _rebuildRows(); }),
      icon: const Icon(Icons.unfold_more_rounded, size: 16),
      label: Text('展开其余 $rest 题'),
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    if (!_hasMore && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: MonoText('已加载全部 $_total 题', fontSize: 10, color: AppColors.text4Of(context))),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _buildFilterBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _filterRow('科室', _departments, (v) { setState(() { _department = v; _knowledgeTag = null; }); _applyFilters(); }, _department),
      const SizedBox(height: 6),
      _filterRow('知识点', _knowledgeTags, (v) { setState(() => _knowledgeTag = v); _applyFilters(); }, _knowledgeTag),
      const SizedBox(height: 6),
      _filterRow('难度', ['简单', '标准', '困难'], (v) {
        setState(() => _difficulty = switch (v) { '简单' => 1, '困难' => 3, _ => 2 });
        _applyFilters();
      }, _difficulty == null ? null : (_difficulty == 1 ? '简单' : (_difficulty == 3 ? '困难' : '标准'))),
      const SizedBox(height: 6),
      _filterRow('题型', ['单选', '多选', '判断', '填空'], (v) {
        setState(() => _questionType = switch (v) {
          '单选' => 'single_choice', '多选' => 'multiple_choice',
          '判断' => 'judgment', '填空' => 'fill_blank', _ => null });
        _applyFilters();
      }, _typeLabelOf(_questionType)),
    ]);
  }

  String? _typeLabelOf(String? type) {
    if (type == null) return null;
    return switch (type) {
      'single_choice' => '单选', 'multiple_choice' => '多选',
      'judgment' => '判断', 'fill_blank' => '填空', _ => null };
  }

  Widget _filterRow(String label, List<String> options, ValueChanged<String> onSelect, String? current) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 52, child: MonoText(label, fontSize: 11, color: AppColors.text4Of(context))),
      Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
        _filterChip('全部', current == null, () {
          setState(() {
            if (label == '科室') _department = null;
            if (label == '知识点') _knowledgeTag = null;
            if (label == '难度') _difficulty = null;
            if (label == '题型') _questionType = null;
          });
          _applyFilters();
        }),
        ...options.map((opt) => _filterChip(opt, current == opt, () => onSelect(opt))),
      ])),
    ]);
  }

  Widget _filterChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: PressableScale(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
            border: Border.all(color: selected ? AppColors.primaryOf(context) : AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(text, style: TextStyle(fontSize: 11, fontFamily: 'JetBrainsMono',
              fontFamilyFallback: kCjkMonoFallback,
              color: selected ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context))),
        ),
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFilterBar(),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('共 $_total 题', style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
        if (_loadingMore) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: const [AppListSkeleton(rows: 5)],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(children: [
        Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
        const SizedBox(height: 12),
        SerifText('当前筛选无题目', fontSize: 15, color: AppColors.text2Of(context)),
        const SizedBox(height: 4),
        Text('下拉刷新或调整筛选条件后重试', style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
      ]),
    );
  }

  Widget _questionTile(int index, Map<String, dynamic> q) {
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final type = q['questionType'] as String? ?? 'single_choice';
    final typeLabel = switch (type) {
      'multiple_choice' => '多选', 'fill_blank' => '填空', 'judgment' => '判断', _ => '单选' };
    final title = q['title'] as String? ?? '';
    final questionNo = q['questionNo'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuestionPracticeScreen(title: '题目作答', department: _department,
            knowledgeTag: _knowledgeTag, difficulty: _difficulty, questionType: _questionType),
      )),
      child: PressableScale(child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(top: BorderSide(color: AppColors.ruleSoftOf(context)),
                left: const BorderSide(color: Colors.transparent),
                right: const BorderSide(color: Colors.transparent),
                bottom: const BorderSide(color: Colors.transparent))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 28, child: MonoText(questionNo.isNotEmpty ? questionNo : '${index + 1}.',
              fontSize: 12, color: AppColors.primaryOf(context), weight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w500, color: AppColors.textOf(context))),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.library_books_outlined, size: 11, color: AppColors.text4Of(context)),
              const SizedBox(width: 4),
              MonoText(typeLabel, fontSize: 10, color: AppColors.text4Of(context)),
              const SizedBox(width: 8),
              Icon(Icons.tune_rounded, size: 11, color: AppColors.text4Of(context)),
              const SizedBox(width: 4),
              MonoText(difficultyLabel, fontSize: 10, color: AppColors.text4Of(context)),
            ]),
          ])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.text3Of(context)),
        ]),
      )),
    );
  }
}
```

> Agent A 取舍：由「整页翻页+全屏 spinner」改为「骨架+无限滚动+下拉刷新」；组嵌套卡片改为扁平行（组头+题目各一行）以适配 `ListView.builder` 按需构建；悬浮按钮用 `Scaffold.floatingActionButton`，列表底部预留 `92+bottomInset` 不遮挡最后一项；题目无图片字段，故未引入 `cached_network_image`。

---

# Agent B · 首页UI与题库卡片重构

> **关键事实**（Agent B 核查）：「病例实训」卡并不在 `student_home_screen.dart`，而是在 **`student_case_market_screen.dart`**（训练中心，Tab2）。首页 `student_home_screen.dart` 无此卡，无需structure手术。底部 tab 已是悬浮胶囊且各页预留 `bottom:100`，**无需改动**。

### File: e:\zhiyu\mobile\lib\features\student\market\student_case_market_screen.dart

替换 `_buildGrid()`（把「病例实训」强调主卡改为「病例库」入口卡，样式复用「基础题库」卡 `_trainCell`）：

```dart
Widget _buildGrid() {
  return Column(
    children: [
      Row(children: [
        Expanded(child: _trainCell(
          icon: Icons.folder_copy_rounded, color: AppColors.moss,
          emphasize: false, title: '病例库', subtitle: '浏览 · 查找全部病例',
          onTap: () => context.pushNamed(RouteNames.caseLibrary),
        )),
        const SizedBox(width: 10),
        Expanded(child: _trainCell(
          icon: Icons.quiz_outlined, color: AppColors.indigo,
          emphasize: false, title: '基础题库', subtitle: '知识点刷题',
          onTap: () => context.pushNamed(RouteNames.questionTraining),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _trainCell(
          icon: Icons.description_outlined, color: AppColors.vermilion,
          emphasize: false, title: '模拟试卷', subtitle: '全真组卷',
          onTap: () => context.pushNamed(RouteNames.paperPractice),
        )),
        const SizedBox(width: 10),
        Expanded(child: _trainCell(
          icon: Icons.smart_toy_outlined, color: AppColors.amber,
          emphasize: false, title: 'AI 陪练', subtitle: '对话问诊',
          onTap: () => context.pushNamed(RouteNames.companion),
        )),
      ]),
    ],
  );
}
```

同时删除被取代的「病例实训快捷入口」方法（原约 71–78 行，改为注释占位）。

### File: e:\zhiyu\mobile\lib\shared\widgets\question_bank_card.dart （新建）

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'app_widgets.dart'; // SerifText / MonoText / AppProgressBar / AppChip / AppPressable

class QuestionBankCardModel {
  const QuestionBankCardModel({
    required this.name, required this.total,
    this.answered = 0, this.correct = 0, this.accuracy = 0,
    this.difficulty = 2, this.questionTypes = const [],
  });
  final String name;
  final int total;
  final int answered;
  final int correct;
  final double accuracy; // 0~1
  final int difficulty;  // 1 简单 / 2 标准 / 3 困难（待完善：暂无题库级难度）
  final List<String> questionTypes; // 题型标签（待完善：暂无题型分布）

  bool get hasRecord => answered > 0;
  double get mastery => hasRecord ? accuracy.clamp(0.0, 1.0) : 0.0;

  factory QuestionBankCardModel.fromDeptMap(String dept, Map<String, dynamic> stat) {
    return QuestionBankCardModel(
      name: dept,
      total: (stat['total'] as num?)?.toInt() ?? 0,
      answered: (stat['answered'] as num?)?.toInt() ?? 0,
      correct: (stat['correct'] as num?)?.toInt() ?? 0,
      accuracy: ((stat['accuracy'] as num?)?.toDouble() ?? 0.0) / 100.0,
    );
  }
  String get difficultyLabel =>
      difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
}

class QuestionBankCard extends StatelessWidget {
  const QuestionBankCard({super.key, required this.data, this.onTap});
  final QuestionBankCardModel data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(color: AppColors.mossTintOf(context), shape: BoxShape.circle),
                child: const Icon(Icons.library_books_rounded, size: 15, color: AppColors.moss)),
              const SizedBox(width: 9),
              Flexible(child: SerifText(data.name, fontSize: 15, color: AppColors.textOf(context))),
            ])),
            const SizedBox(width: 8),
            _DifficultyStars(level: data.difficulty),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _tag('${data.total} 题', AppColors.mossTintOf(context), AppColors.primaryOf(context)),
            ...data.questionTypes.isEmpty
                ? [_tag('题型 待完善', AppColors.ruleSoftOf(context), AppColors.text3Of(context))]
                : data.questionTypes.map((t) => _tag(t, AppColors.indigoSoftOf(context), AppColors.indigo)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            MonoText('掌握度', fontSize: 10, color: AppColors.text3Of(context)),
            const SizedBox(width: 6),
            Expanded(child: AppProgressBar(value: data.mastery, height: 6,
              backgroundColor: AppColors.paper2Of(context),
              foregroundColor: data.hasRecord ? AppColors.primaryOf(context) : AppColors.text4Of(context))),
            const SizedBox(width: 10),
            MonoText(data.hasRecord ? '${(data.mastery * 100).round()}%' : '未开始',
                fontSize: 11, weight: FontWeight.w600,
                color: data.hasRecord ? AppColors.primaryOf(context) : AppColors.text4Of(context)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            MonoText('已做 ${data.answered}', fontSize: 10, color: AppColors.text4Of(context)),
            const SizedBox(width: 10),
            MonoText('答对 ${data.correct}', fontSize: 10, color: AppColors.text4Of(context)),
            const Spacer(),
            MonoText('难度 ${data.difficultyLabel} 待完善', fontSize: 9, color: AppColors.text4Of(context)),
          ]),
        ]),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(text, style: TextStyle(fontSize: 10, fontFamily: 'JetBrainsMono',
          fontFamilyFallback: kCjkMonoFallback, color: fg)),
    );
  }
}

class _DifficultyStars extends StatelessWidget {
  const _DifficultyStars({required this.level});
  final int level; // 1~3
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
      final filled = i < level.clamp(1, 3);
      return Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 15, color: filled ? AppColors.amber : AppColors.text4Of(context));
    }));
  }
}
```

### File: e:\zhiyu\mobile\lib\features\student\training\question_training_screen.dart

顶部 import 新增，并替换 `_buildModuleAccuracy()` 内的列表渲染段：
```dart
import '../../../shared/widgets/question_bank_card.dart';
// 渲染段替换：
..._departments!.map((dept) {
  final name = dept as String;
  final stat = deptMap[name] ?? const <String, dynamic>{};
  return QuestionBankCard(data: QuestionBankCardModel.fromDeptMap(name, stat),
      onTap: () => _openPractice(name));
}),
```
> 原「薄弱模块」红色高亮 + `AppChip('需加强')` 绿色警示色块已按偏好收敛，不再用色块强调。

### File: e:\zhiyu\mobile\lib\shared\widgets\case_library_entry_card.dart （新建）

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'app_widgets.dart';

class CaseLibraryEntryCard extends StatelessWidget {
  const CaseLibraryEntryCard({super.key, required this.count, this.ratingAvg, this.onTap});
  final int? count;       // 病例总量；null=后端未返回，标注待完善
  final double? ratingAvg;// 平均评分
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rating = ratingAvg ?? 0;
    return AppPressable(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 30, height: 30,
              decoration: BoxDecoration(color: AppColors.mossTintOf(context), shape: BoxShape.circle),
              child: const Icon(Icons.folder_copy_rounded, size: 15, color: AppColors.moss)),
            const SizedBox(width: 9),
            SerifText('病例库', fontSize: 15, color: AppColors.textOf(context)),
            const Spacer(),
            MonoText('★ ${rating.toStringAsFixed(1)}', fontSize: 11, color: AppColors.amber),
          ]),
          const SizedBox(height: 8),
          Text('浏览 · 查找全部临床病例',
              style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
          const SizedBox(height: 12),
          Row(children: [
            if (count != null)
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: AppColors.mossTintOf(context), borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text('$count 例', style: TextStyle(fontSize: 10, fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: kCjkMonoFallback, color: AppColors.primaryOf(context))))
            else
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: AppColors.ruleSoftOf(context), borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text('病例总数 待完善', style: TextStyle(fontSize: 10, fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: kCjkMonoFallback, color: AppColors.text3Of(context)))),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.text3Of(context)),
          ]),
        ]),
      ),
    );
  }
}
```

> Agent B 待后端补充字段：`publisher`（出版社）、科室级聚合 `difficulty`、科室级题型分布、病例库 `total` 计数。已端降级为「待完善」占位，不编造字段。

---

# Agent C · AI组卷异步化 + 考试状态机

> **真实维度核查**：难度 int 1~3（下拉）；题量 1~20（滑块）；题型 `single_choice/judgment` 真实存在、`multiple_choice/fill_blank` 待完善；「学科/章节」对应真实字段 `department`(科室) / `knowledgeTag`(知识点)。

### File: e:\zhiyu\mobile\lib\features\student\training\widgets\paper_config_form.dart （新建）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../data/student_service.dart';

class PaperConfig {
  const PaperConfig({required this.questionTypes, required this.departments,
    required this.knowledgeTags, this.difficulty, required this.count});
  final List<String> questionTypes;
  final List<String> departments;
  final List<String> knowledgeTags;
  final int? difficulty;
  final int count;
}

class PaperConfigForm extends ConsumerStatefulWidget {
  const PaperConfigForm({super.key, required this.onSubmit});
  final ValueChanged<PaperConfig> onSubmit;
  @override
  ConsumerState<PaperConfigForm> createState() => _PaperConfigFormState();
}

class _PaperConfigFormState extends ConsumerState<PaperConfigForm> {
  final Set<String> _questionTypes = {'single_choice', 'judgment'};
  final Set<String> _departments = {};
  final Set<String> _knowledgeTags = {};
  int? _difficulty;
  double _count = 10;
  List<String> _deptOptions = const [];
  List<String> _tagOptions = const [];
  bool _loadingOptions = true;

  static const List<({String value, String label, bool released})> _typeOptions = [
    (value: 'single_choice', label: '单选', released: true),
    (value: 'judgment', label: '判断', released: true),
    (value: 'multiple_choice', label: '多选', released: false),
    (value: 'fill_blank', label: '填空', released: false),
  ];

  @override
  void initState() { super.initState(); _loadOptions(); }

  Future<void> _loadOptions() async {
    final service = StudentService();
    final depts = await service.getQuestionDepartments();
    final tags = await service.getQuestionKnowledgeTags();
    if (!mounted) return;
    setState(() {
      _deptOptions = (depts ?? const []).map((e) => '$e').where((s) => s.isNotEmpty).toSet().toList();
      _tagOptions = (tags ?? const []).map((e) => '$e').where((s) => s.isNotEmpty).toSet().toList();
      _loadingOptions = false;
    });
  }

  bool _canSubmit() => _questionTypes.isNotEmpty;

  void _submit() {
    if (!_canSubmit()) { AppFeedback.info(context, '请至少选择一种题型'); return; }
    widget.onSubmit(PaperConfig(
      questionTypes: _questionTypes.toList(), departments: _departments.toList(),
      knowledgeTags: _knowledgeTags.toList(), difficulty: _difficulty,
      count: _count.round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadow.card(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 15, color: AppColors.primaryOf(context)),
          const SizedBox(width: 6),
          SerifText('组卷配置', fontSize: 15, color: AppColors.textOf(context), weight: FontWeight.w700),
        ]),
        const SizedBox(height: 16),
        _sectionTitle('题型', hint: 'multiple_choice/fill_blank 待完善'),
        Wrap(spacing: 8, runSpacing: 8, children: _typeOptions.map((t) {
          final selected = _questionTypes.contains(t.value);
          return ChoiceChip(label: Text(t.label), selected: selected,
            onSelected: t.released ? (v) => setState(() { v ? _questionTypes.add(t.value) : _questionTypes.remove(t.value); }) : null,
            selectedColor: AppColors.primarySoftOf(context),
            backgroundColor: AppColors.surfaceOf(context),
            labelStyle: TextStyle(fontSize: 13, color: selected ? AppColors.primaryOf(context) : AppColors.text2Of(context)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.ruleOf(context)),
          );
        }).toList()),
        const SizedBox(height: 16),
        _sectionTitle('学科/模块（科室）', hint: '对应后端 department，按此组卷过滤待完善'),
        if (_loadingOptions)
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
        else if (_deptOptions.isEmpty)
          MonoText('暂无可选科室', fontSize: 12, color: AppColors.text4Of(context))
        else
          _multiSelectChips(_deptOptions, _departments),
        const SizedBox(height: 16),
        _sectionTitle('章节/知识点', hint: '对应后端 knowledgeTag，按此组卷过滤待完善'),
        if (!_loadingOptions && _tagOptions.isNotEmpty) _multiSelectChips(_tagOptions, _knowledgeTags),
        const SizedBox(height: 16),
        _sectionTitle('难度'),
        _difficultyDropdown(),
        const SizedBox(height: 16),
        _sectionTitle('题量：${_count.round()}'),
        Slider(value: _count, min: 5, max: 20, divisions: 15, label: '${_count.round()}',
          activeColor: AppColors.primaryOf(context), inactiveColor: AppColors.paper2Of(context),
          onChanged: (v) => setState(() => _count = v)),
        const SizedBox(height: 18),
        AppGradientButton(label: '开始生成', color: AppColors.primaryOf(context), height: 48, fullWidth: true,
          icon: const Icon(Icons.auto_awesome, size: 16), onPressed: _canSubmit() ? _submit : null),
      ]),
    );
  }

  Widget _sectionTitle(String title, {String? hint}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SerifText(title, fontSize: 13, color: AppColors.text2Of(context), weight: FontWeight.w600),
        if (hint != null) ...[const SizedBox(width: 6), MonoText(hint, fontSize: 10, color: AppColors.vermilion)],
      ]));
  }

  Widget _multiSelectChips(List<String> options, Set<String> selected) {
    return Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
      final sel = selected.contains(o);
      return ChoiceChip(label: Text(o), selected: sel,
        onSelected: (v) => setState(() { v ? selected.add(o) : selected.remove(o); }),
        selectedColor: AppColors.primarySoftOf(context), backgroundColor: AppColors.surfaceOf(context),
        labelStyle: TextStyle(fontSize: 12, color: sel ? AppColors.primaryOf(context) : AppColors.text2Of(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide(color: sel ? AppColors.primary : AppColors.ruleOf(context)));
    }).toList());
  }

  Widget _difficultyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(value: _difficulty, isExpanded: true,
          hint: Text('不限', style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
          icon: const Icon(Icons.arrow_drop_down),
          items: const [
            DropdownMenuItem(value: null, child: Text('不限', style: TextStyle(fontSize: 14))),
            DropdownMenuItem(value: 1, child: Text('简单', style: TextStyle(fontSize: 14))),
            DropdownMenuItem(value: 2, child: Text('标准', style: TextStyle(fontSize: 14))),
            DropdownMenuItem(value: 3, child: Text('困难', style: TextStyle(fontSize: 14))),
          ],
          onChanged: (v) => setState(() => _difficulty = v),
          style: TextStyle(fontSize: 14, color: AppColors.textOf(context))),
      ),
    );
  }
}
```

### File: e:\zhiyu\mobile\lib\features\student\data\student_api.dart（追加两个方法）

```dart
  Future<ApiResponse<Map<String, dynamic>>> submitPaperTask({
    int count = 10, int? difficulty, List<String> focusTags = const [],
    List<String> questionTypes = const [], List<String> departments = const [],
    List<String> knowledgeTags = const [],
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/student/paper/tasks', data: {
        'count': count,
        if (difficulty != null) 'difficulty': difficulty,
        'focusTags': focusTags,
        if (questionTypes.isNotEmpty) 'questionTypes': questionTypes,   // 待完善
        if (departments.isNotEmpty) 'departments': departments,          // 待完善
        if (knowledgeTags.isNotEmpty) 'knowledgeTags': knowledgeTags,    // 待完善
      });
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getPaperTask(String taskId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/paper/tasks/$taskId');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }
```

### File: e:\zhiyu\mobile\lib\features\student\data\student_service.dart（追加封装）

```dart
  Future<Map<String, dynamic>?> submitPaperTask({
    int count = 10, int? difficulty, List<String> focusTags = const [],
    List<String> questionTypes = const [], List<String> departments = const [],
    List<String> knowledgeTags = const [],
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitPaperTask(count: count, difficulty: difficulty, focusTags: focusTags,
        questionTypes: questionTypes, departments: departments, knowledgeTags: knowledgeTags);
    if (!resp.isSuccess) { log('submitPaperTask failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  Future<Map<String, dynamic>?> getPaperTask(String taskId) async {
    if (_isMock) return null;
    final resp = await _api.getPaperTask(taskId);
    if (!resp.isSuccess) { log('getPaperTask failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }
```

### File: e:\zhiyu\mobile\lib\features\student\training\paper_practice_screen.dart（替换 46~94 行区间）

```dart
  bool _configDone = false;
  bool _generating = false;
  String? _taskId;
  int _pollTick = 0;

  @override
  void initState() { super.initState(); _configDone = false; }

  Future<void> _startGenerate(PaperConfig cfg) async {
    setState(() { _configDone = true; _generating = true; _error = null; _isLoading = true; _taskId = null; _pollTick = 0; });
    final t = await StudentService().submitPaperTask(
      count: cfg.count, difficulty: cfg.difficulty, questionTypes: cfg.questionTypes,
      departments: cfg.departments, knowledgeTags: cfg.knowledgeTags,
    );
    if (!mounted) return;
    final tid = (t?['taskId'] as String?) ?? (t?['id'] as String?);
    if (tid == null) { setState(() { _isLoading = false; _generating = false; _error = '提交组卷任务失败，请稍后重试'; }); return; }
    setState(() => _taskId = tid);
    const maxTick = 60;
    while (_pollTick < maxTick) {
      await Future<void>.delayed(const Duration(seconds: 2));
      _pollTick++;
      final task = await StudentService().getPaperTask(tid);
      if (!mounted) return;
      final status = (task?['status'] as String?) ?? 'PENDING';
      if (status == 'SUCCEEDED') {
        final paper = task?['paper'] as Map<String, dynamic>?;
        final list = (paper?['questions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) { setState(() { _isLoading = false; _generating = false; _error = '题库暂无可用题目，无法生成自测卷'; }); return; }
        StudentService().track('paper_generate', detail: '${(paper?['weakTags'] as List<dynamic>?)?.join(',')}');
        setState(() { _paper = paper; _questions = list; _isLoading = false; _generating = false; });
        return;
      }
      if (status == 'FAILED_FINAL' || status == 'FAILED_RETRYABLE') {
        setState(() { _isLoading = false; _generating = false; _error = (task?['errorMessage'] as String?) ?? '组卷失败，请重试'; });
        return;
      }
      if (mounted && _generating) setState(() {});
    }
    if (mounted) setState(() { _isLoading = false; _generating = false; _error = '组卷超时，请稍后重试'; });
  }

  void _retry() { setState(() { _error = null; _configDone = false; _isLoading = false; }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppColors.bgOf(context),
      body: SafeArea(bottom: false, child: Column(children: [
        AppBackAppBar(title: widget.title, onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: _buildBody()),
      ])));
  }

  Widget _buildBody() {
    if (_isLoading && _generating) return _buildGenerating();
    if (!_configDone && _error == null) return _buildConfig();
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
      const SizedBox(height: 12),
      SerifText(_error!, fontSize: 15, color: AppColors.text2Of(context)),
      const SizedBox(height: 16),
      AppGhostButton(label: '重新配置', fullWidth: false, onPressed: _retry),
    ]));
    if (_isFinished) return _buildSummary();
    return _buildQuestion();
  }

  Widget _buildConfig() {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [PaperConfigForm(onSubmit: _startGenerate)]);
  }

  Widget _buildGenerating() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
      const SizedBox(height: 16),
      SerifText('AI 正在组卷…', fontSize: 15, color: AppColors.textOf(context)),
      const SizedBox(height: 6),
      Text('已生成 ${_pollTick * 2}s · 请稍候', style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
    ]));
  }
```
> 顶部需加 `import 'widgets/paper_config_form.dart';`。

### File: e:\zhiyu\mobile\lib\features\student\training\paper_exam_screen.dart （新建，考试状态机）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

enum PaperExamStatus { configuring, answering, grading, finished }

class PaperExamScreen extends ConsumerStatefulWidget {
  const PaperExamScreen({super.key, this.title = 'AI 组卷考试', this.examTaskId});
  final String title;
  final String? examTaskId;
  @override
  ConsumerState<PaperExamScreen> createState() => _PaperExamScreenState();
}

class _PaperExamScreenState extends ConsumerState<PaperExamScreen> {
  PaperExamStatus _status = PaperExamStatus.configuring;
  String? _error;
  List<Map<String, dynamic>> _questions = const [];
  final List<Map<String, dynamic>> _answers = [];
  final List<Map<String, dynamic>> _results = [];
  int _index = 0;
  int? _selected;
  Set<int> _multiSelected = {};
  final TextEditingController _blankCtl = TextEditingController();
  int _correctCount = 0;
  int _total = 0;

  @override
  void dispose() { _blankCtl.dispose(); super.dispose(); }
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions()); }

  Future<void> _loadQuestions() async {
    if (widget.examTaskId == null) { setState(() { _error = '缺少组卷任务'; _status = PaperExamStatus.configuring; }); return; }
    final task = await StudentService().getPaperTask(widget.examTaskId!);
    if (!mounted) return;
    final paper = task?['paper'] as Map<String, dynamic>?;
    final list = (paper?['questions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) { setState(() { _error = '题库暂无可用题目'; _status = PaperExamStatus.configuring; }); return; }
    setState(() {
      _questions = list; _total = list.length;
      _answers.addAll(List.generate(list.length, (_) => <String, dynamic>{}));
      _status = PaperExamStatus.answering;
    });
  }

  Map<String, dynamic>? get _current => _index < _questions.length ? _questions[_index] : null;
  String get _questionType => (_current?['questionType'] as String?) ?? 'single_choice';
  bool get _isMulti => _questionType == 'multiple_choice';
  bool get _isBlank => _questionType == 'fill_blank';

  bool get _currentAnswered {
    if (_isBlank) return (_blankCtl.text.trim().isNotEmpty);
    if (_isMulti) return _multiSelected.isNotEmpty;
    return _selected != null;
  }
  String get _currentAnswerText {
    if (_isBlank) return _blankCtl.text.trim();
    if (_isMulti) { final l = _multiSelected.toList()..sort(); return l.join(','); }
    return '$_selected';
  }
  void _saveCurrent() => _answers[_index] = {'answer': _currentAnswerText};
  void _next() { _saveCurrent(); setState(() { _index++; _selected = null; _multiSelected = {}; _blankCtl.clear(); }); }
  void _prev() { setState(() { if (_index > 0) _index--; _selected = null; _multiSelected = {}; _blankCtl.clear(); }); }

  /// 交卷：逐题判题（调用判题接口，不依赖题目自带答案），出分 + 收集解析
  Future<void> _submitPaper() async {
    _saveCurrent();
    setState(() => _status = PaperExamStatus.grading);
    _results.clear(); _correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final ans = (_answers[i]['answer'] as String?) ?? '';
      final res = await StudentService().submitQuestion(questionId: ((q['id'] as num?) ?? 0).toInt(), selectedAnswer: ans);
      if (!mounted) return;
      final core = res?['isCorrect'] == true;
      _results.add({
        'isCorrect': core, 'correctAnswer': res?['correctAnswer'] ?? '', 'explanation': res?['explanation'] ?? '',
        'selectedAnswer': ans, 'title': q['title'] ?? '', 'options': q['options'] ?? const [],
        'questionType': q['questionType'] ?? '', 'knowledgeTag': q['knowledgeTag'] ?? '',
      });
      if (core) _correctCount++;
    }
    if (!mounted) return;
    setState(() => _status = PaperExamStatus.finished);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppColors.bgOf(context),
      body: SafeArea(bottom: false, child: Column(children: [
        AppBackAppBar(title: widget.title, onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: _buildBody()),
      ])));
  }

  Widget _buildBody() {
    switch (_status) {
      case PaperExamStatus.configuring:
        return _error != null
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
                const SizedBox(height: 12),
                SerifText(_error!, fontSize: 15, color: AppColors.text2Of(context))]))
            : const Center(child: CircularProgressIndicator());
      case PaperExamStatus.answering: return _buildAnswering();
      case PaperExamStatus.grading: return const Center(child: CircularProgressIndicator());
      case PaperExamStatus.finished: return _buildResult();
    }
  }

  Widget _buildAnswering() {
    final q = _current!;
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final typeLabel = _isMulti ? '多选' : (_isBlank ? '填空' : (q['questionType'] == 'judgment' ? '判断' : '单选'));
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Row(children: [
        Icon(Icons.lock_outline, size: 13, color: AppColors.primary),
        const SizedBox(width: 4),
        MonoText('考试中 · 提交后可查看答案与解析', fontSize: 11, color: AppColors.text4Of(context)),
        const Spacer(),
        MonoText('第 ${_index + 1}/$_total 题', fontSize: 11, color: AppColors.text4Of(context), weight: FontWeight.w700),
      ])),
      LinearProgressIndicator(value: (_index + 1) / _total, minHeight: 4,
        backgroundColor: AppColors.paper2Of(context), valueColor: const AlwaysStoppedAnimation(AppColors.primary)),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 30), children: [
        Row(children: [
          AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
          const SizedBox(width: 6),
          AppChip(label: typeLabel, type: ChipType.indigo),
          const SizedBox(width: 6),
          AppChip(label: difficultyLabel, type: ChipType.amber),
        ]),
        const SizedBox(height: 14),
        Text(q['title'] as String? ?? '', style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
        const SizedBox(height: 18),
        if (_isMulti) ...options.asMap().entries.map((e) => _choiceTile(e.key, e.value, multi: true))
        else if (_isBlank) _blankTile()
        else ...options.asMap().entries.map((e) => _choiceTile(e.key, e.value, multi: false)),
        const SizedBox(height: 18),
        Row(children: [
          if (_index > 0) ...[AppGhostButton(label: '上一题', fullWidth: false, onPressed: _prev), const SizedBox(width: 8)],
          Expanded(child: _index < _total - 1
              ? AppPrimaryButton(label: '下一题', fullWidth: true, icon: const Icon(Icons.arrow_forward, size: 16), onPressed: _currentAnswered ? _next : null)
              : AppGradientButton(label: '交卷', color: AppColors.vermilion, height: 48, fullWidth: true, icon: const Icon(Icons.task_alt, size: 16), onPressed: _currentAnswered ? _submitPaper : null)),
        ]),
      ])),
    ]);
  }

  Widget _choiceTile(int idx, String text, {required bool multi}) {
    final isSelected = multi ? _multiSelected.contains(idx) : _selected == idx;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(onTap: () => setState(() {
      if (multi) { isSelected ? _multiSelected.remove(idx) : _multiSelected.add(idx); } else { _selected = idx; }
    }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: isSelected ? AppColors.mossTintOf(context) : AppColors.surfaceOf(context),
        border: Border.all(color: isSelected ? AppColors.primaryOf(context) : AppColors.surfaceEdgeOf(context), width: isSelected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.ruleOf(context), width: 1.5),
          shape: multi ? BoxShape.rectangle : BoxShape.circle),
          child: isSelected ? Center(child: Icon(Icons.check, size: 13, color: AppColors.primary)) : null),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: AppColors.textOf(context)))),
      ])));
  }

  Widget _blankTile() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context), width: 1), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: TextField(controller: _blankCtl, style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: '请输入答案', border: InputBorder.none)));
  }

  Widget _buildResult() {
    final accuracy = _total == 0 ? 0.0 : _correctCount / _total;
    final pass = accuracy >= 0.6;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)), borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.card(context)),
        child: Column(children: [
          Icon(pass ? Icons.emoji_events_outlined : Icons.trending_up, size: 40, color: pass ? AppColors.amber : AppColors.primary),
          const SizedBox(height: 10),
          SerifText('考试完成', fontSize: 18, color: AppColors.textOf(context), weight: FontWeight.w700),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stat('$_correctCount', '答对', AppColors.primary),
            _stat('$total', '总题数', AppColors.indigo),
            _stat('${(accuracy * 100).toStringAsFixed(0)}%', '正确率', AppColors.amber),
          ]),
        ])),
      const SizedBox(height: 18),
      ..._results.asMap().entries.map((e) => _analysisCard(e.key, e.value)),
      const SizedBox(height: 18),
      AppPrimaryButton(label: '返回', fullWidth: true, onPressed: () => Navigator.of(context).maybePop()),
    ]);
  }

  Widget _analysisCard(int i, Map<String, dynamic> r) {
    final ok = r['isCorrect'] == true;
    final options = (r['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final correctRaw = (r['correctAnswer'] as String?) ?? '';
    final isMulti = r['questionType'] == 'multiple_choice';
    final correctText = isMulti ? _formatMulti(correctRaw, options) : correctRaw;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceOf(context),
        border: Border.all(color: ok ? AppColors.primary.withValues(alpha: 0.4) : AppColors.vermilion.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 17, color: ok ? AppColors.primary : AppColors.vermilion),
          const SizedBox(width: 6),
          MonoText('第 ${i + 1} 题', fontSize: 11, color: AppColors.text4Of(context)),
          const Spacer(),
          Text(ok ? '正确' : '错误', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? AppColors.primary : AppColors.vermilion)),
        ]),
        const SizedBox(height: 6),
        Text(r['title'] as String? ?? '', style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textOf(context))),
        const SizedBox(height: 8),
        Text('你的答案：${r['selectedAnswer'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
        const SizedBox(height: 2),
        Text('正确答案：$correctText', style: TextStyle(fontSize: 12, color: ok ? AppColors.primary : AppColors.vermilion)),
        if ((r['explanation'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text('解析：${r['explanation']}', style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context))),
        ],
      ]));
  }

  String _formatMulti(String raw, List<String> options) {
    if (options.isEmpty) return raw;
    final indices = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return indices.map((i) { final idx = int.tryParse(i);
      if (idx == null || idx < 0 || idx >= options.length) return i;
      return '$i.${options[idx]}'; }).join('、');
  }

  Widget _stat(String value, String label, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Column(children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
    ]));
  }
}
```

### File: e:\zhiyu\ai\app\workers\paper_worker.py （新建，异步 worker 核心）

```python
"""AI 组卷异步 Worker（复用 task_queue 的 TaskQueue + TaskWorker 机制）。
Java 业务中台负责候选组装+规则兜底+题目解析；AI 中台负责异步调度+LLM 选题组卷。
"""
import uuid
from typing import Any

from app.domain.enums import TaskStatus, TaskType
from app.workers.base_worker import TaskWorker
from app.workers.task_queue import TaskQueue
from app.services.llm_client import llm_client


def _to_user_msg(payload: dict[str, Any]) -> str:
    lines = [
        f"学生 ID：{payload.get('studentId')}",
        f"目标题量：{payload.get('count')}",
        f"难度偏好：{payload.get('difficulty') or '不限'}",
        f"薄弱知识点：{'、'.join(payload.get('focusTags') or []) or '（暂无统计）'}",
        "候选题目列表：",
    ]
    for c in payload.get('candidates') or []:
        diff = {1: "简单", 2: "标准", 3: "困难"}.get(c.get('difficulty'), "未知")
        lines.append(f"- id={c.get('id')} | {c.get('knowledgeTag') or '未知'} | {diff} | "
                     f"{c.get('questionType') or 'unknown'} | {c.get('title') or '（无题干）'}")
    lines.append("请仅从候选中选题组卷，禁止编造题目。")
    return "\n".join(lines)


def _degraded() -> dict[str, Any]:
    return {"paperTitle": "", "selectedIds": [], "source": "RULE", "status": "DEGRADED"}


async def paper_handler(payload: dict[str, Any]) -> dict[str, Any]:
    trace_id = str(uuid.uuid4())
    messages = [
        {"role": "system", "content": "请作为医学组卷助手，从给定候选中挑选最贴合学生薄弱点的题目。"},
        {"role": "user", "content": _to_user_msg(payload)},
    ]
    try:
        result = await llm_client.chat_json(messages, trace_id=trace_id)
    except Exception:
        return _degraded()

    raw_ids = result.get("selectedIds") if isinstance(result, dict) else None
    if not isinstance(raw_ids, list) or not raw_ids:
        return _degraded()

    allowed = {c.get("id") for c in payload.get("candidates") or []}
    valid = []
    for i in raw_ids:
        try:
            iid = int(i)
        except (TypeError, ValueError):
            continue
        if iid in allowed and iid not in valid:
            valid.append(iid)

    return {
        "paperTitle": str(result.get("paperTitle") or "").strip() or "个性化自测卷",
        "selectedIds": valid,
        "rationale": str(result.get("rationale") or "").strip(),
        "source": "AI",
        "status": "SUCCESS",
    }


def build_paper_worker(queue: TaskQueue) -> TaskWorker:
    return TaskWorker(queue=queue, task_type=TaskType.PAPER.value, handler=paper_handler)
```

### File: e:\zhiyu\ai\app\domain\enums.py（新增枚举）

```python
class TaskType(str, Enum):
    REVIEW = "review"
    REPORT = "report"
    KNOWLEDGE_INGEST = "knowledge_ingest"
    PAPER = "paper"          # 新增
```

> AI 中台已有 `/v1/ai/tasks`（提交）与 `/v1/ai/tasks/{task_id}`（查询），可直接复用。**移动端不能直连 AI（`require_internal_token`）**，须经 Java 中转轮询。

### File: e:\zhiyu\backend\src\main\java\com\zhiyu\service\impl\StudentPaperServiceImpl.java（异步化伪代码）

```java
// 提交异步任务：先组装候选+提交队列，返回 taskId；SUCCEEDED 后补解析
public SubmitResult submitAsync(PaperGenerateRequest req) {
    Long studentId = UserContext.requireUserId();
    int count = req.getCount() == null ? 10 : req.getCount();
    List<String> focusTags = resolveFocusTags(studentId, req.getFocusTags());
    // 待完善：按 req.questionTypes / departments / knowledgeTags 过滤候选
    List<PracticeQuestion> candidates = loadCandidates(focusTags, count);
    Map<String,Object> payload = new HashMap<>();
    payload.put("studentId", studentId);
    payload.put("count", count);
    payload.put("difficulty", req.getDifficulty());
    payload.put("focusTags", focusTags);
    payload.put("candidates", toAiCandidates(candidates)); // 只给元数据
    Map<String,Object> task = aiPlatformClient.submitAiTask("paper",
        "paper:" + studentId + ":" + System.currentTimeMillis(), payload);
    return new SubmitResult(taskId(String.valueOf(task.get("task_id"))));
}

public Map<String,Object> taskStatus(String taskId) {
    Map<String,Object> t = aiPlatformClient.getAiTaskDetail(taskId); // 已存在
    String status = String.valueOf(t.get("status"));
    Map<String,Object> out = new HashMap<>();
    out.put("taskId", taskId);
    out.put("status", status);
    out.put("errorMessage", t.get("error_message"));
    if ("SUCCEEDED".equals(status)) {
        Map<String,Object> r = (Map<String,Object>) t.get("result");
        List<Long> ids = pickIds(r.get("selectedIds"));
        List<PracticeQuestionVO> questions = resolveQuestions(ids);
        out.put("paper", buildPaper(r, questions, focusTags));
    }
    return out;
}
```
> 新增移动端口 `/paper/tasks`（提交）与 `/paper/tasks/{id}`（状态查询）。

> Agent C 待后端补齐：`PaperGenerateRequest` 增加 `questionTypes/departments/knowledgeTags`；`loadCandidates/ruleSelect` 增加过滤；题目实体补多选/填空数据；**考试模式专用的不含 `answer/explanation` 的 VO 变体**（当前 `toVO()` 会把答案/解析直接返回前端，"隐藏答案"需后端屏蔽）。

---

# Agent D · AI学伴修复 + 会话历史

> **核查结论**：SSE 流式与多模态后端已实现（`ai/app/api/companion.py` 的 `/v1/ai/companion/stream` + Java `SseEmitter` 转发；`companion_workflow` 支持 `image_url` data URL 直传；`image_picker` 已在依赖）。**唯一缺口是会话历史管理**。`chat_session`（问诊表）字段与学伴不匹配，**不复用**，新建独立表。

### File: e:\zhiyu\backend\src\main\resources\db\migration\V33__companion_conversation.sql

```sql
-- AI 学伴会话（P1-2 会话历史管理）
-- 与 chat_session（问诊会话）解耦：学伴=陪伴闲聊，不承载评分/病例字段。
CREATE TABLE IF NOT EXISTS companion_conversation (
    id            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    student_id    BIGINT       NOT NULL COMMENT '学生ID',
    title         VARCHAR(100) NOT NULL DEFAULT '新对话' COMMENT '会话标题（首条消息截断）',
    deleted       TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除 0否 1是',
    gmt_create    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    gmt_modified  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_student_gmt (student_id, gmt_create DESC, id DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI学伴会话';

CREATE TABLE IF NOT EXISTS companion_message (
    id             BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    conversation_id BIGINT      NOT NULL COMMENT '会话ID',
    sender         VARCHAR(16)  NOT NULL COMMENT 'user/assistant',
    content        TEXT         NOT NULL COMMENT '文本内容',
    image_url      TEXT         NULL COMMENT '图片(HTTP URL 或 data URL)',
    gmt_create     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_conversation (conversation_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI学伴消息';
```

Java 实体核心：
```java
@Data
@TableName("companion_conversation")
public class CompanionConversation extends BaseEntity {
    private Long studentId;
    private String title;
}
```
> Controller 四接口：`POST /`新建、`GET /`列表倒序（`student_id+deleted=0 ORDER BY gmt_create DESC`）、`PUT /{id}`重命名、`DELETE /{id}`逻辑删除（`deleted=1`）。Mapper 用 `LambdaQueryWrapper` 即可。

### File: e:\zhiyu\mobile\lib\features\student\companion\companion_conversation_provider.dart （新建）

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/student_service.dart';

class CompanionConversation {
  final int id; String title; final DateTime createdAt;
  const CompanionConversation({required this.id, required this.title, required this.createdAt});
  String get groupLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '7 天内';
    if (createdAt.year == now.year && createdAt.month == now.month) return '这个月';
    if (createdAt.year == now.year) return '${createdAt.month} 月';
    return '${createdAt.year} 年';
  }
}

class CompanionConversationNotifier extends StateNotifier<AsyncValue<List<CompanionConversation>>> {
  CompanionConversationNotifier() : super(const AsyncValue.loading());
  static const _cacheKey = 'companion_conversations_v1';
  final _svc = StudentService();
  int _nextId = 1;

  Future<void> load() async {
    state = const AsyncValue.loading();
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    List<CompanionConversation>? local;
    if (cached != null) {
      local = (jsonDecode(cached) as List).map((e) => CompanionConversation(
        id: (e['id'] as num).toInt(), title: e['title'] as String,
        createdAt: DateTime.parse(e['createdAt'] as String))).toList();
      state = AsyncValue.data(local);
    }
    final list = await _svc.getCompanionConversations();
    if (list != null && list.isNotEmpty) { state = AsyncValue.data(list); await _cache(list); }
    else if (local == null) state = const AsyncValue.data([]);
  }

  Future<CompanionConversation> create() async {
    final conv = await _svc.createCompanionConversation(title: '新对话') ??
        CompanionConversation(id: _nextId++, title: '新对话', createdAt: DateTime.now());
    final updated = [conv, ...(state.valueOrNull ?? [])];
    state = AsyncValue.data(updated); await _cache(updated); return conv;
  }

  Future<void> rename(int id, String title) async {
    final ok = await _svc.renameCompanionConversation(id, title);
    if (!ok) return;
    final updated = (state.valueOrNull ?? []).map((c) =>
        c.id == id ? CompanionConversation(id: c.id, title: title, createdAt: c.createdAt) : c).toList();
    state = AsyncValue.data(updated); await _cache(updated);
  }

  Future<void> remove(int id) async {
    final ok = await _svc.deleteCompanionConversation(id);
    final updated = (state.valueOrNull ?? []).where((c) => c.id != id).toList();
    state = AsyncValue.data(updated); await _cache(updated);
    if (!ok) rethrow;
  }

  Future<void> _cache(List<CompanionConversation> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(list.map((c) => {
      'id': c.id, 'title': c.title, 'createdAt': c.createdAt.toIso8601String(),
    }).toList()));
  }
}

final companionConversationsProvider = StateNotifierProvider.autoDispose<
    CompanionConversationNotifier, AsyncValue<List<CompanionConversation>>>(
      (ref) => CompanionConversationNotifier()..load());
```

### File: e:\zhiyu\mobile\lib\features\student\companion\companion_history_drawer.dart （新建，底部抽屉）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'companion_conversation_provider.dart';

class CompanionHistoryDrawer extends ConsumerWidget {
  final int? currentId;
  final void Function(int conversationId, String title) onSelect;
  const CompanionHistoryDrawer({super.key, this.currentId, required this.onSelect});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, int id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除该会话？'),
      content: const Text('删除后不可恢复，本机已同步的漫游记录也会移除。'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'))],
    ));
    if (ok == true) {
      try { await ref.read(companionConversationsProvider.notifier).remove(id); }
      catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败，请检查网络'))); }
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, int id, String currentTitle) async {
    final ctl = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('重命名会话'), content: TextField(controller: ctl, maxLength: 30),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('保存'))],
    ));
    if (result != null && result.isNotEmpty) await ref.read(companionConversationsProvider.notifier).rename(id, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(companionConversationsProvider);
    final list = convs.valueOrNull ?? const <CompanionConversation>[];
    return SafeArea(top: false, child: Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 8, 4), child: Row(children: [
          SerifText('会话历史', fontSize: 16, color: AppColors.textOf(context)),
          const Spacer(),
          TextButton.icon(onPressed: () async {
            final c = await ref.read(companionConversationsProvider.notifier).create();
            if (context.mounted) { onSelect(c.id, c.title); Navigator.pop(context); }
          }, icon: const Icon(Icons.add_comment_outlined, size: 18), label: const Text('新对话')),
        ])),
        if (convs.isLoading && list.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: MonoText('暂无历史会话', fontSize: 11)))
        else
          Flexible(child: ListView(shrinkWrap: true, children: _grouped(list).entries.expand((entry) => [
            _groupHeader(entry.key), ...entry.value.map((c) => _tile(context, ref, c)),
          ]).toList())),
      ])));
  }

  Map<String, List<CompanionConversation>> _grouped(List<CompanionConversation> list) {
    final map = <String, List<CompanionConversation>>{};
    for (final c in list) map.putIfAbsent(c.groupLabel, () => []).add(c);
    return map;
  }
  Widget _groupHeader(String label) => Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: MonoText(label, fontSize: 10, color: AppColors.text4Of(context)));

  Widget _tile(BuildContext context, WidgetRef ref, CompanionConversation c) {
    final selected = c.id == currentId;
    return ListTile(dense: true,
      leading: Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline, size: 18, color: AppColors.primaryOf(context)),
      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: AppColors.textOf(context))),
      selected: selected, selectedTileColor: AppColors.primaryOf(context).withValues(alpha: 0.08),
      onTap: () { Navigator.pop(context); onSelect(c.id, c.title); },
      trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) { if (v == 'rename') _rename(context, ref, c.id, c.title); if (v == 'delete') _confirmDelete(context, ref, c.id); },
        itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('重命名')), PopupMenuItem(value: 'delete', child: Text('删除'))]));
  }
}
```
> `withValues(alpha:)` 需 Flutter 3.27+，旧版改 `.withOpacity(0.08)`。

### File: e:\zhiyu\mobile\lib\features\student\data\student_api.dart（增强 companion + companionStream）

```dart
  /// 同步学伴对话（增强：指数退避重试 + 兜底错误）
  Future<ApiResponse<Map<String, dynamic>>> companion({
    required String message, List<Map<String, String>> history = const [],
    int retries = 2,
  }) async {
    final body = <String, dynamic>{'message': message, 'history': history};
    final opts = Options(receiveTimeout: const Duration(seconds: 60), sendTimeout: const Duration(seconds: 15));
    Object? lastErr;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final resp = await _dio.post<Map<String, dynamic>>('/api/v1/student/companion', data: body, options: opts);
        return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
      } on DioException catch (e) {
        lastErr = e;
        final retryable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout || (e.response?.statusCode ?? 0 >= 500);
        if (!retryable) break;
        if (attempt < retries) { await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1))); continue; }
      }
    }
    final e = lastErr;
    return ApiResponse(code: -1, message: e is DioException ? _mapError(e) : '请求失败，请稍后重试');
  }

  /// 学伴 SSE 流式（增强：连接级重试 + 空流字段兜底）
  Stream<AskStreamEvent> companionStream({
    required String message, List<Map<String, String>> history = const [],
    String? imageUrl, int connectRetries = 2,
  }) async* {
    final body = <String, dynamic>{'message': message, 'history': history};
    if (imageUrl != null && imageUrl.isNotEmpty) body['imageUrl'] = imageUrl;
    for (var attempt = 0; attempt <= connectRetries; attempt++) {
      try {
        final opts = Options(responseType: ResponseType.stream, headers: {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(minutes: 5), sendTimeout: const Duration(seconds: 15));
        final resp = await _dio.post<dynamic>('/api/v1/student/companion/stream', data: body, options: opts);
        if (resp.data is! ResponseBody) { yield AskStreamEvent('error', {'message': '流式响应格式异常'}); return; }
        final rs = resp.data as ResponseBody;
        var event = ''; final buf = StringBuffer(); var gotDone = false;
        await for (final line in utf8.decoder.bind(rs.stream).transform(const LineSplitter())) {
          if (line.isEmpty) {
            if (event.isNotEmpty) {
              final data = _tryParseJson(buf.toString());
              yield AskStreamEvent(event, data);
              if (event == 'done') gotDone = true;
              event = ''; buf.clear();
            }
            continue;
          }
          if (line.startsWith('event:')) event = line.substring('event:'.length).trim();
          else if (line.startsWith('data:')) { var d = line.substring('data:'.length); if (d.startsWith(' ')) d = d.substring(1); buf.write(d); }
        }
        if (!gotDone && _isConnectionLost(resp)) yield const AskStreamEvent('error', {'message': '连接中断，请重试'});
        return;
      } on DioException catch (e) {
        final retryable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout;
        if (!retryable || attempt >= connectRetries) { yield const AskStreamEvent('error', {'message': '连接学伴服务失败，请检查网络'}); return; }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
  }
  bool _isConnectionLost(ResponseBody rs) => !rs.stream.isBroadcast;
```

### File: e:\zhiyu\mobile\lib\features\student\companion\companion_screen.dart（集成，增量）

```dart
// 1) 增加字段
int? _conversationId;
String _conversationTitle = 'AI 学伴';

// 2) AppBar 增加"历史"按钮
action: IconButton(icon: const Icon(Icons.history, size: 20, color: AppColors.textOf(context)),
  tooltip: '会话历史', onPressed: _openHistory),

// 3) 打开历史抽屉
void _openHistory() {
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => CompanionHistoryDrawer(currentId: _conversationId, onSelect: (id, title) {
      _persistCurrentConversation();
      setState(() { _conversationId = id; _conversationTitle = title; });
      _loadConversation(id);
    }));
}

// 4) 每次发送把消息落本地缓存（hive：Hive.box('companion_msgs_${_conversationId}') 追加记录）
void _persistMessage(String role, String text, [String? image]) { /* 见第四部分说明 */ }
```

> Agent D 取舍：会话列表用 `shared_preferences`，消息级用 `hive`；图片 data URL 由 companion 直传 OpenAI，绕开 `vision.py` 的 SSRF 校验（该校验只属问诊影像）。待补齐：Java 4 个 CRUD 接口落地 + `StudentService` 对应 `getCompanionConversations/create/rename/delete` 四个方法（自行按既有方法模式补）。

---

# Agent E · 每日一例自动化调度 + Redis

> **技术栈适配**：本项目后端是 Java（非 Node/Python），定时用 Spring `@Scheduled`。病例主表 `sp_case_config`，排期表 `daily_case_schedule`（含 `uk_date(publish_date)`）。Redis 依赖已存在，`StringRedisTemplate` 自动装配即可。

### File: e:\zhiyu\backend\src\main\resources\db\migration\V34__daily_case_schedule_fields.sql

```sql
-- 每日一例自动化调度：病例表增加 is_daily / daily_date 字段
ALTER TABLE sp_case_config
    ADD COLUMN is_daily TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否被选为每日一例:0否 1是' AFTER admin_audit_status,
    ADD COLUMN daily_date DATE NULL COMMENT '最近一次被选为每日一例的日期' AFTER is_daily;

ALTER TABLE sp_case_config ADD INDEX idx_daily (is_daily, daily_date);
```

### File: e:\zhiyu\backend\src\main\java\com\zhiyu\mapper\SpCaseConfigMapper.java（新增方法）

```java
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhiyu.entity.SpCaseConfig;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;
import java.time.LocalDate;

@Mapper
public interface SpCaseConfigMapper extends BaseMapper<SpCaseConfig> {

    @Update("UPDATE sp_case_config SET reference_count = reference_count + 1 WHERE id = #{id}")
    int incrementReferenceCount(@Param("id") Long id);

    /** 随机抽取一个"未使用"的每日一例病例：已发布+已过审+未被标记+从未进入排期表 */
    @Select("""
            SELECT * FROM sp_case_config
            WHERE is_daily = 0 AND status = 1 AND admin_audit_status = 2 AND is_deleted = 0
              AND NOT EXISTS (SELECT 1 FROM daily_case_schedule d WHERE d.case_id = sp_case_config.id)
            ORDER BY RAND() LIMIT 1
            """)
    SpCaseConfig selectRandomUnusedCase();

    @Update("UPDATE sp_case_config SET is_daily = 1, daily_date = #{date} WHERE id = #{id}")
    int markAsDaily(@Param("id") Long id, @Param("date") LocalDate date);
}
```

### File: e:\zhiyu\backend\src\main\java\com\zhiyu\service\impl\DailyCaseServiceImpl.java（新增字段/常量 + 定时任务 + 改 today() 读 Redis）

```java
    private static final String TODAY_KEY = "daily_case_today";
    private static final java.time.Duration TODAY_TTL = java.time.Duration.ofDays(2);
    private final StringRedisTemplate redisTemplate; // 需注入 + import

    /** 每天 0 点自动排期（Asia/Shanghai；可用 zhiyu.daily-case.cron 覆盖） */
    @Scheduled(cron = "${zhiyu.daily-case.cron:0 0 0 * * *}")
    public void autoScheduleToday() {
        LocalDate today = LocalDate.now();
        log.info("每日一例自动排期开始: date={}", today);
        DailyCaseSchedule s = selectTodaySchedule();
        if (s != null) { log.info("今日已有手动排期, 直接写缓存");
            writeToRedis(buildVo(s, caseMapper.selectById(s.getCaseId()))); return; }
        DailyCaseSchedule picked = tryAutoPickToday();
        if (picked == null) { log.warn("自动排期: 今日无可用（未使用）病例, 跳过"); return; }
        writeToRedis(buildVo(picked, caseMapper.selectById(picked.getCaseId())));
    }

    /** 读当天：先 Redis，未命中回填 */
    @Override
    public DailyCaseVO today() {
        String cached = redisTemplate.opsForValue().get(TODAY_KEY);
        if (cached != null && !cached.isBlank()) { DailyCaseVO vo = parseVo(cached); if (vo != null) return vo; }
        return resolveAndCacheToday();
    }

    private DailyCaseVO resolveAndCacheToday() {
        DailyCaseSchedule s = selectTodaySchedule();
        if (s == null) { s = tryAutoPickToday(); if (s == null) return null; }
        SpCaseConfig c = caseMapper.selectById(s.getCaseId());
        DailyCaseVO vo = buildVo(s, c); writeToRedis(vo); return vo;
    }

    private DailyCaseSchedule selectTodaySchedule() {
        return scheduleMapper.selectOne(new LambdaQueryWrapper<DailyCaseSchedule>()
                .eq(DailyCaseSchedule::getPublishDate, LocalDate.now())
                .eq(DailyCaseSchedule::getStatus, 2).last("LIMIT 1"));
    }

    @Transactional(rollbackFor = Exception.class)
    protected DailyCaseSchedule tryAutoPickToday() {
        SpCaseConfig c = caseMapper.selectRandomUnusedCase();
        if (c == null) return null;
        LocalDate today = LocalDate.now();
        DailyCaseSchedule s = new DailyCaseSchedule();
        s.setCaseId(c.getId()); s.setPublishDate(today); s.setStatus(2);
        try { scheduleMapper.insert(s); }
        catch (org.springframework.dao.DuplicateKeyException e) {
            DailyCaseSchedule exists = selectTodaySchedule();
            if (exists != null) return exists;
            throw e;
        }
        caseMapper.markAsDaily(c.getId(), today);
        log.info("自动排期每日一例: caseId={} date={}", c.getId(), today);
        return s;
    }

    private DailyCaseVO buildVo(DailyCaseSchedule s, SpCaseConfig c) {
        return DailyCaseVO.builder().scheduleId(s.getId()).caseId(s.getCaseId())
                .caseTitle(c == null ? null : c.getTitle())
                .department(c == null ? null : c.getDepartment())
                .difficulty(c == null ? null : c.getDifficulty())
                .publishDate(s.getPublishDate()).targetGrade(s.getTargetGrade())
                .question(s.getQuestion()).optionsJson(s.getOptionsJson())
                .textbookRef(s.getTextbookRef()).status(s.getStatus()).build();
    }

    private void writeToRedis(DailyCaseVO vo) {
        try { redisTemplate.opsForValue().set(TODAY_KEY, toJson(vo), TODAY_TTL); }
        catch (Exception e) { log.warn("写入每日一例 Redis 缓存失败: {}", e.getMessage()); }
    }
    private String toJson(DailyCaseVO vo) {
        try { return objectMapper.writeValueAsString(vo); } catch (Exception e) { return null; }
    }
    private DailyCaseVO parseVo(String json) {
        try {
            JsonNode n = objectMapper.readTree(json);
            String pDate = n.path("publishDate").asText("");
            return DailyCaseVO.builder()
                .scheduleId(n.path("scheduleId").isNull() ? null : n.path("scheduleId").asLong())
                .caseId(n.path("caseId").isNull() ? null : n.path("caseId").asLong())
                .caseTitle(textOrNull(n.path("caseTitle")))
                .department(textOrNull(n.path("department")))
                .difficulty(n.path("difficulty").isNull() ? null : n.path("difficulty").asInt())
                .publishDate(pDate.isEmpty() ? null : LocalDate.parse(pDate))
                .targetGrade(textOrNull(n.path("targetGrade")))
                .question(textOrNull(n.path("question")))
                .optionsJson(textOrNull(n.path("optionsJson")))
                .textbookRef(textOrNull(n.path("textbookRef")))
                .status(n.path("status").isNull() ? null : n.path("status").asInt())
                .build();
        } catch (Exception e) { return null; }
    }
    private static String textOrNull(JsonNode node) {
        if (node == null || node.isNull()) return null;
        String s = node.asText(""); return s.isEmpty() ? null : s;
    }
```

### File: e:\zhiyu\backend\src\main\java\com\zhiyu\config\DailyScheduleTimezoneConfig.java（可选，强制 cron 用时区）

```java
package com.zhiyu.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.SchedulingConfigurer;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.scheduling.config.ScheduledTaskRegistrar;
import java.util.TimeZone;

@Configuration
public class DailyScheduleTimezoneConfig implements SchedulingConfigurer {
    @Override
    public void configureTasks(ScheduledTaskRegistrar taskRegistrar) {
        ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(5);
        scheduler.setThreadNamePrefix("scheduled-");
        scheduler.setTimeZone(TimeZone.getTimeZone("Asia/Shanghai"));
        scheduler.initialize();
        taskRegistrar.setTaskScheduler(scheduler);
    }
}
```
> 等价方案：JVM/容器设 `-Duser.timezone=Asia/Shanghai` 或 Docker `TZ=Asia/Shanghai`。

### 管理端（方案级）

### File: e:\zhiyu\front\src\admin\api\dailyCase.ts（新增）

```ts
import http from './http'
import type { ApiResult } from '../types'
export interface DailyCaseScheduleItem {
  scheduleId: number; caseId: number; caseTitle: string | null;
  department: string | null; difficulty: number | null;
  publishDate: string; targetGrade: string | null; status: number;
}
export interface DailyCaseSchedulePage { list: DailyCaseScheduleItem[]; total: number }
export async function listDailySchedules(pageNum: number, pageSize: number) {
  const { data } = await http.get<ApiResult<DailyCaseSchedulePage>>('/api/v1/admin/daily-cases', { params: { pageNum, pageSize } });
  return data.data;
}
export async function createDailySchedule(payload: { caseId: number; publishDate: string; targetGrade?: string }) {
  const { data } = await http.post<ApiResult<number>>('/api/v1/admin/daily-cases', payload);
  return data.data;
}
```

新建 `front/src/admin/views/DailyCaseSchedule.vue`（新增排期表单 + 列表，病例下拉复用 `/api/v1/case-market/list`，详见 Agent E 交付），并在 `router.ts` 注册 `{ path: '/daily-cases', component: () => import('./views/DailyCaseSchedule.vue'), meta: { roles: [4] } }`。

> Agent E：**移动端无需改动**（`daily_case_screen.dart` 接口返回值不变，后端 `today()` 改读 Redis 对端透明）。无需新增依赖；推荐启用时区配置。

---

# 应用清单（一次性落全）

**后端 Java**
1. `resources/db/migration/V33__companion_conversation.sql`
2. `resources/db/migration/V34__daily_case_schedule_fields.sql`
3. `mapper/SpCaseConfigMapper.java`（+2 方法）
4. `service/impl/DailyCaseServiceImpl.java`（Redis + 定时 + today 改造）
5. 可选 `config/DailyScheduleTimezoneConfig.java`
6. 学伴会话：新增 `CompanionConversation` 实体 + 4 个 CRUD Controller（复用 `StudentCompanionController`）
7. 组卷：`StudentPaperServiceImpl` 异步化（`submitAsync`/`taskStatus`）+ 新增 `/paper/tasks`、`/paper/tasks/{id}` 端点

**AI 平台（Python）**
8. `ai/app/domain/enums.py`（+`TaskType.PAPER`）
9. `ai/app/workers/paper_worker.py`（新建）

**移动端（Flutter）**
10. 重写 `question_bank_screen.dart`
11. `student_case_market_screen.dart`（病例库入口）+ 新建 `question_bank_card.dart`、`case_library_entry_card.dart`
12. `question_training_screen.dart`（接入题库卡）
13. 组卷：新建 `paper_config_form.dart`、`paper_exam_screen.dart`；改 `paper_practice_screen.dart`、`student_api.dart`、`student_service.dart`
14. 学伴：新建 `companion_conversation_provider.dart`、`companion_history_drawer.dart`；改 `student_api.dart`（companion/companionStream + 新增会话CRUD方法）、`companion_screen.dart`

**管理端（Vue）**
15. `front/src/admin/api/dailyCase.ts`（新建）+ `DailyCaseSchedule.vue`（新建）+ router 注册

> 注：`student_api.dart` / `student_service.dart` 同时被 Agent C（组卷）与 Agent D（学伴）追加方法，两者方法段落不同，直接合并即可。所有迁移文件需按版本号连续（V33/V34 已排好，可与现有 V32 衔接）。