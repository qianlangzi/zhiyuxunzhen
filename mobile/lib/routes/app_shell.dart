import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../features/common/guide/guide_controller.dart';
import '../features/common/guide/guide_host.dart';
import '../shared/widgets/bottom_tab_bar.dart';

/// 学生端 Shell —— 固定底部导航，切换分支时保留同一个滑块做平滑滑动
///
/// 外层套 [GuideHost]：首次进入 / 切换 Tab 时自动播放对应页的新手指引。
class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    return GuideHost(
      role: GuideRole.student,
      currentIndex: shell.currentIndex,
      child: Scaffold(
        backgroundColor: AppColors.bgOf(context),
        extendBody: false,
        body: shell,
        bottomNavigationBar: AppBottomTabBar(
          currentIndex: shell.currentIndex,
          onTap: (i) {
            if (i != shell.currentIndex) shell.goBranch(i);
          },
          tabs: studentTabs,
        ),
      ),
    );
  }
}

/// 教师端 Shell —— 固定底部导航
class TeacherShell extends ConsumerStatefulWidget {
  const TeacherShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    return GuideHost(
      role: GuideRole.teacher,
      currentIndex: shell.currentIndex,
      child: Scaffold(
        backgroundColor: AppColors.bgOf(context),
        body: shell,
        bottomNavigationBar: AppBottomTabBar(
          currentIndex: shell.currentIndex,
          onTap: (i) {
            if (i != shell.currentIndex) shell.goBranch(i);
          },
          tabs: teacherTabs,
        ),
      ),
    );
  }
}
