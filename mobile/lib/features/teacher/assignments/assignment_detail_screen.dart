import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 某次作业的批阅详情
///
/// 从「作业管理」顶部选中某次具体作业后进入，按 班级 → 学生 两级组织该作业的批阅任务，
/// 顶部在「待批阅 / 已批阅」两个 tab 间切换，点击学生进入复核。
class AssignmentDetailScreen extends ConsumerStatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    this.assignmentTitle,
    this.classId,
  });

  final int assignmentId;
  final String? assignmentTitle;

  /// 从班级详情进入时按班过滤；为空则显示该作业全部班级
  final int? classId;

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  int _tabIndex = 0; // 0 待批阅 / 1 已批阅
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> data;
    try {
      data = await TeacherService().getReviewQueue();
    } catch (e) {
      debugPrint('loadAssignmentDetail error: $e');
      data = [];
    }
    // 只保留当前作业的批阅数据
    final filtered = data.where((it) {
      final aid = (it['assignmentId'] as num?)?.toInt();
      if (aid != widget.assignmentId) return false;
      final cid = widget.classId;
      if (cid != null) {
        final listClass = (it['classId'] as num?)?.toInt();
        if (listClass != null && listClass != cid) return false;
      }
      return true;
    }).toList();
    if (!mounted) return;
    setState(() {
      _items = filtered;
      _isLoading = false;
    });
  }

  /// 待批阅：AI批阅中(3) / 待复核(4)；已批阅：已完成(5)
  List<Map<String, dynamic>> get _visible {
    final reviewed = _tabIndex == 1;
    return _items.where((it) {
      final s = (it['instanceStatus'] as num?)?.toInt() ?? 0;
      return reviewed ? s == 5 : (s == 3 || s == 4);
    }).toList();
  }

  int get _pendingCount => _items.where((it) {
        final s = (it['instanceStatus'] as num?)?.toInt() ?? 0;
        return s == 3 || s == 4;
      }).length;

  int get _reviewedCount => _items.where((it) {
        final s = (it['instanceStatus'] as num?)?.toInt() ?? 0;
        return s == 5;
      }).length;

  /// 按班级分组（无班级归入「未分班」）
  List<MapEntry<String, List<Map<String, dynamic>>>> _groupByClass(
      List<Map<String, dynamic>> list) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final it in list) {
      var cls = (it['className'] as String?)?.trim() ?? '';
      if (cls.isEmpty) cls = '未分班';
      map.putIfAbsent(cls, () => []).add(it);
    }
    final entries = map.entries.toList()
      ..sort((a, b) {
        final aUn = a.key == '未分班', bUn = b.key == '未分班';
        if (aUn != bUn) return aUn ? 1 : -1;
        return a.key.compareTo(b.key);
      });
    return entries;
  }

  void _openReview(Map<String, dynamic> it) {
    final itemProgressId = (it['itemProgressId'] as num?)?.toInt();
    final itemType = it['itemType'] as String? ?? 'CASE';
    final base = {
      'studentName': it['studentName'],
      'assignmentTitle': it['assignmentTitle'],
    };

    // 主观题（PRACTICE）走独立批改页：展示题目/答案/评分要点 → AI 批阅 → 教师确认提交
    if (itemType == 'PRACTICE') {
      if (itemProgressId == null) {
        AppFeedback.error(context, '缺少任务项进度，暂无法打开主观题批改');
        return;
      }
      context.pushNamed(
        RouteNames.essayReview,
        extra: {
          ...base,
          'itemProgressId': itemProgressId,
        },
      );
      return;
    }

    // 病例（CASE / 存量）走病例批阅
    final instanceId = (it['instanceId'] as num?)?.toInt();
    if (instanceId == null) {
      AppFeedback.error(context, '缺少作业实例，暂无法打开批阅');
      return;
    }
    context.pushNamed(
      RouteNames.review,
      extra: {
        ...base,
        'instanceId': instanceId,
        if (itemProgressId != null) 'itemProgressId': itemProgressId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.assignmentTitle?.trim().isNotEmpty == true
        ? widget.assignmentTitle!.trim()
        : '作业批阅';
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTitleAppBar(
              tag: '教师端 · 作业批阅',
              title: title,
              onBack: () => context.canPop() ? context.pop() : null,
            ),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ruleSoftOf(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final pillW = w / 2;
          // -1 靠左 / +1 靠右：让高亮胶囊平滑滑到目标 tab
          final dx = _tabIndex == 0 ? 0.0 : w - pillW;
          return Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: dx,
                top: 0,
                bottom: 0,
                width: pillW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadow.lifted(context),
                  ),
                ),
              ),
              Row(
                children: [
                  _tabButton(0, '待批阅', _pendingCount, AppColors.vermilionOf(context)),
                  _tabButton(
                      1, '已批阅', _reviewedCount, AppColors.primaryOf(context)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabButton(int index, String label, int count, Color activeColor) {
    final active = index == _tabIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? AppColors.textOf(context)
                      : AppColors.text3Of(context),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.vermilionSoftOf(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: kCjkMonoFallback,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          index == 0 ? activeColor : AppColors.text3Of(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final visible = _visible;
    if (visible.isEmpty) {
      return _emptyState(
        _tabIndex == 0 ? '暂无待批阅作业' : '暂无已批阅作业',
        _tabIndex == 0 ? '学生提交后 AI 批阅完成会出现在这里' : '教师复核完成后会归入已批阅',
      );
    }
    final groups = _groupByClass(visible);
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 110),
      children: [
        for (final g in groups) ...[
          _buildClassSection(g.key, g.value),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildClassSection(String className, List<Map<String, dynamic>> list) {
    final reviewed = _tabIndex == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.indigoSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.groups_rounded,
                    size: 18, color: AppColors.indigoOf(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SerifText(className,
                        fontSize: 15, color: AppColors.textOf(context)),
                    const SizedBox(height: 2),
                    MonoText('${list.length} 人${reviewed ? '已完成' : '待复核'}',
                        fontSize: 10, color: AppColors.text3Of(context)),
                  ],
                ),
              ),
              AppChip(
                  label: '${list.length}', type: ChipType.indigo, fontSize: 10),
            ],
          ),
        ),
        ...list.map((it) => _buildSubmissionCard(it, reviewed)),
      ],
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> it, bool reviewed) {
    final score = it['score'] as num?;
    final status = (it['instanceStatus'] as num?)?.toInt() ?? 0;
    final submitTime = it['submitTime'] as String? ?? '';
    final issue = (it['issue'] as String?)?.isNotEmpty == true
        ? it['issue'] as String
        : '等待 AI 批阅结果';

    return PressableScale(
      child: GestureDetector(
        onTap: () => _openReview(it),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: reviewed
                          ? AppColors.mossTintOf(context)
                          : AppColors.amberSoftOf(context),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initialOf(it['studentName'] as String? ?? '生'),
                      style: TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontFamilyFallback: [
                          'Songti SC',
                          'STSong',
                          'Noto Serif CJK SC'
                        ],
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: reviewed
                            ? AppColors.primaryOf(context)
                            : AppColors.amberOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it['studentName'] as String? ?? '未命名学生',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        MonoText(it['caseTitle'] as String? ?? '大病历作业',
                            fontSize: 10, color: AppColors.text3Of(context)),
                      ],
                    ),
                  ),
                  if (reviewed && score != null)
                    _scorePill(score.toDouble())
                  else
                    _statusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              const DottedDivider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    reviewed
                        ? Icons.fact_check_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: reviewed
                        ? AppColors.primaryOf(context)
                        : AppColors.amberOf(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      issue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.text2Of(context)),
                    ),
                  ),
                ],
              ),
              if (submitTime.isNotEmpty) ...[
                const SizedBox(height: 6),
                MonoText('提交 ${_formatTime(submitTime)}',
                    fontSize: 10, color: AppColors.text3Of(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _initialOf(String? name) {
    if (name == null || name.isEmpty) return '生';
    return name.characters.first;
  }

  Widget _scorePill(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mossSoftOf(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        score.toStringAsFixed(0),
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: kCjkMonoFallback,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryOf(context),
        ),
      ),
    );
  }

  Widget _statusChip(int status) {
    final (label, type) = switch (status) {
      3 => ('AI批阅中', ChipType.indigo),
      4 => ('待复核', ChipType.amber),
      _ => ('批阅中', ChipType.default_),
    };
    return AppChip(label: label, type: type, fontSize: 10);
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.ruleSoftOf(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _tabIndex == 0
                  ? Icons.fact_check_outlined
                  : Icons.task_alt_rounded,
              size: 30,
              color: AppColors.text4Of(context),
            ),
          ),
          const SizedBox(height: 16),
          SerifText(title, fontSize: 16, color: AppColors.text2Of(context)),
          const SizedBox(height: 6),
          MonoText(subtitle, fontSize: 11, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    final body = iso.replaceFirst('T', ' ');
    if (body.length >= 16) return body.substring(5, 16);
    return body;
  }
}
