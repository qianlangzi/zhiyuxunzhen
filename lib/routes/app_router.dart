import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/student/home/student_home_screen.dart';
import '../features/student/cases/case_list_screen.dart';
import '../features/student/chat/chat_screen.dart';
import '../features/student/daily_case/daily_case_screen.dart';
import '../features/student/mistakes/mistake_list_screen.dart';
import '../features/student/report/report_screen.dart';
import '../features/teacher/home/teacher_home_screen.dart';
import '../features/teacher/case_config/case_config_screen.dart';
import '../features/teacher/assignments/assignment_list_screen.dart';
import '../features/teacher/review/review_screen.dart';
import '../features/teacher/dashboard/dashboard_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(WidgetRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: authState.isAuthenticated
        ? (authState.isStudent ? '/student/home' : '/teacher/home')
        : '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) {
        return authState.isStudent ? '/student/home' : '/teacher/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Student shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudentShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/home',
              builder: (context, state) => const StudentHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/cases',
              builder: (context, state) => const CaseListScreen(),
              routes: [
                GoRoute(
                  path: ':caseId',
                  builder: (context, state) => ChatScreen(
                    caseId: int.tryParse(
                            state.pathParameters['caseId'] ?? '') ??
                        0,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/daily',
              builder: (context, state) => const DailyCaseScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/mistakes',
              builder: (context, state) => const MistakeListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/report',
              builder: (context, state) => const ReportScreen(),
            ),
          ]),
        ],
      ),
      // Teacher shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TeacherShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/home',
              builder: (context, state) => const TeacherHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/cases',
              builder: (context, state) => const CaseConfigScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/assignments',
              builder: (context, state) => const AssignmentListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/review',
              builder: (context, state) => const ReviewScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
}

// ── Student Shell ──
class StudentShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const StudentShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book), label: '病例'),
          NavigationDestination(icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today), label: '每日一例'),
          NavigationDestination(icon: Icon(Icons.error_outline_outlined),
              selectedIcon: Icon(Icons.error_outline), label: '错题本'),
          NavigationDestination(icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment), label: '报告'),
        ],
      ),
    );
  }
}

// ── Teacher Shell ──
class TeacherShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const TeacherShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note), label: '病例配置'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment), label: '作业'),
          NavigationDestination(icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review), label: '批阅'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard), label: '学情'),
        ],
      ),
    );
  }
}
