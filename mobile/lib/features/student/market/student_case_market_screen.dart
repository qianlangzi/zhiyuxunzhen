import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../../common/data/drug_api.dart';
import '../../common/guide/guide_anchor.dart';
import '../data/student_service.dart';

/// 学生端 Tab2 · 训练中心（枢纽）
///
/// 承担「练能力」的入口聚合，采用「枢纽 + 独立库房」结构：
/// - [主内容] 训练宫格 2×2：病例库 / 基础题库 / 模拟试卷 / AI 陪练；
/// - 每日一例（快捷入口，琥珀色调）；
/// - [药品库] 药房入口区块：随身药房主卡 + 常用科室快捷入口，
///   「全部药品」进入独立药品库页（原「精选病例」区块因与病例库入口
///   重复，已被本区块替换）。
/// 视觉与学习 / 成长页同一套「纸感场景层」语言，消除 tab 间的风格断层。
class StudentCaseMarketScreen extends ConsumerStatefulWidget {
  const StudentCaseMarketScreen({super.key});

  @override
  ConsumerState<StudentCaseMarketScreen> createState() =>
      _StudentCaseMarketScreenState();
}

class _StudentCaseMarketScreenState
    extends ConsumerState<StudentCaseMarketScreen> {
  Map<String, dynamic>? _dailyCaseData;
  bool _isLoading = true;

  /// 药品库快捷科室（来自 /drugs/filters 动态去重，按内科高频顺序取前几个）
  List<String> _drugDepts = [];

  /// 科室快捷入口的展示优先级（内科药房最常用的科室维度）
  static const _deptPriority = [
    '心血管内科',
    '呼吸内科',
    '消化内科',
    '内分泌科',
    '神经内科',
    '感染科',
    '肾内科',
    '全科',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final results = await Future.wait([
      // 每日一例入口卡：走新版九段病历 today 接口（旧版 open-answer 接口已下线）
      StudentService().getTodayDailyMr(),
      // 药品库快捷科室：动态去重后按内科高频顺序截取（失败静默降级为空）
      DrugApi().getFilters(),
    ]);
    if (!mounted) return;
    final filters = results[1] as dynamic;
    final deptSet = (filters.isSuccess && filters.data != null)
        ? ((filters.data!['departments'] as List<dynamic>? ?? [])
            .map((e) => e.toString().trim())
            .where((d) => d.isNotEmpty)
            .toSet())
        : <String>{};
    setState(() {
      _dailyCaseData = results[0] as Map<String, dynamic>?;
      _drugDepts = _deptPriority
          .where(deptSet.contains)
          .take(6)
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      tag: '内科教研 · 学生端',
      title: '训练中心',
      subtitle: '病例问诊 · 刷题 · 组卷，从这开始练',
      loading: _isLoading,
      onRefresh: _load,
      bottomInset: 104,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
        children: [
          _buildGrid(),
          const SizedBox(height: 14),
          // 唯一锚点：每日一例背后有 AI 逐段批改，属于看名字看不出来的机制
          GuideTarget(
            anchor: GuideAnchors.studentTrainingDaily,
            child: _buildDailyCaseEntry(),
          ),
          const SizedBox(height: 22),
          _buildDrugLibrary(),
        ],
      ),
    );
  }

  // ---------- 训练宫格（主内容） ----------
  Widget _buildGrid() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _trainCell(
            icon: Icons.folder_copy_rounded, color: AppColors.primaryOf(context),
            title: '病例库', subtitle: '浏览 · 查找全部病例',
            onTap: () => context.pushNamed(RouteNames.caseLibrary),
          )),
          const SizedBox(width: 10),
          Expanded(child: _trainCell(
            icon: Icons.quiz_outlined, color: AppColors.indigoOf(context),
            title: '基础题库', subtitle: '知识点刷题',
            onTap: () => context.pushNamed(RouteNames.questionTraining),
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _trainCell(
            icon: Icons.description_outlined, color: AppColors.vermilionOf(context),
            title: '模拟试卷', subtitle: '全真组卷',
            onTap: () => context.pushNamed(RouteNames.paperPractice),
          )),
          const SizedBox(width: 10),
          Expanded(child: _trainCell(
            icon: Icons.smart_toy_outlined, color: AppColors.amberOf(context),
            title: 'AI 陪练', subtitle: '对话问诊',
            onTap: () => context.pushNamed(RouteNames.companion),
          )),
        ]),
      ],
    );
  }

  Widget _trainCell({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return PaperCard(
      tint: color,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: SizedBox(
        height: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientIconBadge(icon: icon, color: color, size: 36),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5, color: AppColors.text3Of(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 每日一例 ----------
  Widget _buildDailyCaseEntry() {
    final title = _dailyCaseData?['caseTitle'] as String? ?? '每日一例 · 今天就一道';
    return PaperCard(
      tint: AppColors.amberOf(context),
      tintStrength: 1.4,
      radius: AppRadius.xl,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      onTap: () => context.pushNamed(RouteNames.dailyCase),
      child: Row(
        children: [
          GradientIconBadge(
            icon: Icons.today_rounded,
            color: AppColors.amberOf(context),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每日一例',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    )),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.text3Of(context))),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  // ---------- 药品库（药房入口区块，替换原「精选病例」） ----------
  Widget _buildDrugLibrary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Text('药品库',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => context.pushNamed(RouteNames.drugLibrary),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('全部药品',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.primaryOf(context))),
                    Icon(Icons.chevron_right,
                        size: 15, color: AppColors.primaryOf(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildDrugHeroCard(),
        if (_drugDepts.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildDeptShortcuts(),
        ],
      ],
    );
  }

  /// 药房主卡：药盒徽标 + 说明文字，点击进入完整药品库
  Widget _buildDrugHeroCard() {
    final drugColor = AppColors.indigoOf(context);
    return PaperCard(
      tint: drugColor,
      radius: AppRadius.xl,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      onTap: () => context.pushNamed(RouteNames.drugLibrary),
      child: Row(
        children: [
          GradientIconBadge(
            icon: Icons.local_pharmacy_outlined,
            color: drugColor,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('随身药房',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    )),
                const SizedBox(height: 3),
                Text('内科常用药 · 说明书式速查',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.text3Of(context))),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  /// 常用科室快捷入口：横向滚动，点击直达带科室预选的药品库
  Widget _buildDeptShortcuts() {
    final drugColor = AppColors.indigoOf(context);
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _drugDepts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final dept = _drugDepts[i];
          return GestureDetector(
            onTap: () => context.pushNamed(
              RouteNames.drugLibrary,
              queryParameters: {'department': dept},
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: drugColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: drugColor.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.medication_outlined,
                      size: 15, color: drugColor),
                  const SizedBox(width: 6),
                  Text(
                    dept,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: drugColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
