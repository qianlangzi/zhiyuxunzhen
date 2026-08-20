import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/student/home/student_home_screen.dart';
import '../features/student/market/student_case_market_screen.dart';
import '../features/student/chat/chat_room_screen.dart';
import '../features/student/tree/thinking_tree_screen.dart';
import '../features/student/result/osce_result_screen.dart';
import '../features/student/mistakes/mistakes_screen.dart';
import '../features/student/recommend/recommendation_screen.dart';
import '../features/student/training/question_training_screen.dart';
import '../features/student/training/question_bank_screen.dart';
import '../features/student/training/question_practice_screen.dart';
import '../features/student/textbook/textbook_center_screen.dart';
import '../features/student/search/search_result_screen.dart';
import '../features/student/report/review_report_screen.dart';
import '../features/student/daily_case/daily_case_screen.dart';
import '../features/student/profile/student_profile_screen.dart';
import '../features/student/assignments/todo_assignments_screen.dart';
import '../features/student/assignments/todo_assignment_detail_screen.dart';
import '../features/student/result/osce_history_screen.dart';
import '../features/common/profile/profile_edit_screen.dart';
import '../features/teacher/home/teacher_home_screen.dart';
import '../features/teacher/case_config/sp_config_screen.dart';
import '../features/teacher/market/case_market_screen.dart';
import '../features/teacher/assignments/assignment_screen.dart';
import '../features/teacher/review/review_screen.dart';
import '../features/teacher/dashboard/dashboard_screen.dart';
import '../features/teacher/profile/teacher_profile_screen.dart';
import '../features/teacher/textbook/teacher_textbook_screen.dart';
import '../features/common/about/about_app_screen.dart';
import '../features/common/settings/settings_screen.dart';
import '../features/common/legal/legal_document_screen.dart';
import 'route_names.dart';
import 'app_shell.dart';

/// Bridge Riverpod 认证状态到 GoRouter 的 refreshListenable（ChangeNotifier）
///
/// P1：ApiClient 检测到 1001/1002/401 触发 logout、或 2015 触发 markMustChangePassword 时，
/// AuthNotifier 状态变化 → ref.listen 回调 → notifyListeners → GoRouter 重新执行 redirect，
/// 确保自动登出 / 强制改密重定向立即生效，而非等下次导航。
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// 全局路由 Provider
///
/// 学生端 / 教师端均使用 [StatefulShellRoute.indexedStack]：
/// 底部 tab 栏由 Shell 常驻持有，切换分支时滑块平滑滑动；
/// 各 tab 首页为分支，其余详情页为顶层路由（push 时覆盖 Shell）。
/// 使用 refreshListenable 监听认证状态变化，使自动登出 / 2015 强制改密
/// 能立即触发路由重定向，而非停留在当前页直到下次导航。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final goingToLogin = loc == '/login';
      final goingToChangePwd = loc == '/change-password';

      // 报告条目: P0 #9 — 初始化加载中时不做重定向，等待加载完成
      // （配合 main() 预热，正常情况下此分支不会命中，仅作安全网）
      if (auth.isLoading) return null;

      // 未登录只能进登录页 / 注册页（注册页无需登录即可访问）
      if (!auth.isAuthenticated) {
        return (goingToLogin || loc == '/register') ? null : '/login';
      }
      // 强制改密：后端标记 mustChangePassword=true 时，只允许进入改密页，
      // 阻止用户绕过改密流程访问其他功能（与后端拦截器形成双层防护）。
      if (auth.mustChangePassword && !goingToChangePwd) {
        return '/change-password';
      }
      // 已完成改密后再次访问改密页 → 按角色回首页
      if (goingToChangePwd && !auth.mustChangePassword) {
        return auth.isStudent ? '/student' : '/teacher';
      }
      // 已登录访问登录页 → 按角色回首页
      if (goingToLogin) {
        return auth.isStudent ? '/student' : '/teacher';
      }
      // 角色越权拦截：学生不可进教师区，反之亦然（/about 为公共页放行）
      if (auth.isStudent && loc.startsWith('/teacher')) return '/student';
      if (auth.isTeacher && loc.startsWith('/student')) return '/teacher';
      return null;
    },
    routes: [
      // 登录
      GoRoute(
        name: RouteNames.login,
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),

      // 独立注册页
      GoRoute(
        name: RouteNames.register,
        path: '/register',
        builder: (context, state) => RegisterScreen(),
      ),

      // 强制改密页（导入学生首次登录 / 后端标记 mustChangePassword=true）
      GoRoute(
        name: RouteNames.changePassword,
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // ========== 学生端 Shell（4 个 tab） ==========
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudentShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.studentHome,
                path: '/student',
                builder: (context, state) => StudentHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.studentCaseMarket,
                path: '/student/market',
                builder: (context, state) => StudentCaseMarketScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.mistakes,
                path: '/student/mistakes',
                builder: (context, state) => MistakesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.studentProfile,
                path: '/student/profile',
                builder: (context, state) => StudentProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- 学生端详情页（顶层路由，push 时覆盖 Shell） ----
      GoRoute(
        name: RouteNames.chat,
        path: '/student/chat',
        builder: (context, state) => ChatRoomScreen(),
      ),
      GoRoute(
        name: RouteNames.thinkingTree,
        path: '/student/tree',
        builder: (context, state) => ThinkingTreeScreen(),
      ),
      GoRoute(
        name: RouteNames.osceResult,
        path: '/student/result',
        builder: (context, state) => OsceResultScreen(),
      ),
      GoRoute(
        name: RouteNames.recommendation,
        path: '/student/recommend',
        builder: (context, state) => RecommendationScreen(),
      ),
      GoRoute(
        name: RouteNames.questionTraining,
        path: '/student/training',
        builder: (context, state) => QuestionTrainingScreen(),
      ),
      GoRoute(
        name: RouteNames.questionBank,
        path: '/student/questions/bank',
        builder: (context, state) => QuestionBankScreen(),
      ),
      GoRoute(
        name: RouteNames.questionPractice,
        path: '/student/questions/practice',
        builder: (context, state) => QuestionPracticeScreen(
          department: state.uri.queryParameters['department'],
          knowledgeTag: state.uri.queryParameters['knowledgeTag'],
          difficulty: int.tryParse(state.uri.queryParameters['difficulty'] ?? ''),
          questionType: state.uri.queryParameters['questionType'],
        ),
      ),
      GoRoute(
        name: RouteNames.textbookCenter,
        path: '/student/textbooks',
        builder: (context, state) => TextbookCenterScreen(),
      ),
      GoRoute(
        name: RouteNames.searchResult,
        path: '/student/search',
        builder: (context, state) => SearchResultScreen(
          initialKeyword: state.uri.queryParameters['keyword'] ?? '',
        ),
      ),
      GoRoute(
        name: RouteNames.todoAssignments,
        path: '/student/assignments/todo',
        builder: (context, state) => TodoAssignmentsScreen(),
      ),
      GoRoute(
        name: RouteNames.todoAssignmentDetail,
        path: '/student/assignments/:id',
        builder: (context, state) => TodoAssignmentDetailScreen(
          instanceId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        name: RouteNames.osceHistory,
        path: '/student/osce-history',
        builder: (context, state) => OsceHistoryScreen(),
      ),
      GoRoute(
        name: RouteNames.reviewReport,
        path: '/student/report',
        builder: (context, state) => ReviewReportScreen(),
      ),
      GoRoute(
        name: RouteNames.dailyCase,
        path: '/student/daily',
        builder: (context, state) => DailyCaseScreen(),
      ),
      GoRoute(
        name: RouteNames.profileEdit,
        path: '/student/profile/edit',
        builder: (context, state) => ProfileEditScreen(),
      ),

      // ========== 教师端 Shell（4 个 tab） ==========
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TeacherShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.teacherHome,
                path: '/teacher',
                builder: (context, state) => TeacherHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.spConfig,
                path: '/teacher/sp-config',
                builder: (context, state) => SpConfigScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.caseMarket,
                path: '/teacher/market',
                builder: (context, state) => CaseMarketScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.teacherProfile,
                path: '/teacher/profile',
                builder: (context, state) => TeacherProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- 教师端详情页（顶层路由） ----
      GoRoute(
        name: RouteNames.assignment,
        path: '/teacher/assignment',
        builder: (context, state) => AssignmentScreen(),
      ),
      GoRoute(
        name: RouteNames.review,
        path: '/teacher/review',
        builder: (context, state) => ReviewScreen(),
      ),
      GoRoute(
        name: RouteNames.dashboard,
        path: '/teacher/dashboard',
        builder: (context, state) => DashboardScreen(),
      ),
      GoRoute(
        name: RouteNames.profileEditTeacher,
        path: '/teacher/profile/edit',
        builder: (context, state) => ProfileEditScreen(),
      ),
      GoRoute(
        name: RouteNames.teacherTextbook,
        path: '/teacher/textbooks',
        builder: (context, state) => TeacherTextbookScreen(),
      ),

      // ========== 通用 ==========
      GoRoute(
        name: RouteNames.about,
        path: '/about',
        builder: (context, state) => AboutAppScreen(),
      ),
      GoRoute(
        name: RouteNames.settings,
        path: '/settings',
        builder: (context, state) => SettingsScreen(),
      ),
      GoRoute(
        name: RouteNames.privacyPolicy,
        path: '/privacy',
        builder: (context, state) => LegalDocumentScreen(type: 'privacy'),
      ),
      GoRoute(
        name: RouteNames.userAgreement,
        path: '/agreement',
        builder: (context, state) => LegalDocumentScreen(type: 'agreement'),
      ),
    ],
  );
});
