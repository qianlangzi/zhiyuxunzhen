import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 教师"我的"页面
class TeacherProfileScreen extends ConsumerWidget {
const   TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final displayName = user?.nickname ?? user?.realName ?? '老师';
    final initial =
        displayName.isNotEmpty ? displayName[0] : '王';

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTitleAppBar(tag: '内科教研 · 教师端', title: '我的'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    _ProfileHeader(
                      initial: initial,
                      displayName: displayName,
                      avatarPath: user?.avatarPath,
                      onEdit: () =>
                          context.pushNamed(RouteNames.profileEditTeacher),
                    ),
                    _buildStatsRow(context),
                    _buildMenuSection(context),
                    const MedicalDisclaimer(),
                  ],
                ),
              ),
            ),
            TeacherTabBar(
              currentIndex: 3,
              onTap: (i) {
                if (i == 0) context.goNamed(RouteNames.teacherHome);
                if (i == 1) context.goNamed(RouteNames.spConfig);
                if (i == 2) context.goNamed(RouteNames.caseMarket);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard(context, '28', '我的病例', AppColors.moss),
      SizedBox(width: 8),
          _statCard(context, '63', '累计引用', AppColors.amber),
      SizedBox(width: 8),
          _statCard(context, '4.8', '平均评分', AppColors.indigo),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String num, String label, Color color) {
    return Expanded(
      child: Container(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              num,
              style: TextStyle(
                fontFamily: 'NotoSerifSC',
                fontFamilyFallback: [
                  'Songti SC',
                  'STSong',
                  'Noto Serif CJK SC',
                  'Source Han Serif SC',
                ],
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            MonoText(label, fontSize: 10, color: AppColors.text3Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final menus = [
      ('我的病例', Icons.folder_outlined, AppColors.moss),
      ('学情看板', Icons.dashboard_outlined, AppColors.indigo),
      ('批阅历史', Icons.history_outlined, AppColors.vermilion),
      ('病例广场', Icons.storefront_outlined, AppColors.amber),
      ('资质认证', Icons.verified_user_outlined, AppColors.moss),
      ('设置', Icons.settings_outlined, AppColors.text3Of(context)),
      ('关于智愈寻真', Icons.info_outline, AppColors.text3Of(context)),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: AppPaper(
        padding: EdgeInsets.zero,
        child: Column(
          children: menus.map((m) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.ruleSoft)),
              ),
              child: ListTile(
                leading: Icon(m.$2, color: m.$3, size: 20),
                title: Text(
                  m.$1,
         style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
                ),
        trailing: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.text4Of(context),
                ),
                onTap: () {
                  switch (m.$1) {
                    case '学情看板':
                      context.pushNamed(RouteNames.dashboard);
                    case '批阅历史':
                      context.pushNamed(RouteNames.review);
                    case '病例广场':
                      context.pushNamed(RouteNames.caseMarket);
                    case '我的病例':
                      context.pushNamed(RouteNames.spConfig);
                    case '设置':
                      context.pushNamed(RouteNames.settings);
                    case '关于智愈寻真':
                      context.pushNamed(RouteNames.about);
                    default:
                      AppFeedback.info(context, '${m.$1} 即将开放');
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 教师个人信息头部（含编辑按钮）
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initial,
    required this.displayName,
    this.avatarPath,
    required this.onEdit,
  });

  final String initial;
  final String displayName;
  final String? avatarPath;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.mossTint,
        border: Border.all(color: AppColors.moss3),
        shape: BoxShape.circle,
        image: avatarPath != null
            ? DecorationImage(
                image: FileImage(File(avatarPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: avatarPath == null
          ? Text(
              initial,
              style: const TextStyle(
                fontFamily: 'NotoSerifSC',
                fontFamilyFallback: [
                  'Songti SC',
                  'STSong',
                  'Noto Serif CJK SC',
                  'Source Han Serif SC',
                ],
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.moss,
              ),
            )
          : null,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
           style: TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontFamilyFallback: [
                          'Songti SC',
                          'STSong',
                          'Noto Serif CJK SC',
                          'Source Han Serif SC',
                        ],
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mossTint,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const MonoText(
                        '✓ 已认证',
                        fontSize: 10,
                        color: AppColors.moss,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const MonoText('附属第一医院 · 心血管内科', fontSize: 12),
              ],
            ),
          ),
          _ProfileEditButton(onPressed: onEdit),
        ],
      ),
    );
  }
}

/// 编辑按钮（带 hover 视觉反馈）
class _ProfileEditButton extends StatefulWidget {
  const _ProfileEditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ProfileEditButton> createState() => _ProfileEditButtonState();
}

class _ProfileEditButtonState extends State<_ProfileEditButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
    duration: Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered ? AppColors.mossTint : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: IconButton(
          onPressed: widget.onPressed,
          hoverColor: Colors.transparent,
          highlightColor: AppColors.mossTint,
          splashColor: AppColors.mossSoft,
          tooltip: '编辑资料',
          icon: Icon(
            Icons.edit_outlined,
            size: 18,
            color: _hovered ? AppColors.moss : AppColors.text3Of(context),
          ),
        ),
      ),
    );
  }
}
