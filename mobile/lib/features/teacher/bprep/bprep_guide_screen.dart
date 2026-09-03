import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 对话式备课引导（向导式）
///
/// AI 逐项询问 主题 → 教材 → 学情 → 课时 → 重难点 → 其他，
/// 教师可打字、多选快捷选项、填写其他、上传课件素材，或按住麦克风语音输入。
/// 要素确认齐全后 AI 汇总需求单，一键生成教案；
/// 生成后在本页预览并直接编辑（自动保存 + 语音输入），点「完成」返回工作台。
class BprepGuideScreen extends ConsumerStatefulWidget {
  const BprepGuideScreen({super.key, required this.lessonId});
  final int lessonId;

  @override
  ConsumerState<BprepGuideScreen> createState() => _BprepGuideScreenState();
}

class _Msg {
  _Msg.defaults(this.text, this.options, this.multiSelect) : isUser = false;
  _Msg.user(this.text)
      : isUser = true,
        options = const [],
        multiSelect = false;
  final bool isUser;
  final String text;
  final List<String> options;
  final bool multiSelect;
}

/// 教案可编辑段落格式
enum _Fmt { list, text, outline, skill }

class _EditField {
  _EditField(this.key, this.label, this.fmt, this.hint);
  final String key;
  final String label;
  final _Fmt fmt;
  final String hint;
  late final TextEditingController ctrl;
}

/// 生成教案时的精致加载卡片：图标轻缓浮动 + 三条游走光带 + 错峰呼吸圆点
class _GeneratingCard extends StatefulWidget {
  const _GeneratingCard();
  @override
  State<_GeneratingCard> createState() => _GeneratingCardState();
}

class _GeneratingCardState extends State<_GeneratingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mossTintOf(context),
            AppColors.surfaceOf(context),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.moss.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 轻缓浮动的魔法星（非旋转，避免眩晕）
              AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, _) {
                  final wave = math.sin(_ctrl.value * 2 * math.pi);
                  return Transform.translate(
                    offset: Offset(0, -3 * wave),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.moss.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome_rounded,
                          size: 15, color: AppColors.moss),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              SerifText('AI 正在生成教案', fontSize: 14),
              const Spacer(),
              // 三条游走光带（细进度条）
              SizedBox(
                width: 78,
                height: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (ctx, _) {
                      final t = _ctrl.value;
                      return Stack(
                        children: [
                          Container(color: AppColors.bgOf(context)),
                          // 依次滑过的三道光
                          for (int i = 0; i < 3; i++)
                            Align(
                              alignment: Alignment(
                                  -1 + 2 * ((t * 3 - i) % 1.0), 0),
                              child: FractionallySizedBox(
                                widthFactor: 0.34,
                                heightFactor: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.moss.withValues(alpha: 0),
                                        AppColors.moss,
                                        AppColors.moss.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 错峰呼吸的三个圆点 + 文案
          Row(
            children: [
              Row(
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (ctx, _) {
                        final p =
                            (math.sin(_ctrl.value * 2 * math.pi - i * 2.094) +
                                    1) /
                                2;
                        return Transform.scale(
                          scale: 0.5 + 0.5 * p,
                          child: Opacity(
                            opacity: 0.35 + 0.65 * p,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.moss,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '正在结合教学目标、教材与素材设计教案…',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.text3Of(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 对话推进时的极简打字指示（仅三个小点，避免每次都出现华丽动画）
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.xs),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, _) {
                  final p = (math.sin(_ctrl.value * 2 * math.pi - i * 2.094) +
                          1) /
                      2;
                  return Opacity(
                    opacity: 0.25 + 0.75 * p,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.text3Of(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BprepGuideScreenState extends ConsumerState<BprepGuideScreen> {
  final TeacherService _service = TeacherService();
  final List<_Msg> _messages = [];
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  stt.SpeechToText? _speech;
  String _metaTitle = '';
  String _metaDept = '';
  String _metaGrade = '';
  bool _isListening = false;
  TextEditingController? _activeVoiceCtrl; // 当前正在语音输入的输入框
  bool _sending = false;
  bool _generating = false; // 真正点击「生成教案」时才为 true
  bool _complete = false;
  Map<String, dynamic>? _summary;

  // 多选：当前可多选的那条消息索引 + 已勾选集合
  int? _multiMsgIndex;
  final Set<String> _multiSel = {};
  bool _fillOther = false;

  // 附件上传
  bool _uploading = false;
  final List<String> _uploadedTitles = [];

  // 生成后的教案预览/编辑
  Map<String, dynamic> _design = {};
  bool _generated = false;
  List<_EditField>? _editFields;
  bool _saving = false;
  String _saveStatus = ''; // '' | 保存中… | 已自动保存 | 保存失败
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMeta();
      _ask('');
    });
  }

  /// 拉取备课包当前元信息（标题/科室/年级），自动保存时回传避免被清空
  Future<void> _loadMeta() async {
    final detail = await _service.getLessonDetail(widget.lessonId);
    if (!mounted || detail == null) return;
    setState(() {
      _metaTitle = (detail['title'] as String?) ?? '';
      _metaDept = (detail['department'] as String?) ?? '';
      _metaGrade = (detail['targetGrade'] as String?) ?? '';
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _speech?.stop();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    for (final f in _editFields ?? const <_EditField>[]) {
      f.ctrl.dispose();
    }
    super.dispose();
  }

  // ---------- 引导对话 ----------
  Future<void> _ask(String reply) async {
    if (_sending) return;
    setState(() => _sending = true);
    final result = await _service.guideLesson(widget.lessonId, reply);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result == null) {
        _messages.add(_Msg.defaults('网络或服务暂不可用，请稍后再试。', const [], false));
        return;
      }
      _complete = result['complete'] == true;
      _summary = (result['summary'] as Map<String, dynamic>?) ?? {};
      final question = (result['question'] as String?) ?? '';
      final options = ((result['options'] as List<dynamic>?) ?? const [])
          .map((e) => '$e')
          .toList();
      final multi = result['multiSelect'] == true;
      if (question.isNotEmpty) {
        _messages.add(_Msg.defaults(question, options, multi));
        if (multi && options.isNotEmpty) {
          _multiMsgIndex = _messages.length - 1;
          _multiSel.clear();
        }
      }
      if (_complete) {
        _messages.add(_Msg.defaults('已收集齐备课要素，可以生成教案了。', const [], false));
      }
      _scrollToBottom();
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _fillOther = false;
    setState(() => _messages.add(_Msg.user(text)));
    _scrollToBottom();
    await _ask(text);
  }

  /// 多选提交：把勾选的选项合并成一条回答
  Future<void> _submitMultiSelect() async {
    if (_multiSel.isEmpty) return;
    final joined = _multiSel.join('、');
    _multiSel.clear();
    _multiMsgIndex = null;
    setState(() => _messages.add(_Msg.user(joined)));
    _scrollToBottom();
    await _ask(joined);
  }

  Future<void> _skip() async {
    setState(() => _messages.add(_Msg.user('跳过')));
    _scrollToBottom();
    await _ask('跳过');
  }

  void _onOptionTap(_Msg msg, String opt) {
    if (msg.multiSelect) {
      setState(() {
        if (_multiSel.contains(opt)) {
          _multiSel.remove(opt);
        } else {
          _multiSel.add(opt);
        }
      });
      return;
    }
    setState(() => _messages.add(_Msg.user(opt)));
    _scrollToBottom();
    _fillOther = false;
    _ask(opt);
  }

  void _onFillOther() {
    setState(() {
      _fillOther = true;
      _multiMsgIndex = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => FocusScope.of(context).requestFocus(_inputFocus));
  }

  // ---------- 生成教案 ----------
  Future<void> _generate() async {
    setState(() {
      _sending = true;
      _generating = true;
    });
    final design = await _service.generateLessonDesign(widget.lessonId);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _generating = false;
      _generated = true;
      _design = Map<String, dynamic>.from(design ?? {});
      _saveStatus = '';
    });
    if (design == null) {
      AppFeedback.error(context, '教案生成失败，请重试');
      return;
    }
    _ensureEditFields();
    _saveStatus = '已生成，编辑后自动保存';
    _scrollToBottom();
  }

  // ---------- 教案编辑 + 自动保存 ----------
  void _ensureEditFields() {
    if (_editFields != null) return;
    final fields = <_EditField>[
      _EditField('teachingObjectives', '教学目标', _Fmt.list, '每行一条'),
      _EditField('keyPoints', '教学重点', _Fmt.list, '每行一条'),
      _EditField('keyDifficultPoints', '教学难点', _Fmt.list, '每行一条'),
      _EditField('lessonOutline', '教学过程', _Fmt.outline, '每行：阶段（分钟）：内容'),
      _EditField('caseDiscussion', '病例讨论题', _Fmt.list, '每行一条'),
      _EditField('skillTraining', '技能训练环节', _Fmt.skill, '每行：名称（分钟）：说明'),
      _EditField('spInterviewDesign', 'SP 问诊设计', _Fmt.list, '每行一条'),
      _EditField('boardDesign', '板书设计', _Fmt.text, ''),
      _EditField('homeworkSuggestions', '课后作业布置', _Fmt.list, '每行一条'),
      _EditField('teachingReflection', '教学反思', _Fmt.text, ''),
    ];
    for (final f in fields) {
      f.ctrl = TextEditingController(text: _designToText(f));
    }
    _editFields = fields;
    setState(() {});
  }

  String _designToText(_EditField f) {
    switch (f.fmt) {
      case _Fmt.text:
        return '${_design[f.key] ?? ''}';
      case _Fmt.list:
        return ((_design[f.key] as List<dynamic>?) ?? const [])
            .map((e) => '$e')
            .join('\n');
      case _Fmt.outline:
        return (((_design[f.key] as List<dynamic>?) ?? const [])
                .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return '${m['phase'] ?? ''}（${m['duration'] ?? 0}分钟）：${m['content'] ?? ''}';
        }))
            .join('\n');
      case _Fmt.skill:
        return (((_design[f.key] as List<dynamic>?) ?? const [])
                .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return '${m['name'] ?? ''}（${m['duration'] ?? 0}分钟）：${m['description'] ?? ''}';
        }))
            .join('\n');
    }
  }

  void _onFieldChanged(_EditField f) {
    setState(() => _saveStatus = '保存中…');
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), _doAutoSave);
  }

  Object _parseFieldText(_EditField f) {
    switch (f.fmt) {
      case _Fmt.list:
        return f.ctrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      case _Fmt.text:
        return f.ctrl.text.trim();
      case _Fmt.outline:
        return f.ctrl.text
            .split('\n')
            .where((e) => e.trim().isNotEmpty)
            .map((line) {
          final m =
              RegExp(r'^(.*?)（(\d+)分钟）[:：]?(.*)$').firstMatch(line.trim());
          if (m != null) {
            return <String, dynamic>{
              'phase': m.group(1),
              'duration': int.tryParse(m.group(2) ?? '0') ?? 0,
              'content': m.group(3) ?? '',
            };
          }
          return <String, dynamic>{
            'phase': line.trim(),
            'duration': 0,
            'content': '',
          };
        }).toList();
      case _Fmt.skill:
        return f.ctrl.text
            .split('\n')
            .where((e) => e.trim().isNotEmpty)
            .map((line) {
          final m =
              RegExp(r'^(.*?)（(\d+)分钟）[:：]?(.*)$').firstMatch(line.trim());
          if (m != null) {
            return <String, dynamic>{
              'name': m.group(1),
              'duration': int.tryParse(m.group(2) ?? '0') ?? 0,
              'description': m.group(3) ?? '',
            };
          }
          return <String, dynamic>{
            'name': line.trim(),
            'duration': 0,
            'description': '',
          };
        }).toList();
    }
  }

  Future<void> _doAutoSave() async {
    if (_saving) return;
    _saving = true;
    try {
      for (final f in _editFields ?? const <_EditField>[]) {
        _design[f.key] = _parseFieldText(f);
      }
      final ok = await _service.updateLesson(widget.lessonId, {
        'title': _metaTitle.isNotEmpty ? _metaTitle : (_summary?['topic'] ?? ''),
        'department': _metaDept,
        'targetGrade': _metaGrade,
        'aiDesign': jsonEncode(_design),
      });
      if (!mounted) return;
      setState(() => _saveStatus = ok ? '已自动保存' : '保存失败');
    } finally {
      _saving = false;
    }
  }

  void _finish() {
    _saveTimer?.cancel();
    Future(() => _doAutoSave()).whenComplete(() {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.goNamed(RouteNames.bprepDetail,
            pathParameters: {'id': '${widget.lessonId}'});
      }
    });
  }

  // ---------- 附件上传（复用工作台逻辑） ----------
  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'mp4', 'mp3', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    var uploaded = 0;
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
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
      final id = await _service.uploadMaterial(
        lessonId: widget.lessonId,
        filePath: path,
        title: file.name,
        materialType: type,
      );
      if (id != null) uploaded++;
    }
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (uploaded > 0) _uploadedTitles.add('x$uploaded');
    });
    AppFeedback.success(context, '已上传 $uploaded 个素材，生成教案时将自动识别');
  }

  // ---------- 语音输入（实时转文字，聊条与编辑共用） ----------
  Future<void> _voiceInto(TextEditingController ctrl) async {
    // 再次点击当前正在收听的输入框：停止
    if (_isListening && _activeVoiceCtrl == ctrl) {
      await _speech?.stop();
      setState(() {
        _isListening = false;
        _activeVoiceCtrl = null;
      });
      return;
    }
    // 其他输入框正在收听：先停掉它
    if (_isListening) {
      await _speech?.stop();
      setState(() => _isListening = false);
      _activeVoiceCtrl = null;
    }
    final speech = _speech ??= stt.SpeechToText();
    final available = await speech.initialize(
      onError: (_) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _activeVoiceCtrl = null;
          });
        }
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() {
              _isListening = false;
              _activeVoiceCtrl = null;
            });
          }
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      AppFeedback.info(context, '当前设备不支持语音输入');
      return;
    }
    setState(() {
      _isListening = true;
      _activeVoiceCtrl = ctrl;
    });
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: 'AI 备课助手',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.bprep),
            ),
            Expanded(child: _generated ? _buildEditView() : _buildChatList()),
            if (_generated)
              _buildEditBar()
            else if (_complete)
              _buildGenerateBar()
            else
              _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty && !_sending) {
      return const Center(child: CircularProgressIndicator());
    }
    final hasSummary = _complete;
    // 对话推进与生成教案都处于等待中；仅在真正生成时才展示华丽动画，其余用极简打字指示
    final hasWork = _sending;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: _messages.length + (hasSummary ? 1 : 0) + (hasWork ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < _messages.length) return _buildBubble(_messages[i]);
        // 尾部尾巴：需求单 → 生成动画 / 打字指示
        var idx = i - _messages.length;
        if (hasSummary) {
          if (idx == 0) return _buildSummaryCard();
          idx--;
        }
        return _generating ? const _GeneratingCard() : const _TypingIndicator();
      },
    );
  }

  Widget _buildBubble(_Msg msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: AppColors.primaryOf(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.onPrimaryOf(context)),
          ),
        ),
      );
    }
    final showMultiAction =
        msg.multiSelect && (_multiMsgIndex == (_messages.indexOf(msg)));
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.xs),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.mossTintOf(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.auto_awesome, size: 13, color: AppColors.moss),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // AI 追问文本打字机（公共组件）
                  child: TypewriterText(
                    msg.text,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: AppColors.textOf(context)),
                  ),
                ),
              ],
            ),
            if (msg.options.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.options.map((opt) {
                  final selected = msg.multiSelect && _multiSel.contains(opt);
                  return GestureDetector(
                    onTap: () => _onOptionTap(msg, opt),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.mossTintOf(context)
                            : AppColors.bgOf(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: selected
                              ? AppColors.moss
                              : AppColors.ruleOf(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.multiSelect) ...[
                            Icon(
                              selected
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 15,
                              color: selected
                                  ? AppColors.moss
                                  : AppColors.text4Of(context),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(opt,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryOf(context))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (showMultiAction) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      label: _multiSel.isEmpty
                          ? '请选择选项'
                          : '提交所选（${_multiSel.length}）',
                      small: true,
                      onPressed: _multiSel.isEmpty ? null : _submitMultiSelect,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _onFillOther,
                    child: MonoText('填写其他',
                        fontSize: 11, color: AppColors.primaryOf(context)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final s = _summary ?? {};
    final entries = <(String, Object?)>[
      ('主题', s['topic']),
      ('教材', s['textbook']),
      ('授课班级/学情', s['classInfo']),
      ('课时', s['duration']),
      ('重难点偏好', s['emphasis']),
      ('其他要求', s['extra']),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.amberOf(context).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_rounded, size: 16, color: AppColors.amberOf(context)),
              const SizedBox(width: 6),
              SerifText('备课需求确认单', fontSize: 14),
            ],
          ),
          const SizedBox(height: 8),
          for (final (k, v) in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText(k, fontSize: 10.5, color: AppColors.text4Of(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      v == null || '$v'.isEmpty || '$v' == '待补充' ? '待补充' : '$v',
                      style: TextStyle(
                        fontSize: 12,
                        color: v == null || '$v'.isEmpty || '$v' == '待补充'
                            ? AppColors.vermilionOf(context)
                            : AppColors.textOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 生成后：预览与编辑 ----------
  Widget _buildEditView() {
    _ensureEditFields();
    final fields = _editFields ?? const <_EditField>[];
    final refs = ((_design['textbookRefs'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final note = '${_design['studentProfileNote'] ?? ''}';
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        Row(
          children: [
            const Expanded(child: EyebrowText('教案预览与编辑（自动保存）')),
            _saveStatus.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _saveStatus == '保存失败'
                          ? AppColors.vermilionOf(context).withValues(alpha: 0.12)
                          : AppColors.mossTintOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(_saveStatus,
                        style: TextStyle(
                            fontSize: 10,
                            color: _saveStatus == '保存失败'
                                ? AppColors.vermilionOf(context)
                                : AppColors.moss)),
                  ),
          ],
        ),
        for (final f in fields) ...[
          const SizedBox(height: 12),
          _editFieldCard(f),
        ],
        if (refs.isNotEmpty || note.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EyebrowText('教材出处 / 学情说明'),
                const SizedBox(height: 6),
                for (final r in refs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '· 《${r['book_name'] ?? ''}》${r['chapter'] ?? ''}${r['page_number'] != null ? '·P${r['page_number']}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text3Of(context)),
                    ),
                  ),
                if (note.isNotEmpty)
                  Text(note,
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.amberOf(context))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _editFieldCard(_EditField f) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: MonoText(f.label,
                      fontSize: 10.5, color: AppColors.primaryOf(context))),
              GestureDetector(
                onLongPress: () => _voiceInto(f.ctrl),
                onTap: () => _voiceInto(f.ctrl),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isListening && _activeVoiceCtrl == f.ctrl
                        ? AppColors.vermilionOf(context).withValues(alpha: 0.15)
                        : AppColors.bgOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening && _activeVoiceCtrl == f.ctrl
                        ? Icons.mic
                        : Icons.mic_none_rounded,
                    size: 16,
                    color: _isListening && _activeVoiceCtrl == f.ctrl
                        ? AppColors.vermilionOf(context)
                        : AppColors.primaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: f.ctrl,
            minLines: f.fmt == _Fmt.text ? 2 : 1,
            maxLines: f.fmt == _Fmt.text ? 5 : 8,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
            onChanged: (_) => _onFieldChanged(f),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgOf(context),
              hintText: f.hint,
              isDense: true,
              hintStyle:
                  TextStyle(fontSize: 11.5, color: AppColors.text4Of(context)),
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
          const SizedBox(height: 4),
          MonoText('点上方麦克风可语音输入该字段',
              fontSize: 9.5, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  Widget _buildGenerateBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.ruleSoftOf(context))),
        ),
        child: AppPrimaryButton(
          label: _sending ? '正在生成教案…' : '生成教案',
          fullWidth: true,
          icon: const Icon(Icons.auto_awesome, size: 15),
          onPressed: _sending ? null : _generate,
        ),
      ),
    );
  }

  Widget _buildEditBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.ruleSoftOf(context))),
        ),
        child: AppPrimaryButton(
          label: '完成教案',
          fullWidth: true,
          icon: const Icon(Icons.check_rounded, size: 15),
          onPressed: _finish,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.ruleSoftOf(context))),
        ),
        child: Row(
          children: [
            // 附加上传
            GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.attach_file_rounded,
                        size: 21, color: AppColors.primaryOf(context)),
              ),
            ),
            const SizedBox(width: 2),
            TextButton(
              onPressed: _sending ? null : _skip,
              child: MonoText('跳过',
                  fontSize: 11, color: AppColors.text4Of(context)),
            ),
            const SizedBox(width: 4),
            // 输入框
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.ruleOf(context)),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  style: const TextStyle(fontSize: 13.5),
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: _uploadedTitles.isNotEmpty
                        ? '已上传 ${_uploadedTitles.length} 个素材'
                        : (_fillOther ? '填写其他要求…' : '回答 AI 的问题…'),
                    hintStyle: TextStyle(
                        fontSize: 13, color: AppColors.text4Of(context)),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 麦克风（长按说话，实时转文字）
            GestureDetector(
              onLongPressStart: (_) => _voiceInto(_inputCtrl),
              onLongPressEnd: (_) => _voiceInto(_inputCtrl),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isListening && _activeVoiceCtrl == _inputCtrl
                      ? AppColors.vermilionOf(context)
                      : AppColors.primaryOf(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening && _activeVoiceCtrl == _inputCtrl
                      ? Icons.graphic_eq
                      : Icons.mic_rounded,
                  size: 20,
                  color: AppColors.onPrimaryOf(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 发送
            AppIconButton(
              icon: Icon(Icons.send_rounded,
                  size: 18,
                  color: _sending
                      ? AppColors.text4Of(context)
                      : AppColors.primaryOf(context)),
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}