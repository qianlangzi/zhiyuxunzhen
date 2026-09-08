import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../data/models/models.dart';
import '../features/student/home/student_home_screen.dart';
import '../features/student/market/student_case_market_screen.dart';
import '../features/student/chat/chat_room_screen.dart';
import '../features/student/result/osce_history_screen.dart';
import '../features/student/result/osce_result_screen.dart';
import '../features/student/mistakes/mistakes_screen.dart';
import '../features/student/mistakes/mistake_detail_screen.dart';
import '../features/student/growth/widgets/mistake_tile.dart';
import '../features/student/recommend/recommendation_screen.dart';
import '../features/student/training/question_training_screen.dart';
import '../features/student/training/paper_practice_screen.dart';
import '../features/student/appeals/student_appeals_screen.dart';
import '../features/student/training/question_bank_screen.dart';
import '../features/student/training/case_library_screen.dart';
import '../features/student/training/drug_library_screen.dart';
import '../features/student/training/drug_detail_screen.dart';
import '../features/student/textbook/textbook_center_screen.dart';
import '../features/student/search/search_result_screen.dart';
import '../features/student/companion/companion_screen.dart';
import '../features/student/companion/memory_manage_screen.dart';
import '../features/student/archive/learning_archive_screen.dart';
import '../features/student/feedback/feedback_screen.dart';
import '../features/student/daily_case/daily_case_screen.dart';
import '../features/student/daily_case/mr_bank_screen.dart';
import '../features/student/daily_case/mr_calendar_screen.dart';
import '../features/student/daily_case/mr_report_screen.dart';
import '../features/student/daily_case/mr_workshop_screen.dart';
import '../features/student/profile/student_profile_screen.dart';
import '../features/student/growth/growth_screen.dart';
import '../features/student/growth/ability_profile_screen.dart';
import '../features/student/growth/training_overview_screen.dart';
import '../features/student/assignments/todo_assignments_screen.dart';
import '../features/student/assignments/todo_assignment_detail_screen.dart';
import '../features/common/profile/profile_edit_screen.dart';
import '../features/teacher/daily_mr/teacher_mr_console_screen.dart';
import '../features/teacher/home/teacher_home_screen.dart';
import '../features/teacher/case_config/sp_config_screen.dart';
import '../features/teacher/case_config/my_cases_screen.dart';
import '../features/teacher/market/case_market_screen.dart';
import '../features/teacher/classes/class_manage_screen.dart';
import '../features/teacher/classes/class_detail_screen.dart';
import '../features/teacher/classes/class_members_screen.dart';
import '../features/teacher/classes/class_invite_screen.dart';
import '../features/student/courses/my_courses_screen.dart';
import '../features/student/courses/my_course_detail_screen.dart';
import '../features/student/courses/course_material_detail_screen.dart';
import '../features/student/courses/course_material_preview_screen.dart';
import '../features/student/join/student_join_class_screen.dart';
import '../features/teacher/assignments/assignment_manage_screen.dart';
import '../features/teacher/assignments/assignment_detail_screen.dart';
import '../features/teacher/assignments/assignment_create_screen.dart';
import '../features/teacher/assignments/assignment_screen.dart';
import '../features/teacher/review/review_screen.dart';
import '../features/teacher/review/essay_review_screen.dart';
import '../features/teacher/review/teacher_appeals_screen.dart';
import '../features/teacher/dashboard/dashboard_screen.dart';
import '../features/teacher/profile/teacher_profile_screen.dart';
import '../features/teacher/textbook/teacher_textbook_screen.dart';
import '../features/teacher/questions/question_list_screen.dart';
import '../features/teacher/questions/question_edit_screen.dart';
import '../features/teacher/bprep/bprep_screen.dart';
import '../features/teacher/bprep/bprep_detail_screen.dart';
import '../features/teacher/bprep/bprep_guide_screen.dart';
import '../features/teacher/alert/alert_screen.dart';
import '../features/teacher/diagnosis/diagnosis_report_list_screen.dart';
import '../features/teacher/diagnosis/diagnosis_report_detail_screen.dart';
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
  late final ProviderSubscription<AuthState> _subscription;

  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// GoRouter 认证刷新监听器 Provider。
///
/// 使用 [ChangeNotifierProvider] 管理生命周期，确保 _AuthRefreshNotifier 在无人监听时
/// 被 Riverpod 自动 dispose，并正确关闭对 authProvider 的订阅，避免 InheritedElement
/// 依赖残留导致 debug 下 _dependents.isEmpty 断言崩溃。
final _authRefreshNotifierProvider =
    ChangeNotifierProvider<_AuthRefreshNotifier>((ref) {
  return _AuthRefreshNotifier(ref);
});

/// 全局路由 Provider
///
/// 学生端 / 教师端均使用 [StatefulShellRoute.indexedStack]：
/// 底部 tab 栏由剪辑的 Shell 常驻持有，切换分支时滑块平滑滑动；
/// 各 tab 首页为分支，其余详情页为顶层路由（push 时覆盖 Shell）。
/// 使用 refreshListenable 监听认证状态变化，使自动登出 / 2015 强制改密
/// 能立即触发路由重定向，而非停留在当前页直到下次导航。
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_authRefreshNotifierProvider);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final goingToLogin = loc == '/login';
      final goingToChangePwd = loc == '/change-password';

      // 报告条目: P0 #9 — 初始化加载中时不做重定向，等待加载完成
      // （配合 main() 预热，正常情况下此分支不会命中，仅作安全网）
      if (auth.isLoading) return null;

      // 未登录仅允许进入登录页 / 注册页 / 忘记密码页（三者为无需登录的认证流程）
      // 忘记密码页必须放行，否则 redirect 会把 push 过来的 /forgot-password 立即弹回登录页，
      // 导致页面无法进入（用户点「忘记密码？」毫无反应）。
      if (!auth.isAuthenticated) {
        return (goingToLogin || loc == '/register' || loc == '/forgot-password')
            ? null
            : '/login';
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

      // 忘记密码（手机号短信验权重置，无需登录）
      GoRoute(
        name: RouteNames.forgotPassword,
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          role: state.extra is UserRole
              ? state.extra! as UserRole
              : UserRole.student,
        ),
      ),

      // 强制改密页（导入学生首次登录 / 后端标记 mustChangePassword=true）
      GoRoute(
        name: RouteNames.changePassword,
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // 主动修改密码（设置页「修改密码」入口，可返回）
      GoRoute(
        name: RouteNames.changePasswordActive,
        path: '/change-password-active',
        builder: (context, state) => const ChangePasswordScreen(active: true),
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
                // 路径沿用旧的 /student/mistakes 以保持深链接兼容；
                // 页面已从「错题列表」升级为「成长」tab（错题列表移至 mistakeBook 二级页）
                name: RouteNames.mistakes,
                path: '/student/mistakes',
                builder: (context, state) => GrowthScreen(),
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
      // 注：questionPractice 由题库/训练页内部直接跳转（不再走路由）；
      // thinkingTree / osceHistory 页面已在 main 重构中移除。
      GoRoute(
        name: RouteNames.chat,
        path: '/student/chat',
        builder: (context, state) => ChatRoomScreen(),
      ),
      GoRoute(
        name: RouteNames.osceResult,
        path: '/student/result',
        builder: (context, state) => OsceResultScreen(),
      ),
      GoRoute(
        name: RouteNames.osceHistory,
        path: '/student/osce-history',
        builder: (context, state) => const OsceHistoryScreen(),
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
        name: RouteNames.paperPractice,
        path: '/student/training/paper',
        builder: (context, state) => const PaperPracticeScreen(),
      ),
      GoRoute(
        name: RouteNames.studentAppeals,
        path: '/student/appeals',
        builder: (context, state) => const StudentAppealsScreen(),
      ),
      GoRoute(
        name: RouteNames.questionBank,
        path: '/student/questions/bank',
        builder: (context, state) => QuestionBankScreen(),
      ),
      GoRoute(
        name: RouteNames.caseLibrary,
        path: '/student/cases',
        builder: (context, state) => const CaseLibraryScreen(),
      ),
      GoRoute(
        name: RouteNames.drugLibrary,
        path: '/student/drugs',
        builder: (context, state) => DrugLibraryScreen(
          initialDepartment: state.uri.queryParameters['department'],
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        name: RouteNames.drugDetail,
        path: '/student/drugs/:id',
        builder: (context, state) => DrugDetailScreen(
          drugId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
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
        name: RouteNames.companion,
        path: '/student/companion',
        builder: (context, state) => const CompanionScreen(),
      ),
      GoRoute(
        name: RouteNames.memoryManage,
        path: '/student/companion/memories',
        builder: (context, state) => const MemoryManageScreen(),
      ),
      GoRoute(
        name: RouteNames.feedback,
        path: '/student/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        name: RouteNames.learningArchive,
        path: '/student/archive',
        builder: (context, state) => const LearningArchiveScreen(),
      ),
      GoRoute(
        name: RouteNames.abilityProfile,
        path: '/student/ability-profile',
        builder: (context, state) => const AbilityProfileScreen(),
      ),
      GoRoute(
        name: RouteNames.trainingOverview,
        path: '/student/training-overview',
        builder: (context, state) => const TrainingOverviewScreen(),
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
        name: RouteNames.mistakeBook,
        path: '/student/mistake-book',
        builder: (context, state) => const MistakeBookScreen(),
      ),
      GoRoute(
        name: RouteNames.mistakeDetail,
        path: '/student/mistake-detail',
        builder: (context, state) => MistakeDetailScreen(
          entry: state.extra! as MistakeEntry,
        ),
      ),
      GoRoute(
        name: RouteNames.dailyCase,
        path: '/student/daily',
        builder: (context, state) => DailyCaseScreen(),
      ),
      GoRoute(
        name: RouteNames.mrBank,
        path: '/student/daily/bank',
        builder: (context, state) => const MrBankScreen(),
      ),
      GoRoute(
        name: RouteNames.mrWorkshop,
        path: '/student/daily/workshop/:scheduleId',
        builder: (context, state) => MrWorkshopScreen(
          scheduleId: int.tryParse(state.pathParameters['scheduleId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        name: RouteNames.mrReport,
        path: '/student/daily/report/:scheduleId',
        builder: (context, state) => MrReportScreen(
          scheduleId: int.tryParse(state.pathParameters['scheduleId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        name: RouteNames.mrCalendar,
        path: '/student/daily/calendar',
        builder: (context, state) => const MrCalendarScreen(),
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
                name: RouteNames.bprep,
                path: '/teacher/bprep',
                builder: (context, state) => BprepScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.classManage,
                path: '/teacher/classes',
                builder: (context, state) => ClassManageScreen(),
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

      // ---- 教师端详情页（顶层路由，push 时覆盖 Shell） ----
      // 「病例广场」不再占 tab，作为可推入的详情页保留（备课/我的页仍可引用）
      GoRoute(
        name: RouteNames.caseMarket,
        path: '/teacher/market',
        builder: (context, state) => CaseMarketScreen(),
      ),
      GoRoute(
        name: RouteNames.classDetail,
        path: '/teacher/classes/:id',
        builder: (context, state) => ClassDetailScreen(
          classId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          className: state.extra is Map
              ? (state.extra! as Map)['className'] as String?
              : state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        name: RouteNames.classMembers,
        path: '/teacher/classes/:id/members',
        builder: (context, state) => ClassMembersScreen(
          classId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          className: state.extra is Map
              ? (state.extra! as Map)['className'] as String?
              : state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        name: RouteNames.classInvite,
        path: '/teacher/classes/:id/invite',
        builder: (context, state) => ClassInviteScreen(
          classId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          className: state.extra is Map
              ? (state.extra! as Map)['className'] as String?
              : state.uri.queryParameters['name'],
          inviteCode: state.extra is Map
              ? (state.extra! as Map)['inviteCode'] as String?
              : state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        name: RouteNames.studentJoinClass,
        path: '/student/join-class',
        builder: (context, state) => const StudentJoinClassScreen(),
      ),
      GoRoute(
        name: RouteNames.myCourses,
        path: '/student/courses',
        builder: (context, state) => const MyCoursesScreen(),
      ),
      GoRoute(
        name: RouteNames.myCourseDetail,
        path: '/student/courses/:id',
        builder: (context, state) => MyCourseDetailScreen(
          classId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          className: state.extra is Map
              ? (state.extra! as Map)['name'] as String? ?? '课程详情'
              : state.uri.queryParameters['name'] ?? '课程详情',
        ),
      ),
      GoRoute(
        name: RouteNames.courseMaterialDetail,
        path: '/student/course-material/:publishId',
        builder: (context, state) => CourseMaterialDetailScreen(
          publishId: int.tryParse(state.pathParameters['publishId'] ?? '') ?? 0,
          classId: state.extra is Map
              ? ((state.extra! as Map)['classId'] as num?)?.toInt() ?? 0
              : 0,
          title: state.extra is Map
              ? (state.extra! as Map)['title'] as String? ?? '学习资料'
              : state.uri.queryParameters['title'] ?? '学习资料',
          material: state.extra is Map
              ? (state.extra! as Map)['material'] as Map<String, dynamic>?
              : null,
        ),
      ),
      GoRoute(
        name: RouteNames.courseMaterialPreview,
        path: '/student/course-material/preview/:type',
        builder: (context, state) => CourseMaterialPreviewScreen(
          type: state.pathParameters['type'] ?? '',
          title: state.extra is Map
              ? (state.extra! as Map)['title'] as String? ?? '资料预览'
              : state.uri.queryParameters['title'] ?? '资料预览',
          url: state.extra is Map
              ? (state.extra! as Map)['url'] as String? ?? ''
              : state.uri.queryParameters['url'] ?? '',
        ),
      ),
      GoRoute(
        name: RouteNames.spConfig,
        path: '/teacher/sp-config',
        builder: (context, state) => SpConfigScreen(
          // 支持 extra {'caseId': int} 或 query ?caseId= 两种方式传参（继续编辑）
          caseId: state.extra is Map
              ? (state.extra! as Map)['caseId'] as int?
              : int.tryParse(state.uri.queryParameters['caseId'] ?? ''),
        ),
      ),
      GoRoute(
        name: RouteNames.myCases,
        path: '/teacher/my-cases',
        builder: (context, state) => const MyCasesScreen(),
      ),
      GoRoute(
        name: RouteNames.assignment,
        path: '/teacher/assignment',
        builder: (context, state) => AssignmentScreen(),
      ),
      GoRoute(
        name: RouteNames.review,
        path: '/teacher/review',
        builder: (context, state) => ReviewScreen(
          instanceId: state.extra is Map
              ? (state.extra! as Map)['instanceId']
              : state.uri.queryParameters['instanceId'] ??
                  state.uri.queryParameters['id'],
          studentName:
              state.extra is Map ? (state.extra! as Map)['studentName'] : null,
          assignmentTitle: state.extra is Map
              ? (state.extra! as Map)['assignmentTitle']
              : null,
          itemProgressId: state.extra is Map
              ? (state.extra! as Map)['itemProgressId'] as int?
              : null,
        ),
      ),
      GoRoute(
        name: RouteNames.essayReview,
        path: '/teacher/essay-review',
        builder: (context, state) => EssayReviewScreen(
          itemProgressId: state.extra is Map
              ? ((state.extra! as Map)['itemProgressId'] as int? ?? 0)
              : int.tryParse(
                      state.uri.queryParameters['itemProgressId'] ?? '') ??
                  0,
          studentName:
              state.extra is Map ? (state.extra! as Map)['studentName'] : null,
          assignmentTitle: state.extra is Map
              ? (state.extra! as Map)['assignmentTitle']
              : null,
        ),
      ),
      GoRoute(
        name: RouteNames.dashboard,
        path: '/teacher/dashboard',
        builder: (context, state) => DashboardScreen(
          classId: state.extra is Map
              ? (state.extra! as Map)['classId'] as int?
              : int.tryParse(state.uri.queryParameters['classId'] ?? ''),
        ),
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
      GoRoute(
        name: RouteNames.teacherMrConsole,
        path: '/teacher/daily-mr',
        builder: (context, state) => const TeacherMrConsoleScreen(),
      ),
      GoRoute(
        name: RouteNames.teacherQuestions,
        path: '/teacher/questions',
        builder: (context, state) => QuestionListScreen(),
      ),
      GoRoute(
        name: RouteNames.teacherQuestionEdit,
        path: '/teacher/questions/edit/:id',
        builder: (context, state) => QuestionEditScreen(
          id: state.pathParameters['id'] ?? 'new',
        ),
      ),
      GoRoute(
        name: RouteNames.teacherAssignments,
        path: '/teacher/assignments',
        builder: (context, state) => AssignmentManageScreen(
          classId: state.extra is Map
              ? (state.extra! as Map)['classId'] as int?
              : int.tryParse(state.uri.queryParameters['classId'] ?? ''),
        ),
      ),
      GoRoute(
        name: RouteNames.assignmentDetail,
        path: '/teacher/assignment-detail/:id',
        builder: (context, state) => AssignmentDetailScreen(
          assignmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          classId: state.extra is Map
              ? (state.extra! as Map)['classId'] as int?
              : null,
          assignmentTitle:
              state.extra is Map && (state.extra! as Map)['title'] != null
                  ? (state.extra! as Map)['title'] as String?
                  : state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        name: RouteNames.assignmentCreate,
        path: '/teacher/assignments/create',
        builder: (context, state) => AssignmentCreateScreen(),
      ),
      GoRoute(
        name: RouteNames.bprepDetail,
        path: '/teacher/bprep/:id',
        builder: (context, state) => BprepDetailScreen(
          lessonId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        name: RouteNames.bprepGuide,
        path: '/teacher/bprep/:id/guide',
        builder: (context, state) => BprepGuideScreen(
          lessonId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        name: RouteNames.alert,
        path: '/teacher/alert',
        builder: (context, state) => AlertScreen(),
      ),
      GoRoute(
        name: RouteNames.diagnosisReports,
        path: '/teacher/diagnosis-reports',
        builder: (context, state) => const DiagnosisReportListScreen(),
      ),
      GoRoute(
        name: RouteNames.diagnosisReportDetail,
        path: '/teacher/diagnosis-reports/:id',
        builder: (context, state) => DiagnosisReportDetailScreen(
          reportId: int.parse(state.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        name: RouteNames.teacherAppeals,
        path: '/teacher/appeals',
        builder: (context, state) => const TeacherAppealsScreen(),
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
