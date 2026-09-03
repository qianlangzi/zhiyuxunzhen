import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 题型枚举
enum QuestionType {
  singleChoice('single_choice', '单选题'),
  multipleChoice('multiple_choice', '多选题'),
  judgment('judgment', '判断题'),
  fillBlank('fill_blank', '填空题'),
  essay('essay', '简答/论述');

  const QuestionType(this.code, this.label);
  final String code;
  final String label;

  static QuestionType fromCode(String? code) {
    switch (code) {
      case 'single_choice':
        return singleChoice;
      case 'multiple_choice':
        return multipleChoice;
      case 'judgment':
        return judgment;
      case 'fill_blank':
        return fillBlank;
      case 'essay':
      default:
        return essay;
    }
  }

  /// 是否需要选项编辑器（单选/多选才有选项行）
  bool get needOptions =>
      this == singleChoice || this == multipleChoice;
}

/// 教师端 · 题目录入 / 编辑（保存草稿 + 提交审核）
class QuestionEditScreen extends ConsumerStatefulWidget {
  const QuestionEditScreen({super.key, required this.id});

  /// 题目 ID；'new' 表示新增
  final String id;

  @override
  ConsumerState<QuestionEditScreen> createState() => _QuestionEditScreenState();
}

class _QuestionEditScreenState extends ConsumerState<QuestionEditScreen> {
  late final bool _isNew = widget.id == 'new';
  int? _questionId;

  QuestionType _questionType = QuestionType.singleChoice;
  int _difficultyIndex = 0; // 0=简单/1=标准/2=困难 -> difficulty 1/2/3

  final _departmentCtl = TextEditingController();
  final _knowledgeTagCtl = TextEditingController();
  final _titleCtl = TextEditingController();
  final _answerCtl = TextEditingController();
  final _explanationCtl = TextEditingController();

  // 选项行编辑器（单选/多选使用）
  final List<TextEditingController> _options = [];

  int? _sourceTextbookId;
  String? _sourceTextbookTitle;

  // 审核状态
  int _auditStatus = 0; // 0未提交/1待审核/2通过/3驳回
  bool _isLoading = true;
  bool _saving = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _options.addAll([
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ]);
    if (!_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _departmentCtl.dispose();
    _knowledgeTagCtl.dispose();
    _titleCtl.dispose();
    _answerCtl.dispose();
    _explanationCtl.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final id = int.tryParse(widget.id);
    if (id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final item = await TeacherService().getQuestionDetail(id);
    if (!mounted) return;
    if (item == null) {
      AppFeedback.error(context, '题目加载失败');
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _questionId = id;
      _auditStatus = (item['adminAuditStatus'] as num?)?.toInt() ?? 0;
      _questionType = QuestionType.fromCode(item['questionType'] as String?);
      _departmentCtl.text = item['department'] as String? ?? '';
      _knowledgeTagCtl.text = item['knowledgeTag'] as String? ?? '';
      _titleCtl.text = item['title'] as String? ?? '';
      _answerCtl.text = item['answer'] as String? ?? '';
      _explanationCtl.text = item['explanation'] as String? ?? '';
      _sourceTextbookId = (item['sourceTextbookId'] as num?)?.toInt();
      _sourceTextbookTitle = item['sourceTextbookTitle'] as String?;
      _rejectReason = item['rejectReason'] as String?;
      final diff = (item['difficulty'] as num?)?.toInt() ?? 1;
      _difficultyIndex = (diff - 1).clamp(0, 2);
      final opts = (item['options'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [];
      // 选项多于当前行数时补充控制器，避免回显时丢选项
      while (_options.length < (opts.isEmpty ? 2 : opts.length)) {
        _options.add(TextEditingController());
      }
      for (var i = 0; i < _options.length; i++) {
        _options[i].text = i < opts.length ? opts[i] : '';
      }
      _isLoading = false;
    });
  }

  bool get _readOnly => _auditStatus == 1 || _auditStatus == 2;

  String? _validate() {
    if (_titleCtl.text.trim().isEmpty) return '请填写题干';
    if (_departmentCtl.text.trim().isEmpty) return '请填写科室';
    if (_questionType.needOptions) {
      final filled = _options.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      if (filled.length < 2) return '选择题至少需要 2 个选项';
    }
    if (_answerCtl.text.trim().isEmpty) return '请填写标准答案';
    return null;
  }

  Map<String, dynamic> _buildPayload() {
    final options = _questionType.needOptions
        ? _options.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return {
      'questionType': _questionType.code,
      'department': _departmentCtl.text.trim(),
      'knowledgeTag': _knowledgeTagCtl.text.trim(),
      'title': _titleCtl.text.trim(),
      'options': options,
      'answer': _answerCtl.text.trim(),
      'explanation': _explanationCtl.text.trim(),
      'difficulty': _difficultyIndex + 1,
      if (_sourceTextbookId != null) 'sourceTextbookId': _sourceTextbookId,
    };
  }

  /// 保存为草稿（新增走 create，已有走 update），返回题目 ID；失败返回 null
  Future<int?> _saveDraft() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return null;
    }
    setState(() => _saving = true);
    final payload = _buildPayload();
    int? id = _questionId;
    if (id == null) {
      id = await TeacherService().createQuestion(payload);
      if (id != null) _questionId = id;
    } else {
      final ok = await TeacherService().updateQuestion(id, payload);
      if (!ok) id = null;
    }
    if (!mounted) return null;
    setState(() {
      _saving = false;
      // 已驳回题目修改保存后重置为未提交草稿，可重新提交
      if (id != null && _auditStatus == 3) _auditStatus = 0;
    });
    return id;
  }

  Future<void> _saveAndNotify() async {
    final id = await _saveDraft();
    if (!mounted) return;
    if (id == null) {
      AppFeedback.error(context, '保存失败，请稍后重试');
      return;
    }
    if (_auditStatus == 3) {
      AppFeedback.success(context, '已保存并重置为草稿，可重新提交审核');
    } else {
      AppFeedback.success(context, '草稿已保存');
    }
  }

  Future<void> _submit() async {
    final id = await _saveDraft();
    if (!mounted) return;
    if (id == null) return;
    setState(() => _submitting = true);
    final ok = await TeacherService().submitQuestion(id);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) _auditStatus = 1;
    });
    if (ok) {
      AppFeedback.success(context, '已提交审核，请等待管理员审核');
      context.pop();
    } else {
      AppFeedback.error(context, '提交审核失败，请稍后重试');
    }
  }

  // ===== UI 辅助 =====

  InputDecoration _inputDec({String? hintText}) => InputDecoration(
        filled: true,
        fillColor: AppColors.bgOf(context),
        hintText: hintText,
        hintStyle: hintText == null
            ? null
            : TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
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
          borderSide: BorderSide(color: AppColors.primaryOf(context)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.ruleSoftOf(context)),
        ),
      );

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText(label.toUpperCase(), fontSize: 11, color: AppColors.text2Of(context), letterSpacing: 0.04),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _buildFormSection(String no, String title, {required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MonoText(no, fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.08),
              const SizedBox(width: 8),
              SerifText(title, fontSize: 15),
              const Spacer(),
              if (_readOnly)
                AppChip(label: '只读', type: ChipType.amber, fontSize: 10),
            ],
          ),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  void _addOption() {
    if (_options.length >= 8) {
      AppFeedback.info(context, '选项最多 8 个');
      return;
    }
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      AppFeedback.info(context, '至少保留 2 个选项');
      return;
    }
    setState(() {
      _options[index].dispose();
      _options.removeAt(index);
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
              title: _isNew ? '录入题目' : '编辑题目',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherQuestions),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBanner(context),
                          if (_readOnly) _buildReadOnlyHint(context),
                          _buildBasicInfo(),
                          _buildOptionsSection(),
                          _buildAnswerSection(),
                          if (!_readOnly) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppGhostButton(
                                    label: _saving ? '保存中…' : '保存为草稿',
                                    fullWidth: true,
                                    onPressed: _saving || _submitting ? null : _saveAndNotify,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppGradientButton(
                                    label: _submitting ? '提交中…' : '提交审核',
                                    color: AppColors.primaryOf(context),
                                    height: 44,
                                    loading: _submitting,
                                    onPressed: _saving || _submitting ? null : _submit,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MonoText(
                              '保存为草稿后，可点击「提交审核」送管理员审核。',
                              fontSize: 10,
                              color: AppColors.text4Of(context),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 审核状态 / 驳回原因提示条
  Widget _buildStatusBanner(BuildContext context) {
    if (_isNew) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.mossTintOf(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: AppColors.primaryOf(context)),
            const SizedBox(width: 8),
            Expanded(
              child: MonoText(
                '录入题目后可保存为草稿，或直接提交审核。',
                fontSize: 11,
                color: AppColors.primaryOf(context),
              ),
            ),
          ],
        ),
      );
    }

    switch (_auditStatus) {
      case 3:
        final reason = _rejectReason;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.vermilionSoftOf(context),
            border: Border.all(color: AppColors.vermilionOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: AppColors.vermilionOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: MonoText(
                  '审核未通过：${reason ?? '无驳回原因'}。修改保存后将重置为草稿，可重新提交。',
                  fontSize: 11,
                  color: AppColors.vermilionOf(context),
                ),
              ),
            ],
          ),
        );
      case 1:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.amberSoftOf(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.hourglass_top, size: 14, color: AppColors.amberOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: MonoText('待审核中，暂不可编辑', fontSize: 11, color: AppColors.amberOf(context)),
              ),
            ],
          ),
        );
      case 2:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.mossTintOf(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: AppColors.primaryOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: MonoText('审核已通过，暂不可编辑', fontSize: 11, color: AppColors.primaryOf(context)),
              ),
            ],
          ),
        );
      default:
        // 未提交草稿
        if (_questionId != null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mossTintOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 14, color: AppColors.primaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: MonoText('草稿 · 题目 #$_questionId · 可编辑', fontSize: 11, color: AppColors.primaryOf(context)),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  String? _rejectReason;

  Widget _buildReadOnlyHint(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.indigoSoftOf(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.indigoOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: MonoText('该题目已提交审核/已通过，以下内容为只读查看。', fontSize: 11, color: AppColors.indigoOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: QuestionType.values.map((t) {
        final active = t == _questionType;
        return Expanded(
          child: GestureDetector(
            onTap: _readOnly ? null : () => setState(() => _questionType = t),
            child: Container(
              margin: EdgeInsets.only(right: t != QuestionType.values.last ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                border: Border.all(color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: MonoText(
                  t.label,
                  fontSize: 11,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifficultySelector() {
    const labels = ['简单', '标准', '困难'];
    return Row(
      children: List.generate(3, (i) {
        final active = i == _difficultyIndex;
        return Expanded(
          child: GestureDetector(
            onTap: _readOnly ? null : () => setState(() => _difficultyIndex = i),
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                border: Border.all(color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: MonoText(
                  labels[i],
                  fontSize: 12,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBasicInfo() {
    return _buildFormSection('01', '基础信息', children: [
      _field('题型 *', _buildTypeSelector()),
      const SizedBox(height: 10),
      _field('科室 *', TextField(
        decoration: _inputDec(hintText: '如：心血管内科'),
        enabled: !_readOnly,
        controller: _departmentCtl,
      )),
      const SizedBox(height: 10),
      _field('知识点', TextField(
        decoration: _inputDec(hintText: '如：冠心病'),
        enabled: !_readOnly,
        controller: _knowledgeTagCtl,
      )),
      const SizedBox(height: 10),
      _field('题干 *', TextField(
        decoration: _inputDec(hintText: '请输入题目内容'),
        maxLines: 4,
        enabled: !_readOnly,
        controller: _titleCtl,
      )),
      if (_sourceTextbookId != null) ...[
        const SizedBox(height: 10),
        _field('关联教材', MonoText(
          _sourceTextbookTitle ?? '教材 #$_sourceTextbookId',
          fontSize: 12,
          color: AppColors.text3Of(context),
        )),
      ],
    ]);
  }

  Widget _buildOptionsSection() {
    return _buildFormSection('02', '选项', children: [
      if (!_questionType.needOptions)
        MonoText('当前题型无需选项（判断 / 填空 / 简答论述）。', fontSize: 11, color: AppColors.text4Of(context))
      else ...[
        ..._options.asMap().entries.map((entry) {
          final i = entry.key;
          final ctl = entry.value;
          final letters = 'ABCDEFGH';
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(
              color: AppColors.bgOf(context),
              border: Border.all(color: AppColors.ruleSoftOf(context)),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                MonoText(letters[i], fontSize: 13, color: AppColors.primaryOf(context), weight: FontWeight.w600),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: ctl,
                    enabled: !_readOnly,
                    style: TextStyle(color: AppColors.textOf(context), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '选项内容',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (!_readOnly)
                  GestureDetector(
                    onTap: () => _removeOption(i),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 15, color: AppColors.text4Of(context)),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (!_readOnly) ...[
          const SizedBox(height: 8),
          AppGhostButton(
            label: '+ 添加选项',
            fullWidth: true,
            small: true,
            dashed: true,
            onPressed: _addOption,
          ),
        ],
      ],
    ]);
  }

  Widget _buildAnswerSection() {
    return _buildFormSection('03', '答案与解析', children: [
      _field(
        _questionType == QuestionType.singleChoice ||
                _questionType == QuestionType.multipleChoice
            ? '标准答案 *（如：ABC）'
            : _questionType == QuestionType.judgment
                ? '标准答案 *（如：对 / 错）'
                : _questionType == QuestionType.essay
                    ? '参考答案 *（供 AI 批阅参考）'
                    : '标准答案 *',
        TextField(
          decoration: _inputDec(
            hintText: _questionType == QuestionType.judgment
                ? '对 / 错'
                : _questionType == QuestionType.essay
                    ? '填写参考答案要点，供 AI 批阅参考…'
                    : '如：A / AB',
          ),
          maxLines: _questionType == QuestionType.essay ? 4 : 1,
          enabled: !_readOnly,
          controller: _answerCtl,
        ),
      ),
      const SizedBox(height: 10),
      _field('答案解析', TextField(
        decoration: _inputDec(hintText: '填写解题思路或要点（可选）'),
        maxLines: 4,
        enabled: !_readOnly,
        controller: _explanationCtl,
      )),
      const SizedBox(height: 10),
      _field('难度 *', _buildDifficultySelector()),
    ]);
  }
}