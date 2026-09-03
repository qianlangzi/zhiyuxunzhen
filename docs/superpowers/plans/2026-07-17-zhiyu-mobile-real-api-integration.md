# 智愈寻真移动端真实接口联调 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留默认 Mock 演示能力的同时，让 Flutter 真机通过可切换的 Repository、真实 JWT 和统一 Dio 边界接入现有 Spring Boot 核心只读接口，并恢复 AI 容器健康状态。

**Architecture:** `AppEnvironment` 决定 Mock/Remote 模式，页面只依赖 Riverpod Provider 和 Repository。Dio 通过 `TokenStore` 自动附加 JWT，统一解析后端 `{code,message,data}`；Remote Source 解析 DTO，Repository 将 DTO 映射为移动端展示模型。没有后端读取接口的模块继续显式使用 Mock，不在真实失败时自动降级。

**Tech Stack:** Flutter 3.44、Dart 3.12、flutter_riverpod 2.5、Dio 5.5、flutter_secure_storage、SharedPreferences、Flutter Test、Docker Compose、Spring Boot OpenAPI、FastAPI。

---

## 参考与执行约束

- 设计规格：`docs/superpowers/specs/2026-07-17-zhiyu-mobile-real-api-integration-design.md`
- Flutter 工程：`mobile/`
- Spring OpenAPI：`http://127.0.0.1:8080/v3/api-docs`
- 真机设备：`adb-AQWPUT4513019475-huFWws._adb-tls-connect._tcp`
- 所有生产代码必须先有失败测试；每个任务只实现让当前测试变绿的最小代码。
- 不修改 Spring Boot 业务接口，不执行会写入业务数据的接口冒烟测试。
- 真实模式失败不得回退 Mock；Mock 模式默认开启以保护现有 UI 测试。
- 不记录密码、JWT、refresh token、完整病历或身份信息。

## 文件结构

| 文件 | 责任 |
| --- | --- |
| `mobile/lib/core/config/app_environment.dart` | 可注入的 Mock/Remote 环境配置 |
| `mobile/lib/data/auth/token_store.dart` | JWT 安全存储抽象与生产实现 |
| `mobile/lib/data/network/api_exception.dart` | 统一错误类型 |
| `mobile/lib/data/network/api_envelope.dart` | `{code,message,data}` 契约解析 |
| `mobile/lib/data/sources/api_client.dart` | Dio 配置、鉴权和 HTTP 传输 |
| `mobile/lib/data/dto/auth_dto.dart` | 登录和当前用户 DTO |
| `mobile/lib/data/dto/case_dto.dart` | 病例广场、今日病例、教师病例 DTO |
| `mobile/lib/data/dto/student_dto.dart` | 学生作业和错题 DTO |
| `mobile/lib/data/sources/auth_remote_source.dart` | 认证接口 |
| `mobile/lib/data/sources/case_remote_source.dart` | 病例接口 |
| `mobile/lib/data/sources/student_remote_source.dart` | 学生接口 |
| `mobile/lib/data/repositories/auth_repository.dart` | 登录、登出、会话恢复与模式分流 |
| `mobile/lib/data/repositories/content_repository.dart` | 病例数据分流与模型映射 |
| `mobile/lib/data/repositories/student_repository.dart` | 作业、错题数据分流与模型映射 |
| `mobile/lib/data/providers/remote_data_providers.dart` | 页面使用的 FutureProvider |
| `mobile/lib/shared/widgets/zy_async_state.dart` | 统一加载、空、错误和重试状态 |

---

### Task 1: 建立可注入的运行环境

**Files:**
- Create: `mobile/lib/core/config/app_environment.dart`
- Modify: `mobile/lib/core/config/app_config.dart`
- Modify: `mobile/pubspec.yaml`
- Test: `mobile/test/core/config/app_environment_test.dart`

- [ ] **Step 1: 写失败测试，固定默认 Mock 和显式 Remote 配置**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/core/config/app_environment.dart';

void main() {
  test('defaults to mock mode', () {
    const AppEnvironment env = AppEnvironment.defaults();
    expect(env.useMock, isTrue);
    expect(env.apiBaseUrl, 'http://10.0.2.2:8080');
  });

  test('accepts an injected remote environment', () {
    const AppEnvironment env = AppEnvironment(
      useMock: false,
      apiBaseUrl: 'http://127.0.0.1:8080',
    );
    expect(env.useMock, isFalse);
    expect(env.apiBaseUrl, 'http://127.0.0.1:8080');
  });
}
```

- [ ] **Step 2: 运行测试并确认因类型不存在而失败**

Run:

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/core/config/app_environment_test.dart
```

Expected: FAIL，提示找不到 `app_environment.dart` 或 `AppEnvironment`。

- [ ] **Step 3: 实现最小环境对象和 Provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.useMock,
    required this.apiBaseUrl,
  });

  const AppEnvironment.defaults()
      : useMock = true,
        apiBaseUrl = 'http://10.0.2.2:8080';

  factory AppEnvironment.fromCompileTime() {
    return const AppEnvironment(
      useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8080',
      ),
    );
  }

  final bool useMock;
  final String apiBaseUrl;
}

final Provider<AppEnvironment> appEnvironmentProvider =
    Provider<AppEnvironment>((ProviderRef<AppEnvironment> ref) {
  return AppEnvironment.fromCompileTime();
});
```

从 `AppConfig` 移除硬编码 `useMock` 和 `apiBaseUrl`，仅保留 SharedPreferences 键名与角色常量。在 `pubspec.yaml` dependencies 增加：

```yaml
flutter_secure_storage: ^9.2.2
```

- [ ] **Step 4: 获取依赖并验证测试变绿**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat pub get
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/core/config/app_environment_test.dart
```

Expected: PASS。

- [ ] **Step 5: 提交环境配置**

```powershell
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/core/config/app_config.dart mobile/lib/core/config/app_environment.dart mobile/test/core/config/app_environment_test.dart
git commit -m "feat(mobile): add injectable API environment"
```

---

### Task 2: 建立 TokenStore 与统一 API 错误契约

**Files:**
- Create: `mobile/lib/data/auth/token_store.dart`
- Create: `mobile/lib/data/network/api_exception.dart`
- Create: `mobile/lib/data/network/api_envelope.dart`
- Test: `mobile/test/data/network/api_envelope_test.dart`
- Test: `mobile/test/data/auth/token_store_test.dart`

- [ ] **Step 1: 写 ApiEnvelope 失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/data/network/api_envelope.dart';
import 'package:zhiyu/data/network/api_exception.dart';

void main() {
  test('returns decoded data when business code is zero', () {
    final int value = ApiEnvelope.decode<int>(
      <String, Object?>{'code': 0, 'message': 'ok', 'data': 7},
      (Object? data) => data as int,
    );
    expect(value, 7);
  });

  test('throws a business exception when code is non-zero', () {
    expect(
      () => ApiEnvelope.decode<Object?>(
        <String, Object?>{'code': 2001, 'message': '用户名或密码错误'},
        (Object? data) => data,
      ),
      throwsA(
        isA<ApiException>()
            .having((ApiException e) => e.code, 'code', 2001)
            .having((ApiException e) => e.kind, 'kind', ApiErrorKind.business),
      ),
    );
  });

  test('throws a contract exception for malformed envelopes', () {
    expect(
      () => ApiEnvelope.decode<Object?>(
        <String, Object?>{'message': 'missing code'},
        (Object? data) => data,
      ),
      throwsA(isA<ApiException>().having(
        (ApiException e) => e.kind,
        'kind',
        ApiErrorKind.contract,
      )),
    );
  });
}
```

- [ ] **Step 2: 写 TokenStore 失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/data/auth/token_store.dart';

void main() {
  test('memory store writes reads and clears both tokens', () async {
    final MemoryTokenStore store = MemoryTokenStore();
    await store.write(accessToken: 'access', refreshToken: 'refresh');
    expect(await store.readAccessToken(), 'access');
    expect(await store.readRefreshToken(), 'refresh');
    await store.clear();
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });
}
```

- [ ] **Step 3: 运行测试并确认失败原因是契约尚未实现**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/network/api_envelope_test.dart test/data/auth/token_store_test.dart
```

Expected: FAIL，缺少导入文件与类型。

- [ ] **Step 4: 实现 ApiException 与 ApiEnvelope**

```dart
enum ApiErrorKind {
  network,
  timeout,
  unauthenticated,
  forbidden,
  business,
  contract,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    required this.kind,
    this.cause,
  });

  final int code;
  final String message;
  final ApiErrorKind kind;
  final Object? cause;

  @override
  String toString() => message;
}
```

```dart
import 'api_exception.dart';

class ApiEnvelope {
  const ApiEnvelope._();

  static T decode<T>(Object? raw, T Function(Object? data) decoder) {
    if (raw is! Map) {
      throw const ApiException(
        code: -3,
        message: '服务响应格式错误',
        kind: ApiErrorKind.contract,
      );
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final Object? codeValue = json['code'];
    if (codeValue is! num) {
      throw const ApiException(
        code: -3,
        message: '服务响应缺少业务码',
        kind: ApiErrorKind.contract,
      );
    }
    final int code = codeValue.toInt();
    final String message = json['message']?.toString() ?? '请求失败';
    if (code != 0) {
      throw ApiException(
        code: code,
        message: message,
        kind: code == 1001 || code == 1002
            ? ApiErrorKind.unauthenticated
            : code == 1003
                ? ApiErrorKind.forbidden
                : ApiErrorKind.business,
      );
    }
    try {
      return decoder(json['data']);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        code: -3,
        message: '服务响应字段不匹配',
        kind: ApiErrorKind.contract,
        cause: error,
      );
    }
  }
}
```

- [ ] **Step 5: 实现 TokenStore 抽象、生产实现和内存实现**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> write({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);
  final FlutterSecureStorage _storage;
  static const String _accessKey = 'zhiyu_access_token';
  static const String _refreshKey = 'zhiyu_refresh_token';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

class MemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;
  @override
  Future<String?> readRefreshToken() async => refreshToken;
  @override
  Future<void> write({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore(const FlutterSecureStorage());
});
```

- [ ] **Step 6: 运行测试并提交**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/network/api_envelope_test.dart test/data/auth/token_store_test.dart
git add mobile/lib/data/auth/token_store.dart mobile/lib/data/network mobile/test/data/auth/token_store_test.dart mobile/test/data/network/api_envelope_test.dart
git commit -m "feat(mobile): define secure API session contracts"
```

Expected: PASS。

---

### Task 3: 实现统一 Dio 传输层

**Files:**
- Modify: `mobile/lib/data/sources/api_client.dart`
- Create: `mobile/test/data/sources/api_client_test.dart`
- Create: `mobile/test/helpers/recording_http_adapter.dart`

- [ ] **Step 1: 写失败测试，证明自动附加 JWT 且能解析业务错误**

测试使用自定义 `RecordingHttpAdapter` 返回固定 JSON，不访问网络：

```dart
test('adds bearer token before sending a request', () async {
  final MemoryTokenStore store = MemoryTokenStore();
  await store.write(accessToken: 'real-token', refreshToken: 'refresh');
  final RecordingHttpAdapter adapter = RecordingHttpAdapter(
    statusCode: 200,
    data: <String, Object?>{'code': 0, 'message': 'ok', 'data': <String, Object?>{'id': 1}},
  );
  final ApiClient client = ApiClient.create(
    baseUrl: 'http://example.test',
    tokenStore: store,
    adapter: adapter,
  );

  await client.get<Map<String, dynamic>>(
    '/api/v1/auth/me',
    decode: (Object? data) => Map<String, dynamic>.from(data! as Map),
  );

  expect(adapter.lastOptions?.headers['Authorization'], 'Bearer real-token');
});

test('converts dio timeouts into a typed exception', () async {
  final ApiClient client = ApiClient.create(
    baseUrl: 'http://example.test',
    tokenStore: MemoryTokenStore(),
    adapter: RecordingHttpAdapter.timeout(),
  );
  expect(
    () => client.get<Object?>('/slow', decode: (Object? data) => data),
    throwsA(isA<ApiException>().having(
      (ApiException e) => e.kind,
      'kind',
      ApiErrorKind.timeout,
    )),
  );
});
```

- [ ] **Step 2: 运行测试并确认旧 `dioProvider` 不满足新接口**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/sources/api_client_test.dart
```

Expected: FAIL，缺少 `ApiClient.create`、`get` 和测试适配器。

- [ ] **Step 3: 实现 `RecordingHttpAdapter`**

实现 `HttpClientAdapter.fetch`，记录最后一个 `RequestOptions`，成功分支返回 `ResponseBody.fromString(jsonEncode(data), statusCode, headers: {Headers.contentTypeHeader: ['application/json']})`；超时分支抛出 `DioException(requestOptions: options, type: DioExceptionType.connectionTimeout)`。`close` 为空实现。

- [ ] **Step 4: 将 `api_client.dart` 改为可测试的 ApiClient**

```dart
class ApiClient {
  ApiClient._(this._dio);
  final Dio _dio;

  factory ApiClient.create({
    required String baseUrl,
    required TokenStore tokenStore,
    HttpClientAdapter? adapter,
  }) {
    final Dio dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: <String, String>{Headers.contentTypeHeader: 'application/json'},
    ));
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        final String? token = await tokenStore.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
    return ApiClient._(dio);
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) decode,
  }) => _send<T>(
        () => _dio.get<Object?>(path, queryParameters: queryParameters),
        decode,
      );

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? data) decode,
  }) => _send<T>(() => _dio.post<Object?>(path, data: body), decode);

  Future<T> _send<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? data) decode,
  ) async {
    try {
      final Response<Object?> response = await request();
      return ApiEnvelope.decode<T>(response.data, decode);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      final bool timeout = error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
      throw ApiException(
        code: timeout ? -2 : -1,
        message: timeout ? '请求超时，请重试' : '无法连接服务器，请检查网络',
        kind: timeout ? ApiErrorKind.timeout : ApiErrorKind.network,
        cause: error,
      );
    }
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final AppEnvironment env = ref.watch(appEnvironmentProvider);
  return ApiClient.create(
    baseUrl: env.apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
  );
});
```

- [ ] **Step 5: 验证并提交**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/sources/api_client_test.dart
git add mobile/lib/data/sources/api_client.dart mobile/test/data/sources/api_client_test.dart mobile/test/helpers/recording_http_adapter.dart
git commit -m "feat(mobile): add authenticated Dio API client"
```

Expected: PASS。

---

### Task 4: 定义 DTO 与远程数据源

**Files:**
- Create: `mobile/lib/data/dto/auth_dto.dart`
- Create: `mobile/lib/data/dto/case_dto.dart`
- Create: `mobile/lib/data/dto/student_dto.dart`
- Create: `mobile/lib/data/sources/auth_remote_source.dart`
- Create: `mobile/lib/data/sources/case_remote_source.dart`
- Create: `mobile/lib/data/sources/student_remote_source.dart`
- Test: `mobile/test/data/dto/remote_dto_test.dart`
- Test: `mobile/test/data/sources/remote_sources_test.dart`

- [ ] **Step 1: 写 DTO 失败测试**

覆盖以下真实字段：

```dart
test('parses login response fields', () {
  final LoginDto dto = LoginDto.fromJson(<String, Object?>{
    'token': 'jwt',
    'refreshToken': 'refresh',
    'expiresIn': 86400,
    'userId': 11,
    'username': 'student01',
    'realName': '李同学',
    'role': 0,
    'auditStatus': 0,
  });
  expect(dto.userId, 11);
  expect(dto.realName, '李同学');
  expect(dto.role, 0);
});

test('parses page result and market cases', () {
  final PageDto<MarketCaseDto> page = PageDto.fromJson(
    <String, Object?>{
      'list': <Object?>[
        <String, Object?>{
          'id': 7,
          'title': '胸痛训练',
          'department': '心血管',
          'difficulty': 3,
          'ratingAvg': 4.8,
          'referenceCount': 5,
          'creatorName': '张老师',
          'knowledgeTags': '["ACS","心电图"]',
        },
      ],
      'total': 1,
      'page': 1,
      'pageSize': 20,
    },
    MarketCaseDto.fromJson,
  );
  expect(page.items.single.id, 7);
  expect(page.total, 1);
});
```

同时覆盖 `DailyCaseDto`、`TeacherCaseDto`、`StudentAssignmentDto` 和 `MistakeDto` 的 OpenAPI 字段。

- [ ] **Step 2: 运行 DTO 测试并确认缺少类型**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/dto/remote_dto_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 手写最小 DTO 解析**

每个 DTO 使用 `factory Type.fromJson(Map<String, dynamic> json)`；必填数字统一通过 `(json['id'] as num).toInt()`，可空字符串通过 `json['field']?.toString()`。分页类型：

```dart
class PageDto<T> {
  const PageDto({required this.items, required this.total, required this.page, required this.pageSize});
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  factory PageDto.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemDecoder,
  ) {
    final List<Object?> rawItems = (json['list'] as List<Object?>?) ?? const <Object?>[];
    return PageDto<T>(
      items: rawItems
          .map((Object? item) => itemDecoder(Map<String, dynamic>.from(item! as Map)))
          .toList(growable: false),
      total: (json['total'] as num? ?? 0).toInt(),
      page: (json['page'] as num? ?? 1).toInt(),
      pageSize: (json['pageSize'] as num? ?? 20).toInt(),
    );
  }
}
```

- [ ] **Step 4: 写 Remote Source 失败测试**

用 `FakeApiClient` 记录 method、path、query 和 body，并返回 DTO JSON。断言：

```dart
expect(fake.lastPath, '/api/v1/auth/login');
expect(fake.lastBody, <String, Object?>{'username': 'student01', 'password': '123456'});
expect(fake.lastQuery, <String, Object?>{'pageNum': 1, 'pageSize': 20});
```

覆盖七个接口路径：登录、当前用户、病例广场、今日病例、学生作业、错题、教师病例。

- [ ] **Step 5: 让 ApiClient 实现可替换接口并实现三个 Remote Source**

在 `api_client.dart` 定义：

```dart
abstract interface class ApiTransport {
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, required T Function(Object? data) decode});
  Future<T> post<T>(String path, {Object? body, required T Function(Object? data) decode});
}
```

`ApiClient implements ApiTransport`。Remote Source 构造函数接收 `ApiTransport`，例如：

```dart
class AuthRemoteSource {
  AuthRemoteSource(this._api);
  final ApiTransport _api;

  Future<LoginDto> login(String username, String password) {
    return _api.post<LoginDto>(
      '/api/v1/auth/login',
      body: <String, Object?>{'username': username, 'password': password},
      decode: (Object? data) => LoginDto.fromJson(Map<String, dynamic>.from(data! as Map)),
    );
  }

  Future<UserDto> me() => _api.get<UserDto>(
        '/api/v1/auth/me',
        decode: (Object? data) => UserDto.fromJson(Map<String, dynamic>.from(data! as Map)),
      );
}
```

三个 Remote Source 的 Provider 使用同一个 `apiClientProvider`：

```dart
final Provider<AuthRemoteSource> authRemoteSourceProvider =
    Provider<AuthRemoteSource>((ref) {
  return AuthRemoteSource(ref.watch(apiClientProvider));
});

final Provider<CaseRemoteSource> caseRemoteSourceProvider =
    Provider<CaseRemoteSource>((ref) {
  return CaseRemoteSource(ref.watch(apiClientProvider));
});

final Provider<StudentRemoteSource> studentRemoteSourceProvider =
    Provider<StudentRemoteSource>((ref) {
  return StudentRemoteSource(ref.watch(apiClientProvider));
});
```

其余 Remote Source 使用同一模式，并严格使用以下路径：

```text
GET /api/v1/case-market/list?pageNum=1&pageSize=20
GET /api/v1/student/daily-cases/today
GET /api/v1/student/assignments/my?pageNum=1&pageSize=20
GET /api/v1/student/mistakes?pageNum=1&pageSize=20
GET /api/v1/teacher/cases?pageNum=1&pageSize=20
```

- [ ] **Step 6: 验证 DTO 和 Source 测试并提交**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/dto/remote_dto_test.dart test/data/sources/remote_sources_test.dart
git add mobile/lib/data/dto mobile/lib/data/sources mobile/test/data/dto mobile/test/data/sources mobile/test/helpers/fake_api_transport.dart
git commit -m "feat(mobile): add typed backend remote sources"
```

Expected: PASS。

---

### Task 5: 改造真实登录、JWT 持久化与角色恢复

**Files:**
- Modify: `mobile/lib/data/models/user_model.dart`
- Modify: `mobile/lib/data/repositories/auth_repository.dart`
- Modify: `mobile/lib/features/auth/auth_controller.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/test/helpers/test_harness.dart`
- Create: `mobile/test/data/repositories/auth_repository_remote_test.dart`
- Modify: `mobile/test/features/auth/login_page_test.dart`

- [ ] **Step 1: 写 AuthRepository 远程模式失败测试**

```dart
test('remote login stores real tokens and user snapshot', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final MemoryTokenStore tokens = MemoryTokenStore();
  final FakeAuthRemoteSource remote = FakeAuthRemoteSource.success(
    LoginDto(
      token: 'jwt-token',
      refreshToken: 'refresh-token',
      expiresIn: 86400,
      userId: 9,
      username: 'teacher01',
      realName: '张老师',
      role: 1,
      auditStatus: 2,
    ),
  );
  final AuthRepository repo = AuthRepository(
    prefs: prefs,
    tokens: tokens,
    environment: const AppEnvironment(useMock: false, apiBaseUrl: 'http://test'),
    remote: remote,
  );

  final LoginResult result = await repo.login(username: 'teacher01', password: '123456');

  expect(result.token, 'jwt-token');
  expect(await tokens.readAccessToken(), 'jwt-token');
  expect(prefs.getInt(AppConfig.kUserId), 9);
  expect(prefs.getString(AppConfig.kDisplayName), '张老师');
  expect(repo.current()?.role, 1);
});

test('remote failures never fall back to mock credentials', () async {
  final AuthRepository repo = buildRemoteRepository(
    remote: FakeAuthRemoteSource.failure(
      const ApiException(code: -1, message: '无法连接服务器，请检查网络', kind: ApiErrorKind.network),
    ),
  );
  expect(
    () => repo.login(username: 'teacher01', password: '123456'),
    throwsA(isA<AuthException>().having((AuthException e) => e.message, 'message', '无法连接服务器，请检查网络')),
  );
});
```

- [ ] **Step 2: 运行测试并确认旧构造函数和 Mock-only 登录失败**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/repositories/auth_repository_remote_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 扩展会话键与 LoginResult**

在 `AppConfig` 增加 `kUserId`、`kDisplayName`、`kAuditStatus`。`LoginResult` 增加 `userId`、`displayName`、`auditStatus`，保持 token、username、role。

- [ ] **Step 4: 改造 AuthRepository 构造函数和模式分流**

```dart
class AuthRepository {
  AuthRepository({
    required SharedPreferences prefs,
    required TokenStore tokens,
    required AppEnvironment environment,
    required AuthRemoteSource remote,
  })  : _prefs = prefs,
        _tokens = tokens,
        _environment = environment,
        _remote = remote;

  final SharedPreferences _prefs;
  final TokenStore _tokens;
  final AppEnvironment _environment;
  final AuthRemoteSource _remote;

  Future<LoginResult> login({required String username, required String password}) async {
    if (_environment.useMock) return _loginMock(username, password);
    try {
      final LoginDto dto = await _remote.login(username, password);
      if (dto.role != AppConfig.roleStudent && dto.role != AppConfig.roleTeacher) {
        throw AuthException('当前账号请使用 Web 管理端登录');
      }
      await _tokens.write(accessToken: dto.token, refreshToken: dto.refreshToken);
      await _writeSnapshot(dto);
      return dto.toLoginResult();
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }
}
```

`logout` 同时清除 TokenStore 和 SharedPreferences 快照。`current()` 从快照构造 `UserModel`，不再依赖 `MockData.userFor`；Mock 登录同样写完整快照。

- [ ] **Step 5: 更新 Provider 和测试装配**

`authRepositoryProvider` 注入 `sharedPreferencesProvider`、`tokenStoreProvider`、`appEnvironmentProvider` 和 `authRemoteSourceProvider`。`pumpPage` 与 `pumpZhiyuApp` 默认覆盖：

```dart
appEnvironmentProvider.overrideWithValue(const AppEnvironment.defaults()),
tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
```

现有路由测试的 SharedPreferences 快照补充 `zhiyu_user_id` 和 `zhiyu_display_name`，或者由 `current()` 为旧快照提供安全兼容值。

- [ ] **Step 6: 新增登录页面真实错误测试并跑完整认证测试**

在 `login_page_test.dart` 覆盖远程 `AuthRepository`，让它返回 `AuthException('用户名或密码错误')`，点击登录后断言错误文本、无路由跳转、按钮恢复可用。

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/repositories/auth_repository_remote_test.dart test/features/auth/login_page_test.dart test/routes/role_routing_test.dart
```

Expected: PASS。

- [ ] **Step 7: 提交真实认证链路**

```powershell
git add mobile/lib/data/models/user_model.dart mobile/lib/data/repositories/auth_repository.dart mobile/lib/features/auth/auth_controller.dart mobile/lib/main.dart mobile/test/helpers/test_harness.dart mobile/test/data/repositories/auth_repository_remote_test.dart mobile/test/features/auth/login_page_test.dart mobile/test/routes
git commit -m "feat(mobile): connect login to backend JWT session"
```

---

### Task 6: 实现业务 Repository、模型映射与 FutureProvider

**Files:**
- Modify: `mobile/lib/data/models/case_model.dart`
- Modify: `mobile/lib/data/models/learning_model.dart`
- Create: `mobile/lib/data/models/student_assignment_model.dart`
- Modify: `mobile/lib/data/models.dart`
- Modify: `mobile/lib/data/repositories/content_repository.dart`
- Create: `mobile/lib/data/repositories/student_repository.dart`
- Create: `mobile/lib/data/providers/remote_data_providers.dart`
- Test: `mobile/test/data/repositories/remote_repository_test.dart`

- [ ] **Step 1: 写映射和禁止静默降级的失败测试**

```dart
test('maps market DTO into a model with stable backend id and tags', () async {
  final CaseRepository repo = buildRemoteCaseRepository(
    market: <MarketCaseDto>[
      MarketCaseDto(
        id: 7,
        title: '胸痛训练',
        department: '心血管',
        difficulty: 3,
        ratingAvg: 4.8,
        referenceCount: 5,
        creatorName: '张老师',
        knowledgeTags: '["ACS","心电图"]',
        createdAt: null,
      ),
    ],
  );
  final List<MarketCaseModel> result = await repo.market();
  expect(result.single.id, '7');
  expect(result.single.tags, <String>['ACS', '心电图']);
});

test('remote case repository rethrows connection errors', () async {
  final CaseRepository repo = buildFailingRemoteCaseRepository();
  expect(() => repo.market(), throwsA(isA<ApiException>()));
});

test('maps student assignments without reusing teacher progress model', () async {
  final StudentRepository repo = buildStudentRepository();
  final List<StudentAssignmentModel> items = await repo.assignments();
  expect(items.single.instanceId, 12);
  expect(items.single.caseTitle, '胸痛训练');
});
```

- [ ] **Step 2: 运行测试并确认模型与 Repository 方法缺失**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/repositories/remote_repository_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 调整展示模型**

`MarketCaseModel` 增加：

```dart
final String id;
final List<String> tags;
```

`CaseModel` 将后端列表未提供的 `chief`、`duration` 改为有安全默认值的可选展示字段，并新增 `isDemoDetail`；详情页只渲染非空字段。`MistakeItem` 增加可选 `id` 和 `caseId`。创建：

```dart
@immutable
class StudentAssignmentModel {
  const StudentAssignmentModel({
    required this.instanceId,
    required this.assignmentId,
    required this.title,
    required this.caseId,
    required this.caseTitle,
    required this.deadline,
    required this.status,
  });
  final int instanceId;
  final int assignmentId;
  final String title;
  final int caseId;
  final String caseTitle;
  final DateTime? deadline;
  final int status;
}
```

- [ ] **Step 4: 改造 CaseRepository 与新增 StudentRepository**

`CaseRepository` 注入 `AppEnvironment` 和 `CaseRemoteSource`。`all()`、`daily()`、`market()` 返回 `Future`。Mock 分支返回 `MockData`；Remote 分支分别调用教师病例、今日病例和病例广场，异常原样抛出。学生病例列表不调用教师接口，改由 `StudentRepository.assignments()` 提供。

`StudentRepository` 注入 `AppEnvironment` 和 `StudentRemoteSource`：

```dart
Future<List<StudentAssignmentModel>> assignments();
Future<List<MistakeItem>> mistakes();
```

Mock assignments 由现有病例 Mock 映射为确定性的学生作业；Mock mistakes 复用 `MockData.mistakes`。

- [ ] **Step 5: 创建页面 Provider**

```dart
final FutureProvider<CaseModel?> dailyCaseProvider =
    FutureProvider<CaseModel?>((ref) => ref.watch(caseRepositoryProvider).daily());

final FutureProvider<List<MarketCaseModel>> marketCasesProvider =
    FutureProvider<List<MarketCaseModel>>((ref) => ref.watch(caseRepositoryProvider).market());

final FutureProvider<List<CaseModel>> teacherCasesProvider =
    FutureProvider<List<CaseModel>>((ref) => ref.watch(caseRepositoryProvider).all());

final FutureProvider<List<StudentAssignmentModel>> studentAssignmentsProvider =
    FutureProvider<List<StudentAssignmentModel>>((ref) => ref.watch(studentRepositoryProvider).assignments());

final FutureProvider<List<MistakeItem>> studentMistakesProvider =
    FutureProvider<List<MistakeItem>>((ref) => ref.watch(studentRepositoryProvider).mistakes());
```

所有需要鉴权的 FutureProvider 通过同一个守卫执行，确保 `1001/1002` 会清除会话，而不是只显示列表错误：

```dart
Future<T> runAuthenticated<T>(Ref ref, Future<T> Function() request) async {
  try {
    return await request();
  } on ApiException catch (error) {
    if (error.kind == ApiErrorKind.unauthenticated) {
      await ref.read(authControllerProvider.notifier).logout();
    }
    rethrow;
  }
}
```

例如 `studentMistakesProvider` 调用 `runAuthenticated(ref, () => ref.watch(studentRepositoryProvider).mistakes())`。新增 Repository 测试断言远程异常原样抛出；新增 Provider 测试注入 `ApiErrorKind.unauthenticated` 后断言 `AuthState.isLoggedIn == false`。

- [ ] **Step 6: 验证并提交 Repository 层**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/data/repositories/remote_repository_test.dart
git add mobile/lib/data/models mobile/lib/data/models.dart mobile/lib/data/repositories mobile/lib/data/providers mobile/test/data/repositories/remote_repository_test.dart
git commit -m "feat(mobile): add hybrid backend repositories"
```

Expected: PASS。

---

### Task 7: 为真实数据页面增加加载、空、错误和重试状态

**Files:**
- Create: `mobile/lib/shared/widgets/zy_async_state.dart`
- Modify: `mobile/lib/shared/widgets/widgets.dart`
- Modify: `mobile/lib/features/student/home/student_home_page.dart`
- Modify: `mobile/lib/features/student/cases/cases_list_page.dart`
- Modify: `mobile/lib/features/student/feedback/mistakes_page.dart`
- Modify: `mobile/lib/features/teacher/cases/case_market_page.dart`
- Modify: `mobile/lib/features/teacher/cases/case_config_page.dart`
- Modify: `mobile/lib/features/teacher/overview/teacher_overview_page.dart`
- Modify: `mobile/lib/features/teacher/profile/teacher_profile_page.dart`
- Modify: `mobile/lib/features/student/cases/case_detail_page.dart`
- Test: `mobile/test/shared/widgets/zy_async_state_test.dart`
- Modify: `mobile/test/features/student/student_home_cases_test.dart`
- Modify: `mobile/test/features/student/student_feedback_review_test.dart`
- Modify: `mobile/test/features/teacher/teacher_cases_clinical_test.dart`
- Modify: `mobile/test/features/teacher/teacher_assignments_profile_test.dart`

- [ ] **Step 1: 写通用异步状态组件失败测试**

```dart
testWidgets('shows a retry action for an AsyncError', (tester) async {
  var retried = false;
  await tester.pumpWidget(MaterialApp(
    home: ZyAsyncState<List<String>>(
      value: AsyncValue<List<String>>.error(Exception('offline'), StackTrace.empty),
      isEmpty: (items) => items.isEmpty,
      emptyTitle: '暂无数据',
      onRetry: () => retried = true,
      builder: (context, items) => Text(items.join(',')),
    ),
  ));
  expect(find.text('加载失败'), findsOneWidget);
  await tester.tap(find.text('重新加载'));
  expect(retried, isTrue);
});
```

同时覆盖 loading、empty 和 data。

- [ ] **Step 2: 运行测试并确认组件缺失**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test test/shared/widgets/zy_async_state_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现通用异步状态组件**

```dart
class ZyAsyncState<T> extends StatelessWidget {
  const ZyAsyncState({
    super.key,
    required this.value,
    required this.builder,
    required this.isEmpty,
    required this.emptyTitle,
    required this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data) isEmpty;
  final String emptyTitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) => ZyEmptyState(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        detail: error.toString(),
        actionLabel: '重新加载',
        onAction: onRetry,
      ),
      data: (T data) => isEmpty(data)
          ? ZyEmptyState(title: emptyTitle)
          : builder(context, data),
    );
  }
}
```

- [ ] **Step 4: 先写页面 Remote Provider 失败测试**

每个目标页面通过 Provider override 注入：

```dart
dailyCaseProvider.overrideWith((ref) async => remoteCase),
studentAssignmentsProvider.overrideWith((ref) async => assignments),
studentMistakesProvider.overrideWith((ref) async => mistakes),
marketCasesProvider.overrideWith((ref) async => marketCases),
teacherCasesProvider.overrideWith((ref) async => teacherCases),
```

断言数据文本出现。再注入 `Future.error(ApiException(...))`，断言出现“加载失败”和“重新加载”，点击后 Provider 被刷新。测试必须先因页面仍直接调用同步 Repository 而失败。

- [ ] **Step 5: 改造学生页面**

- `StudentHomePage` 监听 `dailyCaseProvider`、`studentAssignmentsProvider`、`studentMistakesProvider`。Mock-only 的能力雷达继续同步读取 `LearningRepository`。
- 今日病例为空时显示“今日暂无病例”；详情字段为空时不渲染伪造主诉、查体或时长。
- `CasesListPage` 展示 `StudentAssignmentModel`，副标题使用病例标题、截止时间和状态；真实作业行不跳转到不存在的详情接口。
- `MistakesPage` 使用 `studentMistakesProvider`，保留现有本地筛选。
- `CaseDetailPage` 对 `isDemoDetail == false` 的有限字段模型只显示接口真实字段，并隐藏“开始问诊”按钮。

- [ ] **Step 6: 改造教师页面**

- `CaseMarketPage` 使用 `marketCasesProvider`，筛选发生在已加载列表上；本期“引用病例”保持演示动作并标注“演示”，不调用 POST。
- `CaseConfigPage` 的已配置病例区域使用 `teacherCasesProvider`，表单保存仍为演示动作。
- `TeacherOverviewPage` 仅将病例数量切换为 `teacherCasesProvider`；作业、批阅和薄弱点继续使用 Mock。
- `TeacherProfilePage` 的病例数量使用 `teacherCasesProvider`；认证资料和教学统计中暂无接口的字段继续使用明确的演示数据。

每个页面重试回调使用：

```dart
ref.invalidate(providerName);
```

- [ ] **Step 7: 跑目标 Widget 测试**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test `
  test/shared/widgets/zy_async_state_test.dart `
  test/features/student/student_home_cases_test.dart `
  test/features/student/student_feedback_review_test.dart `
  test/features/teacher/teacher_cases_clinical_test.dart `
  test/features/teacher/teacher_assignments_profile_test.dart
```

Expected: PASS；Mock 默认测试仍保留原有演示数据断言，新增 Remote 覆盖测试通过。

- [ ] **Step 8: 提交页面异步状态改造**

```powershell
git add mobile/lib/shared/widgets mobile/lib/features/student mobile/lib/features/teacher mobile/test/shared/widgets/zy_async_state_test.dart mobile/test/features/student mobile/test/features/teacher
git commit -m "feat(mobile): render backend data states"
```

---

### Task 8: 配置 Android 本地 HTTP 调试边界

**Files:**
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/android/app/src/debug/AndroidManifest.xml`
- Test: generated merged manifests under `mobile/build/app/intermediates/merged_manifests/`

- [ ] **Step 1: 运行当前 Manifest 检查并记录失败**

```powershell
cd E:\zhiyu\mobile
rg -n "usesCleartextTraffic|android.permission.INTERNET" android/app/src/main/AndroidManifest.xml android/app/src/debug/AndroidManifest.xml
```

Expected: main Manifest 缺少 INTERNET，debug Manifest 缺少 `usesCleartextTraffic=true`。

- [ ] **Step 2: 将 INTERNET 放入 main Manifest**

在 `<application>` 前加入：

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] **Step 3: 仅在 debug Manifest 放行本地明文 HTTP**

debug Manifest 只覆盖 application 的明文调试属性：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:usesCleartextTraffic="true" />
</manifest>
```

release/main 不设置 `usesCleartextTraffic=true`。

- [ ] **Step 4: 构建 Debug APK 并检查合并 Manifest**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat build apk --debug
rg -n "usesCleartextTraffic=\"true\"|android.permission.INTERNET" build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml
```

Expected: Debug 合并 Manifest 同时包含 INTERNET 和 `usesCleartextTraffic="true"`。

- [ ] **Step 5: 提交 Android 网络配置**

```powershell
git add mobile/android/app/src/main/AndroidManifest.xml mobile/android/app/src/debug/AndroidManifest.xml
git commit -m "fix(mobile): allow local API access in debug"
```

---

### Task 9: 恢复 AI 容器并增加健康检查

**Files:**
- Modify: `docker-compose.yml`
- Verify: `ai/requirements.txt`

- [ ] **Step 1: 记录当前失败状态**

```powershell
cd E:\zhiyu
curl.exe --max-time 10 http://127.0.0.1:8000/health
docker logs --tail 80 zhiyu-ai
```

Expected: health 请求失败；日志包含 `ModuleNotFoundError: No module named 'pypdf'`。

- [ ] **Step 2: 在 Compose 中增加 AI healthcheck**

在 `ai` 服务中加入：

```yaml
healthcheck:
  test:
    - CMD
    - python
    - -c
    - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"
  interval: 10s
  timeout: 5s
  retries: 10
  start_period: 20s
```

使用 Python 标准库，不依赖容器内额外安装 curl。

- [ ] **Step 3: 验证 Compose 配置**

```powershell
cd E:\zhiyu
docker compose config --quiet
```

Expected: exit 0。

- [ ] **Step 4: 重新构建且只重启 AI 服务**

```powershell
cd E:\zhiyu
docker compose build ai
docker compose up -d --no-deps ai
```

Expected: 新镜像安装 `pypdf==4.3.1`，不重建 backend、mysql 或 redis。

- [ ] **Step 5: 等待健康并验证接口**

```powershell
docker compose ps ai
curl.exe --fail --max-time 10 http://127.0.0.1:8000/health
docker logs --tail 80 zhiyu-ai
```

Expected: `zhiyu-ai` 显示 healthy，health 返回成功，日志无 `ModuleNotFoundError`。

- [ ] **Step 6: 提交健康检查**

```powershell
git add docker-compose.yml
git commit -m "fix(ai): add container health check"
```

---

### Task 10: 全量回归、真实接口烟测与真机启动

**Files:**
- Modify only if verification exposes a tested regression.
- Verify: all files changed in Tasks 1-9.

- [ ] **Step 1: 执行格式化、静态分析与完整测试**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\dart.bat format lib test
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat analyze
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test
```

Expected: analyze 0 errors；完整测试 0 failures。

- [ ] **Step 2: 构建 Mock 默认 APK 和 Remote Debug APK**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat build apk --debug
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat build apk --debug `
  --dart-define=USE_MOCK=false `
  --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Expected: 两次构建成功；默认构建仍使用 Mock，第二次使用 Remote。

- [ ] **Step 3: 建立手机反向端口并验证 Spring 与 AI**

```powershell
$adb='E:\Android_sdk\platform-tools\adb.exe'
$id='adb-AQWPUT4513019475-huFWws._adb-tls-connect._tcp'
& $adb -s $id reverse tcp:8080 tcp:8080
& $adb -s $id reverse tcp:8000 tcp:8000
& $adb -s $id shell "curl -sS --max-time 10 http://127.0.0.1:8080/api/v1/health"
& $adb -s $id shell "curl -sS --max-time 10 http://127.0.0.1:8000/health"
```

Expected: 两个 health 都成功。

- [ ] **Step 4: 在真机启动 Remote 模式**

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat run `
  -d adb-AQWPUT4513019475-huFWws._adb-tls-connect._tcp `
  --dart-define=USE_MOCK=false `
  --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Expected: 应用显示真实登录页并建立 Flutter 调试会话。

- [ ] **Step 5: 验证学生和教师真实登录**

依次使用：

```text
student01 / 123456
teacher01 / 123456
```

验证后端日志出现 `/api/v1/auth/login`、`/api/v1/auth/me` 和对应角色的只读接口。通过 ADB 读取应用 SharedPreferences 时只能检查 token 是否不存在 `mock-` 前缀，不输出完整 token；安全存储中的 JWT 不导出。

- [ ] **Step 6: 验证真实失败不会回退 Mock**

停止 Remote Flutter 会话后临时移除 ADB reverse：

```powershell
& $adb -s $id reverse --remove tcp:8080
```

重新进入真实数据页，Expected: 显示“无法连接服务器”与“重新加载”，不出现 Mock 病例。完成后恢复：

```powershell
& $adb -s $id reverse tcp:8080 tcp:8080
```

- [ ] **Step 7: 最终仓库检查**

```powershell
cd E:\zhiyu
git diff --check
git status --short
docker compose ps
```

Expected: 无空白错误；仅存在计划内变更；backend 健康运行，AI healthy。

- [ ] **Step 8: 处理验证中暴露的回归**

如果验证失败，先在对应现有测试文件中增加一个能够稳定复现该失败的测试，确认测试为红色，再修改唯一相关生产文件并运行该测试与完整测试。修复提交信息固定为 `fix(mobile): resolve real API integration regression`；如果没有失败，不创建空提交。

---

## 完成检查表

- [ ] 默认 Mock 构建不依赖 Docker。
- [ ] Remote 构建使用真实登录和 JWT。
- [ ] 七类已批准接口在真机读取成功。
- [ ] HTTP 200 中的非零业务码被识别为错误。
- [ ] token 失效会清除会话并回到登录页。
- [ ] 真实失败不回退 Mock。
- [ ] Mock-only 模块保持可用且边界明确。
- [ ] debug 可访问本地 HTTP，release 不全局放行明文。
- [ ] Spring Boot 未无故重建。
- [ ] AI 镜像重建且 Compose 健康检查通过。
- [ ] `flutter analyze`、完整测试和 Debug APK 构建通过。
