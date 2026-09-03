/// 「纸感场景层」组件库
///
/// 解决学生端 tab 之间的风格断层：首页有「插画层 + 渐变遮罩 + 弧形浮层」，
/// 而训练 / 成长页只有「AppBar + 纯色卡片」，观感像后台管理系统。
///
/// 本文件把首页那套层次抽成可复用组件：
/// - [AmbientBackdrop]：氛围背景（径向光晕 + 渐隐细网格 + 装饰弧），不用图片、不增包体；
/// - [AmbientScaffold]：紧凑头（AppBar + 一行描述）+ 滚动内容区；
/// - [PaperCard]：带色晕渐变的纸卡，替代过去的纯色块；
/// - [RingGauge]：环形进度与数据可视化。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'app_widgets.dart';

// ============================================================
// 氛围背景层
// ============================================================

/// 氛围背景 —— 径向光晕 + 渐隐细网格 + 装饰弧线
///
/// 全部用 Canvas 绘制（径向渐变 + 直线），不依赖任何图片资源，
/// 颜色一律取自当前主题预设，深色模式自动适配。
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    super.key,
    this.colors,
    this.grid = true,
    this.arcs = true,
    this.height = 220,
  });

  /// 光晕颜色，缺省为「主色 → 琥珀 → 靛蓝」三色
  final List<Color>? colors;

  /// 是否绘制渐隐细网格（宣纸 / 病历格的秩序感）
  final bool grid;

  /// 是否绘制装饰弧线
  final bool arcs;

  /// 背景高度
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = colors ??
        [
          AppColors.primaryOf(context),
          AppColors.amberOf(context),
          AppColors.indigoOf(context),
        ];
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _AmbientPainter(
          glowA: pal[0],
          glowB: pal.length > 1 ? pal[1] : pal[0],
          glowC: pal.length > 2 ? pal[2] : pal[0],
          rule: AppColors.ruleOf(context),
          bg: AppColors.bgOf(context),
          showGrid: grid,
          showArcs: arcs,
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.glowA,
    required this.glowB,
    required this.glowC,
    required this.rule,
    required this.bg,
    required this.showGrid,
    required this.showArcs,
  });

  final Color glowA;
  final Color glowB;
  final Color glowC;
  final Color rule;
  final Color bg;
  final bool showGrid;
  final bool showArcs;

  void _glow(Canvas canvas, Offset center, double radius, Color color,
      double alpha) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.45),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 光晕：三团低饱和径向渐变，营造「场景纵深」 ----
    _glow(canvas, Offset(size.width * 0.88, -size.height * 0.10),
        size.width * 0.66, glowA, 0.20);
    _glow(canvas, Offset(-size.width * 0.16, size.height * 0.06),
        size.width * 0.58, glowB, 0.14);
    _glow(canvas, Offset(size.width * 0.52, size.height * 0.72),
        size.width * 0.50, glowC, 0.10);

    // ---- 细网格：病历格秩序感，向下渐隐 ----
    if (showGrid) {
      const step = 26.0;
      final gridPaint = Paint()
        ..color = rule.withValues(alpha: 0.16)
        ..strokeWidth = 0.6;
      for (double x = 0; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
      // 渐隐遮罩：让网格自然消隐在内容浮层之上
      final fadePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.30),
          Offset(0, size.height),
          [bg.withValues(alpha: 0), bg.withValues(alpha: 0.92)],
        );
      canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.30, size.width, size.height * 0.70),
          fadePaint);
    }

    // ---- 装饰弧线：右上同心弧，呼应首页弧形浮层 ----
    if (showArcs) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = glowA.withValues(alpha: 0.18);
      final center = Offset(size.width * 0.96, size.height * 0.06);
      for (var i = 0; i < 3; i++) {
        final r = size.width * (0.30 + i * 0.11);
        canvas.drawArc(Rect.fromCircle(center: center, radius: r),
            math.pi * 0.62, math.pi * 0.52, false, arcPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      glowA != old.glowA ||
      glowB != old.glowB ||
      glowC != old.glowC ||
      rule != old.rule ||
      bg != old.bg ||
      showGrid != old.showGrid ||
      showArcs != old.showArcs;
}

// ============================================================
// 页面骨架：氛围头 + 弧形浮层内容区
// ============================================================

/// 氛围头 —— 浮在 [AmbientBackdrop] 之上的标题区
///
/// 视觉上等价于 [AppTitleAppBar]，但支持副标题、无背景色、可压在氛围层上。
class AmbientHeader extends StatelessWidget {
  const AmbientHeader({
    super.key,
    required this.tag,
    required this.title,
    this.subtitle,
    this.action,
    this.onBack,
  });

  final String tag;
  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final onSurface = AppColors.textOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: onBack != null ? 12 : 20,
        right: 16,
        top: 6,
        bottom: subtitle != null ? 16 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            AppIconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: onBack,
            ),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppHeaderTag(label: tag),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.02,
                    color: onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AppColors.text3Of(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}

/// 氛围页骨架（紧凑头版）
///
/// 结构：常规一行 AppBar + 一行副标题小字 + 滚动内容区。
/// 不再铺满屏氛围背景——氛围感交给内容里的 Hero 卡自带背景装饰（光晕 / 弧线 / 细网格），
/// 页面头部保持克制，避免顶部出现一整块「氛围色块」。
class AmbientScaffold extends StatelessWidget {
  const AmbientScaffold({
    super.key,
    required this.tag,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.onBack,
    this.onRefresh,
    this.bottomInset = 96,
    this.loading = false,
    this.empty,
  });

  final String tag;
  final String title;

  /// 一行简短描述，显示在标题下方
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onBack;

  /// 主体内容，通常是一个 [ListView]
  final Widget child;

  final Future<void> Function()? onRefresh;

  /// 内容区底部留白（避开悬浮底栏）
  final double bottomInset;

  /// 首屏加载态：显示骨架而不是空白
  final bool loading;

  /// 空态：非空且 [loading] 为 false 时展示
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bgOf(context);

    final body = empty != null && !loading
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
            children: [empty!],
          )
        : child;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTitleAppBar(
              tag: tag,
              title: title,
              action: action,
              onBack: onBack,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.text3Of(context),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: loading
                  ? _AmbientSkeleton(bottomInset: bottomInset)
                  : (onRefresh != null
                      ? RefreshIndicator(onRefresh: onRefresh!, child: body)
                      : body),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientSkeleton extends StatelessWidget {
  const _AmbientSkeleton({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
      children: const [
        AppSkeleton(height: 132, radius: AppRadius.xl),
        SizedBox(height: 14),
        AppSkeleton(height: 168, radius: AppRadius.xl),
        SizedBox(height: 14),
        AppSkeleton(height: 176, radius: AppRadius.xl),
        SizedBox(height: 14),
        AppSkeleton(height: 120, radius: AppRadius.xl),
      ],
    );
  }
}

// ============================================================
// 纸卡
// ============================================================

/// 纸卡 —— 替代过往的纯色块
///
/// 层次：柔和色晕渐变（tint → surface）+ 顶部 1px 内高光 + 发丝描边 + 单层投影。
/// 传 [onTap] 自动附带按压缩放与水波纹。
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.tint,
    this.tintStrength = 1.0,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.xl,
    this.onTap,
    this.accent,
    this.strong = false,
  });

  final Widget child;

  /// 色晕来源色，缺省用主色
  final Color? tint;

  /// 色晕强度（0=近乎纯白，1=标准）
  final double tintStrength;

  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  /// 左侧竖向渐变强调条
  final Color? accent;

  /// 是否用更强的色晕（用于 Hero 卡的底色）
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.surfaceOf(context);
    final base = tint ?? AppColors.primaryOf(context);
    final k = tintStrength * (strong ? 1.0 : 1.0);

    final top = Color.lerp(surface, base, (strong ? 0.20 : 0.11) * k)!;
    final bottom = Color.lerp(surface, base, (strong ? 0.07 : 0.022) * k)!;

    return PressableScale(
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: base.withValues(alpha: 0.06),
          highlightColor: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bottom],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.9)),
              boxShadow: AppShadow.card(context),
            ),
            child: Stack(
              children: [
                // 顶部内高光 —— 让卡片有「受光」的实体感
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                if (accent != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [accent!, accent!.withValues(alpha: 0.15)],
                        ),
                      ),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 图标徽标
// ============================================================

/// 渐变图标徽标 —— 替代「单色圆底 + 图标」
///
/// 用主色的斜向渐变底 + 顶部内高光，图标本身保持纯色，整体更通透。
class GradientIconBadge extends StatelessWidget {
  const GradientIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  /// 右上角小徽标（红点 / 数字）
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(size * 0.32),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, size: iconSize ?? size * 0.5, color: color),
          ),
          if (badge != null)
            Positioned(right: -2, top: -2, child: badge!),
        ],
      ),
    );
  }
}

// ============================================================
// 数据可视化
// ============================================================

/// 环形进度 —— 渐变描边 + 圆头端点 + 中心插槽
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.value,
    this.size = 96,
    this.stroke = 9,
    this.colors,
    this.trackColor,
    this.child,
  });

  /// 0.0 ~ 1.0
  final double value;
  final double size;
  final double stroke;
  final List<Color>? colors;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final pal = colors ??
        [
          AppColors.primaryOf(context),
          AppColors.moss3Of(context),
        ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              value: value.clamp(0.0, 1.0),
              stroke: stroke,
              colors: pal,
              trackColor:
                  trackColor ?? AppColors.primaryOf(context).withValues(alpha: 0.14),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.colors,
    required this.trackColor,
  });

  final double value;
  final double stroke;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    if (value <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          center,
          colors.length > 2
              ? colors
              : [colors.first, colors.first, colors.last],
          colors.length > 2
              ? const [0.0, 0.5, 1.0]
              : const [0.0, 0.55, 1.0],
          TileMode.clamp,
          -math.pi / 2,
          math.pi * 1.5,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      value != old.value ||
      stroke != old.stroke ||
      trackColor != old.trackColor ||
      colors != old.colors;
}

/// 单条能力条
class AbilityBar extends StatelessWidget {
  const AbilityBar({
    super.key,
    required this.label,
    required this.score,
    this.max = 100,
    this.lowThreshold = 70,
    this.color,
  });

  final String label;
  final double score;
  final double max;
  final double lowThreshold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isLow = score < lowThreshold;
    final base = color ??
        (isLow ? AppColors.vermilionOf(context) : AppColors.primaryOf(context));
    final ratio = (score / max).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.text2Of(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Container(color: base.withValues(alpha: 0.13)),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [base, base.withValues(alpha: 0.62)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 26,
            child: Text(
              score.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: kCjkMonoFallback,
                color: base,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 区块小标题
class PaperSectionLabel extends StatelessWidget {
  const PaperSectionLabel({
    super.key,
    required this.title,
    this.meta,
    this.onMore,
    this.moreLabel = '查看全部',
    this.icon,
  });

  final String title;
  final String? meta;
  final VoidCallback? onMore;
  final String moreLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.primaryOf(context)),
          const SizedBox(width: 7),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
          ),
        ),
        const SizedBox(width: 8),
        if (meta != null)
          Expanded(
            child: MonoText(
              meta!,
              fontSize: 11,
              color: AppColors.text4Of(context),
            ),
          )
        else
          const Spacer(),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moreLabel,
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.primaryOf(context)),
                ),
                Icon(Icons.chevron_right,
                    size: 15, color: AppColors.primaryOf(context)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 数据小胶囊（Hero 卡内的指标单元）
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.onPrimary = false,
  });

  final String value;
  final String label;
  final Color? color;

  /// 位于深色 / 主色底上时，弱化文字用不透明度而非灰阶
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (onPrimary
            ? AppColors.onPrimaryOf(context)
            : AppColors.textOf(context));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.15,
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: kCjkMonoFallback,
            color: c,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.2,
            color: onPrimary ? c.withValues(alpha: 0.78) : AppColors.text3Of(context),
          ),
        ),
      ],
    );
  }
}
