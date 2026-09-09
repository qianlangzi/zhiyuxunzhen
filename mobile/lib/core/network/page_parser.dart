import 'dart:developer' as developer;

/// 后端统一分页体解析工具
///
/// 背景：后端 `com.zhiyu.common.result.PageResult` 序列化后的字段是
/// `list`（不是 `records`），历史上一度有 14 处页面误读 `data['records']`，
/// 导致题库（5.6w 条）、病例广场、组卷选题、我的病例等页面恒显示为空。
///
/// 这里收敛成唯一入口：
/// - [PageParser.listOf] 兼容 `list` / `records` / `content` / `items`，
///   任何一处后端改字段名都不会再让整页变空；
/// - [PageParser.totalOf] 同理取总数；
/// - 命中非首选字段时打日志，方便后续把后端/前端口径彻底统一。
class PageParser {
  PageParser._();

  /// 从分页 data 中取列表，兼容多种字段名。data 为空或类型不符时返回空列表。
  static List<dynamic> listOf(Map<String, dynamic>? data) {
    if (data == null) return const [];
    for (final key in const ['list', 'records', 'content', 'items']) {
      final raw = data[key];
      if (raw is List) {
        if (key != 'list') {
          developer.log(
            'PageParser: 分页字段走兼容分支 "$key"，请确认后端 PageResult 口径',
            name: 'page_parser',
          );
        }
        return raw;
      }
    }
    return const [];
  }

  /// 取 Map 结构的列表项（绝大多数场景），自动 cast 成 Map<String, dynamic>。
  static List<Map<String, dynamic>> mapListOf(Map<String, dynamic>? data) =>
      listOf(data)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  /// 取字符串列表（如科室列表）。
  static List<String> stringListOf(Map<String, dynamic>? data) =>
      listOf(data).map((e) => e.toString()).toList();

  /// 取总条数，兼容 total / totalCount。
  static int totalOf(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final raw = data['total'] ?? data['totalCount'];
    if (raw is num) return raw.toInt();
    return 0;
  }

  /// 判断后端确实返回了空列表（而非解析失败）——用于区分「真空」和「字段读错」。
  /// 返回 true 表示 data 里存在任一已知分页字段且为空。
  static bool isEmptyPage(Map<String, dynamic>? data) {
    if (data == null) return false;
    return const ['list', 'records', 'content', 'items']
        .any((k) => data.containsKey(k) && data[k] is List);
  }
}
