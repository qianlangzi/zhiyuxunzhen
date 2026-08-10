import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import 'question_practice_screen.dart';

/// 基础题训练（大型题库 · 按科室模块）
///
/// 包含：
/// 1. 总体正确率统计卡片
/// 2. 各科室/模块正确率面板（进度条 + 做题数 + 薄弱高亮）
/// 3. 题库浏览入口（可按科室/知识点/难度/题型筛选）
/// 4. 进入科室逐题刷题
class QuestionTrainingScreen extends ConsumerStatefulWidget {
  const QuestionTrainingScreen({super.key});

  @override
  ConsumerState<QuestionTrainingScreen> createState() => _QuestionTrainingScreenState();
}

class _QuestionTrainingScreenState extends ConsumerState<QuestionTrainingScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _departments;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final service = StudentService();
    final stats = await service.getQuestionStats();
    final depts = await service.getQuestionDepartments();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _departments = depts;
      final depts2 = _departments;
      if (depts2 == null || depts2.isEmpty) {
        _departments = ['心血管内科', '呼吸内科', '诊断学', '综合'];
      }
      _isLoading = false;
    });
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
              title: '基础题训练',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                        children: [
                          _buildStats(),
                          const SizedBox(height: 18),
                          _buildModuleAccuracy(),
                          const SizedBox(height: 18),
                          _buildBankEntry(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 总体统计 ----------
  Widget _buildStats() {
    final totalAnswered = (_stats?['totalAnswered'] as num?)?.toInt() ?? 0;
    final correctCount = (_stats?['correctCount'] as num?)?.toInt() ?? 0;
    final accuracy = (_stats?['accuracy'] as num?)?.toDouble() ?? 0.0;
    final totalCount = (_stats?['totalCount'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCell(accuracy.toStringAsFixed(1), '正确率', AppColors.onPrimaryOf(context)),
              _divider(),
              _statCell('$totalAnswered', '已做', AppColors.onPrimaryOf(context)),
              _divider(),
              _statCell('$correctCount', '答对', AppColors.onPrimaryOf(context)),
              _divider(),
              _statCell('$totalCount', '题库', AppColors.onPrimaryOf(context)),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(
            value: accuracy / 100,
            height: 6,
            backgroundColor: AppColors.onPrimaryOf(context).withValues(alpha: 0.25),
            foregroundColor: AppColors.onPrimaryOf(context),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          MonoText(label, fontSize: 10, color: AppColors.onPrimarySoftOf(context)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.onPrimaryOf(context).withValues(alpha: 0.2),
    );
  }

  // ---------- 各科室/模块正确率面板 ----------
  Widget _buildModuleAccuracy() {
    final byDept = (_stats?['byDepartment'] as List<dynamic>?) ?? [];
    final deptMap = <String, Map<String, dynamic>>{};
    for (final d in byDept) {
      final m = d as Map<String, dynamic>;
      deptMap[m['department'] as String? ?? ''] = m;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SerifText('模块正确率', fontSize: 15, color: AppColors.textOf(context)),
            MonoText('薄弱模块', fontSize: 10, color: AppColors.vermilion),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '各科室做题数、正确率一览，正确率偏低模块建议重点练习',
          style: TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
        ),
        const SizedBox(height: 12),
        ..._departments!.map((dept) => _moduleAccuracyTile(
              dept as String,
              deptMap[dept] ?? const <String, dynamic>{},
            )),
      ],
    );
  }

  Widget _moduleAccuracyTile(String dept, Map<String, dynamic> stat) {
    final total = (stat['total'] as num?)?.toInt() ?? 0;
    final answered = (stat['answered'] as num?)?.toInt() ?? 0;
    final correct = (stat['correct'] as num?)?.toInt() ?? 0;
    final accuracy = (stat['accuracy'] as num?)?.toDouble() ?? 0.0;
    final isWeak = answered > 0 && accuracy < 0.6;
    final hasRecord = answered > 0;

    return GestureDetector(
      onTap: () => _openPractice(dept),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(
            color: isWeak ? AppColors.vermilion.withValues(alpha: 0.5) : AppColors.surfaceEdgeOf(context),
            width: isWeak ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isWeak ? AppColors.vermilionSoftOf(context) : AppColors.mossTintOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(
                    isWeak ? Icons.warning_amber_rounded : Icons.local_hospital,
                    size: 15,
                    color: isWeak ? AppColors.vermilion : AppColors.primaryOf(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SerifText(dept, fontSize: 14, color: AppColors.textOf(context)),
                ),
                if (isWeak)
                  AppChip(label: '需加强', type: ChipType.vermilion)
                else if (hasRecord)
                  AppChip(label: '${(accuracy * 100).round()}%', type: ChipType.moss)
                else
                  MonoText('未练习', fontSize: 10, color: AppColors.text4Of(context)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppProgressBar(
                    value: hasRecord ? accuracy : 0,
                    height: 6,
                    backgroundColor: AppColors.paper2Of(context),
                    foregroundColor: isWeak ? AppColors.vermilion : AppColors.primaryOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                MonoText('$answered/$total', fontSize: 10, color: AppColors.text3Of(context)),
                const SizedBox(width: 6),
                MonoText('答对$correct', fontSize: 10, color: AppColors.text4Of(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 题库浏览入口 ----------
  Widget _buildBankEntry() {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.questionBank),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.indigoSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.indigo,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.grid_view_rounded, size: 20, color: AppColors.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText('浏览题库', fontSize: 15, color: AppColors.textOf(context)),
                  const SizedBox(height: 3),
                  Text(
                    '按科室 / 知识点 / 难度 / 题型筛选，逐题练习',
                    style: TextStyle(fontSize: 12, color: AppColors.text3Of(context)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18, color: AppColors.indigo),
          ],
        ),
      ),
    );
  }

  void _openPractice(String department) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionPracticeScreen(title: department, department: department),
      ),
    );
  }
}
