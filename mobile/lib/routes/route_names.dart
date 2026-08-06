/// 导航路由名称
///
/// 抽出来单独成文件，避免 routes/app_router.dart 与 features 之间形成循环导入。
class RouteNames {
  RouteNames._();

  // Auth
  static const login = 'login';
  static const register = 'register';

  // Student
  static const studentHome = 'studentHome';
  static const studentCaseMarket = 'studentCaseMarket';
  static const chat = 'chat';
  static const thinkingTree = 'thinkingTree';
  static const osceResult = 'osceResult';
  static const mistakes = 'mistakes';
  static const reviewReport = 'reviewReport';
  static const dailyCase = 'dailyCase';
  static const studentProfile = 'studentProfile';
  static const profileEdit = 'profileEdit';
  static const recommendation = 'recommendation';
  static const questionTraining = 'questionTraining';
  static const textbookCenter = 'textbookCenter';
  static const searchResult = 'searchResult';

  // Teacher
  static const teacherHome = 'teacherHome';
  static const spConfig = 'spConfig';
  static const caseMarket = 'caseMarket';
  static const assignment = 'assignment';
  static const review = 'review';
  static const dashboard = 'dashboard';
  static const teacherProfile = 'teacherProfile';
  static const profileEditTeacher = 'profileEditTeacher';

  // 通用
  static const about = 'about';
  static const settings = 'settings';
  static const privacyPolicy = 'privacyPolicy';
  static const userAgreement = 'userAgreement';
}
