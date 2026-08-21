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
    // 防御式解析：后端某个接口返回的数据结构与约定不符（例如 R<List>
    // 被约定 R<Map> 解析）时，解析可能抛类型转换异常。这里吞掉单个解析
    // 异常并把 data 置空，避免异常逃逸到界面层导致页面永久转圈 / 无法返回。
    T? data;
    if (json['data'] != null && fromData != null) {
      try {
        data = fromData(json['data']);
      } catch (_) {
        data = null;
      }
    }
    return ApiResponse(
      code: (json['code'] as int?) ?? -1,
      message: (json['message'] as String?) ?? '',
      data: data,
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