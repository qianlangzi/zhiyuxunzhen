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
  late List<AssignmentModel> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = ref.read(teachingRepositoryProvider).assignments().toList();
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => _CreateAssignmentSheet(
        onCreate: (AssignmentModel assignment) {
          setState(() => _assignments.add(assignment));
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('作业已创建')),
          );
        },
      ),
    );
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
                description: '共 ${_assignments.length} 项，按截止时间与处理状态登记。',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
            ),
            sliver: SliverList.builder(
              itemCount: _assignments.length,
              itemBuilder: (BuildContext context, int index) {
                final AssignmentModel item = _assignments[index];
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
  const _CreateAssignmentSheet({required this.onCreate});

  final ValueChanged<AssignmentModel> onCreate;

  @override
  State<_CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<_CreateAssignmentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _dueController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _classController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onCreate(
      AssignmentModel(
        title: _titleController.text.trim(),
        className: _classController.text.trim().isEmpty
            ? '未指定班级'
            : _classController.text.trim(),
        submitted: 0,
        total: 0,
        due: _dueController.text.trim().isEmpty
            ? '未设置'
            : _dueController.text.trim(),
        status: '进行中',
        requireRecord: false,
        variable: '关闭',
      ),
    );
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
                TextFormField(
                  controller: _classController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '班级'),
                ),
                const SizedBox(height: AppDimens.grid3),
                TextFormField(
                  controller: _dueController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: '截止日期'),
                ),
                const SizedBox(height: AppDimens.grid5),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('创建作业'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
