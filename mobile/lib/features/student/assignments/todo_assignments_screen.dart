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
  /// 加载失败标记：与「真的没有待办」区分开，避免把网络故障误报为空态
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getTodoAssignments(pageSize: 20);
    if (!mounted) return;
    setState(() {
      _loadFailed = data == null;
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
                  : _loadFailed
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded,
                                  size: 48, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              SerifText('加载失败', fontSize: 15,
                                  color: AppColors.text2Of(context)),
                              const SizedBox(height: 4),
                              Text('未能获取待办作业，请检查网络',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.text4Of(context))),
                              const SizedBox(height: 14),
                              AppGhostButton(
                                label: '重新加载',
                                onPressed: () {
                                  setState(() => _isLoading = true);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _list.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.5,
                                      child: Center(
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
                                                    fontSize: 12,
                                                    color: AppColors.text4Of(context))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                                  itemCount: _list.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, i) =>
                                      _AssignmentCard(
                                        item: _list[i],
                                        onCompleted: _load,
                                      ),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item, this.onCompleted});

  final Map<String, dynamic> item;

  /// 从详情页返回后的刷新回调（由外层 State 注入）。
  /// 此前卡片内部直接调 _load()，但 _load 定义在外层 State 上，
  /// StatelessWidget 引用不到，导致编译失败。
  final VoidCallback? onCompleted;

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
      0 => AppColors.amberOf(context),
      1 => AppColors.indigoOf(context),
      2 => AppColors.vermilionOf(context),
      _ => AppColors.amberOf(context),
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
              AppChip(label: statusText, type: statusColor == AppColors.vermilionOf(context)
                  ? ChipType.vermilion
                  : (statusColor == AppColors.indigoOf(context) ? ChipType.indigo : ChipType.amber)),
            ],
          ),
          const SizedBox(height: 8),
          if (item['items'] != null &&
              (item['items'] as List<dynamic>?)?.isNotEmpty == true)
            _buildItemsSummary(context, item['items'] as List<dynamic>)
          else
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
                onTap: () {
                  final id = item['instanceId'];
                  if (id == null) return;
                  context
                      .pushNamed(RouteNames.todoAssignmentDetail,
                          pathParameters: {'id': '$id'})
                      .then((_) => onCompleted?.call());
                },
                child: MonoText('去完成 →', fontSize: 11, color: AppColors.primaryOf(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 组合任务包：任务项摘要 chips
  Widget _buildItemsSummary(BuildContext context, List<dynamic> items) {
    final chips = items.map<Widget>((e) {
      final m = (e as Map).cast<String, dynamic>();
      final type = m['itemType'] as String? ?? '';
      final title = m['title'] as String? ?? '';
      final status = (m['status'] as num?)?.toInt() ?? 0;
      final done = status == 5;
      final typeColor = switch (type) {
        'CASE' => AppColors.vermilionOf(context),
        'PRACTICE' => AppColors.indigoOf(context),
        _ => AppColors.amberOf(context),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: done ? AppColors.mossTintOf(context) : AppColors.bgOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: done ? AppColors.moss.withValues(alpha: 0.5) : AppColors.ruleOf(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: done ? AppColors.moss : typeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              title.isEmpty ? '任务' : title,
              style: TextStyle(
                fontSize: 10,
                color: done ? AppColors.moss : AppColors.text2Of(context),
              ),
            ),
          ],
        ),
      );
    }).toList();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}