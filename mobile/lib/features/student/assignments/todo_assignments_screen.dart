import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 待办作业列表
class TodoAssignmentsScreen extends ConsumerStatefulWidget {
  const TodoAssignmentsScreen({super.key});

  @override
  ConsumerState<TodoAssignmentsScreen> createState() => _TodoAssignmentsScreenState();
}

class _TodoAssignmentsScreenState extends ConsumerState<TodoAssignmentsScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getTodoAssignments(pageSize: 20);
    if (!mounted) return;
    setState(() {
      _list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
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
              title: '待办作业',
              onBack: () => context.goNamed(RouteNames.studentHome),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt_rounded,
                                  size: 48, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              SerifText('暂无待办作业', fontSize: 15,
                                  color: AppColors.text2Of(context)),
                              const SizedBox(height: 4),
                              Text('所有作业都已完成，继续保持',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.text4Of(context))),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                          itemCount: _list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _AssignmentCard(item: _list[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = item['assignmentTitle'] as String? ?? '未命名作业';
    final caseTitle = item['caseTitle'] as String? ?? '未分配病例';
    final status = item['status'] as int? ?? 0;
    final deadline = item['deadline'] as String?;

    final statusText = switch (status) {
      0 => '未开始',
      1 => '问诊中',
      2 => '格式打回',
      _ => '进行中',
    };
    final statusColor = switch (status) {
      0 => AppColors.amber,
      1 => AppColors.indigo,
      2 => AppColors.vermilion,
      _ => AppColors.amber,
    };

    return Container(
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
                child: SerifText(title, fontSize: 15, color: AppColors.textOf(context)),
              ),
              AppChip(label: statusText, type: statusColor == AppColors.vermilion
                  ? ChipType.vermilion
                  : (statusColor == AppColors.indigo ? ChipType.indigo : ChipType.amber)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.article_outlined, size: 14, color: AppColors.text4Of(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  caseTitle,
                  style: TextStyle(fontSize: 12.5, color: AppColors.text2Of(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (deadline != null && deadline.isNotEmpty) ...[
                Icon(Icons.schedule, size: 13, color: AppColors.text4Of(context)),
                const SizedBox(width: 4),
                MonoText('截止 $deadline', fontSize: 10, color: AppColors.text4Of(context)),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => context.pushNamed(RouteNames.todoAssignmentDetail,
                    pathParameters: {'id': '${item['instanceId']}'}),
                child: MonoText('去完成 →', fontSize: 11, color: AppColors.primaryOf(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}