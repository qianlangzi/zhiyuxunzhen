import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// 卡片默认内边距（抽为顶层 const，规避部分 analyzer 在默认参数位不接受 const 构造调用的问题）
const EdgeInsets _kCardPadding = EdgeInsets.all(14.0);

// ============================================================
// 灵动反馈工具
// ============================================================

/// 按压缩放反馈 —— 给可点击元素加「轻压回弹」的灵动感。
///
/// 用原始 [Listener] 监听指针按起，避免与内部按钮/InkWell 的手势竞技场冲突；
/// 按压时微缩（0.97）+ 松手回弹（elasticOut），克制而自然，不阻断点击。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp:
          widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel:
          widget.enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 180),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// 按钮
// ============================================================

/// 主按钮
class AppPrimaryButton extends StatelessWidget {
const   AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: onPressed != null,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: small ? 34 : 44,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOf(context),
            foregroundColor: AppColors.onPrimaryOf(context),
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: small ? 14 : 20,
              vertical: small ? 6 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            textStyle: TextStyle(
              fontSize: small ? 12 : 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
      if (icon != null) ...[icon!, SizedBox(width: 6)],
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

/// 幽灵按钮
class AppGhostButton extends StatelessWidget {
const   AppGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.small = false,
    this.dashed = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;
  final bool small;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final borderColor = dashed
        ? AppColors.ruleOf(context)
        : AppColors.surfaceEdgeOf(context);

    // dashed 边框用 CustomPainter 绘制，Border.all 不支持虚线
    if (dashed) {
      return PressableScale(
        enabled: onPressed != null,
        child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: small ? 34 : 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: borderColor,
                radius: AppRadius.full,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 14 : 20,
                  vertical: small ? 6 : 12,
                ),
                child: Row(
                  mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, SizedBox(width: 6)],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: small ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text2Of(context),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      );
    }

    return PressableScale(
      enabled: onPressed != null,
      child: SizedBox(
      width: fullWidth ? double.infinity : null,
      height: small ? 34 : 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text2Of(context),
          backgroundColor: Colors.transparent,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: small ? 14 : 20,
            vertical: small ? 6 : 12,
          ),
          textStyle: TextStyle(
            fontSize: small ? 12 : 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text2Of(context),
            letterSpacing: 0.2,
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
      if (icon != null) ...[icon!, SizedBox(width: 6)],
            Text(label),
          ],
        ),
      ),
    ),
    );
  }
}

// ============================================================
// 按键区 —— 渐变胶囊主按钮（用于登录/注册等首屏 CTA）
// ============================================================

/// 渐变胶囊主按钮 —— 在纯色按钮基础上叠一层同色系柔和渐变 + 底部高光受光，
/// 提升首屏 CTA 的质感。克制使用：仅用于登录、注册等关键行动按钮。
class AppGradientButton extends StatelessWidget {
  const AppGradientButton({
    super.key,
    required this.label,
    required this.color,
    this.onPressed,
    this.height = 52,
    this.loading = false,
    this.letterSpacing = 2,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final double height;
  final bool loading;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: !loading && onPressed != null,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: InkWell(
            onTap: (loading) ? null : onPressed,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Ink(
              height: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.20),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: letterSpacing,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 虚线边框绘制器
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashGap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 图标按钮
class AppIconButton extends StatelessWidget {
const   AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.color,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        color: color ?? AppColors.text2Of(context),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          maxWidth: size,
          maxHeight: size,
        ),
      ),
    );
  }
}

// ============================================================
// 卡片
// ============================================================

/// 通用卡片
class AppCard extends StatelessWidget {
AppCard({
    super.key,
    required this.child,
  this.padding = _kCardPadding,
    this.borderLeft,
    this.opacity = 1.0,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderLeft;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.card(context),
        ),
        child: Stack(
          children: [
            if (borderLeft != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: borderLeft,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.md)),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 纸张容器（浅背景区块）
class AppPaper extends StatelessWidget {
AppPaper({
    super.key,
    required this.child,
  this.padding = _kCardPadding,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
  }
}

// ============================================================
// 标签 / Chip
// ============================================================

/// 状态标签
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.type = ChipType.default_,
    this.fontSize = 11,
  });

  final String label;
  final ChipType type;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: type == ChipType.default_
            ? Border.all(color: AppColors.ruleOf(context).withValues(alpha: 0.6), width: 1)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'JetBrainsMono',
          color: fg,
          letterSpacing: 0.02,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (Color, Color) _colorsOf(BuildContext context) {
    switch (type) {
      case ChipType.moss:
        return (AppColors.surfaceOf(context), AppColors.primaryOf(context));
      case ChipType.vermilion:
        return (AppColors.vermilionSoftOf(context), AppColors.vermilion);
      case ChipType.amber:
        return (AppColors.amberSoftOf(context), AppColors.amber);
      case ChipType.indigo:
        return (AppColors.indigoSoftOf(context), AppColors.indigo);
      case ChipType.default_:
        return (AppColors.surfaceOf(context), AppColors.text2Of(context));
    }
  }
}

enum ChipType { default_, moss, vermilion, amber, indigo }

// ============================================================
// 状态徽章
// ============================================================

/// 状态徽章（带背景色）
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  final String label;
  final StatusBadgeType type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'JetBrainsMono',
          color: fg,
          letterSpacing: 0.04,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colorsOf(BuildContext context) {
    switch (type) {
      case StatusBadgeType.ok:
        return (AppColors.surfaceOf(context), AppColors.primaryOf(context));
      case StatusBadgeType.miss:
        return (AppColors.vermilionSoftOf(context), AppColors.vermilion);
      case StatusBadgeType.warn:
        return (AppColors.amberSoftOf(context), AppColors.amber);
      case StatusBadgeType.info:
        return (AppColors.indigoSoftOf(context), AppColors.indigo);
      case StatusBadgeType.done:
        return (AppColors.surfaceOf(context), AppColors.primaryOf(context));
      case StatusBadgeType.neutral:
        return (AppColors.ruleSoftOf(context), AppColors.text3Of(context));
    }
  }
}

enum StatusBadgeType { ok, miss, warn, info, done, neutral }

// ============================================================
// 区块标题
// ============================================================

/// 区块标题（带编号）
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.number,
    this.trailing,
  });

  final String title;
  final String? number;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (number != null) ...[
            Text(
              number!,
       style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: AppColors.text4Of(context),
                letterSpacing: 0.08,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
       style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 更多链接
class AppMoreLink extends StatelessWidget {
  const AppMoreLink({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
    style: TextStyle(
          fontSize: 12,
          color: AppColors.primaryOf(context),
          fontFamily: 'JetBrainsMono',
        ),
      ),
    );
  }
}

// ============================================================
// 头部标签
// ============================================================

/// 顶部小标签（header-tag）
class AppHeaderTag extends StatelessWidget {
const   AppHeaderTag({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
   style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 10,
        color: AppColors.text4Of(context),
        letterSpacing: 0.12,
      ),
    );
  }
}

// ============================================================
// 文字样式辅助
// ============================================================

/// Mono 文字
class MonoText extends StatelessWidget {
const   MonoText(
    this.data, {
    super.key,
    this.fontSize = 11,
    this.color,
    this.letterSpacing = 0.04,
    this.weight = FontWeight.normal,
  });

  final String data;
  final double fontSize;
  final Color? color;
  final double letterSpacing;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: fontSize,
        color: color ?? AppColors.text3Of(context),
        letterSpacing: letterSpacing,
        fontWeight: weight,
      ),
    );
  }
}

/// 眉标文字（t-eyebrow）
class EyebrowText extends StatelessWidget {
const   EyebrowText(
    this.data, {
    super.key,
    this.color,
  });

  final String data;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      data.toUpperCase(),
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 10,
        color: color ?? AppColors.text3Of(context),
        letterSpacing: 0.12,
      ),
    );
  }
}

/// Serif 文字
class SerifText extends StatelessWidget {
const   SerifText(
    this.data, {
    super.key,
    this.fontSize = 14,
    this.weight = FontWeight.w600,
    this.color,
  });

  final String data;
  final double fontSize;
  final FontWeight weight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? AppColors.textOf(context),
      ),
    );
  }
}

// ============================================================
// 分割线
// ============================================================

/// 双线分割
class DoubleDivider extends StatelessWidget {
const   DoubleDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.ruleOf(context), thickness: 1, height: 3),
        const SizedBox(height: 2),
        Divider(color: AppColors.ruleOf(context), thickness: 1, height: 1),
      ],
    );
  }
}

/// 虚线分割
class DottedDivider extends StatelessWidget {
const   DottedDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DottedLinePainter(color: color ?? AppColors.ruleOf(context)),
    );
  }
}

/// 虚线绘制器
class _DottedLinePainter extends CustomPainter {
  final Color color;

  const _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    const dashWidth = 2.0;
    const dashGap = 2.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}

// ============================================================
// 免责声明
// ============================================================

/// 医学免责声明条
class MedicalDisclaimer extends StatelessWidget {
const   MedicalDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Text(
        AppConstants.medicalDisclaimer,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          color: AppColors.text3Of(context),
          height: 1.5,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    );
  }
}

// ============================================================
// 通用 AppBar
// ============================================================

/// 带 返回 按钮的 AppBar
class AppBackAppBar extends StatelessWidget implements PreferredSizeWidget {
const   AppBackAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.action,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 20, bottom: 10, top: 6),
      child: Row(
        children: [
          InkWell(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.text2Of(context),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context),
                letterSpacing: -0.01,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// 带 标题 + 操作 的 AppBar
class AppTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
const   AppTitleAppBar({
    super.key,
    required this.tag,
    required this.title,
    this.action,
  });

  final String tag;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderTag(label: tag),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOf(context),
                  letterSpacing: -0.02,
                ),
              ),
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(62);
}

// ============================================================
// 进度条
// ============================================================

/// 水平进度条
class AppProgressBar extends StatelessWidget {
const   AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.backgroundColor,
    this.foregroundColor,
    this.radius = 3,
  });

  final double value;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: backgroundColor ?? AppColors.surfaceOf(context),
          valueColor: AlwaysStoppedAnimation(
            foregroundColor ?? AppColors.vermilion,
          ),
        ),
      ),
    );
  }
}
