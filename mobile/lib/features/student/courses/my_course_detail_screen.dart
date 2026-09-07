import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_service.dart';

/// 学生端 · 课程（班级）主页
///
/// 校园风简约布局：
/// - 头部纸感课程信息卡
/// - TabBar（学习资料 / 作业）直接切换列表
/// 不再额外做功能入口按钮，避免与 TabBar 重复。
class MyCourseDetailScreen extends ConsumerStatefulWidget {
  const MyCourseDetailScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final int classId;
  final String className;

  @override
  ConsumerState<MyCourseDetailScreen> createState() =>
      _MyCourseDetailScreenState();
}

class _MyCourseDetailScreenState extends ConsumerState<MyCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  late final TabController _tabCtl;

  @override
  void initState() {
    super.initState();
    _tabCtl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await StudentService().getClassDetail(widget.classId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
    if (data != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final materials = data['materials'] as List<dynamic>? ?? const [];
        final assignments = data['assignments'] as List<dynamic>? ?? const [];
        if (materials.isEmpty && assignments.isNotEmpty && _tabCtl.index == 0) {
          _tabCtl.animateTo(1);
        }
      });
    }
  }

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: widget.className,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? _buildError()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Text('无法加载课程内容，请稍后重试',
          style: TextStyle(
              fontSize: 14, color: AppColors.text3Of(context))),
    );
  }

  Widget _buildBody() {
    final data = _data!;
    final name = (data['name'] ?? widget.className).toString();
    final teacher = (data['teacherName'] ?? '未知教师').toString();
    final school = (data['teacherSchool'] ?? '').toString();
    final count = (data['studentCount'] as num?)?.toInt() ?? 0;
    final joined = data['joinedAt'] == null
        ? ''
        : _shortDate(DateTime.tryParse(data['joinedAt'].toString()));
    final materials = (data['materials'] as List<dynamic>?) ?? const [];
    final assignments = (data['assignments'] as List<dynamic>?) ?? const [];

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: _buildHeader(name, teacher, school, count, joined)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabCtl,
              isScrollable: false,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.primaryOf(context),
              unselectedLabelColor: AppColors.text3Of(context),
              labelStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                    color: AppColors.primaryOf(context), width: 2.8),
              ),
              tabs: [
                _buildTab('学习资料', materials.length),
                _buildTab('作业', assignments.length),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabCtl,
        children: [
          _buildMaterialsTab(materials),
          _buildAssignmentsTab(assignments),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryOf(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOf(context),
                  )),
            ),
        ],
      ),
    );
  }

  // ---------------- 头部：纸感课程信息 ----------------
  Widget _buildHeader(
      String name, String teacher, String school, int count, String joined) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.mossTintOf(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      size: 22, color: AppColors.primaryOf(context)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SerifText(name,
                          fontSize: 18,
                          weight: FontWeight.w700,
                          height: 1.25),
                      if (school.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(school,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.text3Of(context))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metaText(Icons.person_outline_rounded, teacher),
                const SizedBox(width: 14),
                _metaText(Icons.groups_outlined, '$count 人'),
                if (joined.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  _metaText(Icons.schedule, joined),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.text4Of(context)),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
      ],
    );
  }

  // ---------------- Tab 内容 ----------------
  Widget _buildMaterialsTab(List<dynamic> materials) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryOf(context),
      child: ListView(
        key: const PageStorageKey('course_materials'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (materials.isEmpty)
            _emptyBox('老师还没有分享资料')
          else
            ...List.generate(materials.length, (i) => RiseIn(
                delay: Duration(milliseconds: i * 40),
                child: _materialCard(_mapOf(materials[i])))),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(List<dynamic> assignments) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryOf(context),
      child: ListView(
        key: const PageStorageKey('course_assignments'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (assignments.isEmpty)
            _emptyBox('暂无作业')
          else
            ...List.generate(assignments.length, (i) => RiseIn(
                delay: Duration(milliseconds: i * 40),
                child: _assignmentCard(_mapOf(assignments[i])))),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(fontSize: 13, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }

  // ---------------- 资料卡片 ----------------
  Widget _materialCard(Map<String, dynamic> m) {
    final title = (m['lessonTitle'] ?? '未命名资料').toString();
    final dep = (m['department'] ?? '').toString();
    final mats = m['materials'] as List<dynamic>? ?? const [];
    final deadline = m['deadline'] ?? '';
    final publishId = (m['publishId'] as num?)?.toInt() ?? 0;
    final materialOnly = m['materialOnly'] == true;
    final completed = m['completed'] == true;
    return AppPressable(
      onTap: () {
        if (publishId == 0) {
          AppFeedback.info(context, '资料暂不可用');
          return;
        }
        context.pushNamed(
          RouteNames.courseMaterialDetail,
          pathParameters: {'publishId': '$publishId'},
          extra: {
            'classId': widget.classId,
            'title': title,
            'material': m,
          },
        ).then((_) => _refresh());
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.indigoSoftOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.folder_open_rounded,
                  size: 20, color: AppColors.indigoOf(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOf(context))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _tagRow(Icons.description_outlined,
                          '${mats.length} 个文件'),
                      if (dep.isNotEmpty) _tagRow(Icons.category_outlined, dep),
                      // 待办联动：独立资料的完成状态一眼可见
                      if (materialOnly)
                        _stateChip(completed
                            ? ('已完成', AppColors.primaryOf(context))
                            : ('待完成', AppColors.amberOf(context))),
                    ],
                  ),
                  if (deadline != null && deadline.toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _tagRow(Icons.schedule,
                        '截止 ${_shortDate(DateTime.tryParse(deadline.toString()))}'),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _tagRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.text4Of(context)),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
      ],
    );
  }

  /// 状态小徽章（资料完成态）
  Widget _stateChip((String, Color) state) {
    final (label, color) = state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ---------------- 作业卡片 ----------------
  Widget _assignmentCard(Map<String, dynamic> a) {
    final title = (a['title'] ?? '未命名作业').toString();
    final description = (a['description'] ?? '').toString();
    final deadline = a['deadline'] ?? '';
    final myStatus = (a['myStatus'] as num?)?.toInt() ?? 0;
    final instanceId = (a['instanceId'] as num?)?.toInt();
    return AppPressable(
      onTap: () {
        if (instanceId == null || instanceId == 0) {
          AppFeedback.info(context, '该作业尚未生成作答实例');
          return;
        }
        context
            .pushNamed(RouteNames.todoAssignmentDetail,
                pathParameters: {'id': '$instanceId'})
            .then((_) => _refresh());
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.task_alt_rounded,
                  size: 20, color: AppColors.primaryOf(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textOf(context))),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(myStatus),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.text3Of(context))),
                  ],
                  const SizedBox(height: 8),
                  _tagRow(Icons.schedule, _deadlineText(deadline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _deadlineText(dynamic deadline) {
    if (deadline == null || deadline.toString().isEmpty) return '未设置截止时间';
    return '截止 ${_shortDate(DateTime.tryParse(deadline.toString()))}';
  }

  Widget _statusBadge(int status) {
    final (label, color) = switch (status) {
      5 => ('已完成', AppColors.primaryOf(context)),
      1 => ('进行中', AppColors.indigoOf(context)),
      2 => ('已打回', AppColors.vermilionOf(context)),
      _ => ('未开始', AppColors.amberOf(context)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Map<String, dynamic> _mapOf(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  String _shortDate(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    return '${local.year}-${_p(local.month)}-${_p(local.day)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

/// 用于把 TabBar 固定在 Sliver 头部下方
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.bgOf(context),
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => false;
}