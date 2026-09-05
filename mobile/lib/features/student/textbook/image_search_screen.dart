import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../student/data/student_service.dart';

/// 以图搜图（P1-4 多模态医学知识库）
///
/// 上传医学影像/教材截图，多模态 embedding 检索教材影像知识库，
/// 返回命中片段（含教材原图回显与知识点溯源）。
class ImageSearchScreen extends ConsumerStatefulWidget {
  const ImageSearchScreen({super.key});

  @override
  ConsumerState<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends ConsumerState<ImageSearchScreen> {
  XFile? _picked;
  final TextEditingController _textCtl = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _citations = [];

  @override
  void dispose() {
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;
    setState(() {
      _picked = file;
      _citations = [];
    });
  }

  Future<void> _search() async {
    if (_picked == null) {
      AppFeedback.info(context, '请先选择一张医学图片');
      return;
    }
    setState(() => _searching = true);
    try {
      final bytes = await _picked!.readAsBytes();
      final base64 = base64Encode(bytes);
      final text = _textCtl.text.trim();
      final result = await StudentService().searchKnowledgeByImage(
        imageBase64: base64,
        text: text.isEmpty ? null : text,
        topK: 6,
      );
      if (!mounted) return;
      final list = (result?['citations'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      setState(() {
        _citations = list;
        _searching = false;
      });
      if (list.isEmpty) {
        AppFeedback.info(context, '未在教材影像库中找到相关结果，换个图片试试');
      }
    } catch (e) {
      log('image search failed: $e', name: 'image_search_screen');
      if (!mounted) return;
      setState(() => _searching = false);
      AppFeedback.error(context, '检索失败，请检查网络后重试');
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
            AppBackAppBar(
              title: '以图搜图',
              onBack: () =>
                  context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
            ),
            _buildUploadArea(),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _citations.isEmpty
                      ? _buildEmpty()
                      : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const Icon(Icons.image_search_rounded,
                    size: 17, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SerifText('影像检索 · 教材多模态知识库',
                        fontSize: 14, color: AppColors.textOf(context)),
                    const SizedBox(height: 2),
                    Text('上传医学影像 / 心电图 / 教材截图，检索教材中的相关知识',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.text3Of(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _searching ? null : _pickImage,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                border: Border.all(
                    color: AppColors.surfaceEdgeOf(context), width: 1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: _picked == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 30, color: AppColors.text3Of(context)),
                        const SizedBox(height: 8),
                        Text('点击选择图片',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.text3Of(context))),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_picked!.path), fit: BoxFit.cover),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: _searching
                                  ? null
                                  : () => setState(() => _picked = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtl,
            enabled: !_searching,
            decoration: InputDecoration(
              isDense: true,
              hintText: '可选：补充上下文，如「这是典型心梗心电图」',
              hintStyle: TextStyle(color: AppColors.text4Of(context), fontSize: 12),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide:
                    BorderSide(color: AppColors.primaryOf(context), width: 1.5),
              ),
            ),
            style: TextStyle(fontSize: 12, color: AppColors.textOf(context)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              label: _searching ? '检索中…' : '开始检索',
              icon: const Icon(Icons.search, size: 15),
              onPressed: _searching ? null : _search,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_rounded,
              size: 48, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('上传图片后检索教材影像知识库',
              style: TextStyle(
                  fontSize: 12, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppSectionHeader(title: '命中教材片段 · ${_citations.length}'),
        ),
        ..._citations.map((c) => _citationCard(c)),
      ],
    );
  }

  Widget _citationCard(Map<String, dynamic> c) {
    final chapter = c['chapter'] as String? ?? '';
    final page = c['pageNumber'] as int?;
    final subject = c['subject'] as String? ?? '';
    final chunk = (c['chunkText'] as String? ?? '').trim();
    final score = c['score'];
    final imageKey = c['imageKey'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.mossTintOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Icon(Icons.menu_book_rounded,
                      size: 17, color: AppColors.primaryOf(context)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SerifText(
                    c['bookName'] as String? ?? '教材', fontSize: 14),
              ),
              if (score != null)
                AppChip(
                  label: '相关度 ${(score * 100).round() ~/ 1}%',
                  type: ChipType.moss,
                ),
            ],
          ),
          const SizedBox(height: 6),
          MonoText(
            [
              if (subject.isNotEmpty) subject,
              if (chapter.isNotEmpty) chapter,
              if (page != null) 'P$page',
            ].join(' · '),
            fontSize: 10,
            color: AppColors.text3Of(context),
          ),
          if (chunk.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              chunk,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.text2Of(context),
              ),
            ),
          ],
          if (imageKey != null && imageKey.isNotEmpty) ...[
            const SizedBox(height: 10),
            _CitationImage(imageKey: imageKey),
          ],
        ],
      ),
    );
  }
}

/// 教材原图回显（按 image_key 从后端拉取字节）
class _CitationImage extends ConsumerStatefulWidget {
  final String imageKey;
  const _CitationImage({required this.imageKey});

  @override
  ConsumerState<_CitationImage> createState() => _CitationImageState();
}

class _CitationImageState extends ConsumerState<_CitationImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await StudentService().getKnowledgeImageBytes(widget.imageKey);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mossTintOf(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text('教材原图加载失败',
            style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
      );
    }
    if (_bytes == null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mossTintOf(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        height: 140,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mossTintOf(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text('教材原图加载失败',
              style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
        ),
      ),
    );
  }
}
