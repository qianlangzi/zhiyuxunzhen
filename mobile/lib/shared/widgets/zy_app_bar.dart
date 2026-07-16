import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';

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

  final Object? title;
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
    Widget? titleWidget = title is Widget ? title as Widget : null;
    if (title is String) {
      titleWidget = Text(title as String, style: AppTextStyles.title);
    }
    if (titleWidget != null && subtitle != null) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          titleWidget,
          const SizedBox(height: 2),
          Text(subtitle!, style: AppTextStyles.caption),
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
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
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

  static bool canPop(BuildContext context) => Navigator.of(context).canPop();

  static void _pop(BuildContext context) {
    Navigator.of(context).maybePop();
  }
}

class ZyPageHead extends StatelessWidget {
  const ZyPageHead({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
    this.avatar,
  });

  final String kicker;
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.grid5,
            AppDimens.pagePadding,
            AppDimens.grid3,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (avatar != null) ...<Widget>[
                avatar!,
                const SizedBox(width: AppDimens.grid3),
              ],
              Expanded(
                child: Text(
                  kicker,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AppDimens.grid2),
          Text(title, style: AppTextStyles.h1),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: AppDimens.grid2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(subtitle!, style: AppTextStyles.caption),
            ),
          ],
        ],
      ),
    );
  }
}
