import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'app_widgets.dart';

/// 个人主页 · 苔藓绿渐变 Hero 头部卡片
///
/// 融合首页 dark-moss 视觉：渐变背景 + 装饰水印 + 白色描边头像。
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.initial,
    required this.displayName,
    this.subtitle,
    this.badge,
    this.avatarPath,
    required this.onEdit,
  });

  /// 无头像时展示的占位字符
  final String initial;

  final String displayName;

  /// 副标题（学号·专业·年级 / 医院·科室）
  final String? subtitle;

  /// 徽标（如「✓ 已认证」）
  final String? badge;

  final String? avatarPath;

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null && File(avatarPath!).existsSync();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryOf(context), AppColors.moss3Of(context)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOf(context).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰水印圆
          Positioned(
            right: -26,
            top: -30,
            child: _decoCircle(96, 0.07),
          ),
          Positioned(
            right: 18,
            bottom: -34,
            child: _decoCircle(64, 0.06),
          ),
          Positioned(
            left: -20,
            bottom: -26,
            child: _decoCircle(72, 0.05),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onPrimaryOf(context),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  image: hasAvatar
                      ? DecorationImage(
                          image: FileImage(File(avatarPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: hasAvatar
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // 信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'NotoSerifSC',
                              fontFamilyFallback: [
                                'Songti SC',
                                'STSong',
                                'Noto Serif CJK SC',
                                'Source Han Serif SC',
                              ],
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.onPrimaryOf(context),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onPrimarySoftOf(context),
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 12),
                    // 编辑资料
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '编辑资料',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decoCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// 单个统计项
class ProfileStat {
  const ProfileStat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;
}

/// 个人主页 · 统计条（三列 + 纵向分隔线）
class ProfileStatsStrip extends StatelessWidget {
  const ProfileStatsStrip({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 36,
                color: AppColors.ruleSoftOf(context),
              ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    stats[i].value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: stats[i].color,
                      height: 1,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MonoText(
                    stats[i].label,
                    fontSize: 10,
                    color: AppColors.text3Of(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 菜单分组标题
class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 22, bottom: 8),
      child: MonoText(
        title.toUpperCase(),
        fontSize: 10,
        color: AppColors.text4Of(context),
        letterSpacing: 0.12,
      ),
    );
  }
}

/// 个人主页 · 菜单项（毛玻璃图标 + 标题 + 箭头）
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.onTap,
    this.divider = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.ruleSoftOf(context)),
              ),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 16,
          color: AppColors.text4Of(context),
        ),
      ),
    );
  }
}