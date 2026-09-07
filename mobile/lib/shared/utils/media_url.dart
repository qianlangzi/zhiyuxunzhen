import '../../core/config/api_config.dart';

/// 媒体资源 URL 解析：把后端返回的路径统一为可直接访问的完整 URL。
///
/// 后端上传接口返回相对路径（如 `/uploads/xxx.jpg`，UPLOAD_BASE_URL=/uploads），
/// 真机上相对路径无法加载，需拼上 API 主机；完整 URL 原样返回。
String resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return '${ApiConfig.apiBaseUrl}$u';
  return '${ApiConfig.apiBaseUrl}/$u';
}
