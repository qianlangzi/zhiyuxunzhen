/// 后端统一响应体 R<T>，对应后端 com.zhiyu.common.R
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  const ApiResponse({required this.code, required this.message, this.data});

  bool get isSuccess => code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse(
      code: (json['code'] as int?) ?? -1,
      message: (json['message'] as String?) ?? '',
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : null,
    );
  }
}

/// 分页结果
class PageResult<T> {
  final List<T> records;
  final int total;
  final int pageNum;
  final int pageSize;

  const PageResult({
    this.records = const [],
    this.total = 0,
    this.pageNum = 1,
    this.pageSize = 10,
  });

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromItem,
  ) {
    return PageResult(
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => fromItem(e))
              .toList() ??
          [],
      total: (json['total'] as int?) ?? 0,
      pageNum: (json['pageNum'] as int?) ?? 1,
      pageSize: (json['pageSize'] as int?) ?? 10,
    );
  }
}