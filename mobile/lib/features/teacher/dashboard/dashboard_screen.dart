import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 学情看板
class DashboardScreen extends StatelessWidget {
const   DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '学情看板 · 心血管 03',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: AppIconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => AppFeedback.info(context, '学情报表导出功能即将开放（演示版）'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatGrid(),
                    _buildOsceSection(context, ),
                    _buildCommonMissSection(context, ),
                    _buildMisdiagnosisSection(context, ),
                    _buildRemediation(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    return GridView.builder(
      shrinkWrap: true,
   physics: NeverScrollableScrollPhysics(),
   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: 4,
      itemBuilder: (context, i) {
        final stats = [
          ('作业完成率', '68%', '↑ 12% · 较上周', AppColors.primaryOf(context)),
          ('平均 OSCE', '82.4', '↑ 4.2 · 较上周', AppColors.primaryOf(context)),
          ('批阅效率', '2.8min/份', '↓ 71% · 较纯人工', AppColors.primaryOf(context)),
          ('过度检查率', '23%', '↑ 5% · 需关注', AppColors.vermilion),
        ];
        final (label, value, trend, color) = stats[i];
        final isNegativeTrend = trend.startsWith('↑') && label == '过度检查率';
        return Container(
     padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoText(label.toUpperCase(), fontSize: 10, color: AppColors.text3Of(context), letterSpacing: 0.1),
        SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 2),
              MonoText(trend, fontSize: 11, color: isNegativeTrend ? AppColors.vermilion : AppColors.primaryOf(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOsceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '01', title: 'OSCE 六维均分'),
        AppPaper(
          child: Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(painter: _MiniRadarPainter(ruleColor: AppColors.ruleOf(context), mossColor: AppColors.primaryOf(context))),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _osceRow(context, '病史采集', '85.2', AppColors.primaryOf(context)),
                    _osceRow(context, '诊断逻辑', '82.6', AppColors.primaryOf(context)),
                    _osceRow(context, '沟通技巧', '78.4', AppColors.amber),
                    _osceRow(context, '人文关怀', '86.8', AppColors.primaryOf(context)),
                    _osceRow(context, '检查决策', '80.8', AppColors.moss3),
                    _osceRow(context, '文书规范', '81.6', AppColors.amber),
                    const DottedDivider(),
                    _osceRow(context, '综合均分', '82.4', AppColors.primaryOf(context), bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _osceRow(BuildContext context, String label, String score, Color color, {bool bold = false}) {
    return Padding(
   padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
                color: AppColors.text2Of(context),
              ),
            ),
          ),
          Text(
            score,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonMissSection(BuildContext context) {
    final items = [
      ('胸痛诱因（体力活动/情绪）', 21, 0.84),
      ('过敏史', 15, 0.60),
      ('家族史', 12, 0.48),
      ('用药依从性', 9, 0.36),
      ('个人史（吸烟/饮酒）', 7, 0.28),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '02',
          title: '共性漏问项',
          trailing: Builder(builder: (ctx) => AppMoreLink(label: 'Top 5', onTap: () => AppFeedback.info(ctx, '已展示 Top 5 漏问项'))),
        ),
        AppPaper(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: items.map((e) => _missRow(context, e.$1, e.$2, e.$3)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _missRow(BuildContext context, String name, int count, double barPercent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
     Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)))),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            height: 4,
            child: AppProgressBar(value: barPercent, height: 4, foregroundColor: AppColors.vermilion, radius: 2),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.vermilion,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMisdiagnosisSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '03', title: '共性误诊'),
        AppPaper(
          child: Column(
            children: [
              _misdiagRow(context, '误诊为胃食管反流', '急性下壁心梗不典型表现', '8 人'),
              const DottedDivider(),
              _misdiagRow(context, '漏诊主动脉夹层', '鉴别诊断未列出', '6 人'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _misdiagRow(BuildContext context, String title, String subtitle, String count) {
    return Padding(
   padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
       Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textOf(context))),
              const SizedBox(height: 2),
              MonoText(subtitle, fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
          AppChip(label: count, type: ChipType.vermilion),
        ],
      ),
    );
  }

  Widget _buildRemediation(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyebrowText('REMEDIATION · 课堂补救建议', color: AppColors.onPrimarySoftOf(context)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.onPrimaryOf(context), height: 1.6),
              children: [
                TextSpan(text: '建议下次课堂重点讲解：'),
                TextSpan(text: '胸痛的诱因询问框架', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '、'),
                TextSpan(text: 'ACS 不典型表现的识别', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '，并安排主动脉夹层鉴别诊断的随堂练习。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRadarPainter extends CustomPainter {
  final Color ruleColor;
  final Color mossColor;

  _MiniRadarPainter({required this.ruleColor, required this.mossColor});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.38;

    final scores = [0.85, 0.83, 0.78, 0.87, 0.80, 0.82];
    final n = scores.length;
    final angleStep = 2 * pi / n;

    // 网格
    final gridPaint = Paint()
      ..color = ruleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var level = 1; level <= 2; level++) {
      final r = radius * level / 2;
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final angle = -pi / 2 + i * angleStep;
        final x = cx + r * cos(angle);
        final y = cy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // 数据
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final r = radius * scores[i];
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = mossColor.withValues(alpha: 0.15)..style = PaintingStyle.fill);
    canvas.drawPath(dataPath, Paint()..color = mossColor..style = PaintingStyle.stroke..strokeWidth = 2);

    // 点
    final dotPaint = Paint()..color = mossColor;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final r = radius * scores[i];
      canvas.drawCircle(Offset(cx + r * cos(angle), cy + r * sin(angle)), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRadarPainter old) =>
      ruleColor != old.ruleColor || mossColor != old.mossColor;
}
