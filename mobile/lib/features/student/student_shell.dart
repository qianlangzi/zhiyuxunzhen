import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/widgets.dart';

/// 学生端 Shell：底部 5 个 Tab
/// 首页 / 病例 / 反馈 / 错题 / 我的
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.child});

  final Widget child;

  static const List<ZyTabSpec> _tabs = <ZyTabSpec>[
    ZyTabSpec(path: '/', label: '首页', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    ZyTabSpec(path: '/student/cases', label: '病例', icon: Icons.layers_outlined, activeIcon: Icons.layers_rounded),
    ZyTabSpec(path: '/student/feedback', label: '反馈', icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded),
    ZyTabSpec(path: '/student/mistakes', label: '错题', icon: Icons.error_outline_rounded, activeIcon: Icons.error_rounded),
    ZyTabSpec(path: '/student/profile', label: '我的', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  int _currentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    // 问诊室和病例详情归到"病例"tab（注意：/student/cases 是 Tab 首页，单独匹配）
    if (location.startsWith('/student/case/') ||
        location.startsWith('/student/chat')) {
      return 1;
    }
    for (int i = 0; i < _tabs.length; i++) {
      if (_tabs[i].path == location) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: ZyBottomBar(
        tabs: _tabs,
        currentIndex: index,
        onTap: (ZyTabSpec tab) {
          if (tab.path == GoRouterState.of(context).matchedLocation) return;
          context.go(tab.path);
        },
      ),
    );
  }
}
