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
import 'widgets/weakness_list_card.dart';

/// 能力画像子页（成长页二级页）
///
/// 成长页瘦身后的下沉内容：OSCE 六维雷达 + 最强/最弱对比 +
/// 薄弱知识点 Top（含 AI 诊断入口 → 薄弱点推荐页补练）。
class AbilityProfileScreen extends ConsumerStatefulWidget {
  const AbilityProfileScreen({super.key});

  @override
  ConsumerState<AbilityProfileScreen> createState() =>
      _AbilityProfileScreenState();
}

class _AbilityProfileScreenState extends ConsumerState<AbilityProfileScreen> {
  GrowthStats _stats = GrowthStats.fromOverview(null);
  List<dynamic> _weaknesses = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final results = await Future.wait([
      StudentService().getReportOverview(),
      StudentService().getWeaknesses(),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = GrowthStats.fromOverview(results[0] as Map<String, dynamic>?);
      _weaknesses = results[1] as List<dynamic>? ?? const [];
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
          WeaknessListCard(
            weaknesses: _weaknesses,
            onAiDiagnosis: () => context.pushNamed(RouteNames.recommendation),
          ),
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
