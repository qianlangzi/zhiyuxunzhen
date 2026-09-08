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
/// 设计口径（2026-09-08 重构）：
/// 1. 待办 = 各科老师布置的作业 + 教师发放的资料任务，卡片上必须能看出「哪位老师 / 哪门课」；
/// 2. 强时效性：按截止时间升序（越紧急越靠前），卡片显示剩余时间，逾期不可补交的沉到「已截止」折叠区；
/// 3. 课程页只做无数字红点提示，数量与时效提醒统一收口在本页。
class TodoAssignmentsScreen extends ConsumerStatefulWidget {
  const TodoAssignmentsScreen({super.key});

  @override
  ConsumerState<TodoAssignmentsScreen> createState() =>
      _TodoAssignmentsScreenState();
}

class _TodoAssignmentsScreenState extends ConsumerState<TodoAssignmentsScreen> {
  List<_TodoItem> _items = [];
  bool _isLoading = true;
  /// 加载失败标记：与「真的没有待办」区分开，避免把网络故障误报为空态
  bool _loadFailed = false;
  /// 「已截止」折叠区是否展开
  bool _closedExpanded = false;

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

    final items = <_TodoItem>[];
    // 1) 作业实例
    for (final e in (data?['list'] as List<dynamic>? ?? const [])) {
      final m = (e as Map).cast<String, dynamic>();
      items.add(_TodoItem.assignment(m));
    }
    // 2) 资料任务（materialOnly=1 且未标记完成）
    for (final t in tasks ?? const []) {
      final m = (t as Map).cast<String, dynamic>();
      if ((m['materialOnly'] as num?)?.toInt() != 1) continue;
      if (m['completed'] == true) continue;
      items.add(_TodoItem.lesson(m));
    }
    _sortItems(items);

    setState(() {
      _loadFailed = data == null;
      _items = items;
      _isLoading = false;
    });
  }

  /// 排序：未截止按截止时间升序（紧急优先、无截止时间垫底）→ 逾期但可补交 → 已截止沉底
  void _sortItems(List<_TodoItem> items) {
    int rank(_TodoItem x) => x.isOverdue ? (x.canSubmitLate ? 1 : 2) : 0;
    items.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      final da = a.deadline;
      final db = b.deadline;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      // 已截止组：最近截止的排前面（更容易补做）
      return ra == 0 ? da.compareTo(db) : db.compareTo(da);
    });
  }

  List<_TodoItem> get _active =>
      _items.where((e) => !e.isOverdue || e.canSubmitLate).toList();
  List<_TodoItem> get _closed =>
      _items.where((e) => e.isOverdue && !e.canSubmitLate).toList();

  /// 48 小时内到期（含已逾期但可补交）的数量，用于顶部汇总卡提示
  int get _urgentCount => _active
      .where((e) =>
          e.deadline != null &&
          e.deadline!.difference(DateTime.now()).inHours < 48)
      .length;

  /// 按课程分组，保持组内紧急优先
  List<_CourseGroup> _grouped(List<_TodoItem> src) {
    final map = <String, List<_TodoItem>>{};
    final order = <String>[];
    for (final it in src) {
      final key = it.className.isEmpty
          ? (it.kind == _TodoKind.lesson ? '学习资料' : '我的作业')
          : it.className;
      map.putIfAbsent(key, () {
        order.add(key);
        return <_TodoItem>[];
      }).add(it);
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
                      : _items.isEmpty
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
    final groups = _grouped(_active);
    final closed = _closed;
    final primary = AppColors.primaryOf(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // 顶部汇总卡：待办总数 + 紧急提示
        RiseIn(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.mossTintOf(context),
                  AppColors.surfaceOf(context)
                ],
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
                      SerifText('共 ${_active.length} 项待完成',
                          fontSize: 16, weight: FontWeight.w700),
                      const SizedBox(height: 4),
                      Text(
                        _urgentCount > 0
                            ? '$_urgentCount 项 48 小时内截止，先做紧急的'
                            : '${groups.length} 个课程的作业汇总于此',
                        style: TextStyle(
                            fontSize: 12,
                            color: _urgentCount > 0
                                ? AppColors.vermilionOf(context)
                                : AppColors.text3Of(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (groups.isEmpty && closed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('当前没有进行中的作业',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.text3Of(context))),
          ),
        // 按课程分组
        for (var gi = 0; gi < groups.length; gi++) ...[
          _buildGroupHeader(groups[gi], gi),
          for (var i = 0; i < groups[gi].items.length; i++)
            RiseIn(
              delay: Duration(milliseconds: 40 + (gi * 3 + i) * 45),
              child: groups[gi].items[i].kind == _TodoKind.lesson
                  ? _LessonCard(item: groups[gi].items[i], onCompleted: _load)
                  : _AssignmentCard(
                      item: groups[gi].items[i], onCompleted: _load),
            ),
        ],
        // 已截止折叠区：不再占用注意力，但可展开查看
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildClosedSection(closed),
        ],
      ],
    );
  }

  Widget _buildClosedSection(List<_TodoItem> closed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _closedExpanded = !_closedExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.lock_clock_rounded,
                      size: 16, color: AppColors.text3Of(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('已截止 ${closed.length} 项',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2Of(context))),
                  ),
                  Text('已结束',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text4Of(context))),
                  const SizedBox(width: 4),
                  Icon(
                    _closedExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.text4Of(context),
                  ),
                ],
              ),
            ),
          ),
          if (_closedExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  for (final it in closed)
                    Opacity(
                      opacity: 0.62,
                      child: it.kind == _TodoKind.lesson
                          ? _LessonCard(item: it, onCompleted: _load)
                          : _AssignmentCard(item: it, onCompleted: _load),
                    ),
                ],
              ),
            ),
        ],
      ),
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
          MonoText('${g.items.length} 项',
              fontSize: 11, color: AppColors.text4Of(context)),
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
          Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.text4Of(context)),
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

/// 待办类型：作业实例 / 资料任务
enum _TodoKind { assignment, lesson }

/// 统一待办模型：屏蔽作业与资料的字段差异，便于统一排序与渲染
class _TodoItem {
  const _TodoItem({
    required this.kind,
    required this.raw,
    required this.title,
    required this.teacherName,
    required this.className,
    required this.deadline,
    required this.overdue,
    required this.canSubmitLate,
  });

  final _TodoKind kind;
  final Map<String, dynamic> raw;
  final String title;
  final String teacherName;
  final String className;
  final DateTime? deadline;
  final bool overdue;
  final bool canSubmitLate;

  factory _TodoItem.assignment(Map<String, dynamic> m) {
    final deadline = _parseDate(m['deadline']);
    final now = DateTime.now();
    final overdue = (m['overdue'] as bool?) ??
        (deadline != null && now.isAfter(deadline));
    // 后端已算好补交窗口，未返回字段时按「允许补交」兜底
    final canLate = (m['canSubmitLate'] as bool?) ??
        (overdue && (m['allowLateSubmit'] as bool? ?? false));
    return _TodoItem(
      kind: _TodoKind.assignment,
      raw: m,
      title: (m['assignmentTitle'] as String?) ?? '未命名作业',
      teacherName: (m['teacherName'] as String?)?.trim() ?? '',
      className: (m['className'] as String?)?.trim() ?? '',
      deadline: deadline,
      overdue: overdue,
      canSubmitLate: canLate,
    );
  }

  factory _TodoItem.lesson(Map<String, dynamic> m) {
    final deadline = _parseDate(m['deadline']);
    final now = DateTime.now();
    return _TodoItem(
      kind: _TodoKind.lesson,
      raw: m,
      title: (m['lessonTitle'] as String?) ?? '未命名资料',
      teacherName: (m['teacherName'] as String?)?.trim() ?? '',
      className: (m['className'] as String?)?.trim() ?? '',
      deadline: deadline,
      overdue: deadline != null && now.isAfter(deadline),
      canSubmitLate: false,
    );
  }

  bool get isOverdue => overdue;

  /// 兼容后端 LocalDateTime 的两种序列化格式（带/不带 T）
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }
}

/// 课程分组：课程名 + 该课程待办列表
class _CourseGroup {
  const _CourseGroup(this.name, this.items);
  final String name;
  final List<_TodoItem> items;
}

/// 单条待办作业卡片 · 突出「哪位老师布置 + 还剩多久」
class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item, this.onCompleted});

  final _TodoItem item;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final m = item.raw;
    final status = (m['status'] as num?)?.toInt() ?? 0;
    final caseTitle = (m['caseTitle'] as String?) ?? '未分配病例';

    final (statusText, statusColor) = switch (status) {
      1 => ('问诊中', AppColors.indigoOf(context)),
      2 => ('格式打回', AppColors.vermilionOf(context)),
      _ => ('待完成', AppColors.amberOf(context)),
    };
    final due = _DueBadge(item: item);

    return AppPressable(
      onTap: () {
        final id = m['instanceId'];
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
                  child: SerifText(item.title,
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
            // 来源信息：哪门课 · 哪位老师（多科作业混排的关键区分）
            _SourceLine(item: item),
            const SizedBox(height: 8),
            if (m['items'] != null &&
                (m['items'] as List<dynamic>?)?.isNotEmpty == true)
              _buildItemsSummary(context, m['items'] as List<dynamic>)
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
                due,
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
          color:
              done ? AppColors.mossTintOf(context) : AppColors.paper2Of(context),
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

/// 资料任务卡片 · 教师发布的备课资料（看完可在详情页标记完成）
class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.item, this.onCompleted});

  final _TodoItem item;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final m = item.raw;
    final dep = (m['department'] as String?) ?? '';
    final files = (m['materials'] as List<dynamic>?) ?? const [];

    return AppPressable(
      onTap: () {
        final publishId = (m['publishId'] as num?)?.toInt();
        final classId = (m['classId'] as num?)?.toInt();
        if (publishId == null || publishId == 0 || classId == null) {
          AppFeedback.info(context, '资料暂不可用');
          return;
        }
        context
            .pushNamed(RouteNames.courseMaterialDetail,
                pathParameters: {'publishId': '$publishId'},
                extra: {
                  'classId': classId,
                  'title': item.title,
                  'material': m,
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
                  child: SerifText(item.title,
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
            _SourceLine(item: item),
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
                        : '${files.length} 个文件${dep.isEmpty ? '' : ' · $dep'}',
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
                _DueBadge(item: item),
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

/// 来源行：课程 · 老师（多科老师布置时区分来源）
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.item});

  final _TodoItem item;

  @override
  Widget build(BuildContext context) {
    final segs = <String>[
      if (item.className.isNotEmpty) item.className,
      if (item.teacherName.isNotEmpty) '${item.teacherName} 老师',
    ];
    if (segs.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.school_outlined, size: 13, color: AppColors.text4Of(context)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(segs.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: AppColors.text3Of(context))),
        ),
      ],
    );
  }
}

/// 时效徽章：剩余时间 / 已逾期 / 可补交
class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.item});

  final _TodoItem item;

  @override
  Widget build(BuildContext context) {
    final text = item.dueLabel;
    final urgent = item.dueLevel;
    final color = switch (urgent) {
      _DueLevel.expired => AppColors.vermilionOf(context),
      _DueLevel.soon => AppColors.vermilionOf(context),
      _DueLevel.near => AppColors.amberOf(context),
      _ => AppColors.text3Of(context),
    };
    final filled = urgent == _DueLevel.expired || urgent == _DueLevel.soon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: filled ? null : Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

/// 紧急度分档
enum _DueLevel { none, normal, near, soon, expired }

extension _TodoItemDue on _TodoItem {
  _DueLevel get dueLevel {
    final d = deadline;
    if (d == null) return _DueLevel.none;
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) {
      return canSubmitLate ? _DueLevel.soon : _DueLevel.expired;
    }
    if (diff.inHours < 24) return _DueLevel.soon;
    if (diff.inDays < 3) return _DueLevel.near;
    return _DueLevel.normal;
  }

  String get dueLabel {
    final d = deadline;
    if (d == null) return '无截止时间';
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) {
      return canSubmitLate ? '已逾期 · 可补交' : '已截止';
    }
    if (diff.inMinutes < 60) return '剩 ${diff.inMinutes} 分钟';
    if (diff.inHours < 24) return '剩 ${diff.inHours} 小时';
    if (diff.inDays < 3) return '剩 ${diff.inDays} 天';
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 截止';
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
    Icon icon = Icon(Icons.arrow_forward_rounded, size: 14, color: primary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [text, const SizedBox(width: 2), icon],
    );
  }
}
