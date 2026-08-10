import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 基础题作答页（按筛选条件逐题作答）
///
/// 支持单选 / 多选 / 填空，传入 department/knowledgeTag/difficulty/questionType 组合筛选。
/// 通过分页逐题加载（pageSize=1），提交后显示解析，点击“下一题”继续。
class QuestionPracticeScreen extends ConsumerStatefulWidget {
  const QuestionPracticeScreen({
    super.key,
    this.title = '基础题训练',
    this.department,
    this.knowledgeTag,
    this.difficulty,
    this.questionType,
  });

  final String title;
  final String? department;
  final String? knowledgeTag;
  final int? difficulty;
  final String? questionType;

  @override
  ConsumerState<QuestionPracticeScreen> createState() => _QuestionPracticeScreenState();
}

class _QuestionPracticeScreenState extends ConsumerState<QuestionPracticeScreen> {
  int _pageNum = 1;
  bool _isLoading = true;
  bool _hasMore = true;
  Map<String, dynamic>? _current;
  int? _selected;
  Set<int> _multiSelected = {};
  final TextEditingController _blankCtl = TextEditingController();
  Map<String, dynamic>? _result;
  bool _submitting = false;
  int _currentIndex = 0;

  @override
  void dispose() {
    _blankCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestion());
  }

  String get _questionType => (_current?['questionType'] as String?) ?? 'single_choice';
  bool get _isMulti => _questionType == 'multiple_choice';
  bool get _isBlank => _questionType == 'fill_blank';

  Future<void> _loadQuestion() async {
    setState(() {
      _isLoading = true;
      _selected = null;
      _multiSelected = {};
      _blankCtl.clear();
      _result = null;
    });
    final data = await StudentService().getQuestions(
      pageNum: _pageNum,
      pageSize: 1,
      department: widget.department,
      knowledgeTag: widget.knowledgeTag,
      difficulty: widget.difficulty,
      questionType: widget.questionType,
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
    if (_isBlank) {
      if (_blankCtl.text.trim().isEmpty) {
        AppFeedback.info(context, '请先填写答案');
        return;
      }
    } else if (_isMulti) {
      if (_multiSelected.isEmpty) {
        AppFeedback.info(context, '请至少选择一个答案');
        return;
      }
    } else if (_selected == null) {
      AppFeedback.info(context, '请先选择一个答案');
      return;
    }

    final String answer;
    if (_isMulti) {
      final list = _multiSelected.toList()..sort();
      answer = list.join(',');
    } else if (_isBlank) {
      answer = _blankCtl.text.trim();
    } else {
      answer = '$_selected';
    }

    setState(() => _submitting = true);
    final result = await StudentService().submitQuestion(
      questionId: ((_current?['id'] as num?) ?? 0).toInt(),
      selectedAnswer: answer,
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
            AppBackAppBar(title: widget.title, onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _current == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              SerifText('当前筛选下暂无题目', fontSize: 15, color: AppColors.text2Of(context)),
                              const SizedBox(height: 4),
                              Text('可调整筛选条件后重试',
                                  style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
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
    final typeLabel = _isMulti ? '多选' : (_isBlank ? '填空' : (q['questionType'] == 'judgment' ? '判断' : '单选'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Row(
          children: [
            AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
            const SizedBox(width: 6),
            AppChip(label: typeLabel, type: ChipType.indigo),
            const SizedBox(width: 6),
            AppChip(label: difficultyLabel, type: ChipType.amber),
            const Spacer(),
            MonoText('第 ${_currentIndex + 1} 题', fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          q['title'] as String? ?? '',
          style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textOf(context)),
        ),
        const SizedBox(height: 18),
        if (_isMulti)
          ...options.asMap().entries.map((e) => _multiOptionTile(e.key, e.value, resolved, isCorrect))
        else if (_isBlank)
          _blankField(resolved, isCorrect)
        else
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
              label: '已完成练习',
              fullWidth: true,
              onPressed: () => Navigator.of(context).maybePop(),
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

  Widget _multiOptionTile(int idx, String text, bool resolved, bool isCorrect) {
    final correctAnswer = _result?['correctAnswer'] as String? ?? '';
    final correctSet = correctAnswer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final isSelected = _multiSelected.contains(idx);
    final isCorrectOption = resolved && correctSet.contains('$idx');

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
        onTap: resolved
            ? null
            : () => setState(() {
                  if (_multiSelected.contains(idx)) {
                    _multiSelected.remove(idx);
                  } else {
                    _multiSelected.add(idx);
                  }
                }),
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
                  borderRadius: BorderRadius.circular(4),
                ),
                child: (isSelected || isCorrectOption)
                    ? Center(child: Icon(Icons.check, size: 13, color: isCorrectOption ? AppColors.primary : border))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: fg))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blankField(bool resolved, bool isCorrect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(
              color: resolved ? (isCorrect ? AppColors.primary : AppColors.vermilion) : AppColors.surfaceEdgeOf(context),
              width: resolved ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: TextField(
            controller: _blankCtl,
            enabled: !resolved,
            style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
            decoration: InputDecoration(
              hintText: '请输入答案',
              hintStyle: TextStyle(fontSize: 14, color: AppColors.text4Of(context)),
              border: InputBorder.none,
            ),
          ),
        ),
        if (resolved) ...[
          const SizedBox(height: 8),
          Text('你的答案：${_result?['selectedAnswer'] ?? ''}',
              style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
        ],
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
              Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 18, color: isCorrect ? AppColors.primary : AppColors.vermilion),
              const SizedBox(width: 6),
              Text(isCorrect ? '回答正确' : '回答错误',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isCorrect ? AppColors.primary : AppColors.vermilion)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '正确答案：${_formatCorrectAnswer(_result?['correctAnswer'] ?? '')}',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textOf(context)),
          ),
          const SizedBox(height: 6),
          Text(_result?['explanation'] as String? ?? '',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context))),
        ],
      ),
    );
  }

  String _formatCorrectAnswer(String raw) {
    if (!_isMulti) return raw;
    final options = (_current?['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final indices = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (options.isEmpty) return raw;
    return indices.map((i) {
      final idx = int.tryParse(i);
      if (idx == null || idx < 0 || idx >= options.length) return i;
      return '$i.${options[idx]}';
    }).join('、');
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
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: fg))),
              if (resolved && isCorrectOption)
                const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
