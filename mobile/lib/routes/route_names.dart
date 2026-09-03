/// 导航路由名称
///
/// 抽出来单独成文件，避免 routes/app_router.dart 与 features 之间形成循环导入。
class RouteNames {
  RouteNames._();

  // Auth
  static const login = 'login';
  static const register = 'register';
  static const forgotPassword = 'forgotPassword';
  static const changePassword = 'changePassword';
  static const changePasswordActive = 'changePasswordActive';

  // Student
  static const studentHome = 'studentHome';
  static const studentCaseMarket = 'studentCaseMarket';
  static const chat = 'chat';
  static const osceResult = 'osceResult';
  static const mistakes = 'mistakes';
  static const mistakeBook = 'mistakeBook';
  static const dailyCase = 'dailyCase';
  static const studentProfile = 'studentProfile';
  static const profileEdit = 'profileEdit';
  static const recommendation = 'recommendation';
  static const questionTraining = 'questionTraining';
  static const questionBank = 'questionBank';
  static const caseLibrary = 'caseLibrary';
  static const drugLibrary = 'drugLibrary';
  static const drugDetail = 'drugDetail';
  static const textbookCenter = 'textbookCenter';
  static const searchResult = 'searchResult';
  static const todoAssignments = 'todoAssignments';
  static const todoAssignmentDetail = 'todoAssignmentDetail';
  static const companion = 'companion';
  static const memoryManage = 'memoryManage';
  static const feedback = 'feedback';
  static const learningArchive = 'learningArchive';
  static const paperPractice = 'paperPractice';
  static const studentAppeals = 'studentAppeals';
  static const myCourses = 'myCourses';
  static const myCourseDetail = 'myCourseDetail';

  // Teacher
  static const teacherHome = 'teacherHome';
  static const teacherAssignments = 'teacherAssignments';
  static const assignmentDetail = 'assignmentDetail';
  static const assignmentCreate = 'assignmentCreate';
  static const spConfig = 'spConfig';
  static const myCases = 'myCases';
  static const caseMarket = 'caseMarket';
  static const assignment = 'assignment';
  static const review = 'review';
  static const essayReview = 'essayReview';
  static const dashboard = 'dashboard';
  static const teacherProfile = 'teacherProfile';
  static const profileEditTeacher = 'profileEditTeacher';
  static const teacherTextbook = 'teacherTextbook';
  static const teacherQuestions = 'teacherQuestions';
  static const teacherQuestionEdit = 'teacherQuestionEdit';
  static const bprep = 'bprep';
  static const bprepDetail = 'bprepDetail';
  static const bprepGuide = 'bprepGuide';
  static const alert = 'alert';
  static const classManage = 'classManage';
  static const classDetail = 'classDetail';
  static const classMembers = 'classMembers';
  static const classInvite = 'classInvite';
  static const diagnosisReports = 'diagnosisReports';
  static const diagnosisReportDetail = 'diagnosisReportDetail';
  static const teacherAppeals = 'teacherAppeals';

  // 学生加入班级
  static const studentJoinClass = 'studentJoinClass';

  // 通用
  static const about = 'about';
  static const settings = 'settings';
  static const privacyPolicy = 'privacyPolicy';
  static const userAgreement = 'userAgreement';
}
