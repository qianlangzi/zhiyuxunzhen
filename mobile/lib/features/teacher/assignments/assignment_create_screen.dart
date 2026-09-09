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

/// 新建作业（组合任务包向导）
///
/// 作业 = 任务包，支持三类任务项：
/// - CASE     病例问诊（我的病例库 / 病例广场已过审）
/// - PRACTICE 基础练习（我的题库多选组卷）
/// - READING  阅读任务（教材 + 阅读范围）
/// 选定班级后一键发放，无需管理员审核，学生即时收到。
class AssignmentCreateScreen extends ConsumerStatefulWidget {
  const AssignmentCreateScreen({super.key});

  @override
  ConsumerState<AssignmentCreateScreen> createState() =>
      _AssignmentCreateScreenState();
}

/// 前端任务项草稿
class _ItemDraft {
  _ItemDraft.caseItem({required this.title, required int caseId, required String caseTitle})
      : itemType = 'CASE',
        caseId = caseId,
        caseTitle = caseTitle;

  _ItemDraft.practice({required this.title, required List<int> ids})
      : itemType = 'PRACTICE',
        questionIds = List.of(ids);

  _ItemDraft.reading({
    required this.title,
    required int textbookId,
    required String textbookTitle,
    this.readingScope = '',
  })  : itemType = 'READING',
        textbookId = textbookId,
        textbookTitle = textbookTitle;

  _ItemDraft.material({
    required this.title,
    required int materialId,
    required String materialTitle,
    this.materialType = '',
  })  : itemType = 'MATERIAL',
        lessonMaterialId = materialId,
        materialTitle = materialTitle;

  final String itemType;
  String title;
  int? caseId;
  String? caseTitle;
  List<int> questionIds = [];
  int? textbookId;
  String? textbookTitle;
  String readingScope = '';
  int? lessonMaterialId;
  String? materialTitle;
  String materialType = '';

  String get summary {
    switch (itemType) {
      case 'CASE':
        return caseTitle ?? '';
      case 'PRACTICE':
        return '${questionIds.length} 道题';
      case 'READING':
        final scope = readingScope.trim().isEmpty ? '' : ' · $readingScope';
        return '${textbookTitle ?? ''}$scope';
      case 'MATERIAL':
        return materialTitle ?? '';
      default:
        return '';
    }
  }
}

class _AssignmentCreateScreenState extends ConsumerState<AssignmentCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _deadline;
  bool _allowLate = false;
  // ---- 学习通式作业设置 ----
  /// 开始时间（定时发布），null = 立即发布
  DateTime? _startTime;
  /// 补交截止时间（_allowLate 为 true 时必填）
  DateTime? _lateDeadline;
  final _scoreCtrl = TextEditingController();
  String _scorePublishMode = 'IMMEDIATE';
  String _answerPublishMode = 'AFTER_DEADLINE';
  bool _shuffleQuestions = false;
  int _maxAttempts = 1;
  bool _plagiarismCheck = false;
  final List<_ItemDraft> _items = [];
  final Set<int> _classIds = {};
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final list = await TeacherService().getClasses();
    if (!mounted) return;
    setState(() {
      _classes = list;
      _loading = false;
    });
  }

  // ========= 时间选择（开始 / 截止 / 补交截止 共用） =========
  Future<DateTime?> _pickDateTime(DateTime? initial, String help) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: help,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: help,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time == null || !mounted) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDeadline() async {
    final picked = await _pickDateTime(_deadline, '选择截止时间');
    if (picked == null) return;
    setState(() => _deadline = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await _pickDateTime(_startTime, '选择开始时间');
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickLateDeadline() async {
    final picked = await _pickDateTime(_lateDeadline ?? _deadline, '选择补交截止时间');
    if (picked == null) return;
    setState(() => _lateDeadline = picked);
  }

  String _fmt(DateTime? t) => t == null
      ? ''
      : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ========= 添加任务项 =========
  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SerifText('添加任务项', fontSize: 17),
              const SizedBox(height: 4),
              MonoText('一个作业可包含多种任务，学生逐项完成', fontSize: 11,
                  color: AppColors.text3Of(context)),
              const SizedBox(height: 14),
              _typeOption(
                icon: Icons.medical_services_outlined,
                title: 'SP 病例问诊',
                subtitle: '选一个病例，学生问诊后提交大病历',
                color: AppColors.vermilionOf(context),
                bg: AppColors.vermilionSoftOf(context),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickCase();
                },
              ),
              const SizedBox(height: 10),
              _typeOption(
                icon: Icons.quiz_outlined,
                title: '基础练习',
                subtitle: '从题库选题组卷，客观题自动判分',
                color: AppColors.indigoOf(context),
                bg: AppColors.indigoSoftOf(context),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickQuestions();
                },
              ),
              const SizedBox(height: 10),
              _typeOption(
                icon: Icons.menu_book_outlined,
                title: '阅读任务',
                subtitle: '指定教材章节或页码范围',
                color: AppColors.amberOf(context),
                bg: AppColors.amberSoftOf(context),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickTextbook();
                },
              ),
              const SizedBox(height: 10),
              _typeOption(
                icon: Icons.attach_file_rounded,
                title: '学习资料',
                subtitle: '附带备课课件（PDF/PPT/视频/音频）',
                color: AppColors.moss3Of(context),
                bg: AppColors.mossTintOf(context),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickMaterial();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SerifText(title, fontSize: 14.5),
                    const SizedBox(height: 2),
                    MonoText(subtitle, fontSize: 10.5, color: AppColors.text3Of(context)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.text4Of(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 选病例 ----------
  Future<void> _pickCase() async {
    final selected = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _CasePickerSheet(),
    );
    if (selected != null) {
      setState(() => _items.add(selected));
    }
  }

  // ---------- 选题 ----------
  Future<void> _pickQuestions() async {
    final selected = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _QuestionPickerSheet(),
    );
    if (selected != null) {
      setState(() => _items.add(selected));
    }
  }

  // ---------- 选教材 ----------
  Future<void> _pickTextbook() async {
    final selected = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => const _TextbookPickerSheet(),
    );
    if (selected != null) {
      setState(() => _items.add(selected));
    }
  }

  // ---------- 选备课资料附件 ----------
  Future<void> _pickMaterial() async {
    final selected = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => const _MaterialPickerSheet(),
    );
    if (selected != null) {
      setState(() => _items.add(selected));
    }
  }

  // ========= 发放 =========
  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppFeedback.info(context, '请填写作业标题');
      return;
    }
    if (_deadline == null) {
      AppFeedback.info(context, '请选择截止时间');
      return;
    }
    if (_startTime != null && !_startTime!.isBefore(_deadline!)) {
      AppFeedback.info(context, '开始时间必须早于截止时间');
      return;
    }
    if (_allowLate) {
      if (_lateDeadline == null) {
        AppFeedback.info(context, '允许补交时请选择补交截止时间');
        return;
      }
      if (!_lateDeadline!.isAfter(_deadline!)) {
        AppFeedback.info(context, '补交截止时间必须晚于截止时间');
        return;
      }
    }
    if (_items.isEmpty) {
      AppFeedback.info(context, '请至少添加一个任务项');
      return;
    }
    if (_classIds.isEmpty) {
      AppFeedback.info(context, '请至少选择一个发放班级');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    final body = {
      'title': title,
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'deadline': _deadline!.toIso8601String(),
      'allowLateSubmit': _allowLate,
      // 学习通式设置：定时发布 / 补交窗口 / 总分 / 公布策略 / 提交次数 / 乱序 / 查重
      'startTime': _startTime?.toIso8601String(),
      'lateDeadline': _allowLate ? _lateDeadline?.toIso8601String() : null,
      'totalScore': double.tryParse(_scoreCtrl.text.trim()),
      'scorePublishMode': _scorePublishMode,
      'answerPublishMode': _answerPublishMode,
      'shuffleQuestions': _shuffleQuestions,
      'maxAttempts': _maxAttempts,
      'plagiarismCheck': _plagiarismCheck,
      'classIds': _classIds.toList(),
      'items': _items.map((it) {
        final base = {
          'itemType': it.itemType,
          'title': it.title.trim().isEmpty ? null : it.title.trim(),
        };
        switch (it.itemType) {
          case 'CASE':
            return {...base, 'caseId': it.caseId};
          case 'PRACTICE':
            return {...base, 'questionIds': it.questionIds};
          case 'READING':
            return {
              ...base,
              'textbookId': it.textbookId,
              'readingScope': it.readingScope.trim().isEmpty ? null : it.readingScope.trim(),
            };
          case 'MATERIAL':
            return {...base, 'lessonMaterialId': it.lessonMaterialId};
          default:
            return base;
        }
      }).toList(),
    };

    final id = await TeacherService().createAssignment(body);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (id == null) {
      AppFeedback.error(context, '发放失败，请检查内容是否有效');
      return;
    }
    AppFeedback.success(context, '已发放给 ${_classIds.length} 个班级');
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.goNamed(RouteNames.teacherAssignments);
    }
  }

  // ========= UI =========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '新建作业',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        _buildBasicCard(),
                        const SizedBox(height: 16),
                        _buildItemsCard(),
                        const SizedBox(height: 16),
                        _buildClassCard(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.verified_outlined,
                                size: 14, color: AppColors.moss),
                            const SizedBox(width: 6),
                            MonoText('发放即生效，无需管理员审核', fontSize: 11,
                                color: AppColors.moss),
                          ],
                        ),
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
          child: AppPrimaryButton(
            label: _submitting
                ? '发放中…'
                : '发放作业（${_items.length} 项 · ${_classIds.length} 班）',
            fullWidth: true,
            icon: const Icon(Icons.send_rounded, size: 15),
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ),
    );
  }

  Widget _buildBasicCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowText('作业信息'),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 15),
            decoration: _inputDeco('作业标题', '如：急性下壁心梗综合训练'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDeco('作业说明（选填）', '给学生的一句话说明'),
          ),
          const SizedBox(height: 10),
          _scheduleSection(),
        ],
      ),
    );
  }

  /// 时间线与提交策略设置（仿学习通）
  Widget _scheduleSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ruleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 15, color: AppColors.amberOf(context)),
              const SizedBox(width: 6),
              Text('时间设置',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2Of(context))),
            ],
          ),
          const SizedBox(height: 10),
          _timeRow(
            icon: Icons.play_circle_outline_rounded,
            label: _startTime == null ? '立即开始' : '开始 ${_fmt(_startTime)}',
            onTap: _pickStartTime,
            trailing: _startTime == null
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 16, color: AppColors.text4Of(context)),
                    onPressed: () => setState(() => _startTime = null),
                    tooltip: '改为立即开始',
                  ),
          ),
          const SizedBox(height: 8),
          _timeRow(
            icon: Icons.event_available_outlined,
            label: _deadline == null ? '选择截止时间' : '截止 ${_fmt(_deadline)}',
            onTap: _pickDeadline,
          ),
          const SizedBox(height: 4),
          _switchRow('允许补交（逾期后仍可提交）', _allowLate,
              (v) => setState(() {
                    _allowLate = v;
                    if (!v) _lateDeadline = null;
                  })),
          if (_allowLate) ...[
            const SizedBox(height: 8),
            _timeRow(
              icon: Icons.more_time_rounded,
              label: _lateDeadline == null
                  ? '选择补交截止时间'
                  : '补交截止 ${_fmt(_lateDeadline)}',
              onTap: _pickLateDeadline,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.rule_rounded, size: 15, color: AppColors.indigoOf(context)),
              const SizedBox(width: 6),
              Text('提交与公布',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2Of(context))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _scoreCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14),
            decoration: _inputDeco('作业总分（选填）', '留空则由任务项自动汇总'),
          ),
          const SizedBox(height: 10),
          _modeRow('成绩公布', _scorePublishMode, (v) => setState(() => _scorePublishMode = v)),
          const SizedBox(height: 8),
          _modeRow('答案/解析公布', _answerPublishMode,
              (v) => setState(() => _answerPublishMode = v)),
          const SizedBox(height: 4),
          _switchRow('题目乱序（每位学生题序不同）', _shuffleQuestions,
              (v) => setState(() => _shuffleQuestions = v)),
          _switchRow('抄袭检测（提交时比对相似度）', _plagiarismCheck,
              (v) => setState(() => _plagiarismCheck = v)),
          const SizedBox(height: 4),
          _attemptsRow(),
        ],
      ),
    );
  }

  /// 时间选择行
  Widget _timeRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ruleOf(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.amberOf(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: label.contains('选择')
                          ? AppColors.text3Of(context)
                          : AppColors.textOf(context),
                      fontFamily: 'JetBrainsMono')),
            ),
            trailing ??
                Icon(Icons.edit_calendar_outlined,
                    size: 16, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  /// 开关行
  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5, color: AppColors.text2Of(context))),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.primaryOf(context),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 公布方式三选一
  Widget _modeRow(String label, String value, ValueChanged<String> onChanged) {
    final opts = const [
      ('IMMEDIATE', '提交后'),
      ('AFTER_DEADLINE', '截止后'),
      ('MANUAL', '手动'),
    ];
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.text2Of(context))),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: opts
                .map((o) => ChoiceChip(
                      label: Text(o.$2,
                          style: TextStyle(
                              fontSize: 12,
                              color: value == o.$1
                                  ? AppColors.onPrimaryOf(context)
                                  : AppColors.text2Of(context))),
                      selected: value == o.$1,
                      selectedColor: AppColors.primaryOf(context),
                      backgroundColor: AppColors.surfaceOf(context),
                      side: BorderSide(color: AppColors.ruleOf(context)),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => onChanged(o.$1),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// 允许提交次数
  Widget _attemptsRow() {
    return Row(
      children: [
        Expanded(
          child: Text('允许提交次数',
              style: TextStyle(
                  fontSize: 13.5, color: AppColors.text2Of(context))),
        ),
        IconButton(
          icon: Icon(Icons.remove_circle_outline_rounded,
              size: 20, color: AppColors.text3Of(context)),
          onPressed: _maxAttempts > 1
              ? () => setState(() => _maxAttempts--)
              : null,
          tooltip: '减少',
        ),
        Text('$_maxAttempts',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textOf(context))),
        IconButton(
          icon: Icon(Icons.add_circle_outline_rounded,
              size: 20, color: AppColors.text3Of(context)),
          onPressed: _maxAttempts < 10
              ? () => setState(() => _maxAttempts++)
              : null,
          tooltip: '增加',
        ),
      ],
    );
  }

  Widget _deadlineRow() {
    final fmt = _deadline == null
        ? '选择截止时间'
        : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')} '
            '${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}';
    return PressableScale(
      child: GestureDetector(
        onTap: _pickDeadline,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgOf(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.ruleOf(context)),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 16, color: AppColors.amberOf(context)),
              const SizedBox(width: 8),
              Text(
                fmt,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _deadline == null
                      ? AppColors.text3Of(context)
                      : AppColors.textOf(context),
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const Spacer(),
              Icon(Icons.edit_calendar_outlined, size: 16, color: AppColors.text4Of(context)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.bgOf(context),
      labelStyle: TextStyle(fontSize: 12.5, color: AppColors.text3Of(context)),
      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.text4Of(context)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.2),
      ),
    );
  }

  Widget _buildItemsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EyebrowText('任务项')),
              AppChip(label: '${_items.length}', type: ChipType.indigo, fontSize: 10),
            ],
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 32, color: AppColors.text4Of(context)),
                  const SizedBox(height: 8),
                  MonoText('还没有任务，点下方按钮添加', fontSize: 11,
                      color: AppColors.text4Of(context)),
                ],
              ),
            )
          else
            ..._items.asMap().entries.map((e) => _buildItemCard(e.key, e.value)),
          const SizedBox(height: 10),
          AppGhostButton(
            label: '添加任务项',
            icon: const Icon(Icons.add_rounded, size: 16),
            fullWidth: true,
            onPressed: _showAddItemSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, _ItemDraft it) {
    final (icon, color, bg) = switch (it.itemType) {
      'CASE' => (Icons.medical_services_outlined, AppColors.vermilionOf(context), AppColors.vermilionSoftOf(context)),
      'PRACTICE' => (Icons.quiz_outlined, AppColors.indigoOf(context), AppColors.indigoSoftOf(context)),
      'MATERIAL' => (Icons.attach_file_rounded, AppColors.moss3Of(context), AppColors.mossTintOf(context)),
      _ => (Icons.menu_book_outlined, AppColors.amberOf(context), AppColors.amberSoftOf(context)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ruleSoftOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.title.trim().isEmpty ? _typeLabel(it.itemType) : it.title.trim(),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                ),
                if (it.summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  MonoText(it.summary, fontSize: 10, color: AppColors.text3Of(context)),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => setState(() => _items.removeAt(index)),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'CASE' => 'SP 病例问诊',
      'PRACTICE' => '基础练习',
      'MATERIAL' => '学习资料',
      _ => '阅读任务',
    };
  }

  Widget _buildClassCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EyebrowText('发放班级')),
              AppChip(label: '${_classIds.length} 班', type: ChipType.moss, fontSize: 10),
            ],
          ),
          const SizedBox(height: 10),
          if (_classes.isEmpty)
            MonoText('暂无已授权班级，请先在管理端完成班级授权',
                fontSize: 11, color: AppColors.text4Of(context))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classes.map((c) {
                final id = (c['id'] as num?)?.toInt() ?? 0;
                final name = c['name'] as String? ?? '';
                final count = (c['studentCount'] as num?)?.toInt() ?? 0;
                final selected = _classIds.contains(id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _classIds.remove(id);
                    } else {
                      _classIds.add(id);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.mossSoftOf(context) : AppColors.bgOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: selected ? AppColors.primaryOf(context) : AppColors.ruleOf(context),
                        width: selected ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          Icon(Icons.check_rounded, size: 13, color: AppColors.primaryOf(context)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.primaryOf(context)
                                : AppColors.text2Of(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        MonoText('$count人', fontSize: 9.5, color: AppColors.text4Of(context)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// 病例选择器（我的病例 / 病例广场）
// =====================================================================
class _CasePickerSheet extends StatefulWidget {
  @override
  State<_CasePickerSheet> createState() => _CasePickerSheetState();
}

class _CasePickerSheetState extends State<_CasePickerSheet> {
  int _tab = 0; // 0 我的病例 1 病例广场
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _market = [];
  bool _loading = true;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final mine = await TeacherService().getCaseList();
    final market = await TeacherService().getMarketList();
    if (!mounted) return;
    setState(() {
      _mine = PageParser.mapListOf(mine);
      _market = PageParser.mapListOf(market);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? _mine : _market;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ruleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: SerifText('选择病例', fontSize: 17)),
                    if (_selectedId != null)
                      AppChip(label: '已选', type: ChipType.moss, fontSize: 10),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _tabBtn(0, '我的病例（${_mine.length}）'),
                    const SizedBox(width: 8),
                    _tabBtn(1, '病例广场（${_market.length}）'),
                  ],
                ),
                Divider(height: 20, color: AppColors.ruleOf(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: MonoText(_tab == 0 ? '暂无病例' : '广场暂无公开病例',
                            fontSize: 12, color: AppColors.text4Of(context)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final c = list[i];
                          final id = (c['id'] as num?)?.toInt() ?? 0;
                          final title = c['title'] as String? ?? '未命名病例';
                          final dept = c['department'] as String? ?? '';
                          final selected = id == _selectedId;
                          return PressableScale(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedId = id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.vermilionSoftOf(context)
                                      : AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.vermilionOf(context)
                                        : AppColors.surfaceEdgeOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.medical_services_outlined,
                                      size: 18,
                                      color: selected
                                          ? AppColors.vermilionOf(context)
                                          : AppColors.text3Of(context),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textOf(context))),
                                          if (dept.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            MonoText(dept, fontSize: 10,
                                                color: AppColors.text3Of(context)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: AppPrimaryButton(
                label: '确定添加',
                fullWidth: true,
                onPressed: _selectedId == null
                    ? null
                    : () {
                        final list = _tab == 0 ? _mine : _market;
                        final c = list.firstWhere((e) =>
                            ((e['id'] as num?)?.toInt() ?? 0) == _selectedId);
                        Navigator.of(context).pop(_ItemDraft.caseItem(
                          title: '',
                          caseId: _selectedId!,
                          caseTitle: c['title'] as String? ?? '',
                        ));
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label) {
    final active = idx == _tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = idx;
          _selectedId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.primaryOf(context) : AppColors.text3Of(context),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 题库多选器
// =====================================================================
class _QuestionPickerSheet extends StatefulWidget {
  @override
  State<_QuestionPickerSheet> createState() => _QuestionPickerSheetState();
}

class _QuestionPickerSheetState extends State<_QuestionPickerSheet> {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await TeacherService().getMyQuestions(pageSize: 200);
    if (!mounted) return;
    setState(() {
      _questions = PageParser.mapListOf(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ruleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: SerifText('选题组卷', fontSize: 17)),
                    if (_selected.isNotEmpty)
                      AppChip(label: '已选 ${_selected.length} 题', type: ChipType.indigo, fontSize: 10),
                  ],
                ),
                const SizedBox(height: 4),
                MonoText('从你的题库多选，交卷后客观题自动判分', fontSize: 11,
                    color: AppColors.text3Of(context)),
                Divider(height: 20, color: AppColors.ruleOf(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? Center(
                        child: MonoText('题库暂无题目，请先在“我的题库”录入',
                            fontSize: 12, color: AppColors.text4Of(context)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        itemCount: _questions.length,
                        itemBuilder: (ctx, i) {
                          final q = _questions[i];
                          final id = (q['id'] as num?)?.toInt() ?? 0;
                          final title = q['title'] as String? ?? '';
                          final type = q['questionType'] as String? ?? '';
                          final selected = _selected.contains(id);
                          return PressableScale(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (selected) {
                                  _selected.remove(id);
                                } else {
                                  _selected.add(id);
                                }
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.indigoSoftOf(context)
                                      : AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.indigoOf(context)
                                        : AppColors.surfaceEdgeOf(context),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      size: 18,
                                      color: selected
                                          ? AppColors.indigoOf(context)
                                          : AppColors.text4Of(context),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textOf(context),
                                                  height: 1.4)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _qTypeChip(type),
                                              const SizedBox(width: 6),
                                              MonoText(
                                                  _qTypeLabel(type),
                                                  fontSize: 10,
                                                  color: AppColors.text3Of(context)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: AppPrimaryButton(
                label: _selected.isEmpty ? '至少选择 1 题' : '添加 ${_selected.length} 道题',
                fullWidth: true,
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_ItemDraft.practice(
                          title: '',
                          ids: _selected.toList(),
                        )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qTypeChip(String type) {
    final (label, color, bg) = switch (type) {
      'single_choice' => ('单选', AppColors.indigoOf(context), AppColors.indigoSoftOf(context)),
      'multiple_choice' => ('多选', AppColors.vermilionOf(context), AppColors.vermilionSoftOf(context)),
      'judgment' => ('判断', AppColors.amberOf(context), AppColors.amberSoftOf(context)),
      'fill_blank' => ('填空', AppColors.moss, AppColors.mossSoftOf(context)),
      'essay' || 'short_answer' || 'subjective' => ('简答', AppColors.amberOf(context), AppColors.amberSoftOf(context)),
      _ => (type, AppColors.text3Of(context), AppColors.ruleSoftOf(context)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.w600, color: color)),
    );
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
}

// =====================================================================
// 教材选择器（单选 + 阅读范围）
// =====================================================================
class _TextbookPickerSheet extends StatefulWidget {
  const _TextbookPickerSheet();

  @override
  State<_TextbookPickerSheet> createState() => _TextbookPickerSheetState();
}

class _TextbookPickerSheetState extends State<_TextbookPickerSheet> {
  List<Map<String, dynamic>> _textbooks = [];
  bool _loading = true;
  int? _selectedId;
  final _scopeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scopeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 组卷关联教材走「教材库」：平台上全部已上架教材都能引用，
    // 不再局限于自己上传的（此前教师没传过教材时这里恒为空）
    final data = await TeacherService().getTextbookLibrary(pageSize: 100);
    if (!mounted) return;
    setState(() {
      _textbooks = PageParser.mapListOf(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ruleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SerifText('选择教材', fontSize: 17),
                const SizedBox(height: 4),
                MonoText('从你的教材库选择，可指定阅读范围', fontSize: 11,
                    color: AppColors.text3Of(context)),
                Divider(height: 20, color: AppColors.ruleOf(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _textbooks.isEmpty
                    ? Center(
                        child: MonoText('暂无教材，请先在“教材管理”上传',
                            fontSize: 12, color: AppColors.text4Of(context)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        itemCount: _textbooks.length,
                        itemBuilder: (ctx, i) {
                          final t = _textbooks[i];
                          final id = (t['id'] as num?)?.toInt() ?? 0;
                          final title = t['title'] as String? ?? '未命名教材';
                          final author = t['author'] as String? ?? '';
                          final selected = id == _selectedId;
                          return PressableScale(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedId = id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.amberSoftOf(context)
                                      : AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.amberOf(context)
                                        : AppColors.surfaceEdgeOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.menu_book_outlined,
                                      size: 18,
                                      color: selected
                                          ? AppColors.amberOf(context)
                                          : AppColors.text3Of(context),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textOf(context))),
                                          if (author.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            MonoText(author, fontSize: 10,
                                                color: AppColors.text3Of(context)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _scopeCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '阅读范围（选填）',
                      hintText: '如：第 3 章 第 1-2 节 / 第 100-150 页',
                      filled: true,
                      fillColor: AppColors.bgOf(context),
                      labelStyle: TextStyle(fontSize: 12, color: AppColors.text3Of(context)),
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppPrimaryButton(
                    label: '确定添加',
                    fullWidth: true,
                    onPressed: _selectedId == null
                        ? null
                        : () {
                            final t = _textbooks.firstWhere((e) =>
                                ((e['id'] as num?)?.toInt() ?? 0) == _selectedId);
                            Navigator.of(context).pop(_ItemDraft.reading(
                              title: '',
                              textbookId: _selectedId!,
                              textbookTitle: t['title'] as String? ?? '',
                              readingScope: _scopeCtrl.text.trim(),
                            ));
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 备课资料选择器：跨教案平铺展示本人全部上传的课件资料，
/// 选中后作为 MATERIAL 任务项随作业下发（学生端可查看）。
class _MaterialPickerSheet extends StatefulWidget {
  const _MaterialPickerSheet();

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;
  int? _selectedId;

  static const _typeIcons = {
    'pdf': Icons.picture_as_pdf_outlined,
    'ppt': Icons.slideshow_rounded,
    'mp4': Icons.movie_outlined,
    'mp3': Icons.headphones_rounded,
    'image': Icons.image_outlined,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final list = await TeacherService().getMyMaterials();
    if (!mounted) return;
    setState(() {
      _materials = list;
      _loading = false;
    });
  }

  IconData _iconOf(String? type) =>
      _typeIcons[(type ?? '').toLowerCase()] ?? Icons.attach_file_rounded;

  String _typeLabel(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'pdf':
        return 'PDF 文档';
      case 'ppt':
        return 'PPT 课件';
      case 'mp4':
        return '视频';
      case 'mp3':
        return '音频';
      case 'image':
        return '图片';
      default:
        return '资料';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ruleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SerifText('选择学习资料', fontSize: 17),
                const SizedBox(height: 4),
                MonoText('从你的备课资料中选择，随作业下发给学生查看', fontSize: 11,
                    color: AppColors.text3Of(context)),
                Divider(height: 20, color: AppColors.ruleOf(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? Center(
                        child: MonoText('暂无备课资料，请先在「备课」里上传课件',
                            fontSize: 12, color: AppColors.text4Of(context)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        itemCount: _materials.length,
                        itemBuilder: (ctx, i) {
                          final m = _materials[i];
                          final id = (m['materialId'] as num?)?.toInt() ?? 0;
                          final title = m['title'] as String? ?? '未命名资料';
                          final type = m['materialType'] as String?;
                          final lessonTitle = m['lessonTitle'] as String? ?? '';
                          final selected = id == _selectedId;
                          return PressableScale(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedId = id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.mossTintOf(context)
                                      : AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primaryOf(context)
                                        : AppColors.surfaceEdgeOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : _iconOf(type),
                                      size: 18,
                                      color: selected
                                          ? AppColors.primaryOf(context)
                                          : AppColors.text3Of(context),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textOf(context))),
                                          const SizedBox(height: 2),
                                          MonoText(
                                            lessonTitle.isEmpty
                                                ? _typeLabel(type)
                                                : '${_typeLabel(type)} · $lessonTitle',
                                            fontSize: 10,
                                            color: AppColors.text3Of(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: AppPrimaryButton(
                label: '确定添加',
                fullWidth: true,
                onPressed: _selectedId == null
                    ? null
                    : () {
                        final m = _materials.firstWhere((e) =>
                            ((e['materialId'] as num?)?.toInt() ?? 0) ==
                            _selectedId);
                        Navigator.of(context).pop(_ItemDraft.material(
                          title: '',
                          materialId: _selectedId!,
                          materialTitle: m['title'] as String? ?? '',
                          materialType:
                              (m['materialType'] as String? ?? '').toLowerCase(),
                        ));
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
