import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 教师首页 · 工作台
class TeacherHomeScreen extends StatelessWidget {
const   TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTitleAppBar(
              tag: '内科教研 · 教师端',
              title: '王老师 · 工作台',
              action: AppPrimaryButton(
                label: '+ 新建病例',
                small: true,
                onPressed: () => context.goNamed(RouteNames.spConfig),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(context, ),
                    const SizedBox(height: 20),
                    _buildStats(context, ),
                    _buildReviewSection(context),
                    _buildClassOverview(context, ),
                    _buildMarketDynamic(context, ),
                  ],
                ),
              ),
            ),
            TeacherTabBar(
              currentIndex: 0,
              onTap: (i) {
                if (i == 1) context.goNamed(RouteNames.spConfig);
                if (i == 2) context.goNamed(RouteNames.caseMarket);
                if (i == 3) context.goNamed(RouteNames.teacherProfile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
     Text(
          '下午好，王老师',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
            height: 1.15,
            letterSpacing: -0.02,
          ),
        ),
     SizedBox(height: 4),
     MonoText('附属第一医院 · 心血管内科 · 带教 3 个班级', fontSize: 12),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        _statCard(context, '12', '待复核', AppColors.vermilion, urgent: true),
     SizedBox(width: 8),
        _statCard(context, '3', '进行作业', AppColors.textOf(context)),
     SizedBox(width: 8),
        _statCard(context, '28', '我的病例', AppColors.textOf(context)),
      ],
    );
  }

  Widget _statCard(BuildContext context, String num, String label, Color color, {bool urgent = false}) {
    return Expanded(
      child: Container(
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: urgent ? AppColors.vermilionSoftOf(context) : AppColors.surfaceOf(context),
          border: Border.all(color: urgent ? AppColors.vermilionSoftOf(context) : AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Stack(
          children: [
            if (urgent)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.vermilion,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  num,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1,
                    letterSpacing: -0.02,
                  ),
                ),
         SizedBox(height: 4),
                MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '01',
          title: '待批阅 · 12',
          trailing: AppMoreLink(label: '全部 →', onTap: () => context.goNamed(RouteNames.review)),
        ),
        _reviewItem(
          context, '陈思远 · 急性心梗大病历', '学号 2021302014 · 心血管 03 班',
          'AI 批阅中', StatusBadgeType.info,
          meta: ['提交于 13:42', 'AI 预评 82 分'],
          urgent: true,
        ),
        _reviewItem(
          context, '林雨欣 · 急性心梗大病历', '学号 2021302022 · 心血管 03 班',
          '格式打回', StatusBadgeType.warn,
          meta: ['提交于 12:18', '主诉超 20 字 / 过敏史空'],
          urgent: true,
        ),
        _reviewItem(
          context, '赵子轩 · 慢阻肺大病历', '学号 2021302008 · 呼吸 02 班',
          'AI 预评 91 分', StatusBadgeType.info,
          meta: ['提交于 11:30', '建议复核'],
        ),
        _reviewItem(
          context, '周明 · 慢阻肺大病历', '学号 2021302015 · 呼吸 02 班',
          '已完成 88', StatusBadgeType.done,
          meta: ['复核于 10:15', '已覆盖 AI 评分'],
        ),
      ],
    );
  }

  Widget _reviewItem(
    BuildContext context, String student, String studentId,
    String status, StatusBadgeType statusType,
    {required List<String> meta, bool urgent = false}
  ) {
    return GestureDetector(
      onTap: () => context.goNamed(RouteNames.review),
      child: Container(
    margin: EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Stack(
          children: [
            if (urgent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: AppColors.vermilion),
              ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
         Text(student, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textOf(context))),
                  const SizedBox(height: 1),
                  MonoText(studentId, fontSize: 11, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            AppStatusBadge(label: status, type: statusType),
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassOverview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '02', title: '班级概览'),
        AppPaper(
          child: Column(
            children: [
              _classRow(context, '心血管 03 班 · 32 人', '急性心梗作业 · 截止 07.22', '68%', AppColors.primaryOf(context)),
              const DottedDivider(),
              _classRow(context, '呼吸 02 班 · 28 人', '慢阻肺作业 · 截止 07.25', '32%', AppColors.amber),
            ],
          ),
        ),
      ],
    );
  }

  Widget _classRow(BuildContext context, String name, String assignment, String rate, Color color) {
    return Padding(
   padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
       Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textOf(context))),
              const SizedBox(height: 2),
              MonoText(assignment, fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rate,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
        MonoText('完成率', fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketDynamic(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '03', title: '病例广场动态'),
        AppPaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
         style: TextStyle(fontSize: 12.5, color: AppColors.text2Of(context), height: 1.6),
                  children: [
                    const TextSpan(text: '你的病例 '),
           TextSpan(text: '《急性下壁心梗的不典型表现》', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOf(context))),
                    const TextSpan(text: ' 被引用 '),
                    TextSpan(text: '+5', style: TextStyle(color: AppColors.primaryOf(context), fontWeight: FontWeight.w500)),
                    const TextSpan(text: ' 次'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
        MonoText('本周新增引用 · 累计 23 次 · 评分 4.8', fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
        ),
      ],
    );
  }
}
