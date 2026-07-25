import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// OSCE 六维雷达图结果页
class OsceResultScreen extends StatelessWidget {
const   OsceResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 状态栏（绿色背景）
            Container(
              color: AppColors.moss,
              height: 44,
              padding: const EdgeInsets.only(left: 4, right: 28),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.chevron_left, size: 22, color: AppColors.paper),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.goNamed(RouteNames.studentHome),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '10:02',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.paper,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 20,
                    height: 10,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.paper, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.68,
                      child: Container(color: AppColors.paper),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHero(),
                  _buildRadarChart(context, ),
                  _buildFeedbackBlock(context, 
                    '主要优点',
                    AppColors.moss,
                    [
                      '主诉采集准确，胸痛性质、部位、放射描述清晰',
                      '及时识别 ST 段抬高与肌钙蛋白升高的关键证据',
                      '对患者"养家"担忧给予共情回应，体现人文关怀',
                    ],
                  ),
                  _buildFeedbackBlock(context, 
                    '优先改进点',
                    AppColors.vermilion,
                    [
                      '未询问胸痛诱因（体力活动/情绪），影响 ACS 鉴别',
                      '未采集药物过敏史，存在安全风险',
                      '心肌酶谱与肌钙蛋白重复开立，违反卫生经济学原则',
                    ],
                  ),
                  _buildRecommendation(context, ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
                    child: AppPrimaryButton(
                      label: '查看 AI 复盘报告',
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      fullWidth: true,
                      onPressed: () => context.pushNamed(RouteNames.reviewReport),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.moss,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Column(
        children: [
          const MonoText(
            '问诊结束 · OSCE 临床考核',
            fontSize: 11,
            color: Color(0xFFB8C9B8),
            letterSpacing: 0.14,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '82',
                style: TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                  fontSize: 64,
                  fontWeight: FontWeight.w600,
                  color: AppColors.paper,
                  height: 1,
                  letterSpacing: -0.04,
                ),
              ),
              const Text(
                ' /100',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFFB8C9B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '良好 — 接近优秀水平',
            style: TextStyle(
              fontFamily: 'NotoSerifSC',
              fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
              fontSize: 14,
              color: Color(0xFFD8E0D3),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(painter: _RadarPainter(ruleColor: AppColors.ruleOf(context), textColor: AppColors.textOf(context), text3Color: AppColors.text3Of(context))),
          ),
          const SizedBox(height: 16),
          _buildRadarLegend(),
        ],
      ),
    );
  }

  Widget _buildRadarLegend() {
    final items = [
      ('病史采集', 88, AppColors.chart1),
      ('诊断逻辑', 85, AppColors.chart2),
      ('沟通技巧', 79, AppColors.chart3),
      ('人文关怀', 90, AppColors.chart4),
      ('检查决策', 76, AppColors.moss3),
      ('文书规范', 82, AppColors.amber),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 16,
        childAspectRatio: 3.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (name, score, color) = items[i];
        return Container(
     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
        child: Text(name, style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
              ),
              Text(
                '$score',
        style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackBlock(BuildContext context, String title, Color color, List<String> items) {
    return Container(
   margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
   padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                color == AppColors.moss ? Icons.check_circle : Icons.error_outline,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              MonoText(title.toUpperCase(), fontSize: 11, color: color, letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: TextStyle(color: color, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
          style: TextStyle(fontSize: 13, color: AppColors.text2Of(context), height: 1.55),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildRecommendation(BuildContext context) {
    return Container(
   margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
   padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book, size: 12, color: AppColors.moss),
              SizedBox(width: 6),
              MonoText('推荐训练', fontSize: 11, color: AppColors.moss, letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 8),
          _recoItem(context, '不稳定型心绞痛 · 鉴别诊断', '心血管 · 标准 · 引用 23 次'),
          const SizedBox(height: 8),
          _recoItem(context, '主动脉夹层 · 急诊识别', '心血管 · 困难 · 引用 15 次'),
          const SizedBox(height: 12),
          Container(
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
                  child: Container(width: 2, color: AppColors.moss),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.book, size: 10, color: AppColors.moss),
                      SizedBox(width: 4),
                      Expanded(
                        child: MonoText(
                          '教材：《内科学》第9版 · 第三篇第七章 · P236-258',
                          fontSize: 11.5,
                          color: AppColors.moss,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recoItem(BuildContext context, String title, String subtitle) {
    return Container(
   padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ruleSoft),
      ),
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
          Builder(builder: (ctx) => AppGhostButton(
            label: '开始',
            small: true,
            onPressed: () => ctx.pushNamed(RouteNames.chat),
          )),
        ],
      ),
    );
  }
}

/// 雷达图 Painter
class _RadarPainter extends CustomPainter {
  final Color ruleColor;
  final Color textColor;
  final Color text3Color;

  _RadarPainter({
    required this.ruleColor,
    required this.textColor,
    required this.text3Color,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.4;

    // 6 个维度
    final dimensions = [
      ('病史采集', 88),
      ('诊断逻辑', 85),
      ('沟通技巧', 79),
      ('人文关怀', 90),
      ('检查决策', 76),
      ('文书规范', 82),
    ];

    final n = dimensions.length;
    final angleStep = 2 * pi / n;

    // 网格（4层）
    final gridPaint = Paint()
      ..color = ruleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var level = 1; level <= 4; level++) {
      final r = radius * level / 4;
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

    // 轴线
    final axisPaint = Paint()
      ..color = ruleColor
      ..strokeWidth = 0.6;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + radius * cos(angle), cy + radius * sin(angle)),
        axisPaint,
      );
    }

    // 数据多边形
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final score = dimensions[i].$2;
      final r = radius * score / 100;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.moss.withOpacity(0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.moss
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 数据点
    final dotPaint = Paint()..color = AppColors.moss;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final score = dimensions[i].$2;
      final r = radius * score / 100;
      canvas.drawCircle(
        Offset(cx + r * cos(angle), cy + r * sin(angle)),
        4,
        dotPaint,
      );
    }

    // 轴标签
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final labelR = radius + 18;
      final x = cx + labelR * cos(angle);
      final y = cy + labelR * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: dimensions[i].$1,
     style: TextStyle(
            fontFamily: 'NotoSerifSC',
            fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));

      // 分数
      final scoreTp = TextPainter(
        text: TextSpan(
          text: '${dimensions[i].$2}',
     style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: text3Color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      scoreTp.layout();
      final scoreR = radius * dimensions[i].$2 / 100;
      final sx = cx + scoreR * cos(angle);
      final sy = cy + scoreR * sin(angle);
      scoreTp.paint(canvas, Offset(sx - scoreTp.width / 2, sy - scoreTp.height - 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
