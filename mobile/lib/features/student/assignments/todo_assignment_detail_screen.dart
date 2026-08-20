import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 待办作业详情（查看作业 + 提交大病历）
class TodoAssignmentDetailScreen extends ConsumerStatefulWidget {
  const TodoAssignmentDetailScreen({super.key, required this.instanceId});
  final int instanceId;

  @override
  ConsumerState<TodoAssignmentDetailScreen> createState() =>
      _TodoAssignmentDetailScreenState();
}

class _TodoAssignmentDetailScreenState
    extends ConsumerState<TodoAssignmentDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  final _recordCtl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _recordCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await StudentService().getAssignmentDetail(widget.instanceId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _recordCtl.text = detail?['medicalRecordText'] as String? ?? '';
      _isLoading = false;
    });
  }

  Future<void> _startSession() async {
    final caseId = (_detail?['caseId'] as num?)?.toInt();
    if (caseId == null) {
      AppFeedback.info(context, '该作业未关联病例');
      return;
    }
    context.pushNamed(
      RouteNames.chat,
      queryParameters: {'caseId': '$caseId'},
    );
  }

  Future<void> _submitRecord() async {
    if (_recordCtl.text.trim().isEmpty) {
      AppFeedback.info(context, '请先填写大病历内容');
      return;
    }
    setState(() => _submitting = true);
    final result = await StudentService().submitRecord(
      instanceId: widget.instanceId,
      medicalRecordText: _recordCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      AppFeedback.error(context, '提交失败，请稍后重试');
      return;
    }
    final passed = result['passed'] == true;
    AppFeedback.success(context, passed ? '提交成功，AI 批阅中' : '格式校验未通过，请修改后重试');
    _load();
  }

  String _statusText(int? status) {
    switch (status) {
      case 0: return '未开始';
      case 1: return '问诊中';
      case 2: return '格式打回';
      case 3: return 'AI 批阅中';
      case 4: return '已批阅';
      case 5: return '已完成';
      default: return '进行中';
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '作业详情',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : d == null
                      ? const Center(child: Text('作业不存在'))
                      : _buildDetail(d),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(Map<String, dynamic> d) {
    final status = d['status'] as int? ?? 0;
    final submitted = d['submitted'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Container(
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
                  Expanded(
                    child: SerifText(d['assignmentTitle'] as String? ?? '未命名作业',
                        fontSize: 16, color: AppColors.textOf(context)),
                  ),
                  AppChip(label: _statusText(status), type: ChipType.amber),
                ],
              ),
              const SizedBox(height: 8),
              if (d['assignmentDescription'] != null)
                Text(
                  d['assignmentDescription'] as String,
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.text2Of(context)),
                ),
              const SizedBox(height: 12),
              _row('病例', d['caseTitle'] ?? '未分配'),
              if (d['department'] != null) _row('科室', d['department']),
              if (d['deadline'] != null) _row('截止时间', '${d['deadline']}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('问诊训练'),
        const SizedBox(height: 8),
        AppPrimaryButton(
          label: submitted ? '重新问诊' : '开始问诊',
          fullWidth: true,
          icon: const Icon(Icons.forum_outlined, size: 16),
          onPressed: _startSession,
        ),
        const SizedBox(height: 20),
        _sectionTitle('提交大病历'),
        const SizedBox(height: 8),
        TextField(
          controller: _recordCtl,
          maxLines: 8,
          enabled: !submitted,
          style: TextStyle(color: AppColors.textOf(context)),
          decoration: InputDecoration(
            hintText: '请填写本次问诊整理的大病历内容…',
            hintStyle: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
            filled: true,
            fillColor: AppColors.surfaceOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!submitted)
          AppGhostButton(
            label: _submitting ? '提交中…' : '提交大病历',
            fullWidth: true,
            onPressed: _submitting ? null : _submitRecord,
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return SerifText(text, fontSize: 14, color: AppColors.textOf(context));
  }

  Widget _row(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(label, fontSize: 11, color: AppColors.text4Of(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$value', style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context))),
          ),
        ],
      ),
    );
  }
}