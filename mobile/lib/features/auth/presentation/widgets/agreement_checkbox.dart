import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/route_names.dart';

/// 用户协议 / 隐私政策同意勾选行（登录 / 注册页共用）
///
/// 一个复选框 + 一行小字，两个书名号链接可点击跳转对应全文页面
/// （[RouteNames.userAgreement] / [RouteNames.privacyPolicy]）。
/// 勾选状态由外部持有，本组件为无状态纯展示。
class AgreementCheckbox extends StatelessWidget {
  const AgreementCheckbox({
    super.key,
    required this.agreed,
    required this.onChanged,
    this.accentColor,
  });

  /// 当前是否已勾选
  final bool agreed;

  /// 勾选状态变化回调
  final ValueChanged<bool> onChanged;

  /// 勾选框高亮色（默认主题色）
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primaryOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: agreed,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.text3Of(context),
              ),
              children: [
                const TextSpan(text: '已阅读并同意'),
                _linkSpan(context, color, '《用户协议》', RouteNames.userAgreement),
                const TextSpan(text: '和'),
                _linkSpan(context, color, '《隐私政策》', RouteNames.privacyPolicy),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _linkSpan(BuildContext context, Color color, String text, String routeName) {
    return TextSpan(
      text: text,
      style: TextStyle(color: color),
      recognizer: TapGestureRecognizer()
        ..onTap = () => context.pushNamed(routeName),
    );
  }
}
