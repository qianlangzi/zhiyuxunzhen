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

/// 上浮入场 —— 灵动微交互：元素以「轻微上移 + 淡入」入场。
///
/// 纯粹装饰，内容始终可达：动画结束态即内容最终态；开启「减少动态」时直接展示，
/// 不做位移。用 [delay] 让列表元素错峰入场（stagger），形成灵动的序列感。
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;

  /// 上移距离，单位像素。
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  bool _reduce = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 注：不要在 initState 读取 MediaQuery（可访问，但 dependOn 在 initState 未完成前非法）。
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在正确的生命周期点读取「减少动态」偏好，并只触发一次入场动画。
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started && !_reduce) {
      _started = true;
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce) return widget.child;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 可折叠区块 —— 灵动的手风琴：点击头部开合，内容以「高度 + 透明度」动画展开/
/// 收起，箭头同步旋转。适合容纳数据密度较高的次级内容（如「分模块占比」）。
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.meta,
    this.initiallyExpanded = false,
  });

  /// 头部标题
  final String title;

  /// 头部右侧补充信息（如「共 N 个模块」）
  final String? meta;

  /// 可展开的主体
  final Widget child;

  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _controller;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: _expanded ? 1.0 : 0.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在正确的生命周期点读取「减少动态」偏好（initState 内 dependOn 会抛异常）。
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_reduce) {
        _controller.value = _expanded ? 1.0 : 0.0;
      } else if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chevronTurns = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut.flipped,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPressable(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2Of(context),
                    ),
                  ),
                ),
                if (widget.meta != null) ...[
                  MonoText(
                    widget.meta!,
                    fontSize: 10.5,
                    color: AppColors.text4Of(context),
                  ),
                  const SizedBox(width: 4),
                ],
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(chevronTurns),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.text3Of(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          alignment: Alignment.topCenter,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

/// 可点击组件 —— 按压灵动反馈（按压缩放 <100ms）+ 主题水波纹
///
/// 统一「点击跟手」基线：按下即反馈，不阻塞点击。
/// 用于替代裸 [GestureDetector] / [InkWell]，保证全 App 微交互一致。
class AppPressable extends StatelessWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tap = enabled ? onTap : null;
    return PressableScale(
      enabled: tap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tap,
          borderRadius: borderRadius,
          splashColor: AppColors.primaryOf(context).withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: child,
        ),
      ),
    );
  }
}

/// 骨架屏 —— 列表/首屏加载时的微光占位
///
/// 克制版：单块圆角占位 + 呼吸微光动画，替代整屏 spinner，让「等待」更顺滑。
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.ruleSoftOf(context);
    final soft = AppColors.surfaceEdgeOf(context).withValues(alpha: 0.6);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(base, soft, _controller.value)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// 列表骨架屏 —— 通用的一组卡片行占位
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(width: 160, height: 15),
                SizedBox(height: 10),
                AppSkeleton(height: 12),
                SizedBox(height: 6),
                AppSkeleton(width: 220, height: 12),
              ],
            ),
          ),
      ],
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
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: borderColor,
                radius: AppRadius.md,
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
    final (_, fg) = _colorsOf(context);
    // 去掉小字外层的彩色框块：之前占地方且不美观，现在仅保留按类型着色的文字，
    // 状态/标签仍靠颜色区分（学生端、教师端所有页面统一生效）。
    return Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: kCjkMonoFallback,
        color: fg,
        letterSpacing: 0.02,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  (Color, Color) _colorsOf(BuildContext context) {
    switch (type) {
      case ChipType.moss:
        return (AppColors.surfaceOf(context), AppColors.primaryOf(context));
      case ChipType.vermilion:
        return (AppColors.vermilionSoftOf(context), AppColors.vermilionOf(context));
      case ChipType.amber:
        return (AppColors.amberSoftOf(context), AppColors.amberOf(context));
      case ChipType.indigo:
        return (AppColors.indigoSoftOf(context), AppColors.indigoOf(context));
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
          fontFamilyFallback: kCjkMonoFallback,
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
        return (AppColors.vermilionSoftOf(context), AppColors.vermilionOf(context));
      case StatusBadgeType.warn:
        return (AppColors.amberSoftOf(context), AppColors.amberOf(context));
      case StatusBadgeType.info:
        return (AppColors.indigoSoftOf(context), AppColors.indigoOf(context));
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
                fontFamilyFallback: kCjkMonoFallback,
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
          fontFamilyFallback: kCjkMonoFallback,
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
        fontFamilyFallback: kCjkMonoFallback,
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

/// JetBrainsMono 仅含拉丁字符，中文需由引擎自动回退到系统默认中文字体。
///
/// 此前在此列出一串未注册的系统字体名（Noto/CJK/PingFang…），在多数设备上
/// 无法解析，导致中文渲染成「豆腐块/乱码」。置空后交由 Flutter 引擎按默认字体
/// 自动兜底，中文可正常显示（拉丁/数字仍走 JetBrainsMono）。
const List<String> kCjkMonoFallback = const [];

/// Mono 文字
class MonoText extends StatelessWidget {
const   MonoText(
    this.data, {
    super.key,
    this.fontSize = 11,
    this.color,
    this.letterSpacing = 0.04,
    this.weight = FontWeight.normal,
    this.height,
  });

  final String data;
  final double fontSize;
  final Color? color;
  final double letterSpacing;
  final FontWeight weight;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: kCjkMonoFallback,
        fontSize: fontSize,
        color: color ?? AppColors.text3Of(context),
        letterSpacing: letterSpacing,
        fontWeight: weight,
        height: height,
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
        fontFamilyFallback: kCjkMonoFallback,
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
    this.height,
  });

  final String data;
  final double fontSize;
  final FontWeight weight;
  final Color? color;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? AppColors.textOf(context),
        height: height,
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
// AI 生成内容标注
// ============================================================

/// AI 生成内容小字标注 —— 在 AI 生成的正文下方显示一行浅灰小字。
///
/// 用于合规透明：所有 AI 生成内容（对话回复、诊断归纳、批改评语、教案、组卷、
/// 归因分析等）下方统一一行「本内容由 AI 生成」，克制不打扰阅读。
class AiGeneratedNote extends StatelessWidget {
  const AiGeneratedNote({
    super.key,
    this.text = '本内容由 AI 生成',
    this.color,
  });

  final String text;

  /// 显式指定颜色（用于深色/渐变背景上覆盖默认浅灰，例如 AI 评分卡片）。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          color: color ?? AppColors.text4Of(context),
          height: 1.3,
          letterSpacing: 0.02,
        ),
      ),
    );
  }
}

// ============================================================
// 免责声明
// ============================================================

/// 医学免责声明条（居中一行小灰字，无容器装饰）
class MedicalDisclaimer extends StatelessWidget {
const   MedicalDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        AppConstants.medicalDisclaimer,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          color: AppColors.text3Of(context),
          height: 1.5,
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: kCjkMonoFallback,
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

/// 带 标题 + 操作 的 AppBar；传入 [onBack] 时在标题前显示返回按钮
class AppTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTitleAppBar({
    super.key,
    required this.tag,
    required this.title,
    this.action,
    this.onBack,
  });

  final String tag;
  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: onBack != null ? 16 : 20,
        right: 20,
        bottom: 10,
        top: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBack != null) ...[
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.text2Of(context),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppHeaderTag(label: tag),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOf(context),
                        letterSpacing: -0.02,
                      ),
                    ),
                  ],
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
const AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.backgroundColor,
    this.foregroundColor,
    this.radius = AppRadius.full,
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
            foregroundColor ?? AppColors.vermilionOf(context),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 搜索框
// ============================================================

/// 全局统一搜索框 —— 胶囊造型 + 聚焦高亮 + 内置清除按钮。
///
/// 设计约定：
/// - 显式置空 TextField 的填充与描边（`filled: false` + 三态 `InputBorder.none`），
///   避免全局 `InputDecorationTheme` 的 OutlineInputBorder / fillColor
///   在容器内再画一层「双层胶囊」；
/// - 聚焦时描边转主题色 + 阴影微浮起，反馈克制而清晰；
/// - 清除按钮由组件内部监听 [controller] 自动显隐，页面无需 setState。
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.textInputAction = TextInputAction.search,
    this.height = 46,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 额外的清除回调（组件已负责 controller.clear()，页面只需刷新列表等）。
  final VoidCallback? onClear;
  final TextInputAction textInputAction;
  final double height;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted && _focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final edge = AppColors.surfaceEdgeOf(context);
    final primary = AppColors.primaryOf(context);
    final borderColor = _focused ? primary : edge;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: borderColor, width: _focused ? 1.2 : 1.0),
        boxShadow: AppShadow.leveled(level: _focused ? 4 : 2),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _focused
                  ? primary.withValues(alpha: 0.10)
                  : AppColors.ruleSoftOf(context),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.search_rounded,
              size: 17,
              color: _focused ? primary : AppColors.text4Of(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: widget.textInputAction,
              // 关键：显式关掉主题级填充与三态描边，杜绝「框中框」
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textOf(context),
              ),
              cursorColor: primary,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.text4Of(context),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _clear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: AppColors.ruleSoftOf(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.text3Of(context),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
