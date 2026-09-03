import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 电子书本地缓存管理工具
///
/// 缓存目录：临时目录/ebook_cache/
/// 命名规则：ebook_{URL路径转义}.pdf
/// 同一教材的 PDF 永久缓存在本地，下次打开秒开。
class EbookCache {
  EbookCache._();

  /// 获取电子书缓存目录
  static Future<Directory> get cacheDir async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/ebook_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 获取缓存文件列表
  static Future<List<File>> get cachedFiles async {
    final dir = await cacheDir;
    if (!await dir.exists()) return [];
    return await dir.list().where((e) => e is File).cast<File>().toList();
  }

  /// 获取缓存总大小（字节）
  static Future<int> get cacheSizeBytes async {
    final files = await cachedFiles;
    int total = 0;
    for (final f in files) {
      try {
        total += await f.length();
      } catch (_) {}
    }
    return total;
  }

  /// 获取格式化的缓存大小字符串
  static Future<String> get cacheSizeFormatted async {
    final bytes = await cacheSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 获取已缓存教材数量
  static Future<int> get cachedCount async {
    return (await cachedFiles).length;
  }

  /// 清除所有电子书缓存
  ///
  /// 返回释放的字节数，-1 表示出错
  static Future<int> clearCache() async {
    final dir = await cacheDir;
    if (!await dir.exists()) return 0;
    int freed = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          freed += await entity.length();
          await entity.delete();
        }
      }
    } catch (_) {
      return -1;
    }
    return freed;
  }

  /// 检查指定 URL 对应的缓存是否存在且有效
  static Future<bool> hasCache(String fileUrl) async {
    final fileName = _fileNameFromUrl(fileUrl);
    final dir = await cacheDir;
    final file = File('${dir.path}/$fileName');
    return await file.exists() && await file.length() > 0;
  }

  /// 从 URL 生成固定缓存文件名
  static String _fileNameFromUrl(String raw) {
    // 先补全基础地址（与 ebook_reader_screen 逻辑一致）
    String fullUrl = raw;
    if (!(Uri.tryParse(raw)?.hasScheme ?? false)) {
      // 这里简单处理：直接用原始路径部分
      final uri = Uri.tryParse(raw);
      final path = uri?.path ?? raw;
      fullUrl = path;
    } else {
      fullUrl = Uri.parse(raw).path;
    }
    return 'ebook_${fullUrl.replaceAll('/', '_').replaceAll('\\', '_').replaceAll(':', '_').replaceAll('?', '_').replaceAll('&', '_')}.pdf';
  }
}
