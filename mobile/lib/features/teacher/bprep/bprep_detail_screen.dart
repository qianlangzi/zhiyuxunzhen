import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 教案工作台（医学教案创作）
///
/// AI 生成的可编辑教案（目标/重点/难点/过程/病例讨论/技能训练/SP问诊/板书/作业/反思/出处）
/// + 关联病例（病历大厅引用）+ 课件资料 + 导出 Word / 分享微信。
/// 备课是教师自用教案，不再面向班级发布。
class BprepDetailScreen extends ConsumerStatefulWidget {
  final int lessonId;
  const BprepDetailScreen({super.key, required this.lessonId});

  @override
  ConsumerState<BprepDetailScreen> createState() => _BprepDetailScreenState();
}

class _BprepDetailScreenState extends ConsumerState<BprepDetailScreen> {
  Map<String, dynamic>? _detail;
  Map<String, dynamic> _design = {};
  bool _isLoading = true;
  bool _saving = false;
  bool _exporting = false;
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _saveStatus = ''; // '' | 保存中… | 已自动保存 | 保存失败

  // ========= 课件 PPT 提纲状态 =========
  bool _pptLoading = false;
  bool _pptSaving = false;
  String _pptTitle = '';
  String _pptOverview = '';
  String _pptNotes = '';
  List<Map<String, dynamic>> _pptSlides = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _speech?.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await TeacherService().getLessonDetail(widget.lessonId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      final raw = detail?['aiDesign'] as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          _design = (jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          _design = {};
        }
      } else {
        _design = {};
      }
      _loadPpt(detail?['pptOutline'] as String?);
      _isLoading = false;
    });
  }

  // ========= 课件 PPT 提纲 =========
  void _applyPpt(Map<String, dynamic>? ppt) {
    _pptTitle = '${ppt?['title'] ?? ''}';
    _pptOverview = '${ppt?['overview'] ?? ''}';
    _pptNotes = '${ppt?['notes'] ?? ''}';
    final slides = ((ppt?['slides'] as List<dynamic>?) ?? const []);
    _pptSlides = slides
        .map((e) => (e as Map).cast<String, dynamic>())
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  void _loadPpt(String? raw) {
    if (raw == null || raw.isEmpty) {
      _pptTitle = '';
      _pptOverview = '';
      _pptNotes = '';
      _pptSlides = [];
      return;
    }
    try {
      _applyPpt(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _pptTitle = '';
      _pptOverview = '';
      _pptNotes = '';
      _pptSlides = [];
    }
  }

  Future<void> _generatePpt() async {
    if (_pptLoading) return;
    if (_design.isEmpty) {
      AppFeedback.info(context, '请先点击「AI 生成教案」生成教学设计，再生成课件 PPT');
      return;
    }
    setState(() => _pptLoading = true);
    final ppt = await TeacherService().generateLessonPpt(widget.lessonId);
    if (!mounted) return;
    setState(() {
      _pptLoading = false;
      if (ppt != null) _applyPpt(ppt);
    });
    if (ppt == null) {
      AppFeedback.error(context, 'PPT 提纲生成失败，请稍后重试');
    } else {
      AppFeedback.success(context, 'PPT 提纲已生成，可逐页编辑后保存');
    }
  }

  Future<void> _savePpt() async {
    if (_pptSaving) return;
    setState(() => _pptSaving = true);
    final ok = await TeacherService().saveLessonPpt(widget.lessonId, {
      'title': _pptTitle,
      'overview': _pptOverview,
      'slides': _pptSlides,
      'notes': _pptNotes,
    });
    if (!mounted) return;
    setState(() => _pptSaving = false);
    if (ok) {
      AppFeedback.success(context, '课件提纲已保存');
    } else {
      AppFeedback.error(context, '保存失败，请重试');
    }
  }

  Future<void> _editSlide(int index) async {
    final s = _pptSlides[index];
    final titleCtrl = TextEditingController(text: '${s['title'] ?? ''}');
    final phaseCtrl = TextEditingController(text: '${s['phase'] ?? ''}');
    final noteCtrl = TextEditingController(text: '${s['speakerNotes'] ?? ''}');
    final materialCtrl =
        TextEditingController(text: '${s['materialNote'] ?? ''}');
    final bulletsCtrl = TextEditingController(
        text: ((s['bullets'] as List<dynamic>?) ?? const []).join('\n'));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑第 ${index + 1} 页'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pptField('标题', titleCtrl, hint: '本页标题'),
              const SizedBox(height: 10),
              _pptField('环节', phaseCtrl,
                  hint: '导入/讲授/病例讨论/技能训练/小结'),
              const SizedBox(height: 10),
              _pptField('要点', bulletsCtrl,
                  hint: '每行一条要点', maxLines: 6),
              const SizedBox(height: 10),
              _pptField('讲稿备注', noteCtrl, hint: '讲解提示', maxLines: 4),
              const SizedBox(height: 10),
              _pptField('配套素材', materialCtrl,
                  hint: '如图表/解剖图/影像/视频（可空）', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _pptSlides[index] = {
        'seq': index + 1,
        'phase': phaseCtrl.text.trim(),
        'title': titleCtrl.text.trim(),
        'bullets': bulletsCtrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'speakerNotes': noteCtrl.text.trim(),
        'materialNote': materialCtrl.text.trim(),
      };
    });
  }

  Widget _pptField(String label, TextEditingController ctrl,
      {String hint = '', int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 2,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none),
      ),
    );
  }

  void _removeSlide(int index) {
    if (index < 0 || index >= _pptSlides.length) return;
    setState(() {
      _pptSlides.removeAt(index);
      for (var i = 0; i < _pptSlides.length; i++) {
        _pptSlides[i]['seq'] = i + 1;
      }
    });
  }

  void _addSlide() {
    setState(() {
      _pptSlides.add({
        'seq': _pptSlides.length + 1,
        'phase': '',
        'title': '未命名页面',
        'bullets': <String>[],
        'speakerNotes': '',
        'materialNote': '',
      });
    });
  }

  Widget _buildPptCard() {
    final hasPpt = _pptSlides.isNotEmpty || _pptOverview.isNotEmpty;
    return AppCard(
      borderLeft: hasPpt ? AppColors.primaryOf(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EyebrowText('课件 PPT（AI 生成）')),
              if (_pptLoading)
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (hasPpt && !_pptSaving)
                AppGhostButton(
                    label: _pptSaving ? '保存中…' : '保存提纲',
                    small: true,
                    onPressed: _savePpt),
            ],
          ),
          const SizedBox(height: 8),
          if (hasPpt) ...[
            MonoText(_pptOverview,
                fontSize: 11, color: AppColors.text3Of(context)),
            const SizedBox(height: 8),
            for (var i = 0; i < _pptSlides.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppColors.surfaceEdgeOf(context),
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryOf(context)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryOf(context))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${_pptSlides[i]['title'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textOf(context))),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          icon: const Icon(Icons.edit_outlined),
                          color: AppColors.text3Of(context),
                          onPressed: () => _editSlide(i),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.vermilionOf(context).withValues(alpha: 0.7),
                          onPressed: () => _removeSlide(i),
                        ),
                      ],
                    ),
                    if ((_pptSlides[i]['phase'] as String?)
                            ?.isNotEmpty ==
                        true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('环节：${_pptSlides[i]['phase']}',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.text3Of(context))),
                      ),
                    for (final b in ((_pptSlides[i]['bullets'])
                            as List<dynamic>? ??
                        const []))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('· $b',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: AppColors.text2Of(context))),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: AppGhostButton(
                    label: '加一页',
                    small: true,
                    fullWidth: true,
                    onPressed: _addSlide,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppGhostButton(
                    label: '全量重新生成',
                    small: true,
                    fullWidth: true,
                    onPressed: _generatePpt,
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '一键把教案转成分页课件提纲（每页标题/要点/讲稿备注），可逐页编辑后保存。',
                  ),
                ),
                const SizedBox(width: 8),
                AppPrimaryButton(
                  label: _pptLoading ? '生成中…' : '生成课件',
                  small: true,
                  onPressed: _generatePpt,
                ),
              ],
            ),
          if (_pptNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('使用建议：$_pptNotes',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.text3Of(context))),
          ],
        ],
      ),
    );
  }

  // ========= 教案保存 =========
  Future<void> _saveDesign() async {
    setState(() {
      _saving = true;
      _saveStatus = '保存中…';
    });
    final ok = await TeacherService().updateLesson(widget.lessonId, {
      'title': _detail?['title'],
      'department': _detail?['department'],
      'targetGrade': _detail?['targetGrade'],
      'aiDesign': jsonEncode(_design),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveStatus = ok ? '已自动保存' : '保存失败';
    });
  }

  // ========= 语音输入（编辑输入用，实时转文字） =========
  Future<void> _voiceInto(TextEditingController ctrl) async {
    if (_isListening) {
      await _speech?.stop();
      setState(() => _isListening = false);
      return;
    }
    final speech = _speech ??= stt.SpeechToText();
    final available = await speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      AppFeedback.info(context, '当前设备不支持语音输入');
      return;
    }
    setState(() => _isListening = true);
    speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'zh_CN',
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        ctrl.text = result.recognizedWords;
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      },
    );
  }

  // ========= 导出 / 分享 =========
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final res = await TeacherService().exportLesson(widget.lessonId);
      if (!mounted) return;
      if (res == null) {
        AppFeedback.error(context, '导出失败');
        return;
      }
      final url = res['url'] as String? ?? '';
      final filename = res['filename'] as String? ?? '教案.docx';
      if (url.isEmpty) {
        AppFeedback.error(context, '导出失败');
        return;
      }
      // 下载到临时目录
      final dir = await getTemporaryDirectory();
      final file = '${dir.path}/$filename';
      final dio = ApiClient.instance;
      final resp = await dio.get<dynamic>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (resp.data is List<int>) {
        await Future(() => _writeBytes(file, resp.data as List<int>));
      } else {
        if (mounted) AppFeedback.error(context, '下载失败');
        return;
      }
      if (mounted) AppFeedback.success(context, '导出成功');
      // 系统分享面板（选微信/钉钉/保存）
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(file,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        ],
        text: '教案：${_detail?['title'] ?? ''}',
      ));
    } catch (e) {
      debugPrint('export error: $e');
      if (mounted) AppFeedback.error(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _writeBytes(String path, List<int> bytes) async {
    final f = await File(path).create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  // ========= 教案编辑（通用） =========
  Future<void> _editList(String field, String title) async {
    final items = ((_design[field] as List<dynamic>?) ?? const [])
        .map((e) => '$e')
        .toList();
    final result = await _showListEditor(title, items);
    if (result == null) return;
    setState(() => _design[field] = result);
    _saveDesign();
  }

  Future<void> _editText(String field, String title) async {
    final text = '${_design[field] ?? ''}';
    final result = await _showTextEditor(title, text);
    if (result == null) return;
    setState(() => _design[field] = result);
    _saveDesign();
  }

  Future<void> _editOutline() async {
    final list = ((_design['lessonOutline'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final lines = list
        .map((m) =>
            '${m['phase'] ?? ''}（${m['duration'] ?? 0}分钟）：${m['content'] ?? ''}')
        .toList();
    final result = await _showListEditor('教学过程（每行：阶段（分钟）：内容）', lines);
    if (result == null) return;
    final parsed = result.map((line) {
      final m = RegExp(r'^(.*?)（(\d+)分钟）[:：]?(.*)$').firstMatch(line);
      if (m != null) {
        return <String, dynamic>{
          'phase': m.group(1),
          'duration': int.tryParse(m.group(2) ?? '0') ?? 0,
          'content': m.group(3) ?? '',
        };
      }
      return <String, dynamic>{'phase': line, 'duration': 0, 'content': ''};
    }).toList();
    setState(() => _design['lessonOutline'] = parsed);
    _saveDesign();
  }

  Future<void> _editSkillTraining() async {
    final list = ((_design['skillTraining'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final lines = list
        .map((m) =>
            '${m['name'] ?? ''}（${m['duration'] ?? 0}分钟）：${m['description'] ?? ''}')
        .toList();
    final result = await _showListEditor('技能训练（每行：名称（分钟）：说明）', lines);
    if (result == null) return;
    final parsed = result.map((line) {
      final m = RegExp(r'^(.*?)（(\d+)分钟）[:：]?(.*)$').firstMatch(line);
      if (m != null) {
        return <String, dynamic>{
          'name': m.group(1),
          'duration': int.tryParse(m.group(2) ?? '0') ?? 0,
          'description': m.group(3) ?? '',
        };
      }
      return <String, dynamic>{'name': line, 'duration': 0, 'description': ''};
    }).toList();
    setState(() => _design['skillTraining'] = parsed);
    _saveDesign();
  }

  Future<List<String>?> _showListEditor(
      String title, List<String> initial) async {
    final ctrl = TextEditingController();
    final items = List<String>.of(initial);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SerifText(title, fontSize: 15),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: items.asMap().entries.map((e) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.value,
                          style: const TextStyle(fontSize: 12.5, height: 1.4)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17),
                        onPressed: () =>
                            setSheetState(() => items.removeAt(e.key)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '输入新内容后点＋添加',
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide:
                              BorderSide(color: AppColors.ruleOf(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide:
                              BorderSide(color: AppColors.ruleOf(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                              color: AppColors.primaryOf(context), width: 1.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icon(Icons.add_rounded,
                        size: 20, color: AppColors.primaryOf(context)),
                    onPressed: () {
                      final t = ctrl.text.trim();
                      if (t.isEmpty) return;
                      setSheetState(() {
                        items.add(t);
                        ctrl.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppPrimaryButton(
                label: '保存',
                fullWidth: true,
                onPressed: () => Navigator.of(ctx).pop(items),
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }

  Future<String?> _showTextEditor(String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ruleOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SerifText(title, fontSize: 15)),
                GestureDetector(
                  onTap: () => _voiceInto(ctrl),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.vermilionOf(context).withValues(alpha: 0.15)
                          : AppColors.surfaceOf(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      size: 18,
                      color: _isListening
                          ? AppColors.vermilionOf(context)
                          : AppColors.primaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.ruleOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.ruleOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                      color: AppColors.primaryOf(context), width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: '保存',
              fullWidth: true,
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            ),
          ],
        ),
        ),
      ),
    );
    return result;
  }

  // ========= 关联病例（病历大厅引用） =========
  Future<void> _pickCase() async {
    final cases = await TeacherService().getCaseList();
    final raw = ((cases?['records'] as List<dynamic>?) ??
            (cases?['list'] as List<dynamic>?) ??
            const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    if (!mounted) return;
    if (raw.isEmpty) {
      AppFeedback.info(context, '暂无可用病例，请先到「我的病例」创建或从病例广场引用');
      return;
    }
    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.85,
        builder: (ctx, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(child: SerifText('关联病例', fontSize: 17)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.pushNamed(RouteNames.caseMarket);
                    },
                    child: MonoText('去病例广场引用 →',
                        fontSize: 11, color: AppColors.primaryOf(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 16, color: AppColors.ruleOf(context)),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                itemCount: raw.length,
                itemBuilder: (ctx, i) {
                  final c = raw[i];
                  final id = (c['id'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.medical_services_outlined,
                        size: 18, color: AppColors.vermilionOf(context)),
                    title: Text('${c['title'] ?? ''}',
                        style: const TextStyle(fontSize: 13.5)),
                    subtitle: c['department'] != null
                        ? Text('${c['department']}',
                            style: const TextStyle(fontSize: 11))
                        : null,
                    onTap: () async {
                      Navigator.of(ctx).pop(c);
                      final ok =
                          await TeacherService().updateLesson(widget.lessonId, {
                        'title': _detail?['title'],
                        'department': _detail?['department'],
                        'targetGrade': _detail?['targetGrade'],
                        'caseId': id,
                        'caseSource': 1,
                      });
                      if (mounted) {
                        if (ok) {
                          AppFeedback.success(context, '已关联病例');
                          _load();
                        } else {
                          AppFeedback.error(context, '关联失败');
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========= 课件上传 =========
  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'ppt',
        'pptx',
        'mp4',
        'mp3',
        'png',
        'jpg',
        'jpeg'
      ],
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      AppFeedback.error(context, '无法读取文件');
      return;
    }
    final lower = file.name.toLowerCase();
    final type = lower.endsWith('.pdf')
        ? 'pdf'
        : (lower.endsWith('.ppt') || lower.endsWith('.pptx'))
            ? 'ppt'
            : (lower.endsWith('.mp4'))
                ? 'mp4'
                : (lower.endsWith('.mp3'))
                    ? 'mp3'
                    : 'image';
    final res = await TeacherService().uploadMaterial(
      lessonId: widget.lessonId,
      filePath: path,
      title: file.name,
      materialType: type,
    );
    if (!mounted) return;
    if (res != null) {
      AppFeedback.success(context, '资料已上传');
      _load();
    } else {
      AppFeedback.error(context, '上传失败');
    }
  }

  // ========= UI =========
  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: detail?['title'] as String? ?? '教案工作台',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.bprep),
              action: AppIconButton(
                icon: Icon(Icons.ios_share_rounded,
                    size: 18, color: AppColors.primaryOf(context)),
                onPressed: _exporting ? null : _export,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      children: [
                        _buildHeaderCard(detail),
                        const SizedBox(height: 12),
                        _buildDesignCard(),
                        const SizedBox(height: 12),
                        _buildPptCard(),
                        const SizedBox(height: 12),
                        _buildCaseCard(detail),
                        const SizedBox(height: 12),
                        _buildMaterialsCard(detail),
                        const SizedBox(height: 12),
                        _buildExportCard(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic>? detail) {
    final status = (detail?['status'] as num?)?.toInt() ?? 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SerifText(detail?['title'] as String? ?? '未命名教案',
                    fontSize: 16, color: AppColors.textOf(context)),
              ),
              AppChip(
                label: status == 1 ? '已生成教案' : '草稿',
                type: status == 1 ? ChipType.moss : ChipType.amber,
                fontSize: 10,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if ((detail?['department'] as String?)?.isNotEmpty == true)
                MonoText('${detail?['department']}',
                    fontSize: 10.5, color: AppColors.text3Of(context)),
              if ((detail?['targetGrade'] as String?)?.isNotEmpty == true)
                MonoText('${detail?['targetGrade']}',
                    fontSize: 10.5, color: AppColors.text3Of(context)),
            ],
          ),
          const SizedBox(height: 10),
          // 单一入口：进入 AI 对话引导，引导内会确认需求并最终生成教案。
          // 合并掉原先并排的「AI 助手引导备课」+「生成教案」两个重复入口。
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'AI 生成教案',
                  icon: const Icon(Icons.auto_awesome, size: 13),
                  small: true,
                  fullWidth: true,
                  onPressed: () async {
                    await context.pushNamed(RouteNames.bprepGuide,
                        pathParameters: {'id': '${widget.lessonId}'});
                    // 从引导页返回时重新拉取最新的教案内容
                    if (mounted) _load();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesignCard() {
    final hasDesign = _design.isNotEmpty;
    return AppCard(
      borderLeft: hasDesign ? AppColors.primaryOf(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EyebrowText('教案内容')),
              if (hasDesign)
                Row(
                  children: [
                    if (_saveStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _saveStatus == '保存失败'
                                ? AppColors.vermilionOf(context).withValues(alpha: 0.12)
                                : AppColors.mossTintOf(context),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(_saveStatus,
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: _saveStatus == '保存失败'
                                      ? AppColors.vermilionOf(context)
                                      : AppColors.moss)),
                        ),
                      ),
                    if (_saving)
                      const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      AppGhostButton(
                        label: '保存',
                        small: true,
                        onPressed: _saveDesign,
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasDesign)
            Text('尚未生成教案。点上方「AI 生成教案」，AI 会先确认主题/教材/学情/课时等需求，再生成教案。',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text3Of(context)))
          else ...[
            _editableSection('教学目标', _design['teachingObjectives'],
                onEdit: () => _editList('teachingObjectives', '教学目标（每行一条）')),
            _editableSection('教学重点', _design['keyPoints'],
                onEdit: () => _editList('keyPoints', '教学重点（每行一条）')),
            _editableSection('教学难点', _design['keyDifficultPoints'],
                onEdit: () => _editList('keyDifficultPoints', '教学难点（每行一条）')),
            _outlineSection(),
            _editableSection('病例讨论题', _design['caseDiscussion'],
                onEdit: () => _editList('caseDiscussion', '病例讨论题（每行一条）')),
            _skillTrainingSection(),
            _editableSection('SP 问诊设计', _design['spInterviewDesign'],
                onEdit: () =>
                    _editList('spInterviewDesign', 'SP 问诊设计要点（每行一条）')),
            _textSection('板书设计', _design['boardDesign'],
                onEdit: () => _editText('boardDesign', '板书设计')),
            _editableSection('课后作业布置', _design['homeworkSuggestions'],
                onEdit: () => _editList('homeworkSuggestions', '课后作业（每行一条）')),
            _textSection('教学反思', _design['teachingReflection'],
                onEdit: () => _editText('teachingReflection', '教学反思')),
            _refsSection(),
            const AiGeneratedNote(),
          ],
        ],
      ),
    );
  }

  Widget _editableSection(String title, Object? raw,
      {required VoidCallback onEdit}) {
    final items =
        ((raw as List<dynamic>?) ?? const []).map((e) => '$e').toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return _sectionWrap(
        title,
        [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $it',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.text2Of(context))),
            ),
        ],
        onEdit: onEdit);
  }

  Widget _textSection(String title, Object? raw,
      {required VoidCallback onEdit}) {
    final text = '${raw ?? ''}';
    if (text.isEmpty) return const SizedBox.shrink();
    return _sectionWrap(
        title,
        [
          Text(text,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: AppColors.text2Of(context))),
        ],
        onEdit: onEdit);
  }

  Widget _outlineSection() {
    final list = ((_design['lessonOutline'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return _sectionWrap(
        '教学过程',
        [
          for (final m in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '${m['phase'] ?? ''}（${m['duration'] ?? 0}分钟）：${m['content'] ?? ''}',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.text2Of(context)),
              ),
            ),
        ],
        onEdit: _editOutline);
  }

  Widget _skillTrainingSection() {
    final list = ((_design['skillTraining'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return _sectionWrap(
        '技能训练环节',
        [
          for (final m in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '${m['name'] ?? ''}（${m['duration'] ?? 0}分钟）：${m['description'] ?? ''}',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.text2Of(context)),
              ),
            ),
        ],
        onEdit: _editSkillTraining);
  }

  Widget _refsSection() {
    final refs = ((_design['textbookRefs'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final note = '${_design['studentProfileNote'] ?? ''}';
    if (refs.isEmpty && note.isEmpty) return const SizedBox.shrink();
    return _sectionWrap('教材出处 / 学情说明', [
      for (final r in refs)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            '· 《${r['book_name'] ?? ''}》${r['chapter'] ?? ''}${r['page_number'] != null ? '·P${r['page_number']}' : ''}',
            style: TextStyle(fontSize: 11, color: AppColors.text3Of(context)),
          ),
        ),
      if (note.isNotEmpty)
        Text(note,
            style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.amberOf(context))),
    ]);
  }

  Widget _sectionWrap(String title, List<Widget> children,
      {VoidCallback? onEdit}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ruleSoftOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: MonoText(title,
                      fontSize: 10.5, color: AppColors.primaryOf(context))),
              if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 12, color: AppColors.text4Of(context)),
                      const SizedBox(width: 2),
                      MonoText('编辑',
                          fontSize: 10, color: AppColors.text4Of(context)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCaseCard(Map<String, dynamic>? detail) {
    final c = detail?['case'] as Map<String, dynamic>?;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EyebrowText('关联病例')),
              TextButton(
                onPressed: _pickCase,
                child: Text(c == null ? '选择病例' : '更换',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (c != null)
            Row(
              children: [
                Icon(Icons.medical_services_outlined,
                    size: 15, color: AppColors.vermilionOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      '${c['title'] ?? '病例'} · ${c['department'] ?? ''}',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.text2Of(context))),
                ),
              ],
            )
          else
            Text('未关联病例。可从「我的病例」选择，或到病例广场引用后回来设置。',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }

  Widget _buildMaterialsCard(Map<String, dynamic>? detail) {
    final materials = ((detail?['materials'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EyebrowText('课件资料')),
              TextButton(
                onPressed: _pickAndUpload,
                child: const Text('上传', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (materials.isEmpty)
            Text('暂无课件资料。可上传 PDF/PPT/视频/音频，导出教案时一并带上。',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text3Of(context)))
          else
            ...materials.map((m) {
              final type = (m['materialType'] as String?) ?? 'file';
              final (IconData icon, Color color) = switch (type) {
                'pdf' => (Icons.picture_as_pdf_outlined, Colors.redAccent),
                'ppt' || 'pptx' => (
                    Icons.slideshow_outlined,
                    Colors.deepOrange
                  ),
                'mp4' => (Icons.play_circle_outline, Colors.blueAccent),
                'mp3' => (Icons.audio_file_outlined, Colors.purple),
                _ => (Icons.image_outlined, Colors.teal),
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${m['title'] ?? '资料'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.text2Of(context))),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildExportCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.file_download_outlined,
                  size: 16, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              SerifText('导出与分享', fontSize: 13.5),
            ],
          ),
          const SizedBox(height: 10),
          AppPrimaryButton(
            label: _exporting ? '导出中…' : '导出教案并分享',
            fullWidth: true,
            icon: const Icon(Icons.ios_share_rounded, size: 15),
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
    );
  }
}
