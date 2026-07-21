import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

class AssignmentsPage extends ConsumerStatefulWidget {
  const AssignmentsPage({super.key});

  @override
  ConsumerState<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends ConsumerState<AssignmentsPage> {
  Future<void> _showCreateSheet() async {
    final TeachingRepository repository = ref.read(teachingRepositoryProvider);
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.fetchClasses(),
        ref.read(caseRepositoryProvider).fetchCases(),
      ]);
      if (!mounted) return;
      final List<Map<String, dynamic>> classes =
          result[0] as List<Map<String, dynamic>>;
      final List<CaseModel> cases = result[1] as List<CaseModel>;
      if (classes.isEmpty || cases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先准备已授权班级和本人病例')),
        );
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) => _CreateAssignmentSheet(
          classes: classes,
          cases: cases,
          onCreate: (AssignmentModel assignment) async {
            await repository.createAssignment(
              caseId: assignment.caseId!,
              classId: assignment.classId!,
              title: assignment.title,
              deadline: DateTime.parse(assignment.due),
            );
            ref.invalidate(teacherAssignmentListProvider);
            if (!mounted || !sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('作业已创建')),
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载创建选项失败：$error')),
      );
    }
  }

  void _showRulesSheet() {
    final List<FormatShieldRule> rules =
        ref.read(teachingRepositoryProvider).formatRules();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) => _FormatRulesSheet(rules: rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FormatShieldRule> rules =
        ref.watch(teachingRepositoryProvider).formatRules();

    final AsyncValue<List<AssignmentModel>> assignmentState =
        ref.watch(teacherAssignmentListProvider);
    final List<AssignmentModel> assignments =
        assignmentState.value ?? const <AssignmentModel>[];
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '作业登记',
              identityLabel: '教师工作区',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid2,
                AppDimens.pagePadding,
                AppDimens.grid4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _showCreateSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('新建作业'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: ClinicalSectionHeader(
                title: '班级任务',
                description: '共 ${assignments.length} 项，按截止时间与处理状态登记。',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
            ),
            sliver: SliverList.builder(
              itemCount: assignments.length,
              itemBuilder: (BuildContext context, int index) {
                final AssignmentModel item = assignments[index];
                return ClinicalRecordRow(
                  leadingLabel: item.due,
                  title: item.title,
                  subtitle:
                      '${item.className}\n提交 ${item.submitted} / ${item.total} · ${_assignmentMeta(item)}',
                  statusLabel: item.status,
                  statusTone: _assignmentTone(item.status),
                );
              },
            ),
          ),
          if (assignmentState.isLoading)
            const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2)),
          if (assignmentState.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.pagePadding),
                child: Text('作业加载失败：${assignmentState.error}'),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid6,
                AppDimens.pagePadding,
                120,
              ),
              child: _FormatRules(
                rules: rules,
                onView: _showRulesSheet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _assignmentMeta(AssignmentModel item) {
  final List<String> parts = <String>[
    if (item.requireRecord) '需提交大病历',
    item.variable,
  ];
  return parts.join(' · ');
}

ClinicalEvidenceTone _assignmentTone(String status) {
  switch (status) {
    case '进行中':
    case 'AI 批阅中':
      return ClinicalEvidenceTone.action;
    case '待复核':
      return ClinicalEvidenceTone.risk;
    case '已完成':
      return ClinicalEvidenceTone.success;
    default:
      return ClinicalEvidenceTone.neutral;
  }
}

class _FormatRules extends StatelessWidget {
  const _FormatRules({required this.rules, required this.onView});

  final List<FormatShieldRule> rules;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClinicalSectionHeader(
          title: '格式规则',
          description: '学生提交前按当前规则自动检查。',
          action: TextButton(
            onPressed: onView,
            child: const Text('查看规则'),
          ),
        ),
        ClinicalEvidenceAxis(
          nodes: rules
              .map(
                (FormatShieldRule rule) => ClinicalEvidenceNode(
                  label: rule.label,
                  detail: rule.detail,
                  statusLabel: rule.state,
                  tone: _ruleTone(rule.state),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

ClinicalEvidenceTone _ruleTone(String state) {
  switch (state) {
    case '通过':
      return ClinicalEvidenceTone.success;
    case '打回':
      return ClinicalEvidenceTone.risk;
    case '提示':
      return ClinicalEvidenceTone.action;
    default:
      return ClinicalEvidenceTone.neutral;
  }
}

class _FormatRulesSheet extends StatelessWidget {
  const _FormatRulesSheet({required this.rules});

  final List<FormatShieldRule> rules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        0,
        AppDimens.pagePadding,
        AppDimens.grid6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ClinicalSectionHeader(
              title: '格式规则说明',
              description: '以下规则在学生提交时自动执行。',
            ),
            ClinicalEvidenceAxis(
              nodes: rules
                  .map(
                    (FormatShieldRule rule) => ClinicalEvidenceNode(
                      label: rule.label,
                      detail: rule.detail,
                      statusLabel: rule.state,
                      tone: _ruleTone(rule.state),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAssignmentSheet extends StatefulWidget {
  const _CreateAssignmentSheet({
    required this.onCreate,
    required this.classes,
    required this.cases,
  });

  final Future<void> Function(AssignmentModel) onCreate;
  final List<Map<String, dynamic>> classes;
  final List<CaseModel> cases;

  @override
  State<_CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<_CreateAssignmentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  late int _classId;
  late int _caseId;
  late DateTime _deadline;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _classId = (widget.classes.first['id'] as num).toInt();
    _caseId = int.tryParse(widget.cases.first.id) ?? 1;
    _deadline = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await widget.onCreate(AssignmentModel(
        caseId: _caseId,
        classId: _classId,
        title: _titleController.text.trim(),
        className: widget.classes
            .firstWhere(
                (item) => (item['id'] as num).toInt() == _classId)['name']
            .toString(),
        submitted: 0,
        total: 0,
        due: _deadline.toIso8601String(),
        status: '进行中',
        requireRecord: true,
        variable: '关闭',
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$error')),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          0,
          AppDimens.pagePadding,
          bottomInset + AppDimens.grid6,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const ClinicalSectionHeader(
                  title: '新建作业',
                  description: '填写任务名称，班级和截止时间。',
                ),
                const SizedBox(height: AppDimens.grid4),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '作业名称'),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入作业名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.grid3),
                DropdownButtonFormField<int>(
                  initialValue: _caseId,
                  decoration: const InputDecoration(labelText: '训练病例'),
                  items: widget.cases
                      .asMap()
                      .entries
                      .map((entry) => DropdownMenuItem<int>(
                            value:
                                int.tryParse(entry.value.id) ?? entry.key + 1,
                            child: Text(entry.value.title),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _caseId = value!),
                ),
                const SizedBox(height: AppDimens.grid3),
                DropdownButtonFormField<int>(
                  initialValue: _classId,
                  decoration: const InputDecoration(labelText: '目标班级'),
                  items: widget.classes
                      .map((item) => DropdownMenuItem<int>(
                            value: (item['id'] as num).toInt(),
                            child: Text(
                                '${item['name']}（${item['studentCount']} 人）'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _classId = value!),
                ),
                const SizedBox(height: AppDimens.grid3),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('截止日期'),
                  subtitle: Text(
                    '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _deadline,
                    );
                    if (picked != null) {
                      setState(() =>
                          _deadline = picked.copyWith(hour: 23, minute: 59));
                    }
                  },
                ),
                const SizedBox(height: AppDimens.grid5),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? '创建中…' : '创建作业'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
