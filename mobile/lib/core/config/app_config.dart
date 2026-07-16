/// 应用配置：API 基址、是否开启 mock 等
class AppConfig {
  AppConfig._();

  /// 后端 API 基址
  /// 真机调试：使用电脑局域网 IP，例如 http://192.168.x.x:8080
  /// 模拟器：Android 使用 http://10.0.2.2:8080，iOS 使用 http://localhost:8080
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// 是否启用 mock 数据
  /// 当前阶段无后端联调，强制 true；接入真实接口后改为 false
  static const bool useMock = true;

  /// SharedPreferences key
  static const String kToken = 'zhiyu_token';
  static const String kUsername = 'zhiyu_username';
  static const String kRole = 'zhiyu_role';

  /// 角色枚举值（对齐后端 sys_user.role）
  static const int roleStudent = 0;
  static const int roleTeacher = 1;

  /// role >= 2 的角色由 Web 管理端处理，App 端拒绝进入
}
