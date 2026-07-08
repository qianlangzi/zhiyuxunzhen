import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 玻璃舱风格 AppBar
/// - 透明背景、与 Scaffold 同色
/// - 左侧返回按钮遵循触控目标 ≥44px
class ZyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ZyAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.transparent = false,
    this.elevation = 0,
  });

  final Widget? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool transparent;
  final double elevation;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    Widget? titleWidget = title;
    if (title is String) {
      titleWidget = Text(
        title as String,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );
    }
    if (titleWidget != null && subtitle != null) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          titleWidget,
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      );
    }

    return Material(
      color: transparent ? Colors.transparent : AppColors.bg,
      elevation: elevation,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppDimens.appBarHeight,
          child: NavigationToolbar(
            leading: leading ??
                (canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20),
                        onPressed: () => _pop(context),
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                      )
                    : null),
            middle: titleWidget,
            trailing: actions == null
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions!),
            centerMiddle: centerTitle,
            middleSpacing: 8,
          ),
        ),
      ),
    );
  }

  static bool canPop(BuildContext context) {
    return GoRouter.of(context).canPop();
  }

  static void _pop(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

/// 大标题头部：用于 Tab 首屏顶部，对齐 Web 端 page-head
class ZyPageHead extends StatelessWidget {
  const ZyPageHead({
    super.key,
    required this.kicker,
    required this.title,
    this.action,
    this.padding,
  });

  final String kicker;
  final String title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
              AppDimens.pagePadding, AppDimens.grid5, AppDimens.pagePadding, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.aqua,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x2414B8A6),
                            blurRadius: 8,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      kicker,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandStrong,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
