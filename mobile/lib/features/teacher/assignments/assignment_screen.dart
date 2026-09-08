import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../common/guide/guide_anchor.dart';
import '../../common/guide/guide_controller.dart';
import '../../common/guide/guide_tours.dart';
import '../data/teacher_service.dart';

/// 作业分发与进度
class AssignmentScreen extends ConsumerStatefulWidget {
  const AssignmentScreen({super.key});

  @override
  ConsumerState<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends ConsumerState<AssignmentScreen> {
  Map<String, dynamic>? _assignmentData;
  bool _isLoading = true;
  bool _aiRecommendLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssignments());
  }

  Future<void> _loadAssignments() async {
    Map<String, dynamic>? data;
    try {
      final list = await TeacherService().getAssignmentList();
      final first = (list == null || list.isEmpty)
          ? null
          : (list.first as Map).cast<String, dynamic>();
      if (first != null) {
        final id = (first['id'] as num?)?.toInt();
        Map<String, dynamic>? progress;
        if (id != null) {
          progress = await TeacherService().getAssignmentProgress(id);
        }
        final classNames = (first['classNames'] as List<dynamic>?)
            ?.map((e) => '$e')
            .join(' · ');
        final studentCount = (first['studentCount'] as num?)?.toInt() ?? 0;
        final statusStats =
            (progress?['statusStats'] as Map<String, dynamic>?) ?? const {};
        final completed = (statusStats['completed'] as num?)?.toInt() ?? 0;
        final progressAvailable =
            (progress?['assignmentTitle'] as String?) != null;
        data = {
          'assignmentName': (first['title'] as String?) ??
              (first['caseTitle'] as String?),
          'className': classNames ?? '',
          'studentCount': (first['studentCount'] as num?)?.toString(),
          'deadline': first['deadline'] != null ? '${first['deadline']}' : '',
          'completionRate': progressAvailable
              ? (studentCount > 0 ? '${completed * 100 ~/ studentCount}%' : '—')
              : '—',
          'stages': _buildStagesFromStatus(statusStats),
        };
      }
    } catch (e) {
      // 兜底：加载异常也要结束 loading，避免页面永久转圈、无法返回
      debugPrint('loadAssignments error: $e');
    }
    if (mounted) {
      setState(() {
        _assignmentData = data;
        _isLoading = false;
      });
      // 数据就绪后再触发页面级引导（AI 推荐面板可拖拽关闭），锚点此时才渲染
      if (data != null) {
        ref
            .read(guideControllerProvider.notifier)
            .schedulePageEnter(GuidePageIds.teacherAssignment);
      }
    }
  }

  /// 将进度接口的 statusStats 映射为看板各状态卡片（仅保留有学生的状态）
  List<Map<String, dynamic>>? _buildStagesFromStatus(Map<String, dynamic> stats) {
    const order = [
      'notStarted',
      'inProgress',
      'formatRejected',
      'aiReviewing',
      'pendingReview',
      'completed',
    ];
    const labels = <String, (String, String)>{
      'notStarted': ('未开始', ''),
      'inProgress': ('问诊中', 'amber'),
      'formatRejected': ('格式打回', 'vermilion'),
      'aiReviewing': ('AI 批阅中', 'indigo'),
      'pendingReview': ('待复核', 'indigo'),
      'completed': ('已完成', 'moss'),
    };
    final result = <Map<String, dynamic>>[];
    for (final k in order) {
      final count = (stats[k] as num?)?.toInt() ?? 0;
      if (count > 0) {
        result.add({
          'count': count,
          'label': labels[k]!.$1,
          'color': labels[k]!.$2,
        });
      }
    }
    return result.isEmpty ? null : result;
  }

  /// AI 推荐作业病例（按班级薄弱点匹配病例库）
  Future<void> _recommendCases() async {
    if (_aiRecommendLoading) return;
    setState(() => _aiRecommendLoading = true);
    final data = _assignmentData;
    // 作业可分发到多个班级，无单一 classId；用教师首个已授权班级作为推荐对象，
    // 避免写死造假数值。无班级时提示。
    var classId = (data?['classId'] as num?)?.toInt();
    if (classId == null) {
      final classes = await TeacherService().getClasses();
      classId = classes.isNotEmpty ? (classes.first['id'] as num?)?.toInt() : null;
    }
    if (classId == null) {
      if (!mounted) return;
      setState(() => _aiRecommendLoading = false);
      AppFeedback.info(context, '暂无可推荐的目标班级');
      return;
    }
    final result = await TeacherService().getRecommendCases(classId);
    if (!mounted) return;
    setState(() => _aiRecommendLoading = false);
    if (result == null) {
      AppFeedback.error(context, 'AI 暂不可用，无法推荐病例');
      return;
    }
    final recommendations =
        (result['recommendations'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    _showRecommendSheet(recommendations);
  }

  void _showRecommendSheet(List<Map<String, dynamic>> recommendations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.85,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SerifText('AI 推荐作业病例', fontSize: 17)),
                  const AppChip(label: 'AI', type: ChipType.moss),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('依据班级薄弱知识点，从你的病例库中匹配', fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: recommendations.isEmpty
                    ? Center(child: MonoText('暂无可推荐的病例', fontSize: 12, color: AppColors.text4Of(context)))
                    : ListView(
                        controller: scrollController,
                        children: recommendations.asMap().entries.map((e) {
                          final item = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
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
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOf(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: MonoText('${e.key + 1}', fontSize: 11,
                                          color: AppColors.onPrimaryOf(context)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: MonoText('病例 #${item['caseId'] ?? ''}',
                                          fontSize: 11, color: AppColors.primaryOf(context)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${item['reason'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 12.5, color: AppColors.textOf(context), height: 1.6)),
                                if ((item['matchedWeakness'] as String?)?.isNotEmpty ?? false)
                                  MonoText('针对薄弱点：${item['matchedWeakness']}',
                                      fontSize: 11, color: AppColors.amberOf(context)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
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
            AppBackAppBar(
              title: '作业进度',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              // 原右上角 more_horiz 是个无 onPressed 的死按钮，点了没反应还让人困惑，已删
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAssignmentCard(context),
                          const SizedBox(height: 16),
                          _buildProgressHeader(context),
                          const SizedBox(height: 10),
                          _buildProgressCard(context),
                          const SizedBox(height: 16),
                          _buildActionButtons(context),
                          const SizedBox(height: 16),
                          _buildAntiCheatInfo(context),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context) {
    final data = _assignmentData;
    final studentCount = data?['studentCount']?.toString() ?? '—';
    return EyebrowText('进度看板 · $studentCount 人');
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppGhostButton(
                label: '催交提醒',
                icon: const Icon(Icons.notifications_active_outlined, size: 14),
                fullWidth: true,
                onPressed: () {
                  final data = _assignmentData;
                  final unsubmitted = data?['unsubmittedCount']?.toString() ?? '—';
                  AppFeedback.success(context, '已向 $unsubmitted 名未提交学生发送催交通知');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppPrimaryButton(
                label: '查看详情 →',
                fullWidth: true,
                onPressed: () => context.pushNamed(RouteNames.review),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 套 GuideTarget：页面级引导教「AI 推荐 + 弹层下拉关闭」
        GuideTarget(
          anchor: GuideAnchors.teacherAssignmentRecommend,
          child: AppGhostButton(
            label: _aiRecommendLoading ? 'AI 推荐中…' : 'AI 推荐作业病例',
            icon: const Icon(Icons.auto_awesome, size: 14),
            fullWidth: true,
            onPressed: _aiRecommendLoading ? null : _recommendCases,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(BuildContext context) {
    final data = _assignmentData;
    final assignmentName = data?['assignmentName'] as String? ?? '未命名作业';
    final className = data?['className'] as String? ?? '';
    final deadline = data?['deadline'] as String? ?? '';
    final variableCount = data?['variableCount'] as int? ?? 0;
    final variables = (data?['variables'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
const EyebrowText('ASSIGNMENT · 进行中', color: AppColors.moss),
          const SizedBox(height: 6),
          SerifText(assignmentName, fontSize: 18),
          const SizedBox(height: 8),
          Row(
            children: [
              MonoText(className, fontSize: 11, color: AppColors.text3Of(context)),
              const SizedBox(width: 12),
              MonoText('·', fontSize: 11, color: AppColors.text3Of(context)),
              const SizedBox(width: 12),
              MonoText(deadline, fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
          const SizedBox(height: 10),
          const DottedDivider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const EyebrowText('防作弊变量'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amberSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: MonoText('$variableCount 个变量已配置', fontSize: 11, color: AppColors.amberOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: variables.map((v) => AppChip(label: v)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final data = _assignmentData;
    final stagesRaw =
        (data?['stages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final completionRate = data?['completionRate'] as String? ?? '—';
    final remainingTime = data?['remainingTime'] as String? ?? '—';

    final stages = stagesRaw
        .map((s) {
          final num = s['count']?.toString() ?? '0';
          final label = s['label'] as String? ?? '';
          final color = _parseStageColor(s['color'] as String?);
          return (num, label, color);
        })
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.3,
            ),
            itemCount: stages.length,
            itemBuilder: (context, i) {
              final (num, label, color) = stages[i];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      num,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.text3Of(context),
                        letterSpacing: 0.04,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const DottedDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText('班级完成率', fontSize: 11, color: AppColors.text3Of(context)),
                  const SizedBox(height: 2),
                  Text(
completionRate,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryOf(context),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MonoText('距截止', fontSize: 11, color: AppColors.text3Of(context)),
                  const SizedBox(height: 2),
                  MonoText(remainingTime, fontSize: 14, color: AppColors.amberOf(context)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _parseStageColor(String? color) {
    switch (color) {
      case 'moss':
        return AppColors.moss;
      case 'amber':
        return AppColors.amberOf(context);
      case 'vermilion':
        return AppColors.vermilionOf(context);
      case 'indigo':
        return AppColors.indigoOf(context);
      default:
        return AppColors.text3Of(context);
    }
  }

  Widget _buildAntiCheatInfo(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.sm),
          bottomRight: Radius.circular(AppRadius.sm),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: AppColors.primaryOf(context)),
          ),
        Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
const MonoText('防作弊机制', fontSize: 11, color: AppColors.moss, letterSpacing: 0.1),
                const SizedBox(height: 4),
                Text(
                  '每名学生获得独立变量快照，AI 批阅以该学生对应快照为标准答案。教师可查看每名学生的变量版本。',
                  style: TextStyle(fontSize: 12, color: AppColors.text2Of(context), height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}