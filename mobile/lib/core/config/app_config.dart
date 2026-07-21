import 'dart:io';

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

  /// 是否启用 mock 数据；真实联调是默认模式，离线演示时显式传 true。
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  /// Flutter 测试进程的离线数据适配；不会影响调试包和发布包。
  static final bool isTest = Platform.environment.containsKey('FLUTTER_TEST');
  static bool get mockEnabled => useMock || isTest;

  /// FastAPI AI 服务基址。Android 模拟器通过宿主机 8000 端口访问。
  static const String aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// SharedPreferences key
  static const String kToken = 'zhiyu_token';
  static const String kRefreshToken = 'zhiyu_refresh_token';
  static const String kUsername = 'zhiyu_username';
  static const String kRole = 'zhiyu_role';
  static const String kUserId = 'zhiyu_user_id';
  static const String kDisplayName = 'zhiyu_display_name';

  /// 角色枚举值（对齐后端 sys_user.role）
  static const int roleStudent = 0;
  static const int roleTeacher = 1;

  /// role >= 2 的角色由 Web 管理端处理，App 端拒绝进入
}
