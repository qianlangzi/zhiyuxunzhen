import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/page_parser.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../student/assignments/material_view_screen.dart';
import '../../student/textbook/ebook_reader_screen.dart';
import '../data/teacher_service.dart';

/// 班级资料库（班级详情「资料」板块）
///
/// 教师maintain本班资料：上传课件/音视频/文档（PDF/PPT/Word/TXT/MP4/MP3/图片），
/// 或引用教材库教材（只存引用不复制文件）。学生端「我的课程-班级详情」同步可见。
class ClassMaterialScreen extends StatefulWidget {
  const ClassMaterialScreen({super.key, required this.classId, this.className});

  final int classId;
  final String? className;

  @override
  State<ClassMaterialScreen> createState() => _ClassMaterialScreenState();
}

class _ClassMaterialScreenState extends State<ClassMaterialScreen> {
  /// false=资料列表 true=教材引用选择（从教材库挑一本挂进班级资料）
  bool _picking = false;

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  bool _uploading = false;

  // 教材引用选择态
  List<Map<String, dynamic>> _tbList = [];
  bool _tbLoading = false;
  bool _tbLoadingMore = false;
  int _tbPage = 1;
  bool _tbHasMore = true;
  String _tbKeyword = '';
  final _tbSearchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tbSearchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await TeacherService().getClassMaterials(widget.classId);
    if (!mounted) return;
    setState(() {
      _list = data ?? [];
      _isLoading = false;
    });
  }

  // ================= 添加入口 =================

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceEdgeOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SerifText('添加班级资料', fontSize: 16, color: AppColors.textOf(context)),
              const SizedBox(height: 4),
              MonoText('支持 PDF / PPT / Word / TXT / MP4 / MP3 / 图片，≤200MB',
                  fontSize: 10.5, color: AppColors.text3Of(context)),
              const SizedBox(height: 16),
              _addOption(
                ctx,
                icon: Icons.cloud_upload_outlined,
                color: AppColors.vermilionOf(context),
                bg: AppColors.vermilionSoftOf(context),
                title: '上传文件',
                subtitle: '课件 / 讲义 / 音视频 / 图片，自行上传',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUpload();
                },
              ),
              const SizedBox(height: 10),
              _addOption(
                ctx,
                icon: Icons.menu_book_rounded,
                color: AppColors.indigoOf(context),
                bg: AppColors.indigoSoftOf(context),
                title: '引用教材库教材',
                subtitle: '从平台教材库挑选，引用后班级内可直接阅读',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _enterTextbookPicker();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addOption(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText(title, fontSize: 14, color: AppColors.textOf(context)),
                  const SizedBox(height: 2),
                  MonoText(subtitle, fontSize: 10.5, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  // ================= 上传文件 =================

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    final size = result!.files.single.size;
    if (size > 200 * 1024 * 1024) {
      AppFeedback.error(context, '文件超过 200MB，请压缩后再上传');
      return;
    }
    setState(() => _uploading = true);
    AppFeedback.info(context, '正在上传，请稍候…');
    final err = await TeacherService()
        .uploadClassMaterial(widget.classId, path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    AppFeedback.success(context, '资料已上传');
    _load();
  }

  // ================= 引用教材 =================

  void _enterTextbookPicker() {
    setState(() => _picking = true);
    _tbPage = 1;
    _tbHasMore = true;
    _tbKeyword = '';
    _tbSearchCtl.clear();
    _tbList = [];
    _loadTextbooks();
  }

  Future<void> _loadTextbooks() async {
    if (_tbLoading) return;
    setState(() => _tbLoading = true);
    final data = await TeacherService().getTextbookLibrary(
      pageNum: 1,
      pageSize: 20,
      keyword: _tbKeyword.isEmpty ? null : _tbKeyword,
    );
    if (!mounted) return;
    final rows = PageParser.mapListOf(data ?? {});
    setState(() {
      _tbList = rows;
      _tbHasMore = rows.length >= 20;
      _tbLoading = false;
    });
  }

  Future<void> _loadMoreTextbooks() async {
    if (_tbLoadingMore || !_tbHasMore) return;
    setState(() => _tbLoadingMore = true);
    final next = _tbPage + 1;
    final data = await TeacherService().getTextbookLibrary(
      pageNum: next,
      pageSize: 20,
      keyword: _tbKeyword.isEmpty ? null : _tbKeyword,
    );
    if (!mounted) return;
    final rows = PageParser.mapListOf(data ?? {});
    setState(() {
      _tbPage = next;
      _tbList.addAll(rows);
      _tbHasMore = rows.length >= 20;
      _tbLoadingMore = false;
    });
  }

  Future<void> _confirmReference(Map<String, dynamic> tb) async {
    final id = (tb['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: SerifText('引用该教材？', fontSize: 16, color: AppColors.textOf(context)),
        content: MonoText(
          '「${tb['title'] ?? '未命名'}」将加入本班资料，学生可在班级资料中查看。',
          fontSize: 12.5,
          color: AppColors.text2Of(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: MonoText('取消', fontSize: 13, color: AppColors.text3Of(context)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: MonoText('引用', fontSize: 13, color: AppColors.primaryOf(context)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await TeacherService().referenceClassTextbook(widget.classId, id);
    if (!mounted) return;
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    AppFeedback.success(context, '教材已加入班级资料');
    setState(() => _picking = false);
    _load();
  }

  // ================= 删除 =================

  Future<void> _confirmRemove(Map<String, dynamic> m) async {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: SerifText('移除资料？', fontSize: 16, color: AppColors.textOf(context)),
        content: MonoText('「${m['title'] ?? ''}」将从本班资料中移除，学生端不再显示。',
            fontSize: 12.5, color: AppColors.text2Of(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: MonoText('取消', fontSize: 13, color: AppColors.text3Of(context)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: MonoText('移除', fontSize: 13, color: AppColors.vermilionOf(context)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await TeacherService().removeClassMaterial(widget.classId, id);
    if (!mounted) return;
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    AppFeedback.success(context, '已移除');
    _load();
  }

  // ================= 预览 =================

  void _openMaterial(Map<String, dynamic> m) {
    final fileUrl = m['fileUrl'] as String?;
    if (fileUrl == null || fileUrl.isEmpty) {
      AppFeedback.info(context, '该资料暂无在线文件');
      return;
    }
    final type = (m['materialType'] as String? ?? '').toLowerCase();
    final title = m['title'] as String? ?? '资料';
    if (type == 'pdf' || type == 'image' || fileUrl.toLowerCase().endsWith('.pdf')) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EbookReaderScreen(title: title, fileUrl: fileUrl),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MaterialViewScreen(
        title: title,
        fileUrl: fileUrl,
        materialType: type,
      ),
    ));
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final name = widget.className?.trim().isNotEmpty == true
        ? widget.className!.trim()
        : '班级资料';
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: _picking ? '引用教材' : name,
              onBack: () {
                if (_picking) {
                  setState(() => _picking = false);
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.classManage);
                }
              },
              action: _picking
                  ? null
                  : AppIconButton(
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 22),
                      onPressed: _uploading ? null : _showAddSheet,
                    ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _picking ? _buildPicker() : _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- 资料列表 --------

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded,
                      size: 48, color: AppColors.text4Of(context)),
                  const SizedBox(height: 12),
                  SerifText('暂无班级资料', fontSize: 15, color: AppColors.text2Of(context)),
                  const SizedBox(height: 4),
                  Text('点击右上角 + 上传课件或引用教材',
                      style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _MaterialRow(
          item: _list[i],
          onTap: () => _openMaterial(_list[i]),
          onDelete: () => _confirmRemove(_list[i]),
        ),
      ),
    );
  }

  // -------- 教材引用选择 --------

  Widget _buildPicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: TextField(
            controller: _tbSearchCtl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadTextbooks(),
            style: TextStyle(color: AppColors.textOf(context), fontSize: 13.5),
            decoration: InputDecoration(
              hintText: '搜索教材名称',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
              prefixIcon: Icon(Icons.search, size: 20, color: AppColors.text4Of(context)),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceOf(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: _tbLoading && _tbList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _tbList.isEmpty
                  ? Center(
                      child: MonoText('没有找到相关教材', fontSize: 13,
                          color: AppColors.text3Of(context)),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >
                            n.metrics.maxScrollExtent - 200) {
                          _loadMoreTextbooks();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                        itemCount: _tbList.length + (_tbHasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          if (i >= _tbList.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _TextbookPickRow(
                            item: _tbList[i],
                            onTap: () => _confirmReference(_tbList[i]),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ================= 行组件 =================

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.item, required this.onTap, required this.onDelete});

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isTextbook = item['sourceType'] == 'textbook';
    final type = (item['materialType'] as String? ?? '').toLowerCase();
    final icon = _typeIcon(isTextbook, type);
    final color = _typeColor(context, isTextbook, type);
    final bg = _typeBg(context, isTextbook, type);

    final subtitleParts = <String>[
      isTextbook ? '教材引用' : '上传',
      _typeLabel(type),
    ];
    final duration = item['durationSec'];
    if (duration is num && duration > 0) {
      subtitleParts.add(_formatDuration(duration.toInt()));
    }
    if (isTextbook && (item['department'] as String? ?? '').isNotEmpty) {
      subtitleParts.add(item['department'] as String);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText(item['title'] as String? ?? '未命名',
                      fontSize: 14, color: AppColors.textOf(context)),
                  const SizedBox(height: 4),
                  MonoText(subtitleParts.join(' · '),
                      fontSize: 10.5, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.remove_circle_outline,
                    size: 18, color: AppColors.text4Of(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(bool isTextbook, String type) {
    if (isTextbook) return Icons.menu_book_rounded;
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'ppt':
        return Icons.slideshow_rounded;
      case 'doc':
        return Icons.article_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      case 'epub':
        return Icons.auto_stories_rounded;
      case 'mp4':
        return Icons.movie_rounded;
      case 'mp3':
        return Icons.headphones_rounded;
      case 'image':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _typeColor(BuildContext context, bool isTextbook, String type) {
    if (isTextbook) return AppColors.indigoOf(context);
    switch (type) {
      case 'mp4':
      case 'mp3':
        return AppColors.vermilionOf(context);
      case 'image':
        return AppColors.moss;
      default:
        return AppColors.amberOf(context);
    }
  }

  Color _typeBg(BuildContext context, bool isTextbook, String type) {
    if (isTextbook) return AppColors.indigoSoftOf(context);
    switch (type) {
      case 'mp4':
      case 'mp3':
        return AppColors.vermilionSoftOf(context);
      case 'image':
        return AppColors.mossTintOf(context);
      default:
        return AppColors.amberSoftOf(context);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'pdf':
        return 'PDF';
      case 'ppt':
        return 'PPT';
      case 'doc':
        return '文档';
      case 'txt':
        return 'TXT';
      case 'epub':
        return 'EPUB';
      case 'mp4':
        return '视频';
      case 'mp3':
        return '音频';
      case 'image':
        return '图片';
      default:
        return '文件';
    }
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _TextbookPickRow extends StatelessWidget {
  const _TextbookPickRow({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.indigoSoftOf(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Center(
                child: Icon(Icons.menu_book_rounded, size: 20, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText(item['title'] as String? ?? '未命名',
                      fontSize: 14, color: AppColors.textOf(context)),
                  const SizedBox(height: 4),
                  MonoText(
                    '${item['department'] ?? '综合'} · ${item['publisher'] ?? ''}',
                    fontSize: 10,
                    color: AppColors.text3Of(context),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryOf(context)),
          ],
        ),
      ),
    );
  }
}
