import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../data/student_service.dart';
import 'growth_stats.dart';
import 'widgets/ability_radar.dart';

/// 能力画像子页（成长页二级页）
///
/// 职责收敛：只讲「能力长什么样」—— OSCE 六维雷达 + 最强/最弱对比。
/// 薄弱知识点 Top 及 AI 补练入口统一收敛到「学习档案」
/// （此前两页各挂一份 WeaknessListCard，同一份内容重复出现）。
class AbilityProfileScreen extends ConsumerStatefulWidget {
  const AbilityProfileScreen({super.key});

  @override
  ConsumerState<AbilityProfileScreen> createState() =>
      _AbilityProfileScreenState();
}

class _AbilityProfileScreenState extends ConsumerState<AbilityProfileScreen> {
  GrowthStats _stats = GrowthStats.fromOverview(null);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getReportOverview();
    if (!mounted) return;
    setState(() {
      _stats = GrowthStats.fromOverview(data);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      tag: '成长 · 能力画像',
      title: '能力画像',
      subtitle: _stats.hasAbility
          ? '六维问诊能力 · 强弱一眼看清'
          : '完成问诊评估后生成',
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.mistakes),
      loading: _isLoading,
      onRefresh: _load,
      bottomInset: 40,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          if (_stats.hasAbility) ...[
            AbilityRadarCard(stats: _stats),
            const SizedBox(height: 16),
          ] else
            _buildEmpty(context),
          _buildWeaknessGuide(context),
        ],
      ),
    );
  }

  /// 薄弱知识点已收敛到学习档案，这里只留一行轻量指引（不做重复内容）
  Widget _buildWeaknessGuide(BuildContext context) {
    return PaperCard(
      tint: AppColors.vermilionOf(context),
      tintStrength: 0.5,
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => context.pushNamed(RouteNames.learningArchive),
      child: Row(
        children: [
          GradientIconBadge(
            icon: Icons.psychology_outlined,
            color: AppColors.vermilionOf(context),
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '薄弱知识点在哪？',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '去学习档案查看薄弱点 Top 与 AI 补练计划',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.text4Of(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return PaperCard(
      tint: AppColors.indigoOf(context),
      radius: AppRadius.xl,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.radar_rounded,
                size: 32, color: AppColors.indigoOf(context)),
            const SizedBox(height: 10),
            Text(
              '还没有能力画像',
              style: TextStyle(fontSize: 13.5, color: AppColors.text2Of(context)),
            ),
            const SizedBox(height: 4),
            MonoText(
              '完成一次问诊评估后自动生成六维雷达',
              fontSize: 11,
              color: AppColors.text4Of(context),
            ),
          ],
        ),
      ),
    );
  }
}
