import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 作业分发与进度
class AssignmentScreen extends StatelessWidget {
const   AssignmentScreen({super.key});

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAssignmentCard(context, ),
                    const SizedBox(height: 16),
                    const EyebrowText('进度看板 · 32 人'),
                    const SizedBox(height: 10),
                    _buildProgressCard(context, ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: AppGhostButton(
                          label: '催交提醒', icon: const Icon(Icons.notifications_active_outlined, size: 14),
                          fullWidth: true,
                          onPressed: () => AppFeedback.success(context, '已向 5 名未提交学生发送催交通知'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: AppPrimaryButton(
                          label: '查看详情 →',
                          fullWidth: true,
                          onPressed: () => context.pushNamed(RouteNames.review),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAntiCheatInfo(context, ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(BuildContext context) {
    return Container(
   padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowText('ASSIGNMENT · 进行中', color: AppColors.moss),
      SizedBox(height: 6),
      SerifText('急性心梗病例问诊 · 大病历', fontSize: 18),
      SizedBox(height: 8),
          Row(
            children: [
              MonoText('心血管 03 班 · 32 人', fontSize: 11, color: AppColors.text3Of(context)),
              SizedBox(width: 12),
              MonoText('·', fontSize: 11, color: AppColors.text3Of(context)),
              SizedBox(width: 12),
              MonoText('截止 07.22 23:59', fontSize: 11, color: AppColors.text3Of(context)),
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
                  color: AppColors.amberSoft,
                  border: Border.all(color: const Color(0xFFE3CFA0)),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const MonoText('3 个变量已配置', fontSize: 11, color: AppColors.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              AppChip(label: '患者年龄 55-65'),
              AppChip(label: '疼痛放射部位'),
              AppChip(label: '血压基线'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final stages = [
      ('4', '未开始', AppColors.text3Of(context)),
      ('6', '问诊中', AppColors.amber),
      ('8', '已提交', AppColors.indigo),
      ('2', '格式打回', AppColors.vermilion),
      ('12', 'AI 批阅中', AppColors.indigo),
      ('0', '已完成', AppColors.moss),
    ];
    return Container(
   padding: EdgeInsets.all(16),
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
              crossAxisCount: 6,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.7,
            ),
            itemCount: stages.length,
            itemBuilder: (context, i) {
              final (num, label, color) = stages[i];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      num,
                      style: TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
           SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.text3Of(context),
                        fontFamily: 'JetBrainsMono',
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
      SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          MonoText('班级完成率', fontSize: 11, color: AppColors.text3Of(context)),
                  const SizedBox(height: 2),
                  const Text(
                    '68%',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.moss,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MonoText('距截止', fontSize: 11, color: AppColors.text3Of(context)),
                  SizedBox(height: 2),
                  MonoText('34h 14min', fontSize: 14, color: AppColors.amber),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAntiCheatInfo(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.mossTint,
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
            child: Container(width: 3, color: AppColors.moss),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoText('防作弊机制', fontSize: 11, color: AppColors.moss, letterSpacing: 0.1),
                SizedBox(height: 4),
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
