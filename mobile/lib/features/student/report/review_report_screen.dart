import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/student_service.dart';
import 'report_pdf_service.dart';

/// AI 复盘报告
///
/// 数据来源：GET /api/v1/student/review-report/overview
/// 返回 StudentLearningOverviewVO：abilityScores / activityDays / completedSessionCount
/// PDF 导出走 POST /api/v1/student/review-report/export，由 report_pdf_service.dart 处理。
class ReviewReportScreen extends ConsumerStatefulWidget {
  const ReviewReportScreen({super.key});

  @override
  ConsumerState<ReviewReportScreen> createState() => _ReviewReportScreenState();
}

class _ReviewReportScreenState extends ConsumerState<ReviewReportScreen> {
  Map<String, dynamic>? _overview;
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    try {
      final data = await StudentService().getReportOverview();
      if (!mounted) return;
      setState(() {
        _overview = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = '加载失败：$e';
        _isLoading = false;
      });
    }
  }

  /// 导出真实 PDF：拉取 export 数据 → 本地生成 → 系统打印/分享
  Future<void> _exportPdf() async {
    if (!mounted) return;
    final hide = AppFeedback.showLoading(context, label: '正在生成复盘 PDF…');
    try {
      final data = await StudentService().exportReport();
      if (!mounted) return;
      hide();
      if (data == null) {
        AppFeedback.error(context, '导出失败：未获取到报告数据，请确认已完成复盘');
        return;
      }
      await ReviewReportPdf.export(data);
    } catch (e) {
      if (mounted) {
        hide();
        AppFeedback.error(context, '导出失败：$e');
      }
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
              title: 'AI 复盘报告',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.osceResult),
              action: const AppIconButton(
                icon: Icon(Icons.ios_share, size: 20),
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_overview == null) {
      return _buildEmpty(_errorMsg ?? '暂无报告数据');
    }
    final sessionCount = (_overview!['completedSessionCount'] as num?)?.toInt() ?? 0;
    final abilityScores = _overview!['abilityScores'] as Map<String, dynamic>?;
    final activityDays = (_overview!['activityDays'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    if (sessionCount == 0 &&
        (abilityScores == null || abilityScores.isEmpty) &&
        activityDays.isEmpty) {
      return _buildEmpty('暂无训练数据，完成问诊后再来查看');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(context, sessionCount, abilityScores),
          const SizedBox(height: 24),
          if (abilityScores != null && abilityScores.isNotEmpty) ...[
            _buildAbilitySection(context, abilityScores),
            const SizedBox(height: 24),
          ],
          if (activityDays.isNotEmpty) ...[
            _buildActivitySection(context, activityDays),
            const SizedBox(height: 24),
          ],
          AppPrimaryButton(
            label: '导出完整 PDF',
            icon: const Icon(Icons.download, size: 14),
            fullWidth: true,
            onPressed: _exportPdf,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 16),
          AppGhostButton(
            label: '返回',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(RouteNames.studentHome),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(
      BuildContext context, int sessionCount, Map<String, dynamic>? abilityScores) {
    final today = _formatDate(DateTime.now());
    // 低分维度数：评分 < 70 视为薄弱
    int lowScoreCount = 0;
    if (abilityScores != null) {
      lowScoreCount = abilityScores.values
          .where((v) => ((v as num?)?.toInt() ?? 100) < 70)
          .length;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          EyebrowText('REVIEW REPORT · $today',
              color: AppColors.primaryOf(context)),
          const SizedBox(height: 10),
          Text(
            'AI 复盘报告\n近 90 天训练概览',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textOf(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          MonoText('基于近 90 天共 $sessionCount 次问诊训练', fontSize: 11),
          const SizedBox(height: 14),
          const DoubleDivider(),
          const SizedBox(height: 14),
          Row(
            children: [
              _coverStat(context, '$sessionCount', '训练次数', AppColors.textOf(context)),
              _coverStat(context, '$lowScoreCount', '薄弱维度',
                  lowScoreCount > 0 ? AppColors.vermilion : AppColors.textOf(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverStat(BuildContext context, String num, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            num,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _buildAbilitySection(
      BuildContext context, Map<String, dynamic> abilityScores) {
    final entries = abilityScores.entries.toList()
      ..sort((a, b) {
        final av = ((a.value as num?)?.toDouble()) ?? 0;
        final bv = ((b.value as num?)?.toDouble()) ?? 0;
        return av.compareTo(bv);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            MonoText('01', fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.08),
            const SizedBox(width: 8),
            Expanded(child: SerifText('能力评分详情', fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OSCE 各维度平均分（0-100）。低于 70 视为薄弱，建议重点强化。',
                style: TextStyle(
                    fontSize: 13.5, color: AppColors.text2Of(context), height: 1.65),
              ),
              const SizedBox(height: 12),
              ...entries.map((e) {
                final score = ((e.value as num?)?.toDouble()) ?? 0;
                final isLow = score < 70;
                return _abilityRow(context, _abilityLabel(e.key), score, isLow);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _abilityRow(BuildContext context, String name, double score, bool isLow) {
    final color = isLow ? AppColors.vermilion : AppColors.primaryOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MonoText(name,
                  fontSize: 12, color: AppColors.text2Of(context)),
              MonoText(score.toStringAsFixed(0),
                  fontSize: 12, color: color),
            ],
          ),
          const SizedBox(height: 4),
          AppProgressBar(
            value: (score / 100).clamp(0.0, 1.0),
            height: 4,
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            radius: 2,
          ),
        ],
      ),
    );
  }

  String _abilityLabel(String key) {
    switch (key) {
      case 'history':
        return '病史采集';
      case 'logic':
        return '诊断逻辑';
      case 'communication':
        return '沟通技巧';
      case 'humanity':
        return '人文关怀';
      case 'exam':
        return '检查决策';
      case 'record':
        return '文书规范';
      default:
        return key;
    }
  }

  Widget _buildActivitySection(
      BuildContext context, List<Map<String, dynamic>> activityDays) {
    // 倒序展示最近 7 天
    final list = [...activityDays]
      ..sort((a, b) {
        final aDate = (a['date'] as String?) ?? '';
        final bDate = (b['date'] as String?) ?? '';
        return bDate.compareTo(aDate);
      });
    final recent = list.take(7).toList();
    final total = activityDays.fold<int>(
        0, (s, e) => s + (((e['completedCount'] as num?)?.toInt()) ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            MonoText('02', fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.08),
            const SizedBox(width: 8),
            Expanded(child: SerifText('近期作答活动', fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '近 90 天累计 $total 次作答记录。展示最近 ${recent.length} 天。',
                style: TextStyle(
                    fontSize: 13.5, color: AppColors.text2Of(context), height: 1.65),
              ),
              const SizedBox(height: 12),
              ...recent.map((d) => _activityRow(context, d)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityRow(BuildContext context, Map<String, dynamic> day) {
    final date = (day['date'] as String?) ?? '--';
    final count = (day['completedCount'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MonoText(date, fontSize: 12, color: AppColors.text2Of(context)),
          MonoText('$count 次',
              fontSize: 12,
              color: count > 0 ? AppColors.primaryOf(context) : AppColors.text4Of(context)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
  }
}
