import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 待办作业 · 按课程分组汇总（校园风）
///
/// 各课程（班级）的待办作业汇总在一起，按班级分组展示，点卡片直接跳转作业详情。
/// 顶部是该学生「全部待办」汇总卡；每个分组带课程名与合计条数。
class TodoAssignmentsScreen extends ConsumerStatefulWidget {
  const TodoAssignmentsScreen({super.key});

  @override
  ConsumerState<TodoAssignmentsScreen> createState() =>
      _TodoAssignmentsScreenState();
}

class _TodoAssignmentsScreenState extends ConsumerState<TodoAssignmentsScreen> {
  List<Map<String, dynamic>> _list = [];
  /// 资料任务待办（教师发布 materialOnly=1 的备课资料，未标记完成的）
  List<Map<String, dynamic>> _lessonTasks = [];
  bool _isLoading = true;
  /// 加载失败标记：与「真的没有待办」区分开，避免把网络故障误报为空态
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // 并行拉取：作业待办 + 资料任务（后端已完成态过滤，这里再防御一遍）
    final results = await Future.wait<Object?>([
      StudentService().getTodoAssignments(pageSize: 50),
      StudentService().getStudentTasks(),
    ]);
    if (!mounted) return;
    final data = results[0] as Map<String, dynamic>?;
    final tasks = results[1] as List<dynamic>?;
    final lessons = tasks
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .where((m) =>
                (m['materialOnly'] as num?)?.toInt() == 1 &&
                m['completed'] != true)
            .toList() ??
        <Map<String, dynamic>>[];
    setState(() {
      _loadFailed = data == null;
      _list =
          (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      _lessonTasks = lessons;
      _isLoading = false;
    });
  }

  int get _totalCount => _list.length + _lessonTasks.length;

  /// 按「课程名」分组，作业与资料任务混排；无课程名的归入兜底组。
  List<_CourseGroup> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];
    void add(String key, Map<String, dynamic> item) {
      map.putIfAbsent(key, () {
        order.add(key);
        return <Map<String, dynamic>>[];
      }).add(item);
    }

    for (final item in _list) {
      final name = (item['className'] as String?)?.trim() ?? '';
      add(name.isEmpty ? '我的作业' : name, item);
    }
    for (final t in _lessonTasks) {
      final name = (t['className'] as String?)?.trim() ?? '';
      add(name.isEmpty ? '学习资料' : name, t);
    }
    return order.map((k) => _CourseGroup(k, map[k]!)).toList();
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
                      ? _buildLoadFailed()
                      : _totalCount == 0
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primaryOf(context),
                              child: _buildList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final groups = _grouped();
    final primary = AppColors.primaryOf(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // 顶部汇总卡：全部待办数
        RiseIn(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mossTintOf(context), AppColors.surfaceOf(context)],
              ),
              border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.task_alt_rounded,
                      color: AppColors.onPrimaryOf(context), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SerifText('共 $_totalCount 项待完成',
                          fontSize: 16, weight: FontWeight.w700),
                      const SizedBox(height: 4),
                      Text('${groups.length} 个课程的作业汇总于此',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.text3Of(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // 按课程分组
        for (var gi = 0; gi < groups.length; gi++) ...[
          _buildGroupHeader(groups[gi], gi),
          for (var i = 0; i < groups[gi].items.length; i++) RiseIn(
            delay: Duration(milliseconds: 40 + (gi * 3 + i) * 45),
            child: _AssignmentCard(
              item: groups[gi].items[i],
              onCompleted: _load,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(_CourseGroup g, int index) {
    final accent = _groupAccent(index);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SerifText(g.name, fontSize: 14, weight: FontWeight.w700),
          ),
          MonoText('${g.items.length} 项', fontSize: 11, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  Color _groupAccent(int index) {
    switch (index % 4) {
      case 0:
        return AppColors.primaryOf(context);
      case 1:
        return AppColors.indigoOf(context);
      case 2:
        return AppColors.amberOf(context);
      default:
        return AppColors.vermilionOf(context);
    }
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt_rounded,
                    size: 48, color: AppColors.text4Of(context)),
                const SizedBox(height: 12),
                SerifText('暂无待办作业',
                    fontSize: 15, color: AppColors.text2Of(context)),
                const SizedBox(height: 4),
                Text('所有作业都已完成，继续保持',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.text4Of(context))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadFailed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          SerifText('加载失败', fontSize: 15, color: AppColors.text2Of(context)),
          const SizedBox(height: 4),
          Text('未能获取待办作业，请检查网络',
              style:
                  TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
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
    );
  }
}

/// 课程分组：课程名 + 该课程待办列表
class _CourseGroup {
  const _CourseGroup(this.name, this.items);
  final String name;
  final List<Map<String, dynamic>> items;
}

/// 单条待办作业卡片 · 校园风精致版
class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item, this.onCompleted});

  final Map<String, dynamic> item;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final title = item['assignmentTitle'] as String? ?? '未命名作业';
    final caseTitle = item['caseTitle'] as String? ?? '未分配病例';
    final status = (item['status'] as num?)?.toInt() ?? 0;
    final deadline = item['deadline'] as String?;

    final (statusText, statusColor) = switch (status) {
      1 => ('问诊中', AppColors.indigoOf(context)),
      2 => ('格式打回', AppColors.vermilionOf(context)),
      _ => ('待完成', AppColors.amberOf(context)),
    };

    return AppPressable(
      onTap: () {
        final id = item['instanceId'];
        if (id == null) return;
        context
            .pushNamed(RouteNames.todoAssignmentDetail,
                pathParameters: {'id': '$id'})
            .then((_) => onCompleted?.call());
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SerifText(title,
                      fontSize: 15, weight: FontWeight.w700, height: 1.3),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item['items'] != null &&
                (item['items'] as List<dynamic>?)?.isNotEmpty == true)
              _buildItemsSummary(context, item['items'] as List<dynamic>)
            else
              Row(
                children: [
                  Icon(Icons.article_outlined,
                      size: 14, color: AppColors.text4Of(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(caseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.text2Of(context))),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (deadline != null && deadline.isNotEmpty) ...[
                  Icon(Icons.schedule, size: 13, color: AppColors.text4Of(context)),
                  const SizedBox(width: 4),
                  MonoText('截止 $deadline',
                      fontSize: 10, color: AppColors.text4Of(context)),
                ],
                const Spacer(),
                _MoreLink(label: '去完成'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 组合任务包：任务项摘要 chips（正文点缀，非绿色解释块）
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
          color: done
              ? AppColors.mossTintOf(context)
              : AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: done ? AppColors.primaryOf(context) : typeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              title.isEmpty ? '任务' : title,
              style: TextStyle(
                fontSize: 10,
                color: done
                    ? AppColors.primaryOf(context)
                    : AppColors.text2Of(context),
              ),
            ),
          ],
        ),
      );
    }).toList();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

/// 去完成链接（灵动：右箭头 + 主色）
class _MoreLink extends StatelessWidget {
  const _MoreLink({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    Text text = Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        color: primary,
        fontWeight: FontWeight.w600,
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: kCjkMonoFallback,
      ),
    );
    Icon icon = Icon(Icons.arrow_forward_rounded,
        size: 14, color: primary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [text, const SizedBox(width: 2), icon],
    );
  }
}

/// 资料任务卡片 · 教师发布的备课资料（看完可在详情页标记完成）
class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.item, this.onCompleted});

  final Map<String, dynamic> item;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final title = (item['lessonTitle'] as String?) ?? '未命名资料';
    final dep = (item['department'] as String?) ?? '';
    final deadline = item['deadline'] as String?;
    final files = (item['materials'] as List<dynamic>?) ?? const [];

    return AppPressable(
      onTap: () {
        final publishId = (item['publishId'] as num?)?.toInt();
        final classId = (item['classId'] as num?)?.toInt();
        if (publishId == null || publishId == 0) {
          AppFeedback.info(context, '资料暂不可用');
          return;
        }
        if (classId == null || classId == 0) {
          AppFeedback.info(context, '资料暂不可用');
          return;
        }
        context
            .pushNamed(RouteNames.courseMaterialDetail,
                pathParameters: {'publishId': '$publishId'},
                extra: {
                  'classId': classId,
                  'title': title,
                  'material': item,
                })
            .then((_) => onCompleted?.call());
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SerifText(title,
                      fontSize: 15, weight: FontWeight.w700, height: 1.3),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.indigoOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('资料学习',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.indigoOf(context))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.folder_open_rounded,
                    size: 14, color: AppColors.text4Of(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    files.isEmpty
                        ? (dep.isEmpty ? '学习资料' : dep)
                        : '$files 个文件${dep.isEmpty ? '' : ' · $dep'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.text2Of(context)),
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
                  MonoText('截止 $deadline',
                      fontSize: 10, color: AppColors.text4Of(context)),
                ],
                const Spacer(),
                _MoreLink(label: '去学习'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}