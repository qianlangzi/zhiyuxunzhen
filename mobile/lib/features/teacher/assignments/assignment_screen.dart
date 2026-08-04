import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssignments());
  }

  Future<void> _loadAssignments() async {
    final data = await TeacherService().getAssignmentList();
    if (mounted) {
      setState(() {
        _assignmentData = data;
        _isLoading = false;
      });
    }
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
              action: const AppIconButton(icon: Icon(Icons.more_horiz, size: 20)),
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
    final studentCount = data?['studentCount']?.toString() ?? '32';
    return EyebrowText('进度看板 · $studentCount 人');
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppGhostButton(
            label: '催交提醒',
            icon: const Icon(Icons.notifications_active_outlined, size: 14),
            fullWidth: true,
            onPressed: () {
              final data = _assignmentData;
              final unsubmittedCount = data?['unsubmittedCount']?.toString() ?? '5';
              AppFeedback.success(context, '已向 $unsubmittedCount 名未提交学生发送催交通知');
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
    );
  }

  Widget _buildAssignmentCard(BuildContext context) {
    final data = _assignmentData;
    final assignmentName = data?['assignmentName'] as String? ?? '急性心梗病例问诊 · 大病历';
    final className = data?['className'] as String? ?? '心血管 03 班 · 32 人';
    final deadline = data?['deadline'] as String? ?? '截止 07.22 23:59';
    final variableCount = data?['variableCount'] as int? ?? 3;
    final variables = (data?['variables'] as List<dynamic>?)?.cast<String>() ?? ['患者年龄 55-65', '疼痛放射部位', '血压基线'];

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
                child: MonoText('$variableCount 个变量已配置', fontSize: 11, color: AppColors.amber),
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
    final stagesRaw = (data?['stages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final completionRate = data?['completionRate'] as String? ?? '68%';
    final remainingTime = data?['remainingTime'] as String? ?? '34h 14min';

    final defaultStages = [
      ('4', '未开始', AppColors.text3Of(context)),
      ('6', '问诊中', AppColors.amber),
      ('8', '已提交', AppColors.indigo),
      ('2', '格式打回', AppColors.vermilion),
      ('12', 'AI 批阅中', AppColors.indigo),
      ('0', '已完成', AppColors.primaryOf(context)),
    ];

    final stages = stagesRaw.isEmpty
        ? defaultStages
        : stagesRaw.map((s) {
            final num = s['count']?.toString() ?? '0';
            final label = s['label'] as String? ?? '';
            final color = _parseStageColor(s['color'] as String?);
            return (num, label, color);
          }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                      fontWeight: FontWeight.w600,
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
                  MonoText(remainingTime, fontSize: 14, color: AppColors.amber),
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
        return AppColors.amber;
      case 'vermilion':
        return AppColors.vermilion;
      case 'indigo':
        return AppColors.indigo;
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