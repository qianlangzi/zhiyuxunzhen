/// API 配置中心
///
/// 所有后端地址、AI 地址、认证模式均可通过 `--dart-define` 在构建时注入，
/// 无需修改代码即可切换环境。
///
/// 使用方式（Android 模拟器默认走 10.0.2.2 映射宿主机 localhost）：
/// ```powershell
/// # 默认 mock 模式（无需后端）
/// flutter run
///
/// # 默认联调模式（USE_MOCK_AUTH=false）
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// # 连接本地后端（Android 模拟器）
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// # 连接本地后端（真机 192.168.1.112，需在同一局域网）
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.112:8080
/// ```
class ApiConfig {
  ApiConfig._();

  /// 后端 API 基础地址
  ///
  /// 默认值 `http://10.0.2.2:8080` 对应 Android 模拟器访问宿主机 localhost。
  /// 真机调试时需改为电脑的局域网 IP（当前: 192.168.1.112）。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// AI 中台基础地址
  ///
  /// 默认与后端 API 共用地址（后端 Spring Boot 转发 AI 请求）。
  /// 分离部署时可通过此变量单独配置。
  static const String aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// 是否使用 Mock 模式（无需后端即可运行）
  ///
  /// - `true`：`AuthService` 使用本地 Mock，不发起 HTTP 请求
  /// - `false`：`AuthService` 调用真实后端 API
  ///
  /// 默认 `false`，接入后端联调。
  /// 前端独立开发时可通过 `--dart-define=USE_MOCK_AUTH=true` 切换回 Mock 模式。
  static const bool useMockAuth = bool.fromEnvironment(
    'USE_MOCK_AUTH',
    defaultValue: false,
  );
}