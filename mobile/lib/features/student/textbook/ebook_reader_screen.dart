import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.get<List<int>>(
        widget.fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(resp.data ?? []);
        _loading = false;
        if (_bytes!.isEmpty) _error = '文件为空';
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