import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 基础题训练（大型题库 · 按科室模块 · 单题模式）
///
/// 流程：选择科室 → 每页只展示一道题 → 提交后显示正确答案与解析 → 点击“下一题”继续。
class QuestionTrainingScreen extends ConsumerStatefulWidget {
  const QuestionTrainingScreen({super.key});

  @override
  ConsumerState<QuestionTrainingScreen> createState() => _QuestionTrainingScreenState();
}

class _QuestionTrainingScreenState extends ConsumerState<QuestionTrainingScreen> {
  List<String> _departments = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final service = StudentService();
    final stats = await service.getQuestionStats();
    final depts = await service.getQuestionDepartments();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _departments = (depts ?? []).cast<String>();
      if (_departments.isEmpty) {
        _departments = const ['心血管内科', '呼吸内科', '诊断学', '综合'];
      }
      _isLoading = false;
    });
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
              title: '基础题训练',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
            ),
            _buildStats(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDepartmentGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final totalAnswered = (_stats?['totalAnswered'] as num?)?.toInt() ?? 0;
    final correctCount = (_stats?['correctCount'] as num?)?.toInt() ?? 0;
    final accuracy = (_stats?['accuracy'] as num?)?.toDouble() ?? 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _statCell(accuracy.toStringAsFixed(1), '正确率', AppColors.onPrimaryOf(context)),
          _divider(),
          _statCell('$totalAnswered', '已做', AppColors.onPrimaryOf(context)),
          _divider(),
          _statCell('$correctCount', '答对', AppColors.onPrimaryOf(context)),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          MonoText(label, fontSize: 10, color: AppColors.onPrimarySoftOf(context)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.onPrimaryOf(context).withValues(alpha: 0.2),
    );
  }

  /// 科室模块选择入口
  Widget _buildDepartmentGrid() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        SerifText('选择科室模块', fontSize: 15, color: AppColors.text2Of(context)),
        const SizedBox(height: 4),
        Text(
          '涵盖多个科室，按基础 → 标准 → 困难进阶',
          style: TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: _departments.length,
          itemBuilder: (context, i) {
            final dept = _departments[i];
            return _DepartmentTile(
              name: dept,
              onTap: () => _openPractice(dept),
            );
          },
        ),
        const SizedBox(height: 20),
        AppGhostButton(
          label: '开始刷题',
          fullWidth: true,
          icon: const Icon(Icons.arrow_forward, size: 16),
          onPressed: () {
            if (_departments.isEmpty) return;
            _openPractice(_departments.first);
          },
        ),
      ],
    );
  }

  void _openPractice(String department) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SingleQuestionPracticeScreen(department: department),
      ),
    );
  }
}

/// 科室入口卡片
class _DepartmentTile extends StatelessWidget {
  const _DepartmentTile({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.mossTintOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: const Icon(Icons.local_hospital, size: 18, color: AppColors.primary),
                ),
              ],
            ),
            SerifText(name, fontSize: 14, color: AppColors.textOf(context)),
            MonoText('开始刷题 →', fontSize: 10, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }
}

/// 单题刷题页（每页一题，提交后显示解析，点击下一题）
class _SingleQuestionPracticeScreen extends ConsumerStatefulWidget {
  const _SingleQuestionPracticeScreen({required this.department});
  final String department;

  @override
  ConsumerState<_SingleQuestionPracticeScreen> createState() => _SingleQuestionPracticeScreenState();
}

class _SingleQuestionPracticeScreenState extends ConsumerState<_SingleQuestionPracticeScreen> {
  int _pageNum = 1;
  bool _isLoading = true;
  bool _hasMore = true;
  Map<String, dynamic>? _current;
  int? _selected;
  Map<String, dynamic>? _result;
  bool _submitting = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestion());
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _isLoading = true;
      _selected = null;
      _result = null;
    });
    final data = await StudentService().getQuestionsByDepartment(
      pageNum: _pageNum,
      pageSize: 1,
      department: widget.department,
    );
    final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    setState(() {
      _current = list.isNotEmpty ? list.first : null;
      _hasMore = _pageNum < total;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_selected == null) {
      AppFeedback.info(context, '请先选择一个答案');
      return;
    }
    setState(() => _submitting = true);
    final result = await StudentService().submitQuestion(
      questionId: ((_current?['id'] as num?) ?? 0).toInt(),
      selectedAnswer: '$_selected',
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _submitting = false;
    });
  }

  void _next() {
    setState(() {
      _pageNum++;
      _currentIndex++;
    });
    _loadQuestion();
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
              title: widget.department,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _current == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              SerifText('本模块暂无题目', fontSize: 15,
                                  color: AppColors.text2Of(context)),
                              const SizedBox(height: 4),
                              Text('老师正在补充题库，敬请期待',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.text4Of(context))),
                            ],
                          ),
                        )
                      : _buildQuestion(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _current!;
    final resolved = _result != null;
    final isCorrect = _result?['isCorrect'] == true;
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        // 进度 + 难度
        Row(
          children: [
            AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
            const SizedBox(width: 6),
            AppChip(label: difficultyLabel, type: ChipType.amber),
            const Spacer(),
            MonoText('第 ${_currentIndex + 1} 题', fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          q['title'] as String? ?? '',
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
          ),
        ),
        const SizedBox(height: 18),
        ...options.asMap().entries.map((e) => _optionTile(e.key, e.value, resolved, isCorrect)),
        const SizedBox(height: 14),
        if (resolved) ...[
          _answerPanel(isCorrect),
          const SizedBox(height: 14),
          if (_hasMore)
            AppPrimaryButton(
              label: _submitting ? '加载中…' : '下一题',
              fullWidth: true,
              icon: const Icon(Icons.arrow_forward, size: 16),
              onPressed: _next,
            )
          else
            AppGhostButton(
              label: '已完成本模块',
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
        ] else
          AppPrimaryButton(
            label: _submitting ? '判题中…' : '提交答案',
            fullWidth: true,
            onPressed: _submitting ? null : _submit,
          ),
      ],
    );
  }

  Widget _answerPanel(bool isCorrect) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.mossTintOf(context) : AppColors.vermilionSoftOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: isCorrect ? AppColors.primary : AppColors.vermilion,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect ? '回答正确' : '回答错误',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? AppColors.primary : AppColors.vermilion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '正确答案：${_result?['correctAnswer'] ?? ''}',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textOf(context)),
          ),
          const SizedBox(height: 6),
          Text(
            _result?['explanation'] as String? ?? '',
            style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context)),
          ),
        ],
      ),
    );
  }

  Widget _optionTile(int idx, String text, bool resolved, bool isCorrect) {
    final correctAnswer = _result?['correctAnswer'] as String?;
    final isSelected = _selected == idx;
    final isCorrectOption = resolved && correctAnswer == '$idx';
    Color bg = AppColors.surfaceOf(context);
    Color border = AppColors.surfaceEdgeOf(context);
    Color fg = AppColors.textOf(context);

    if (resolved) {
      if (isCorrectOption) {
        bg = AppColors.mossTintOf(context);
        border = AppColors.primary;
        fg = AppColors.primary;
      } else if (isSelected) {
        bg = AppColors.vermilionSoftOf(context);
        border = AppColors.vermilion;
        fg = AppColors.vermilion;
      }
    } else if (isSelected) {
      bg = AppColors.mossTintOf(context);
      border = AppColors.primaryOf(context);
      fg = AppColors.primaryOf(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: resolved ? null : () => setState(() => _selected = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isSelected || resolved ? 1.5 : 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: isSelected || isCorrectOption ? border : AppColors.ruleOf(context), width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: (isSelected || isCorrectOption)
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isCorrectOption ? AppColors.primary : border,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 14, color: fg)),
              ),
              if (resolved && isCorrectOption)
                const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}