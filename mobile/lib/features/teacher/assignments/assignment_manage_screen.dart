import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 作业管理（学习通式）
///
/// 第一层：列出「每一次具体作业」（标题 / 面向班级 / 截止 / 进度）。
/// 点击某次作业进入 AssignmentDetailScreen，按 班级 → 学生 两级查看
/// 该作业的「待批阅 / 已批阅」批阅任务。
class AssignmentManageScreen extends ConsumerStatefulWidget {
  const AssignmentManageScreen({super.key, this.classId});

  /// 从班级详情进入时按班过滤；为空则显示全部
  final int? classId;

  @override
  ConsumerState<AssignmentManageScreen> createState() =>
      _AssignmentManageScreenState();
}

class _AssignmentManageScreenState
    extends ConsumerState<AssignmentManageScreen> {
  List<Map<String, dynamic>> _assignments = [];
  final Map<int, _AssignmentStat> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> assignments = [];
    List<Map<String, dynamic>> reviews = [];
    try {
      assignments = (await TeacherService().getAssignmentList())
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      reviews = await TeacherService().getReviewQueue(classId: widget.classId);
    } catch (e) {
      debugPrint('loadAssignmentManage error: $e');
    }
    // 按 assignmentId 统计待批阅(3/4) / 已批阅(5) 数量
    final stats = <int, _AssignmentStat>{};
    for (final it in reviews) {
      final aid = (it['assignmentId'] as num?)?.toInt();
      if (aid == null) continue;
      final s = (it['instanceStatus'] as num?)?.toInt() ?? 0;
      final st = stats.putIfAbsent(aid, _AssignmentStat.new);
      if (s == 3 || s == 4) st.pending++;
      if (s == 5) st.reviewed++;
    }
    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _stats
        ..clear()
        ..addAll(stats);
      _isLoading = false;
    });
  }

  void _openDetail(Map<String, dynamic> assignment) {
    final id = (assignment['id'] as num?)?.toInt();
    if (id == null) {
      AppFeedback.error(context, '缺少作业信息，暂无法打开');
      return;
    }
    final title = (assignment['title'] as String?) ??
        (assignment['caseTitle'] as String?) ??
        '未命名作业';
    context.pushNamed(
      RouteNames.assignmentDetail,
      extra: {'classId': widget.classId},
      pathParameters: {'id': '$id'},
      queryParameters: {'title': title},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTitleAppBar(
              tag: '教师端 · 作业',
              title: '作业管理',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.teacherHome),
              action: AppPrimaryButton(
                label: '新建作业',
                small: true,
                onPressed: () => context.pushNamed(RouteNames.assignmentCreate),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _assignments.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 110),
                          itemCount: _assignments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) =>
                              _assignmentCard(_assignments[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignmentCard(Map<String, dynamic> a) {
    final id = (a['id'] as num?)?.toInt();
    final title = (a['title'] as String?) ??
        (a['caseTitle'] as String?) ??
        '未命名作业';
    final classNames = (a['classNames'] as List<dynamic>?)
        ?.map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .join(' · ');
    final classText = (classNames == null || classNames.isEmpty)
        ? '未指定班级'
        : classNames;
    final studentCount = (a['studentCount'] as num?)?.toInt() ?? 0;
    final submitted = (a['submittedCount'] as num?)?.toInt() ?? 0;
    final deadline = _parseDate(a['deadline']);
    final stat = _stats[id] ?? _AssignmentStat();

    final rate = studentCount > 0 ? submitted * 100 ~/ studentCount : 0;

    return PressableScale(
      child: GestureDetector(
        onTap: id == null ? null : () => _openDetail(a),
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
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.mossTintOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.edit_note_rounded,
                        size: 22, color: AppColors.primaryOf(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SerifText(title,
                        fontSize: 15, color: AppColors.textOf(context)),
                  ),
                  if (stat.pending > 0) ...[
                    AppChip(
                        label: '待批阅 ${stat.pending}',
                        type: ChipType.vermilion,
                        fontSize: 10),
                    const SizedBox(width: 6),
                  ],
                  if (stat.reviewed > 0)
                    AppChip(
                        label: '已批阅 ${stat.reviewed}',
                        type: ChipType.moss,
                        fontSize: 10),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.groups_rounded,
                      size: 13, color: AppColors.text3Of(context)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      classText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text3Of(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: AppColors.text4Of(context)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _deadlineText(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text4Of(context)),
                    ),
                  ),
                  if (id != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      onTap: () => _showSettingsSheet(a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 13, color: AppColors.primaryOf(context)),
                            const SizedBox(width: 3),
                            Text('设置',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryOf(context))),
                          ],
                        ),
                      ),
                    ),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.text4Of(context)),
                ],
              ),
              const SizedBox(height: 12),
              _progressRow(rate, submitted, studentCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressRow(int rate, int submitted, int studentCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('已提交 $submitted / $studentCount',
                style: TextStyle(
                    fontSize: 10.5, color: AppColors.text3Of(context))),
            const Spacer(),
            MonoText('$rate%', fontSize: 10, color: AppColors.primaryOf(context)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: studentCount > 0 ? submitted / studentCount : 0,
            minHeight: 6,
            backgroundColor: AppColors.ruleSoftOf(context),
            valueColor:
                AlwaysStoppedAnimation(AppColors.primaryOf(context)),
          ),
        ),
      ],
    );
  }

  /// 作业设置底部面板：延期 / 补交窗口（学习通式）
  void _showSettingsSheet(Map<String, dynamic> a) {
    final id = (a['id'] as num?)?.toInt();
    if (id == null) return;
    DateTime? deadline = _parseDate(a['deadline']);
    DateTime? lateDeadline = _parseDate(a['lateDeadline']);
    bool allowLate = a['allowLateSubmit'] == true || lateDeadline != null;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.primaryOf(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SerifText('作业设置',
                        fontSize: 16, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('延长截止时间或开放补交窗口，学生端待办会实时更新',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.text3Of(context))),
              const SizedBox(height: 16),
              _sheetTimeRow(
                ctx,
                icon: Icons.event_available_outlined,
                label: deadline == null ? '选择截止时间' : '截止 ${_fmt(deadline)}',
                onTap: () async {
                  final picked = await _pickDateTime(ctx, deadline, '选择截止时间');
                  if (picked != null) setSheet(() => deadline = picked);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('允许补交（逾期后仍可提交）',
                        style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.text2Of(context))),
                  ),
                  Switch(
                    value: allowLate,
                    activeThumbColor: AppColors.primaryOf(context),
                    onChanged: (v) => setSheet(() {
                      allowLate = v;
                      if (!v) lateDeadline = null;
                    }),
                  ),
                ],
              ),
              if (allowLate) ...[
                const SizedBox(height: 8),
                _sheetTimeRow(
                  ctx,
                  icon: Icons.more_time_rounded,
                  label: lateDeadline == null
                      ? '选择补交截止时间'
                      : '补交截止 ${_fmt(lateDeadline)}',
                  onTap: () async {
                    final picked =
                        await _pickDateTime(ctx, lateDeadline ?? deadline, '选择补交截止时间');
                    if (picked != null) setSheet(() => lateDeadline = picked);
                  },
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: saving ? '保存中…' : '保存设置',
                  onPressed: saving
                      ? null
                      : () async {
                          if (deadline == null) {
                            AppFeedback.info(context, '请选择截止时间');
                            return;
                          }
                          if (allowLate) {
                            if (lateDeadline == null) {
                              AppFeedback.info(context, '允许补交时请选择补交截止时间');
                              return;
                            }
                            if (!lateDeadline!.isAfter(deadline!)) {
                              AppFeedback.info(context, '补交截止时间必须晚于截止时间');
                              return;
                            }
                          }
                          setSheet(() => saving = true);
                          final ok = await TeacherService()
                              .updateAssignmentSettings(id, {
                            'deadline': deadline!.toIso8601String(),
                            'allowLateSubmit': allowLate,
                            'lateDeadline':
                                allowLate ? lateDeadline?.toIso8601String() : null,
                          });
                          if (!mounted) return;
                          setSheet(() => saving = false);
                          if (!ok) {
                            AppFeedback.error(context, '保存失败，请重试');
                            return;
                          }
                          Navigator.of(sheetCtx).pop();
                          AppFeedback.success(context, '作业设置已更新');
                          await _load();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTimeRow(BuildContext ctx,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgOf(ctx),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ruleOf(ctx)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.amberOf(ctx)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: label.contains('选择')
                          ? AppColors.text3Of(ctx)
                          : AppColors.textOf(ctx),
                      fontFamily: 'JetBrainsMono')),
            ),
            Icon(Icons.edit_calendar_outlined,
                size: 16, color: AppColors.text4Of(ctx)),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
      BuildContext ctx, DateTime? initial, String help) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(days: 3));
    final date = await showDatePicker(
      context: ctx,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: help,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null) return null;
    if (!ctx.mounted) return null;
    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: help,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  String _fmt(DateTime? t) => t == null
      ? ''
      : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 截止时间文案（含补交窗口）
  String _deadlineText(Map<String, dynamic> a) {
    final d = a['deadline'] as String? ?? '';
    if (d.isEmpty) return '无截止时间';
    final late = a['lateDeadline'] as String? ?? '';
    final base = '截止 ${_formatDeadline(d)}';
    if (a['allowLateSubmit'] == true && late.isNotEmpty) {
      return '$base · 补交至 ${_formatDeadline(late)}';
    }
    return base;
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('暂无作业',
              style:
                  TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 4),
          Text('点击右上角「新建作业」，为班级学生发放病例作业',
              style:
                  TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: '新建作业',
            onPressed: () => context.pushNamed(RouteNames.assignmentCreate),
          ),
        ],
      ),
    );
  }

  String _formatDeadline(String iso) {
    final body = iso.replaceFirst('T', ' ');
    if (body.length >= 16) return body.substring(0, 16);
    return body;
  }
}

/// 某作业的待批阅 / 已批阅统计
class _AssignmentStat {
  _AssignmentStat({this.pending = 0, this.reviewed = 0});
  int pending;
  int reviewed;
}