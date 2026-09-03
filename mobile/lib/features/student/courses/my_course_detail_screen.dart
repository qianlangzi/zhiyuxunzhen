import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_service.dart';

/// 学生端 · 班级详情（与教师端闭环）
///
/// 展示该班授课教师信息，以及老师分享到该班级的学习资料与作业。
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

class _MyCourseDetailScreenState extends ConsumerState<MyCourseDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await StudentService().getClassDetail(widget.classId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    final data = await StudentService().getClassDetail(widget.classId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bgOf(context);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: widget.className, onBack: context.pop),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primaryOf(context),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = _data;
    if (data == null) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text('无法加载课程内容，请稍后重试',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.text3Of(context))),
        ],
      );
    }
    final name = (data['name'] ?? widget.className).toString();
    final teacher = (data['teacherName'] ?? '未知教师').toString();
    final school = (data['teacherSchool'] ?? '').toString();
    final count = (data['studentCount'] as num?)?.toInt() ?? 0;
    final materials = data['materials'] as List<dynamic>? ?? const [];
    final assignments = data['assignments'] as List<dynamic>? ?? const [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _buildHeader(name, teacher, school, count),
        const SizedBox(height: 20),
        _sectionTitle('学习资料', materials.length, Icons.folder_open_rounded),
        const SizedBox(height: 10),
        if (materials.isEmpty)
          _emptyBox('老师还没有分享资料')
        else
          ...materials.map((m) => _materialCard(_mapOf(m))),
        const SizedBox(height: 20),
        _sectionTitle('作业', assignments.length, Icons.task_alt_rounded),
        const SizedBox(height: 10),
        if (assignments.isEmpty)
          _emptyBox('暂无作业')
        else
          ...assignments.map((a) => _assignmentCard(_mapOf(a))),
      ],
    );
  }

  Widget _buildHeader(
      String name, String teacher, String school, int count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryOf(context),
            const Color(0xFF7C93FF),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.lifted(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(teacher,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.95))),
            ],
          ),
          if (school.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(school,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8))),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count 名同学',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.95))),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryOf(context)),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textOf(context))),
        const SizedBox(width: 8),
        Text('$count 项',
            style: TextStyle(
                fontSize: 12, color: AppColors.text3Of(context))),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 13, color: AppColors.text3Of(context))),
    );
  }

  Widget _materialCard(Map<String, dynamic> m) {
    final title = (m['lessonTitle'] ?? '未命名资料').toString();
    final dep = (m['department'] ?? '').toString();
    final mats = m['materials'] as List<dynamic>? ?? const [];
    final deadline = m['deadline'] ?? '';
    final matCount = mats.length;
    return AppPressable(
      onTap: () => AppFeedback.info(context, '点击资料条目可在「学习任务」中查看'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined,
                    size: 18, color: AppColors.primaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOf(context))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip('${matCount} 个文件', Icons.description_outlined),
                if (dep.isNotEmpty) _chip(dep, Icons.category_outlined),
                if (deadline != null && deadline.toString().isNotEmpty)
                  _chip('截止 ${_shortDate(DateTime.tryParse(deadline.toString()))}',
                      Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignmentCard(Map<String, dynamic> a) {
    final title = (a['title'] ?? '未命名作业').toString();
    final deadline = a['deadline'] ?? '';
    final myStatus = (a['myStatus'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context).withValues(alpha: 0.12),
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
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context))),
                const SizedBox(height: 4),
                Text(_deadlineText(deadline),
                    style: TextStyle(
                        fontSize: 12, color: AppColors.text3Of(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(myStatus),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.text3Of(context)),
          const SizedBox(width: 4),
          Text(text,
              style:
                  TextStyle(fontSize: 11, color: AppColors.text2Of(context))),
        ],
      ),
    );
  }

  String _deadlineText(dynamic deadline) {
    if (deadline == null || deadline.toString().isEmpty) return '未设置截止时间';
    return '截止 ${_shortDate(DateTime.tryParse(deadline.toString()))}';
  }

  Widget _statusBadge(int status) {
    // 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成
    final (label, color) = switch (status) {
      5 => ('已完成', const Color(0xFF16A34A)),
      1 => ('进行中', const Color(0xFF2563EB)),
      2 => ('已打回', const Color(0xFFEA580C)),
      _ => ('未开始', AppColors.text4Of(context)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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