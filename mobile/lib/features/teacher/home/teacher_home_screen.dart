import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 教师首页 · 工作台
class TeacherHomeScreen extends ConsumerStatefulWidget {
  const TeacherHomeScreen({super.key});
  @override
  ConsumerState<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends ConsumerState<TeacherHomeScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final data = await TeacherService().getDashboardOverview();
    if (mounted) {
      setState(() {
        _dashboardData = data;
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreeting(context),
                          const SizedBox(height: 20),
                          _buildStats(context),
                          const SizedBox(height: 12),
                          _buildTextbookEntry(context),
                          _buildReviewSection(context),
                          _buildClassOverview(context),
                          _buildMarketDynamic(context),
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
        const SizedBox(height: 4),
        MonoText('附属第一医院 · 心血管内科 · 带教 3 个班级', fontSize: 12),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    final data = _dashboardData;
    final pendingReview = data?['pendingReview']?.toString() ?? '12';
    final activeAssignments = data?['activeAssignments']?.toString() ?? '3';
    final myCases = data?['myCases']?.toString() ?? '28';

    return Row(
      children: [
        _statCard(context, pendingReview, '待复核', AppColors.vermilion, urgent: true),
        const SizedBox(width: 8),
        _statCard(context, activeAssignments, '进行作业', AppColors.textOf(context)),
        const SizedBox(width: 8),
        _statCard(context, myCases, '我的病例', AppColors.textOf(context)),
      ],
    );
  }

  Widget _statCard(BuildContext context, String num, String label, Color color, {bool urgent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                const SizedBox(height: 4),
                MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextbookEntry(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed(RouteNames.teacherTextbook),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.indigoSoftOf(context), AppColors.surfaceOf(context)],
          ),
          border: Border.all(color: AppColors.indigoSoftOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 20, color: AppColors.indigo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText('教材制作', fontSize: 14, color: AppColors.textOf(context)),
                  const SizedBox(height: 2),
                  MonoText('上传医学电子书，供学生查阅', fontSize: 10, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.indigo),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(BuildContext context) {
    final data = _dashboardData;
    final reviews = (data?['reviews'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final pendingCount = data?['pendingReview']?.toString() ?? '12';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '01',
          title: '待批阅 · $pendingCount',
          trailing: AppMoreLink(label: '全部 →', onTap: () => context.goNamed(RouteNames.review)),
        ),
        if (reviews.isEmpty)
          ..._defaultReviewItems(context)
        else
          ...reviews.map((r) => _reviewItem(
            context,
            r['student'] as String? ?? '',
            r['studentId'] as String? ?? '',
            r['status'] as String? ?? '',
            _parseStatusBadgeType(r['statusType'] as String?),
            meta: (r['meta'] as List<dynamic>?)?.cast<String>() ?? [],
            urgent: r['urgent'] as bool? ?? false,
          )),
      ],
    );
  }

  List<Widget> _defaultReviewItems(BuildContext context) {
    return [
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
    ];
  }

  StatusBadgeType _parseStatusBadgeType(String? type) {
    switch (type) {
      case 'info':
        return StatusBadgeType.info;
      case 'warn':
        return StatusBadgeType.warn;
      case 'done':
        return StatusBadgeType.done;
      default:
        return StatusBadgeType.info;
    }
  }

  Widget _reviewItem(
    BuildContext context, String student, String studentId,
    String status, StatusBadgeType statusType,
    {required List<String> meta, bool urgent = false}
  ) {
    return GestureDetector(
      onTap: () => context.goNamed(RouteNames.review),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
              padding: const EdgeInsets.all(16),
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
    final data = _dashboardData;
    final classes = (data?['classes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '02', title: '班级概览'),
        AppPaper(
          child: Column(
            children: [
if (classes.isEmpty)
                Column(
                  children: [
                    _classRow(context, '心血管 03 班 · 32 人', '急性心梗作业 · 截止 07.22', '68%', AppColors.moss),
                    const DottedDivider(),
                    _classRow(context, '呼吸 02 班 · 28 人', '慢阻肺作业 · 截止 07.25', '32%', AppColors.amber),
                  ],
                )
              else
                ...List.generate(classes.length, (i) {
                  final c = classes[i];
                  final color = _parseColor(c['color'] as String?);
                  return Column(
                    children: [
                      if (i > 0) const DottedDivider(),
                      _classRow(
                        context,
                        c['name'] as String? ?? '',
                        c['assignment'] as String? ?? '',
                        c['rate'] as String? ?? '',
                        color,
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(String? color) {
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
        return AppColors.moss;
    }
  }

  Widget _classRow(BuildContext context, String name, String assignment, String rate, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    final data = _dashboardData;
    final dynamicData = data?['marketDynamic'] as Map<String, dynamic>?;

    final caseName = dynamicData?['caseName'] as String? ?? '《急性下壁心梗的不典型表现》';
    final refs = dynamicData?['refs'] as String? ?? '+5';
    final totalRefs = dynamicData?['totalRefs'] as String? ?? '23';
    final rating = dynamicData?['rating'] as String? ?? '4.8';

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
                    TextSpan(text: caseName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOf(context))),
                    const TextSpan(text: ' 被引用 '),
TextSpan(text: refs, style: TextStyle(color: AppColors.moss, fontWeight: FontWeight.w500)),
                    const TextSpan(text: ' 次'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              MonoText('本周新增引用 · 累计 $totalRefs 次 · 评分 $rating', fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
        ),
      ],
    );
  }
}