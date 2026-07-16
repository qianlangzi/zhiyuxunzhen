import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 教师作业列表与格式规则
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
    showModalBottomSheet(
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
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => _FormatRulesSheet(rules: rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FormatShieldRule> rules =
        ref.watch(teachingRepositoryProvider).formatRules();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ZyPageHead(
              kicker: '作业',
              title: '查看班级训练任务',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid2),
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
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            sliver: SliverList.separated(
              itemCount: _assignments.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (BuildContext context, int index) =>
                  _AssignmentRow(item: _assignments[index]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding,
                  AppDimens.grid6, AppDimens.pagePadding, 120),
              child: _FormatRules(
                rules: rules,
                onEdit: _showRulesSheet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.item});

  final AssignmentModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(item.title, style: AppTextStyles.title)),
              ZyChip(item.status, tone: _statusTone(item.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${item.className} · 截止 ${item.due}',
              style: AppTextStyles.caption),
          const SizedBox(height: AppDimens.grid2),
          Row(
            children: <Widget>[
              const Text('提交进度'),
              const Spacer(),
              Text('${item.submitted} / ${item.total}'),
            ],
          ),
          const SizedBox(height: 6),
          ZyProgress(value: item.progress),
          const SizedBox(height: 4),
          Text(
            _metaLine(item),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  String _metaLine(AssignmentModel a) {
    final List<String> parts = <String>[];
    if (a.requireRecord) parts.add('需大病历');
    parts.add(a.variable);
    return parts.join(' · ');
  }

  ZyChipTone _statusTone(String status) {
    switch (status) {
      case '进行中':
        return ZyChipTone.brand;
      case 'AI 批阅中':
        return ZyChipTone.aqua;
      case '待复核':
        return ZyChipTone.warning;
      default:
        return ZyChipTone.neutral;
    }
  }
}

class _FormatRules extends StatelessWidget {
  const _FormatRules({required this.rules, required this.onEdit});

  final List<FormatShieldRule> rules;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZySectionHeader(
          title: '格式规则',
          actionLabel: '编辑规则',
          onAction: onEdit,
        ),
        const SizedBox(height: AppDimens.grid2),
        Text('提交前的自动校验规则，未通过会被打回。', style: AppTextStyles.caption),
        const SizedBox(height: AppDimens.grid3),
        ...rules.map((FormatShieldRule rule) => _RuleRow(rule: rule)),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final FormatShieldRule rule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZyChip(rule.state, tone: _ruleTone(rule.state)),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(rule.label, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(rule.detail, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ZyChipTone _ruleTone(String state) {
    switch (state) {
      case '通过':
        return ZyChipTone.success;
      case '打回':
        return ZyChipTone.danger;
      default:
        return ZyChipTone.warning;
    }
  }
}

/// 格式规则说明（只读）
class _FormatRulesSheet extends StatelessWidget {
  const _FormatRulesSheet({required this.rules});

  final List<FormatShieldRule> rules;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding, 0, AppDimens.pagePadding, AppDimens.grid6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('格式规则说明', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.grid2),
            Text('以下是当前启用的提交校验规则，学生提交时会自动检查。', style: AppTextStyles.caption),
            const SizedBox(height: AppDimens.grid4),
            ...rules.map((FormatShieldRule rule) => _RuleRow(rule: rule)),
          ],
        ),
      ),
    );
  }
}

/// 新建作业表单
class _CreateAssignmentSheet extends StatefulWidget {
  const _CreateAssignmentSheet({required this.onCreate});

  final ValueChanged<AssignmentModel> onCreate;

  @override
  State<_CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<_CreateAssignmentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _classCtrl = TextEditingController();
  final TextEditingController _dueCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _classCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onCreate(AssignmentModel(
      title: _titleCtrl.text.trim(),
      className:
          _classCtrl.text.trim().isEmpty ? '未指定班级' : _classCtrl.text.trim(),
      submitted: 0,
      total: 0,
      due: _dueCtrl.text.trim().isEmpty ? '未设置' : _dueCtrl.text.trim(),
      status: '进行中',
      requireRecord: false,
      variable: '关闭',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppDimens.pagePadding, 0,
            AppDimens.pagePadding, bottomInset + AppDimens.grid6),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('新建作业', style: AppTextStyles.h3),
              const SizedBox(height: AppDimens.grid4),
              TextFormField(
                controller: _titleCtrl,
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
                controller: _classCtrl,
                decoration: const InputDecoration(labelText: '班级'),
              ),
              const SizedBox(height: AppDimens.grid3),
              TextFormField(
                controller: _dueCtrl,
                decoration: const InputDecoration(labelText: '截止日期'),
              ),
              const SizedBox(height: AppDimens.grid5),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                ),
                child: const Text('创建作业'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
