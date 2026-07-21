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
    required this.message,
    this.code = -1,
    this.kind = ApiErrorKind.unknown,
    this.cause,
  });

  final int code;
  final String message;
  final ApiErrorKind kind;
  final Object? cause;

  @override
  String toString() => message;
}
