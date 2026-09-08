import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';

/// 电子书在线阅读器
///
/// 之前的实现用 dio 把整份 PDF 一次性读进内存，再交给 PdfPreview 同步渲染：
/// - 大文件直接 OOM 闪退；
/// - 读条走完（整份 PDF 下载完）才进入渲染，看起来像「读条结束才开始加载」。
///
/// 现在改为：先用 dio 把 PDF 流式写入临时文件（落盘，不整份驻留内存），再用
/// pdfx 的原生 PdfDocument.openFile 打开，按页懒解码——首屏只渲染当前页，
/// 翻页才解码对应页，内存占用大降、打开更快；进度条反映真实的下载进度。
class EbookReaderScreen extends StatefulWidget {
  const EbookReaderScreen({super.key, required this.title, required this.fileUrl});

  final String title;
  final String fileUrl;

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  bool _downloading = true;
  double _progress = 0;
  String? _error;
  PdfController? _controller;
  int _page = 1;
  int _total = 0;
  bool _fromCache = false;

  /// 相对路径（如 /uploads/xxx.pdf）拼上 API 基础地址，确保文件能正确下载，
  /// 避免 404 拿到 HTML 错误页被误当 PDF 渲染成乱码。
  String get _fullUrl {
    final raw = widget.fileUrl;
    if (Uri.tryParse(raw)?.hasScheme ?? false) return raw;
    const base = ApiConfig.apiBaseUrl;
    if (raw.startsWith('/')) return '$base$raw';
    return '$base/$raw';
  }

  /// 基于文件 URL 生成固定缓存文件名（取路径部分，替换非法字符），同一教材永远对应同一个本地文件。
  String get _cacheFileName {
    // 从 URL 中提取路径部分作为标识
    final uri = Uri.tryParse(_fullUrl);
    final path = uri?.path ?? _fullUrl;
    // 替换文件系统非法字符
    return 'ebook_${path.replaceAll('/', '_').replaceAll('\\', '_').replaceAll(':', '_').replaceAll('?', '_').replaceAll('&', '_')}.pdf';
  }

  /// 获取电子书缓存目录（独立子目录，便于统一管理/清理）
  Future<Directory> get _cacheDir async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/ebook_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 获取当前教材的缓存文件
  Future<File> get _cacheFile async {
    final dir = await _cacheDir;
    return File('${dir.path}/$_cacheFileName');
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      // 1) 优先打开缓存（秒开）；缓存不存在/为空时走流式下载
      var file = await _cacheFile;
      var fromCache = await file.exists() && await file.length() > 0;
      if (!fromCache) {
        file = await _downloadToFile();
      }

      // 2) 尝试按 PDF 打开。若打开失败说明缓存/文件是损坏或非 PDF 内容
      //    （例如上次下载被中断的残缺文件，或拿到的 HTML 错误页被误存成 .pdf）。
      //    命中坏缓存时自动删除并重新下载，避免一直卡在同一个坏文件上。
      var document = await _openOrNull(file);
      if (document == null && fromCache) {
        try { await file.delete(); } catch (_) {}
        file = await _downloadToFile();
        document = await _openOrNull(file);
        fromCache = false;
      }

      if (document == null) {
        if (!mounted) return;
        setState(() {
          _error = '电子书文件无效或已损坏，请确认该教材已上传可解析的 PDF 文件';
          _downloading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _controller = PdfController(document: Future.value(document));
        _downloading = false;
        _fromCache = fromCache;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.statusCode == 404
            ? '电子书文件不存在，请确认该教材已上传 PDF 文件'
            : '下载失败：${e.message}';
        _downloading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '电子书加载失败：$e';
        _downloading = false;
      });
    }
  }

  /// 尝试以 PDF 打开文件。
  ///
  /// 文件不存在/为空/损坏/非 PDF 时返回 null（坏缓存走删除+重下流程），
  /// 而不是把异常直接抛给外层 catch，避免「坏缓存永久命中、无法自愈」。
  Future<PdfDocument?> _openOrNull(File file) async {
    try {
      return await PdfDocument.openFile(file.path);
    } catch (_) {
      return null;
    }
  }

  /// 流式下载 PDF 到固定缓存路径（边下边写盘，不把整份读进内存）。
  /// 同一教材永远写入同一个文件，下次打开直接复用。
  Future<File> _downloadToFile() async {
    final dir = await _cacheDir;
    final file = File('${dir.path}/$_cacheFileName');
    // 如果存在不完整文件（上次中断），先删除
    if (await file.exists()) await file.delete();
    await ApiClient.instance.download(
      _fullUrl,
      file.path,
      onReceiveProgress: (received, total) {
        if (total <= 0 || !mounted) return;
        setState(() => _progress = received / total);
      },
      options: Options(
        validateStatus: (s) => s != null && s >= 200 && s < 400,
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    if (file.lengthSync() == 0) {
      throw const FileSystemException('文件内容为空');
    }
    return file;
  }

  void _onPageChanged(int page) => setState(() => _page = page);

  void _onDocumentLoaded(PdfDocument doc) {
    if (!mounted) return;
    setState(() => _total = doc.pagesCount);
  }

  void _onDocumentError(Object error) {
    if (!mounted) return;
    setState(() => _error = _friendlyError(error.toString()));
  }

  String _friendlyError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('format') || s.contains('invalid') || s.contains('corrupt') || s.contains('not pdf')) {
      return '电子书文件无效或已损坏，请确认文件是否为可解析的 PDF';
    }
    return '电子书打开失败，请稍后重试';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: widget.title, onBack: () => Navigator.of(context).pop()),
            Expanded(child: _buildBody()),
            if (_total > 0) _buildPageFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_downloading) return _buildDownloadProgress();
    if (_error != null) return _buildError();
    final controller = _controller!;
    return PdfView(
      controller: controller,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      onDocumentLoaded: _onDocumentLoaded,
      onDocumentError: _onDocumentError,
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const _PdfLoading(),
        pageLoaderBuilder: (_) => const _PdfLoading(),
        errorBuilder: (_, e) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _friendlyError(e.toString()),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
            ),
          ),
        ),
      ),
    );
  }

  /// 下载中：进度百分比 + 真实进度条
  Widget _buildDownloadProgress() {
    final pct = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primaryOf(context),
              value: _progress > 0 ? _progress : null,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '正在下载电子书… $pct%',
            style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
          ),
          if (_progress > 0) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: AppProgressBar(
                value: _progress,
                height: 5,
                foregroundColor: AppColors.primaryOf(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          MonoText(_fromCache ? '已从本地缓存打开' : '首次打开需下载文件，之后将自动缓存',
              fontSize: 10,
              color: AppColors.text4Of(context),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 44, color: AppColors.vermilionOf(context)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部页码指示
  Widget _buildPageFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Center(
        child: MonoText(
          '第 $_page / $_total 页',
          fontSize: 12,
          color: AppColors.text3Of(context),
        ),
      ),
    );
  }
}

/// pdfx 解码中占位
class _PdfLoading extends StatelessWidget {
  const _PdfLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.primaryOf(context),
        ),
      ),
    );
  }
}