import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/widgets/widgets.dart';

class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key, required this.child});

  final Widget child;

  static const List<ZyTabSpec> _tabs = <ZyTabSpec>[
    ZyTabSpec(
        path: '/teacher',
        label: '概览',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded),
    ZyTabSpec(
        path: '/teacher/cases',
        label: '病例',
        icon: Icons.layers_outlined,
        activeIcon: Icons.layers_rounded),
    ZyTabSpec(
        path: '/teacher/assignments',
        label: '作业',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded),
    ZyTabSpec(
        path: '/teacher/review',
        label: '批阅',
        icon: Icons.grading_outlined,
        activeIcon: Icons.grading_rounded),
    ZyTabSpec(
        path: '/teacher/profile',
        label: '我的',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded),
  ];

  int _currentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/teacher/market')) return 1;
    for (int i = 0; i < _tabs.length; i++) {
      if (_tabs[i].path == location) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int index = _currentIndex(context);
    final String location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: ZyBottomBar(
        tabs: _tabs,
        currentIndex: index,
        onTap: (ZyTabSpec tab) {
          if (tab.path == location) return;
          context.go(tab.path);
        },
      ),
    );
  }
}
