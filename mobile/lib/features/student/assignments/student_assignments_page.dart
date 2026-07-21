import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

class StudentAssignmentsPage extends ConsumerWidget {
  const StudentAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AssignmentModel>> state =
        ref.watch(studentAssignmentListProvider);
    return Scaffold(
      appBar: const ZyAppBar(title: '我的作业', subtitle: '问诊与大病历任务'),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ZyErrorState(
          title: '作业加载失败',
          message: error.toString(),
          actionLabel: '重试',
          onRetry: () => ref.invalidate(studentAssignmentListProvider),
        ),
        data: (items) => items.isEmpty
            ? const ZyEmptyState(
                title: '暂无作业',
                detail: '教师布置作业后会显示在这里。',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(studentAssignmentListProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final AssignmentModel item = items[index];
                    return ClinicalRecordRow(
                      leadingLabel: item.due,
                      title: item.title,
                      subtitle: item.className,
                      statusLabel: item.status,
                      statusTone: item.status == '已完成'
                          ? ClinicalEvidenceTone.success
                          : item.status == '格式打回'
                              ? ClinicalEvidenceTone.risk
                              : ClinicalEvidenceTone.action,
                      onTap: () => _openActions(context, ref, item),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    AssignmentModel item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(item.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppDimens.grid3),
              if (item.status == '未开始' || item.status == '问诊中')
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push(
                      '/student/chat?caseId=${item.caseId}&assignmentInstanceId=${item.id}',
                    );
                  },
                  child: Text(item.status == '未开始' ? '开始问诊' : '重新进入问诊'),
                ),
              if (item.status == '问诊中' || item.status == '格式打回') ...<Widget>[
                const SizedBox(height: AppDimens.grid2),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showRecordEditor(context, ref, item);
                  },
                  child: Text(item.status == '格式打回' ? '修改并重新提交病历' : '提交大病历'),
                ),
              ],
              if (item.status != '未开始' &&
                  item.status != '问诊中' &&
                  item.status != '格式打回')
                Text('当前状态：${item.status}。批阅完成后状态会自动更新。'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecordEditor(
    BuildContext context,
    WidgetRef ref,
    AssignmentModel item,
  ) async {
    final TextEditingController controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('提交大病历'),
        content: TextField(
          controller: controller,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(
            hintText: '请按“主诉、现病史、初步诊断”等结构填写',
            alignLabelWithHint: true,
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                final Map<String, dynamic> result = await ref
                    .read(learningRepositoryProvider)
                    .submitMedicalRecord(
                      instanceId: item.id!,
                      text: controller.text.trim(),
                    );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ref.invalidate(studentAssignmentListProvider);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['passed'] == true
                      ? '格式检查通过，已进入 AI 批阅'
                      : '格式检查未通过，请按提示修改'),
                ));
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext)
                    .showSnackBar(SnackBar(content: Text('提交失败：$error')));
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
