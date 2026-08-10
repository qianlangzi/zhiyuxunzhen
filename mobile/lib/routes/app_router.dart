import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/student/home/student_home_screen.dart';
import '../features/student/market/student_case_market_screen.dart';
import '../features/student/chat/chat_room_screen.dart';
import '../features/student/tree/thinking_tree_screen.dart';
import '../features/student/result/osce_result_screen.dart';
import '../features/student/mistakes/mistakes_screen.dart';
import '../features/student/recommend/recommendation_screen.dart';
import '../features/student/training/question_training_screen.dart';
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

/// 全局路由配置
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context, listen: false);
    final auth = container.read(authProvider);
    final loc = state.matchedLocation;
    final goingToLogin = loc == '/login';

    // 报告条目: P0 #9 — 初始化加载中时不做重定向，等待加载完成
    // （配合 main() 预热，正常情况下此分支不会命中，仅作安全网）
    if (auth.isLoading) return null;

    // 未登录只能进登录页
    if (!auth.isAuthenticated) {
      return goingToLogin ? null : '/login';
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

    // ========== 学生端 ==========
    GoRoute(
      name: RouteNames.studentHome,
      path: '/student',
      builder: (context, state) => StudentHomeScreen(),
    ),
    GoRoute(
      name: RouteNames.studentCaseMarket,
      path: '/student/market',
      builder: (context, state) => StudentCaseMarketScreen(),
    ),
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
      name: RouteNames.mistakes,
      path: '/student/mistakes',
      builder: (context, state) => MistakesScreen(),
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
      name: RouteNames.studentProfile,
      path: '/student/profile',
      builder: (context, state) => StudentProfileScreen(),
    ),
    GoRoute(
      name: RouteNames.profileEdit,
      path: '/student/profile/edit',
      builder: (context, state) => ProfileEditScreen(),
    ),

    // ========== 教师端 ==========
    GoRoute(
      name: RouteNames.teacherHome,
      path: '/teacher',
      builder: (context, state) => TeacherHomeScreen(),
    ),
    GoRoute(
      name: RouteNames.spConfig,
      path: '/teacher/sp-config',
      builder: (context, state) => SpConfigScreen(),
    ),
    GoRoute(
      name: RouteNames.caseMarket,
      path: '/teacher/market',
      builder: (context, state) => CaseMarketScreen(),
    ),
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
      name: RouteNames.teacherProfile,
      path: '/teacher/profile',
      builder: (context, state) => TeacherProfileScreen(),
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
