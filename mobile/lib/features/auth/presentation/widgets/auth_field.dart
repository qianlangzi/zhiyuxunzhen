import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// 认证表单输入框（标签 + 必填星号 + 输入框）
///
/// 登录页与注册页共用，支持密码可见性切换，以及验证码场景下的「获取验证码」后缀按钮。
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.suffix,
    this.accentColor,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final Widget? suffix;
  /// 聚焦态边框/强调色（如登录页传入角色色，使输入框与所选身份呼应）
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primaryOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2Of(context),
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(fontSize: 13, color: AppColors.vermilion),
                ),
              ],
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscure,
          validator: validator,
          style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppColors.text4Of(context), fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.surfaceOf(context),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: AppColors.surfaceEdgeOf(context), width: 1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accent, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            errorBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: AppColors.vermilion, width: 1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: AppColors.vermilion, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            suffixIcon: suffix ??
                (onToggleObscure != null
                    ? IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.text3Of(context),
                        ),
                        onPressed: onToggleObscure,
                      )
                    : null),
          ),
        ),
      ],
    );
  }
}
