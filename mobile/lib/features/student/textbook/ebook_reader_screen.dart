import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';

/// 电子书在线阅读器（使用 dio 拉取文件 + printing 分页渲染）
class EbookReaderScreen extends StatefulWidget {
  const EbookReaderScreen({super.key, required this.title, required this.fileUrl});
  final String title;
  final String fileUrl;

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;

  /// 相对路径（如 /uploads/xxx.pdf）拼上 API 基础地址，确保文件能正确下载，
  /// 避免 404 拿到 HTML 错误页被误当 PDF 渲染成乱码。
  String get _fullUrl {
    final raw = widget.fileUrl;
    if (Uri.tryParse(raw)?.hasScheme ?? false) return raw;
    const base = ApiConfig.apiBaseUrl;
    if (raw.startsWith('/')) return '$base$raw';
    return '$base/$raw';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.get<List<int>>(
        _fullUrl,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
        ),
      );
      final bytes = Uint8List.fromList(resp.data ?? const []);
      if (!mounted) return;

      // 校验确实是 PDF：前 5 字节应为 "%PDF-"（占位教材若文件缺失，
      // 后端会返回 404/HTML，这里直接给出清晰提示而非渲染乱码）。
      final isPdf = bytes.length >= 5 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46 &&
          bytes[4] == 0x2d;
      setState(() {
        _loading = false;
        if (bytes.isEmpty) {
          _error = '文件为空，请检查教材是否已上传电子书文件';
        } else if (!isPdf) {
          _error = '未找到有效的电子书文件（文件缺失或正在上传中），请稍后重试';
        } else {
          _bytes = bytes;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.statusCode == 404
            ? '电子书文件不存在，请确认该教材已上传 PDF 文件'
            : '加载失败：${e.message}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 44, color: AppColors.vermilion),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(
                                      fontSize: 13, color: AppColors.text2Of(context))),
                            ],
                          ),
                        )
                      : PdfPreview(
                          build: (_) async => _bytes!,
                          canChangePageFormat: true,
                          canChangeOrientation: true,
                          canDebug: false,
                          pdfFileName: widget.title,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}