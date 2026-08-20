import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/bottom_tab_bar.dart';

/// 学生端 Shell —— 固定底部导航，切换分支时保留同一个滑块做平滑滑动
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: navigationShell,
      bottomNavigationBar: AppBottomTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) {
          if (i != navigationShell.currentIndex) navigationShell.goBranch(i);
        },
        tabs: studentTabs,
      ),
    );
  }
}

/// 教师端 Shell —— 固定底部导航
class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: navigationShell,
      bottomNavigationBar: AppBottomTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) {
          if (i != navigationShell.currentIndex) navigationShell.goBranch(i);
        },
        tabs: teacherTabs,
      ),
    );
  }
}