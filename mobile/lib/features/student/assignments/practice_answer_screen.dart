import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';

/// 基础练习作答页（组合任务包）
///
/// 客观题在线作答，交卷后后端自动判分，展示对错明细与得分。
class PracticeAnswerScreen extends ConsumerStatefulWidget {
  const PracticeAnswerScreen({
    super.key,
    required this.instanceId,
    required this.itemProgressId,
    required this.questions,
    required this.title,
  });

  final int instanceId;
  final int itemProgressId;
  final List<Map<String, dynamic>> questions;
  final String title;

  @override
  ConsumerState<PracticeAnswerScreen> createState() =>
      _PracticeAnswerScreenState();
}

class _PracticeAnswerScreenState extends ConsumerState<PracticeAnswerScreen> {
  final Map<int, String> _answers = {}; // questionId -> 答案
  final Map<int, TextEditingController> _fillCtrls = {}; // questionId -> 输入框控制器
  Map<int, bool>? _result; // 交卷后判分明细
  double? _score;
  int? _correct;
  int _total = 0;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _total = widget.questions.length;
  }

  @override
  void dispose() {
    for (final c in _fillCtrls.values) {
      c.dispose();
    }
    _fillCtrls.clear();
    super.dispose();
  }

  /// 已作答题目数（按非空答案计）
  int get _answeredCount => _answers.values.where((v) => v.trim().isNotEmpty).length;

  Future<void> _submit() async {
    // 校验所有题已答
    final unanswered = widget.questions.where((q) {
      final id = (q['id'] as num?)?.toInt() ?? 0;
      final v = _answers[id]?.trim() ?? '';
      return v.isEmpty;
    }).toList();
    if (unanswered.isNotEmpty) {
      AppFeedback.info(context, '还有 ${unanswered.length} 题未作答');
      return;
    }
    setState(() => _submitting = true);
    final result = await StudentService().submitPractice(
      instanceId: widget.instanceId,
      itemProgressId: widget.itemProgressId,
      answers: _answers,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      AppFeedback.error(context, '交卷失败，请重试');
      return;
    }
    final resultMap = result['result'] as Map<String, dynamic>? ?? {};
    final parsed = <int, bool>{};
    for (final entry in resultMap.entries) {
      final qid = int.tryParse(entry.key);
      if (qid == null) continue;
      final v = entry.value;
      parsed[qid] = v == true || v == 'true' || v == 1;
    }
    setState(() {
      _submitted = true;
      _score = (result['score'] as num?)?.toDouble();
      _correct = (result['correct'] as num?)?.toInt();
      _result = parsed;
    });
    AppFeedback.success(
        context, _hasEssay ? '交卷成功 · 客观题已自动判分，主观题待教师批阅' : '交卷成功');
  }

  String _qTypeLabel(String type) {
    return switch (type) {
      'single_choice' => '单选题',
      'multiple_choice' => '多选题',
      'judgment' => '判断题',
      'fill_blank' => '填空题',
      'essay' || 'short_answer' || 'subjective' => '简答/论述',
      _ => type,
    };
  }

  /// 是否为主观题（简答/论述），交卷后交教师复核，不自动判分
  bool _isEssayType(String? type) {
    return type == 'essay' || type == 'short_answer' || type == 'subjective';
  }

  bool get _hasEssay =>
      widget.questions.any((q) => _isEssayType(q['questionType'] as String?));

  List<String> _parseOptions(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => '$e').toList();
    } catch (_) {
      return [];
    }
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
              title: widget.title.isEmpty ? '基础练习' : widget.title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  ...widget.questions.asMap().entries.map(
                      (e) => _buildQuestionCard(e.key, e.value)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(top: BorderSide(color: AppColors.ruleSoftOf(context))),
          ),
          child: _submitted
              ? Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.mossTintOf(context),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                size: 16, color: AppColors.primaryOf(context)),
                            const SizedBox(width: 6),
                            Text(
                              _hasEssay
                                  ? '客观题得分 ${_score?.toStringAsFixed(1) ?? '-'} · 答对 $_correct/$_total · 主观题待教师批阅'
                                  : '得分 ${_score?.toStringAsFixed(1) ?? '-'} · 答对 $_correct/$_total',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppPrimaryButton(
                      label: '完成',
                      onPressed: () => context.pop(),
                    ),
                  ],
                )
              : AppPrimaryButton(
                  label: _submitting ? '判分中…' : '交卷（已答 $_answeredCount/$_total）',
                  fullWidth: true,
                  icon: const Icon(Icons.send_rounded, size: 15),
                  onPressed: _submitting ? null : _submit,
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final answered = _answeredCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.quiz_outlined, size: 18, color: AppColors.indigoOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: MonoText(
              _hasEssay
                  ? '共 $_total 题 · 已答 $answered · 客观题自动判分，主观题由教师批阅'
                  : '共 $_total 题 · 已答 $answered · 交卷后自动判分',
              fontSize: 11,
              color: AppColors.text2Of(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> q) {
    final id = (q['id'] as num?)?.toInt() ?? 0;
    final type = q['questionType'] as String? ?? 'single_choice';
    final title = q['title'] as String? ?? '';
    final options = _parseOptions(q['optionsJson']);
    final answered = (_answers[id]?.trim() ?? '').isNotEmpty;
    final correct = _result?[id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _submitted
              ? (correct == true
                  ? AppColors.primaryOf(context).withValues(alpha: 0.5)
                  : (correct == false
                      ? AppColors.vermilionOf(context).withValues(alpha: 0.5)
                      : AppColors.surfaceEdgeOf(context)))
              : AppColors.surfaceEdgeOf(context),
          width: _submitted && correct != null ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: answered || correct != null
                      ? AppColors.indigoSoftOf(context)
                      : AppColors.ruleSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: answered || correct != null
                        ? AppColors.indigoOf(context)
                        : AppColors.text3Of(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: AppColors.textOf(context),
                            ),
                          ),
                        ),
                        if (_submitted && correct != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 17,
                            color: correct ? AppColors.primaryOf(context) : AppColors.vermilionOf(context),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    MonoText(_qTypeLabel(type), fontSize: 10,
                        color: AppColors.text4Of(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isEssayType(type))
            _buildEssayInput(id, q, _submitted)
          else if (type == 'fill_blank')
            _buildFillBlank(id, q, _submitted)
          else
            _buildOptions(type, options, id),
        ],
      ),
    );
  }

  Widget _buildOptions(String type, List<String> options, int qid) {
    if (type == 'judgment') {
      options = ['对', '错'];
    }
    final multi = type == 'multiple_choice';
    return Column(
      children: options.asMap().entries.map((e) {
        final key = _optionKey(e.key);
        final text = e.value;
        final selected = _optionSelected(qid, key, multi);
        return GestureDetector(
          onTap: _submitted
              ? null
              : () => _toggleOption(qid, key, multi),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.indigoSoftOf(context) : AppColors.bgOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? AppColors.indigoOf(context) : AppColors.ruleOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  multi
                      ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                      : (selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded),
                  size: 18,
                  color: selected ? AppColors.indigoOf(context) : AppColors.text4Of(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFillBlank(int qid, Map<String, dynamic> q, bool submitted) {
    final initial = _answers[qid] ?? '';
    return TextField(
      enabled: !submitted,
      controller: _controllerOf(qid, initial),
      style: TextStyle(fontSize: 13, color: AppColors.textOf(context)),
      decoration: InputDecoration(
        hintText: '请输入答案…',
        filled: true,
        fillColor: AppColors.bgOf(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.ruleOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.ruleOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.indigoOf(context), width: 1.2),
        ),
      ),
      onChanged: (v) => _answers[qid] = v.trim(),
    );
  }

  Widget _buildEssayInput(int qid, Map<String, dynamic> q, bool submitted) {
    final initial = _answers[qid] ?? '';
    return TextField(
      enabled: !submitted,
      controller: _controllerOf(qid, initial),
      maxLines: 6,
      minLines: 4,
      style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textOf(context)),
      decoration: InputDecoration(
        hintText: _submitted
            ? '已交卷，待教师批阅'
            : '请输入作答内容…交卷后由教师批阅',
        hintStyle: TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
        filled: true,
        fillColor: _submitted ? AppColors.ruleSoftOf(context) : AppColors.bgOf(context),
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.ruleOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.ruleOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.indigoOf(context), width: 1.2),
        ),
      ),
      onChanged: (v) => _answers[qid] = v,
    );
  }

  /// 按题目 ID 复用输入框控制器
  ///
  /// 此前在 build 内直接 new TextEditingController，每次 setState 都重建，
  /// 导致输入时光标跳到末尾、输入法组词被打断，且控制器从不释放。
  TextEditingController _controllerOf(int qid, String initial) {
    final exist = _fillCtrls[qid];
    if (exist != null) return exist;
    final c = TextEditingController(text: initial);
    _fillCtrls[qid] = c;
    return c;
  }

  String _optionKey(int index) {
    return String.fromCharCode(65 + index); // A B C D ...
  }

  bool _optionSelected(int qid, String key, bool multi) {
    final v = _answers[qid] ?? '';
    if (multi) {
      return v.split(',').contains(key);
    }
    return v == key;
  }

  void _toggleOption(int qid, String key, bool multi) {
    setState(() {
      if (multi) {
        final parts = (_answers[qid] ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.contains(key)) {
          parts.remove(key);
        } else {
          parts.add(key);
        }
        // 按选项字母排序，保证与后端标准答案的字符串比对一致。
        // 此前按点击顺序拼接（选 B 再选 A 得到 "B,A"），会被判错。
        parts.sort();
        _answers[qid] = parts.join(',');
      } else {
        _answers[qid] = key;
      }
    });
  }
}
