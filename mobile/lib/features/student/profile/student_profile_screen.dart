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

/// 学生"我的"页面
class StudentProfileScreen extends ConsumerWidget {
const   StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final displayName = user?.nickname ?? user?.realName ?? '同学';
    final initial =
        displayName.isNotEmpty ? displayName[0] : '?';

    final subtitleParts = <String>[];
    if (user != null) {
      if ((user.studentNumber ?? '').isNotEmpty) {
        subtitleParts.add(user.studentNumber!);
      }
      if ((user.major ?? '').isNotEmpty) {
        subtitleParts.add(user.major!);
      }
      if ((user.grade ?? '').isNotEmpty) {
        subtitleParts.add(user.grade!);
      }
    }
    final subtitle = subtitleParts.join(' · ');

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTitleAppBar(tag: '内科教研 · 学生端', title: '我的'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    _ProfileHeader(
                      initial: initial,
                      displayName: displayName,
                      subtitle: subtitle,
                      avatarPath: user?.avatarPath,
                      onEdit: () => context.pushNamed(RouteNames.profileEdit),
                    ),
                    _buildStatsRow(context),
                    _buildMenuSection(context),
                    const MedicalDisclaimer(),
                  ],
                ),
              ),
            ),
            StudentTabBar(
              currentIndex: 3,
              onTap: (i) {
                if (i == 0) context.goNamed(RouteNames.studentHome);
                if (i == 1) context.goNamed(RouteNames.chat);
                if (i == 2) context.goNamed(RouteNames.mistakes);
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
          _statCard(context, '142', '累计训练', AppColors.moss),
      SizedBox(width: 8),
          _statCard(context, '23', '连续天数', AppColors.amber),
      SizedBox(width: 8),
          _statCard(context, '82.4', 'OSCE 均分', AppColors.indigo),
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
      ('错题本', Icons.description_outlined, AppColors.vermilion),
      ('AI 复盘报告', Icons.assessment_outlined, AppColors.indigo),
      ('学习热力图', Icons.calendar_view_week_outlined, AppColors.moss),
      ('每日一例历史', Icons.history_edu_outlined, AppColors.amber),
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
                    case '错题本':
                      context.pushNamed(RouteNames.mistakes);
                    case 'AI 复盘报告':
                      context.pushNamed(RouteNames.reviewReport);
                    case '每日一例历史':
                      context.pushNamed(RouteNames.dailyCase);
                    case '学习热力图':
                      context.goNamed(RouteNames.studentHome);
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

/// 个人信息头部（含编辑按钮）
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initial,
    required this.displayName,
    required this.subtitle,
    this.avatarPath,
    required this.onEdit,
  });

  final String initial;
  final String displayName;
  final String subtitle;
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
                const SizedBox(height: 4),
                if (subtitle.isNotEmpty)
                  MonoText(subtitle, fontSize: 12),
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
