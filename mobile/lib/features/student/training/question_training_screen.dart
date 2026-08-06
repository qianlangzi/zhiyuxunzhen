import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 基础题训练
class QuestionTrainingScreen extends ConsumerStatefulWidget {
  const QuestionTrainingScreen({super.key});

  @override
  ConsumerState<QuestionTrainingScreen> createState() => _QuestionTrainingScreenState();
}

class _QuestionTrainingScreenState extends ConsumerState<QuestionTrainingScreen> {
  final _filters = ['全部', '胸痛鉴别', '冠心病', '病史采集', '心电图判读', '心力衰竭', '慢阻肺', '高血压'];
  String _selectedFilter = '全部';
  List<Map<String, dynamic>> _questions = [];
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
    final data = await service.getQuestions(
      knowledgeTag: _selectedFilter == '全部' ? null : _selectedFilter,
    );
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _questions = (data?['list'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
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
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _questions.isEmpty
                      ? const Center(child: Text('暂无题目'))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
                          children: _questions
                              .map((q) => _QuestionCard(q: q))
                              .toList(),
                        ),
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
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
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

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final active = _filters[i] == _selectedFilter;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = _filters[i]);
              _isLoading = true;
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceOf(context),
                border: Border.all(
                  color: active
                      ? AppColors.primaryOf(context)
                      : AppColors.ruleOf(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  _filters[i],
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
        },
      ),
    );
  }
}

/// 单题卡片（本地状态：选中项 + 判题结果）
class _QuestionCard extends StatefulWidget {
  final Map<String, dynamic> q;
  const _QuestionCard({required this.q});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  int? _selected;
  bool _submitting = false;
  Map<String, dynamic>? _result;

  List<String> get _options =>
      (widget.q['options'] as List<dynamic>?)?.cast<String>() ?? const [];

  String get _difficultyLabel {
    switch (widget.q['difficulty']) {
      case 1: return '简单';
      case 3: return '困难';
      default: return '标准';
    }
  }

  Future<void> _submit() async {
    if (_selected == null) {
      AppFeedback.info(context, '请先选择一个答案');
      return;
    }
    setState(() => _submitting = true);
    final result = await StudentService().submitQuestion(
      questionId: (widget.q['id'] as num).toInt(),
      selectedAnswer: '$_selected',
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _result != null;
    final isCorrect = _result?['isCorrect'] == true;
    final q = widget.q;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(16),
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
              AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
              const SizedBox(width: 6),
              AppChip(label: _difficultyLabel, type: ChipType.default_),
              const Spacer(),
              MonoText('${q['questionType'] == 'judgment' ? '判断' : '单选'}',
                  fontSize: 10, color: AppColors.text4Of(context)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            q['title'] as String? ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textOf(context),
            ),
          ),
          const SizedBox(height: 12),
          ..._options.asMap().entries.map((e) => _optionTile(e.key, e.value, resolved, isCorrect)),
          const SizedBox(height: 8),
          if (resolved) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.mossTintOf(context)
                    : AppColors.vermilionSoftOf(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isCorrect ? AppColors.primary : AppColors.vermilion,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCorrect ? '回答正确' : '回答错误',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCorrect ? AppColors.primary : AppColors.vermilion,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _result?['explanation'] as String? ?? '',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.text2Of(context)),
                  ),
                ],
              ),
            ),
          ] else
            AppPrimaryButton(
              label: _submitting ? '判题中…' : '提交答案',
              fullWidth: true,
              onPressed: _submitting ? null : _submit,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: resolved ? null : () => setState(() => _selected = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13.5, color: fg),
                ),
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