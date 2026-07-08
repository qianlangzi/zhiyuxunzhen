import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/student/student_shell.dart';
import '../features/student/home/student_home_page.dart';
import '../features/student/cases/cases_list_page.dart';
import '../features/student/cases/case_detail_page.dart';
import '../features/student/chat/chat_room_page.dart';
import '../features/student/feedback/feedback_page.dart';
import '../features/student/feedback/mistakes_page.dart';
import '../features/student/profile/student_profile_page.dart';
import '../features/teacher/teacher_shell.dart';
import '../features/teacher/overview/teacher_overview_page.dart';
import '../features/teacher/cases/case_config_page.dart';
import '../features/teacher/cases/case_market_page.dart';
import '../features/teacher/assignments/assignments_page.dart';
import '../features/teacher/review/review_page.dart';
import '../features/teacher/profile/teacher_profile_page.dart';

/// 路由配置 + 角色守卫
class AppRouter {
  AppRouter(this.ref);

  final WidgetRef ref;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = ref.read(authControllerProvider).isLoggedIn;
      final int role = ref.read(currentRoleProvider);
      final String path = state.matchedLocation;
      final bool onLogin = path == '/login';

      // 未登录 → 强制登录页
      if (!loggedIn) {
        return onLogin ? null : '/login';
      }

      // 已登录访问登录页 → 跳到对应首页
      if (onLogin) {
        return role == AppConfig.roleTeacher ? '/teacher' : '/';
      }

      // 教师访问学生根路径 → 重定向到教师首页
      // 学生根路径 `/` 由 StudentShell 接管，教师不能停留在此
      if (path == '/' && role == AppConfig.roleTeacher) {
        return '/teacher';
      }

      // 学生越权访问教师路由
      if (path.startsWith('/teacher') && role != AppConfig.roleTeacher) {
        return '/';
      }
      // 教师越权访问学生路由
      if (path.startsWith('/student') && role != AppConfig.roleStudent) {
        return '/teacher';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),
      // 学生 Shell：仅包裹 Tab 首页，详情/问诊室走全屏推送
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            StudentShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const StudentHomePage(),
          ),
          GoRoute(
            path: '/student/cases',
            builder: (BuildContext context, GoRouterState state) =>
                const CasesListPage(),
          ),
          GoRoute(
            path: '/student/feedback',
            builder: (BuildContext context, GoRouterState state) =>
                const FeedbackPage(),
          ),
          GoRoute(
            path: '/student/mistakes',
            builder: (BuildContext context, GoRouterState state) =>
                const MistakesPage(),
          ),
          GoRoute(
            path: '/student/profile',
            builder: (BuildContext context, GoRouterState state) =>
                const StudentProfilePage(),
          ),
        ],
      ),
      // 学生：问诊室（全屏，自带输入栏，不显示底部 Tab）
      GoRoute(
        path: '/student/chat',
        builder: (BuildContext context, GoRouterState state) {
          final String caseId = state.uri.queryParameters['caseId'] ?? '';
          return ChatRoomPage(caseId: caseId);
        },
      ),
      // 学生：病例详情（全屏，底部带进入问诊室按钮）
      GoRoute(
        path: '/student/case/:id',
        builder: (BuildContext context, GoRouterState state) =>
            CaseDetailPage(caseId: state.pathParameters['id']!),
      ),
      // 教师 Shell
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            TeacherShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/teacher',
            builder: (BuildContext context, GoRouterState state) =>
                const TeacherOverviewPage(),
          ),
          GoRoute(
            path: '/teacher/cases',
            builder: (BuildContext context, GoRouterState state) =>
                const CaseConfigPage(),
          ),
          GoRoute(
            path: '/teacher/market',
            builder: (BuildContext context, GoRouterState state) =>
                const CaseMarketPage(),
          ),
          GoRoute(
            path: '/teacher/assignments',
            builder: (BuildContext context, GoRouterState state) =>
                const AssignmentsPage(),
          ),
          GoRoute(
            path: '/teacher/review',
            builder: (BuildContext context, GoRouterState state) =>
                const ReviewPage(),
          ),
          GoRoute(
            path: '/teacher/profile',
            builder: (BuildContext context, GoRouterState state) =>
                const TeacherProfilePage(),
          ),
        ],
      ),
    ],
  );
}

/// 把 AuthController 状态变化转换为路由 refresh 信号
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }

  final WidgetRef ref;
}
