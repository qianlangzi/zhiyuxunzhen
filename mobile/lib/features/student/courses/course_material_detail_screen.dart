import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';
import '../textbook/ebook_reader_screen.dart';

/// 学习资料详情子页（一次备课发布）
///
/// 展示该资料包的标题/科室/截止时间，以及其中每个文件；点击文件按其类型预览：
/// - pdf → EbookReaderScreen（pdfx 在线阅读）
/// - 图片/视频/音频 → CourseMaterialPreviewScreen 对应查看器
/// - 其它 → CourseMaterialPreviewScreen 下载分享兜底
class CourseMaterialDetailScreen extends ConsumerStatefulWidget {
  const CourseMaterialDetailScreen({
    super.key,
    required this.publishId,
    required this.classId,
    required this.title,
    this.material,
  });

  final int publishId;
  final int classId;
  final String title;

  /// 由班级页直接带入的整条资料包数据（含 materials 文件列表），避免二次请求。
  /// 为空（深链场景）时按 classId+publishId 回源加载。
  final Map<String, dynamic>? material;

  @override
  ConsumerState<CourseMaterialDetailScreen> createState() =>
      _CourseMaterialDetailScreenState();
}

class _CourseMaterialDetailScreenState
    extends ConsumerState<CourseMaterialDetailScreen> {
  Map<String, dynamic>? _material;
  bool _loading = true;
  /// 我是否已标记完成该资料任务（完成后从待办与课程角标清除）
  bool _completed = false;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    if (widget.material != null) {
      _material = widget.material;
      _completed = widget.material?['completed'] == true;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final data = await StudentService().getClassDetail(widget.classId);
    Map<String, dynamic>? found;
    if (data != null) {
      final list = data['materials'] as List<dynamic>? ?? const [];
      for (final it in list) {
        if (it is Map && ((it['publishId'] as num?)?.toInt() ?? 0) == widget.publishId) {
          found = it.map((k, v) => MapEntry(k.toString(), v));
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _material = found;
      _completed = found?['completed'] == true;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _files {
    return ((_material?['materials'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// 标记资料任务完成（幂等；成功后待办与「我的课程」角标同步清除）
  Future<void> _markCompleted() async {
    if (_completed || _completing) return;
    setState(() => _completing = true);
    final ok = await StudentService().completeLessonTask(widget.publishId);
    if (!mounted) return;
    setState(() => _completing = false);
    if (ok) {
      setState(() => _completed = true);
      AppFeedback.success(context, '已完成学习，待办已同步更新');
    } else {
      AppFeedback.error(context, '标记失败，请重试');
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
            AppBackAppBar(title: '学习资料', onBack: () => context.pop()),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_material == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('资料不存在或已被下架',
              style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
        ),
      );
    }
    final m = _material!;
    final title = (m['lessonTitle'] ?? widget.title).toString();
    final dep = (m['department'] ?? '').toString();
    final deadline = m['deadline']?.toString() ?? '';
    final materialOnly = m['materialOnly'] == true;
    final files = _files;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // 校园风资料包头部：柔和苔藓渐变，衬线标题，非高光
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.mossTintOf(context),
                AppColors.surfaceOf(context),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOf(context),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.folder_open_rounded,
                        color: AppColors.onPrimaryOf(context), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SerifText(title,
                        fontSize: 17, weight: FontWeight.w700, height: 1.3),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _meta('共 ${files.length} 个文件'),
              if (dep.isNotEmpty) _meta('科室：$dep'),
              if (deadline.isNotEmpty) _meta('截止：${_shortDate(deadline)}'),
              if (materialOnly) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.vermilionSoftOf(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('仅资料 · 无作业',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.vermilionOf(context))),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.folder_open_rounded,
                size: 18, color: AppColors.primaryOf(context)),
            const SizedBox(width: 8),
            Text('文件清单',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOf(context))),
          ],
        ),
        const SizedBox(height: 10),
        if (files.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            ),
            child: Text('该资料包还没有文件',
                style: TextStyle(
                    fontSize: 13, color: AppColors.text3Of(context))),
          )
        else
          ...files.asMap().entries.map((e) => _fileCard(e.key, e.value)),
        // 资料任务完成动作（仅独立发放的资料需要手动标记；带作业的走作业链路）
        if (materialOnly) ...[
          const SizedBox(height: 20),
          _buildCompleteAction(),
        ],
      ],
    );
  }

  /// 完成动作区：未完成 → 主按钮；已完成 → 绿色确认条
  Widget _buildCompleteAction() {
    if (_completed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mossTintOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.primaryOf(context).withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.primaryOf(context)),
            const SizedBox(width: 8),
            Text('已完成学习',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOf(context))),
          ],
        ),
      );
    }
    return AppPrimaryButton(
      label: _completing ? '正在标记…' : '标记完成学习',
      fullWidth: true,
      onPressed: _completing ? null : _markCompleted,
    );
  }

  Widget _meta(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
    );
  }

  Widget _fileCard(int index, Map<String, dynamic> f) {
    final type = _normalizeType(f['materialType'] as String? ?? '', f['fileUrl']);
    final title = (f['title'] ?? '资料 ${index + 1}').toString();
    final dur = (f['durationSec'] as num?)?.toInt();
    final (icon, color, colorBg, label) = switch (type) {
      'pdf' => (Icons.picture_as_pdf_outlined, AppColors.vermilionOf(context), AppColors.vermilionSoftOf(context), 'PDF'),
      'image' => (Icons.image_outlined, AppColors.moss, AppColors.mossTintOf(context), '图片'),
      'video' => (Icons.videocam_outlined, AppColors.indigoOf(context), AppColors.indigoSoftOf(context), '视频'),
      'audio' => (Icons.graphic_eq_rounded, AppColors.amberOf(context), AppColors.amberSoftOf(context), '音频'),
      _ => (Icons.description_outlined, AppColors.text3Of(context), AppColors.bgOf(context), '文件'),
    };
    return AppPressable(
      onTap: () => _openFile(type, f),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOf(context))),
                  const SizedBox(height: 3),
                  Text(
                    dur != null && dur > 0 ? '$label · $dur 秒' : label,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.text3Of(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  /// 按 fileUrl 扩展名归一预览类型（人脸优先），供图标与预览分发使用
  String _normalizeType(String rawType, Object? fileUrl) {
    final t = rawType.toLowerCase();
    if (t.isNotEmpty && t != 'other') {
      if (t == 'image' || t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'gif') {
        return 'image';
      }
      if (t == 'mp4' || t == 'mov') return 'video';
      if (t == 'mp3' || t == 'wav' || t == 'm4a') return 'audio';
      if (t == 'pdf') return 'pdf';
      if (t == 'ppt' || t == 'pptx') return 'download';
    }
    final url = (fileUrl ?? '').toString().toLowerCase();
    if (url.endsWith('.pdf')) return 'pdf';
    if (RegExp(r'\.(jpg|jpeg|png|gif|webp)$').hasMatch(url)) return 'image';
    if (RegExp(r'\.(mp4|mov|m4v)$').hasMatch(url)) return 'video';
    if (RegExp(r'\.(mp3|wav|m4a|aac)$').hasMatch(url)) return 'audio';
    return 'download';
  }

  void _openFile(String type, Map<String, dynamic> f) {
    final url = (f['fileUrl'] ?? '').toString();
    final title = (f['title'] ?? '资料').toString();
    if (type == 'pdf') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EbookReaderScreen(title: title, fileUrl: url),
      ));
      return;
    }
    if (type == 'download') {
      context.pushNamed(RouteNames.courseMaterialPreview,
          extra: {'type': 'download', 'title': title, 'url': url});
      return;
    }
    context.pushNamed(RouteNames.courseMaterialPreview,
        extra: {'type': type, 'title': title, 'url': url});
  }

  String _shortDate(String raw) {
    final t = DateTime.tryParse(raw);
    if (t == null) return raw;
    final local = t.toLocal();
    return '${local.year}-${_p(local.month)}-${_p(local.day)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}