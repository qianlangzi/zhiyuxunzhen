import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../data/student_service.dart';
import 'growth_stats.dart';
import 'widgets/growth_visual.dart';

/// 训练概览子页（成长页二级页）
///
/// 成长页瘦身后的下沉内容：刷题正确率环 + 答对/答错 + 分模块占比全量展开，
/// 并挂「考核记录」入口（OSCE 历史），训练相关的数字在这里一次看全。
class TrainingOverviewScreen extends StatefulWidget {
  const TrainingOverviewScreen({super.key});

  @override
  State<TrainingOverviewScreen> createState() => _TrainingOverviewScreenState();
}

class _TrainingOverviewScreenState extends State<TrainingOverviewScreen> {
  QuestionStats _question = QuestionStats.fromApi(null);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final q = await StudentService().getQuestionStats();
    if (!mounted) return;
    setState(() {
      _question = QuestionStats.fromApi(q);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      tag: '成长 · 训练概览',
      title: '训练概览',
      subtitle: _question.hasData
          ? '刷题战绩 · 答对答错一目了然'
          : '去题库刷题，攒下第一份战绩',
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.mistakes),
      loading: _isLoading,
      onRefresh: _load,
      bottomInset: 40,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          TrainingOverviewCard(question: _question, loading: _isLoading),
          const SizedBox(height: 16),
          _buildOsceEntry(context),
        ],
      ),
    );
  }

  /// 考核记录入口（原学习档案快捷区迁移至此，训练类入口统一归口）
  Widget _buildOsceEntry(BuildContext context) {
    return PaperCard(
      tint: AppColors.vermilionOf(context),
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => context.pushNamed(RouteNames.osceHistory),
      child: Row(
        children: [
          GradientIconBadge(
            icon: Icons.medical_services_outlined,
            color: AppColors.vermilionOf(context),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '考核记录',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '历次 OSCE 考核成绩与评语',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.text4Of(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }
}
