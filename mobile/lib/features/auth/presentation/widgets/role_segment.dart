import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/models.dart';

/// 角色激活色：学生=苔藓绿，教师=朱砂红（有意义的身份色彩区分）
Color roleActiveColor(UserRole role, BuildContext context) =>
    role == UserRole.student ? AppColors.primaryOf(context) : AppColors.vermilionOf(context);

/// 角色分段选择（学生 / 教师）
///
/// 登录页与注册页共用：用户在此**自行选择自己的身份**，后续登录态与门户跳转均按所选角色区分。
/// 可选 [studentIcon] / [teacherIcon] 时，激活态会显示图标，强化可读性。
class RoleSegment extends StatelessWidget {
  const RoleSegment({
    super.key,
    required this.role,
    required this.onChanged,
    this.studentIcon,
    this.teacherIcon,
  });

  final UserRole role;
  final ValueChanged<UserRole> onChanged;
  final IconData? studentIcon;
  final IconData? teacherIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceEdgeOf(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          _Item(
            role: UserRole.student,
            active: role == UserRole.student,
            icon: studentIcon,
            label: '学生',
            onTap: () => onChanged(UserRole.student),
          ),
          _Item(
            role: UserRole.teacher,
            active: role == UserRole.teacher,
            icon: teacherIcon,
            label: '教师',
            onTap: () => onChanged(UserRole.teacher),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.role,
    required this.active,
    this.icon,
    required this.label,
    required this.onTap,
  });

  final UserRole role;
  final bool active;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = roleActiveColor(role, context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: const Cubic(0.16, 1, 0.3, 1),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? activeColor : null,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active ? Colors.transparent : AppColors.ruleOf(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text3Of(context),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text3Of(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
