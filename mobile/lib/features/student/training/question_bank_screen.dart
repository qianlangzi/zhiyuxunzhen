import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import 'question_practice_screen.dart';

/// 基础题题库浏览页
///
/// 支持按科室 / 知识点 / 难度 / 题型筛选，分页展示题目列表，点击题目进入作答。
class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  bool _isLoading = true;
  List<dynamic> _list = [];
  int _total = 0;
  int _pageNum = 1;
  static const int _pageSize = 10;

  String? _department;
  String? _knowledgeTag;
  int? _difficulty;
  String? _questionType;

  List<String> _departments = [];
  List<String> _knowledgeTags = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final service = StudentService();
    final depts = await service.getQuestionDepartments();
    final tags = await service.getQuestionKnowledgeTags();
    if (!mounted) return;
    setState(() {
      _departments = (depts ?? []).cast<String>();
      _knowledgeTags = (tags ?? []).cast<String>();
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await StudentService().getQuestions(
      pageNum: _pageNum,
      pageSize: _pageSize,
      department: _department,
      knowledgeTag: _knowledgeTag,
      difficulty: _difficulty,
      questionType: _questionType,
    );
    final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    setState(() {
      _list = list;
      _total = total;
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() => _pageNum = 1);
    _load();
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
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '浏览题库', onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                        children: [
                          _buildFilterBar(),
                          const SizedBox(height: 12),
                          _buildResultHeader(),
                          const SizedBox(height: 8),
                          if (_list.isEmpty)
                            _emptyState()
                          else
                            ..._list.asMap().entries.map((e) => _questionTile(e.key, e.value as Map<String, dynamic>)),
                          const SizedBox(height: 14),
                          _buildPagination(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
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
        }, _difficulty == null ? null : (_difficulty == 1 ? '简单' : (_difficulty == 3 ? '困难' : '标准'))),
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
              ...options.map((opt) => _filterChip(opt, current == opt, () => onSelect(opt))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
          border: Border.all(color: selected ? AppColors.primaryOf(context) : AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'JetBrainsMono',
            color: selected ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
          ),
        ),
      ),
    );
  }

  // ---------- 结果头部 ----------
  Widget _buildResultHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '共 $_total 题',
          style: TextStyle(fontSize: 12, color: AppColors.text2Of(context)),
        ),
        GestureDetector(
          onTap: _openPractice,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              '开始作答',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onPrimaryOf(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          SerifText('当前筛选无题目', fontSize: 15, color: AppColors.text2Of(context)),
          const SizedBox(height: 4),
          Text('调整筛选条件后重试', style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
        ],
      ),
    );
  }

  // ---------- 题目卡片 ----------
  Widget _questionTile(int index, Map<String, dynamic> q) {
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final type = q['questionType'] as String? ?? 'single_choice';
    final typeLabel = switch (type) {
      'multiple_choice' => '多选',
      'fill_blank' => '填空',
      'judgment' => '判断',
      _ => '单选',
    };
    final title = q['title'] as String? ?? '';
    final dept = q['department'] as String? ?? '';

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MonoText('${index + 1}.', fontSize: 12, color: AppColors.primaryOf(context)),
                const SizedBox(width: 6),
                if (dept.isNotEmpty) AppChip(label: dept, type: ChipType.moss),
                const SizedBox(width: 6),
                AppChip(label: typeLabel, type: ChipType.indigo),
                const SizedBox(width: 6),
                AppChip(label: difficultyLabel, type: ChipType.amber),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: AppColors.textOf(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 分页 ----------
  Widget _buildPagination() {
    final pages = (_total / _pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pageButton(Icons.chevron_left, _pageNum > 1, () {
          setState(() => _pageNum--);
          _load();
        }),
        const SizedBox(width: 8),
        MonoText('$_pageNum / $pages', fontSize: 12, color: AppColors.text2Of(context)),
        const SizedBox(width: 8),
        _pageButton(Icons.chevron_right, _pageNum < pages, () {
          setState(() => _pageNum++);
          _load();
        }),
      ],
    );
  }

  Widget _pageButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryOf(context) : AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.onPrimaryOf(context) : AppColors.text4Of(context)),
      ),
    );
  }
}
