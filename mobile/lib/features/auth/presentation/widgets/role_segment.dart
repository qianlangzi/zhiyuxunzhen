import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/models.dart';

/// 角色激活色：学生=苔藓绿，教师=靛蓝（有意义的身份色彩区分）
Color roleActiveColor(UserRole role, BuildContext context) =>
    role == UserRole.student
        ? AppColors.primaryOf(context)
        : AppColors.teacherOf(context);

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
      padding: const EdgeInsets.all(5),
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
          const SizedBox(width: 4),
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
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: const Cubic(0.22, 1, 0.36, 1),
          // 选中项微微上浮（灵动感），未选中保持贴地
          transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? activeColor : null,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active ? Colors.transparent : AppColors.ruleOf(context),
            ),
            boxShadow: active ? AppShadow.leveled(level: 3) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.onPrimaryOf(context).withValues(alpha: 0.16)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: active
                        ? AppColors.onPrimaryOf(context)
                        : AppColors.text3Of(context),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text3Of(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
