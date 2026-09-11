import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/media_url.dart';
import '../../../features/common/guide/guide_anchor.dart';
import '../../../features/common/guide/guide_controller.dart';
import '../../../features/common/guide/guide_tours.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_api.dart';
import '../data/student_service.dart';

/// AI 问诊室（SP 病人模拟）
///
/// 交互原则（2026-09-02 训练态收敛）：
/// - 顶部极简：返回 + 患者首字头像 + 患者名 + 状态点 + 结束问诊；
/// - 进程面板只显示「当前阶段 + 进度细线」：训练态不向学生实时推送
///   思维树 / 苏格拉底提示 / 遗漏诊断（防剧透漏诊，AI 侧总闸默认关闭，
///   live_mentor_hint_enabled=false，管理端可热开）；
/// - SP 流式打字机（▌ 光标）：进入页面即主动开场白，回复按 delta 拼装；
/// - 引用来源卡片已下线：SP 回复文案不再带引用编号/书名（AI prompt 约束），
///   若 AI 侧仍推送 citation 事件则直接忽略，不渲染；
/// - 恢复/续聊：复用进行中会话时，先拉取历史消息并插入一条 aside 提示；
/// - 保留问诊核心能力：阶段快捷追问、快捷指令、影像上传、结束问诊（生成报告）。
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with TickerProviderStateMixin {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  // ---- 流式状态 ----
  final List<_Msg> _messages = [];
  final List<_PendingAside> _pending = []; // 待渲染的安全提示 aside
  final List<_ExamReport> _pendingReports = []; // L0/L1 本轮 SP 回复关联的检查报告卡（随回复渲染）
  final List<Map<String, dynamic>> _roundCitations = []; // 本轮 SP 回复的教材引用（随回复渲染，默认隐藏）
  String _streamingText = '';
  String _streamingHint = '';
  bool _streaming = false;
  String? _streamError;

  // ---- 业务状态 ----
  int? _sessionId;
  int? _caseId;
  String _caseTitle = '病例会话';
  String _patientName = '';
  String _patientInitial = '患';
  bool _sessionLoading = true;
  String? _sessionError;
  bool _resumed = false; // 是否复用进行中的历史会话（续聊）

  // ---- 问诊阶段 / 动画 / 结束状态 ----
  String _stage = '主诉采集';
  bool _finishPressed = false;

  // ---- 引用来源（2026-09-03：默认隐藏，左滑托盘「引用」按钮切换显示）----
  bool _showCitations = false;

  // ---- 左滑辅助托盘（提示 / 思维树 / 引用）----
  bool _trayVisible = false;
  Timer? _trayTimer;
  bool _mentorBusy = false; // 正在拉取导师小结（提示/思维树共用一次请求）

  // ---- 空闲提醒（2026-09-03：静默 45s 自动给一次导师提示，不打扰刷屏）----
  Timer? _idleTimer;
  bool _idleHintShown = false;

  // ---- 动画 ----
  late final AnimationController _typing;

  // ---- 流式取消令牌 ----
  CancelToken? _streamCancel;

  // ---- 多模态影像（2026-09-08）：选中→上传→预览→发送调 AI 读图 ----
  XFile? _pickImageFile; // 本地选中的影像文件（即时预览）
  String? _pendingImageUrl; // 上传成功后的服务端 URL
  bool _imageUploading = false; // 正在上传

  @override
  void initState() {
    super.initState();
    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
      // 页面级新手指引：首帧渲染完成后触发（左滑托盘 / 空闲提醒 / 双指缩放）
      ref.read(guideControllerProvider.notifier).schedulePageEnter(
            GuidePageIds.studentChat,
          );
    });
  }

  @override
  void dispose() {
    _streamCancel?.cancel('dispose');
    _trayTimer?.cancel();
    _idleTimer?.cancel();
    _typing.dispose();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─── 数据加载 ─────────────────────────────────────

  void _readRouteIds() {
    final st = GoRouterState.of(context);
    final qs = st.uri.queryParameters;
    _caseId ??= int.tryParse(qs['caseId'] ?? '') ?? _caseId;
    if (_caseId == null && st.extra is Map) {
      final cid = (st.extra as Map)['caseId'];
      if (cid is int) _caseId = cid;
      if (cid is String) _caseId = int.tryParse(cid) ?? _caseId;
    }
    final aid = qs['assignmentInstanceId'];
    if (aid != null) {
      // 不持久化到 state,仅 hint 服务端关联
    }
  }

  Future<void> _initSession() async {
    _readRouteIds();
    if (_caseId == null) {
      setState(() {
        _sessionError = '缺少病例信息，无法开始问诊';
        _sessionLoading = false;
      });
      return;
    }
    setState(() => _sessionLoading = true);
    final result = await StudentService().startSession(
      caseId: _caseId!,
      assignmentInstanceId: null,
      assignmentItemProgressId: null,
    );
    if (!mounted) return;
    setState(() => _sessionLoading = false);
    if (result == null) {
      setState(() => _sessionError = '创建问诊会话失败，请检查网络');
      return;
    }
    _applySessionResult(result);
    // 会话持久化：服务端复用进行中会话时，拉取历史聊天记录继续展示
    if (_resumed && mounted) {
      await _loadResumedHistory();
    }
    // 2026-09-03：会话就绪后启动空闲计时（45s 没开口 → 提醒一次可以左滑要提示）
    _resetIdleTimer();
  }

  void _applySessionResult(Map<String, dynamic> result) {
    final sid = result['sessionId'] as int?;
    if (sid == null) return;
    setState(() {
      _sessionId = sid;
      _resumed = result['resumed'] == true;
      _caseTitle = (result['caseTitle'] as String?) ?? '病例会话';
      _patientName = (result['patientName'] as String?) ?? '';
      _patientInitial = _patientName.isEmpty
          ? '患'
          : _patientName.characters.first;
      _caseId = (result['caseId'] as int?) ?? _caseId;
    });

    // 新会话：注入 SP 开场白流式气泡；续聊会话开场由历史记录承接
    if (_resumed) return;
    final opening = result['openingMessage'] as String?;
    if (opening != null && opening.isNotEmpty) {
      _streamOpening(opening);
    }
  }

  /// 续聊：加载该会话已持久化的历史消息，替换当前空聊天流。
  ///
  /// 2026-09-03：服务端已在会话创建时把 SP 开场白写入历史，且空会话会在 start()
  /// 时废弃重建——续聊历史必然完整，这里静默恢复即可，不再插入「已恢复上次问诊」aside
  /// （那是把"没恢复成功"的观感当成特性提示，反而误导用户以为记录丢了）。
  Future<void> _loadResumedHistory() async {
    final sid = _sessionId;
    if (sid == null) return;
    try {
      final detail = await StudentService().getSessionDetail(sid);
      if (!mounted || detail == null) return;
      final msgs = (detail['messages'] as List<dynamic>?) ?? const [];
      final restored = <_Msg>[];
      for (final raw in msgs) {
        if (raw is! Map) continue;
        final sender = (raw['sender'] as String?)?.toUpperCase() ?? '';
        final content = (raw['content'] as String?)?.trim() ?? '';
        if (content.isEmpty) continue;
        if (sender == 'STUDENT') {
          restored.add(_Msg(role: _Role.student, text: content));
        } else if (sender == 'SP' || sender == 'MENTOR') {
          restored.add(_Msg(role: _Role.patient, text: content));
        }
      }
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(restored);
      });
      _scrollToBottom();
    } catch (_) {
      // 历史加载失败不阻塞问诊
    }
  }

  Future<void> _streamOpening(String text) async {
    if (!mounted) return;
    setState(() {
      _streaming = true;
      _streamingText = '';
      _streamingHint = '患者主动开口…';
    });
    // 模拟打字机动画，按字符节奏分片，最大限度像 ChatGPT
    final chars = text.characters.toList();
    var buf = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (!mounted) return;
      buf.write(chars[i]);
      setState(() => _streamingText = buf.toString());
      _scrollToBottom();
      await Future<void>.delayed(Duration(milliseconds: 18));
    }
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(role: _Role.patient, text: _streamingText));
      _streamingText = '';
      _streaming = false;
      _streamingHint = '';
    });
    _scrollToBottom();
  }

  // ─── 流式发送 ─────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sessionId == null || _streaming) return;
    _ctl.clear();
    _resetIdleTimer();
    setState(() {
      _messages.add(_Msg(role: _Role.student, text: text));
      _streaming = true;
      _streamingText = '';
      _streamingHint = 'SP 正在回复…';
      _streamError = null;
      _pending.clear();
      _roundCitations.clear();
      _pendingReports.clear();
    });
    _scrollToBottom();

    final token = CancelToken();
    _streamCancel = token;
    try {
      await for (final ev in StudentService().chatRoomStream(
        sessionId: _sessionId!,
        message: text,
        cancelToken: token,
      )) {
        if (!mounted || token.isCancelled) return;
        _handleStreamEvent(ev);
      }
      if (!mounted) return;
      // done
      if (_streamingText.trim().isNotEmpty) {
        setState(() {
          _messages.add(_Msg(
              role: _Role.patient,
              text: _streamingText,
              reports: List.of(_pendingReports),
              citations: List.of(_roundCitations)));
          _streamingText = '';
        });
        _pendingReports.clear();
        _roundCitations.clear();
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _streamError = e is DioException ? '网络异常，请重试' : 'AI 问诊服务异常';
        _streaming = false;
        _streamingHint = '';
      });
      return;
    } finally {
      if (_streamCancel == token) _streamCancel = null;
      if (mounted) {
        setState(() => _streaming = false);
      }
    }

    // 收尾渲染 pending（引用 + 导师提示）
    if (!mounted) return;
    setState(() {
      _flushPending();
      _streamingHint = '';
    });
  }

  // ─── 多模态影像（2026-09-08）────────────────────────

  /// 发送分发：存在待发送影像时优先走读图链路，否则走纯文本对话。
  void _onSend() {
    if (_streaming) return;
    if (_pendingImageUrl != null && _pendingImageUrl!.isNotEmpty) {
      _sendImage();
    } else {
      _sendMessage();
    }
  }

  /// 选图 → 上传到后端（返回服务端 URL），期间本地文件即时预览。
  Future<void> _pickAndUploadImage() async {
    if (_streaming || _imageUploading) return;
    // 会话未就绪时静默 return 会让「点了选图没反应」无从解释，这里显式提示一次。
    if (_sessionId == null) {
      AppFeedback.info(context, '问诊会话准备中，请稍候再发送影像');
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      setState(() {
        _pickImageFile = file;
        _imageUploading = true;
      });
      final uploaded = await StudentService().uploadImage(
        sessionId: _sessionId!,
        filePath: file.path,
      );
      if (!mounted) return;
      if (uploaded == null || (uploaded['url'] as String?)?.isEmpty == true) {
        AppFeedback.error(context, '影像上传失败，请重试');
        setState(() {
          _pickImageFile = null;
          _imageUploading = false;
        });
        return;
      }
      setState(() {
        _pendingImageUrl = uploaded['url'] as String;
        _imageUploading = false;
      });
      _scrollToBottom();
    } catch (_) {
      // 取消或读取失败：静默忽略
      if (!mounted) return;
      setState(() {
        _pickImageFile = null;
        _imageUploading = false;
      });
    }
  }

  void _removePendingImage() {
    setState(() {
      _pickImageFile = null;
      _pendingImageUrl = null;
    });
  }

  /// 发送影像：入账学生影像气泡 → 调 AI 读图 → finding 以患者气泡回显；
  /// 触发安全策略或读图降级时以 aside 提示，不中断问诊。
  Future<void> _sendImage() async {
    final url = _pendingImageUrl;
    if (url == null || url.isEmpty || _streaming || _sessionId == null) return;
    final note = _ctl.text.trim();
    _ctl.clear();
    _resetIdleTimer();
    setState(() {
      _messages.add(_Msg(
        role: _Role.student,
        text: note,
        imagePath: _pickImageFile?.path,
      ));
      _pickImageFile = null;
      _pendingImageUrl = null;
      _streaming = true;
      _streamingHint = 'AI 正在读图分析…';
    });
    _scrollToBottom();

    try {
      // 上传接口返回相对路径（/uploads/...），AI 读图要求绝对 HTTP(S) URL，
      // 复用 resolveMediaUrl 拼上公网入口，保证 AI 侧能拉到图片。
      final absUrl = resolveMediaUrl(url);
      final res = await StudentService().analyzeImage(
        sessionId: _sessionId!,
        imageUrl: absUrl,
        studentNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      if (res != null &&
          res['finding'] is String &&
          (res['finding'] as String).trim().isNotEmpty) {
        final finding = res['finding'] as String;
        final degraded = res['degraded'] == true ||
            res['status'] == 'DEGRADED';
        setState(() {
          _messages.add(_Msg(
            role: _Role.patient,
            text: (degraded ? '[读图服务降级] ' : '') + finding,
          ));
          if (res['safetyBlocked'] == true) {
            _pending.add(_PendingAside.socrates('影像内容触发安全策略，已拦截本次分析'));
          }
        });
      } else {
        setState(() {
          _pending.add(_PendingAside.socrates('暂未从影像中读到信息，可重试或换一张图'));
        });
      }
      _flushPending();
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending.add(_PendingAside.socrates('影像分析失败，请稍后重试'));
      });
      _flushPending();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  /// 待发送影像的缩略图预览条：本地即时展示 + 右上角 × 移除。
  Widget _buildPendingImagePreview() {
    final file = _pickImageFile;
    if (file == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(file.path),
              width: 96,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 72,
                color: AppColors.ruleSoftOf(context),
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.text4Of(context)),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: _removePendingImage,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ruleOf(context)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textOf(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStreamEvent(AskStreamEvent ev) {
    switch (ev.event) {
      case 'message':
        final delta = (ev.data['delta'] as String?) ?? '';
        if (delta.isEmpty) return;
        setState(() => _streamingText += delta);
        _scrollToBottom();
        break;
      case 'tree':
        // 训练态不再接收/展示实时思维树（会剧透漏诊）。复盘思维树在结束问诊后
        // 由评分报告页展示。事件保留处理但直接忽略，避免旧数据误渲染。
        break;
      case 'stage':
        final s = (ev.data['stage'] as String?) ?? '';
        if (s.isNotEmpty) setState(() => _stage = s);
        break;
      case 'socrates':
        // 苏格拉底提示属于实时提示，训练态不展示（避免"跟着提示就会看病"）。
        break;
      case 'citation':
        // 2026-09-03 严谨性修复：引用只做「出处溯源」，不再把 RAG 教材配图当
        // 患者影像渲染——此前把 citation 里的 image_key（任意教材章节示意图，
        // 如神经科的"脑袋图"）随 SP 回复拼成"影像资料"条，与病例毫无关联，
        // 造成"开 B 超却看到脑袋图片"的驴唇不对马嘴。影像只来自病例金标准
        // 的检查报告卡（report 事件）。引用文字/书名/页码暂存本轮，SP 回复
        // 落定后挂到消息上，默认隐藏，学生左滑点「引用」才展示出处。
        final list = ev.data['citations'];
        if (list is List) {
          for (final c in list) {
            if (c is! Map) continue;
            final book = (c['book_name'] as String?)?.trim() ?? '';
            final page = (c['page_number'] as num?)?.toInt();
            final snippet = (c['chunk_text'] as String?)?.trim() ?? '';
            if (book.isEmpty) continue;
            final key = '$book|$page';
            if (_roundCitations.any((e) => '${e['book']}|${e['page']}' == key)) {
              continue;
            }
            _roundCitations.add({
              'book': book,
              'chapter': ((c['chapter'] as String?) ?? '').trim(),
              'page': page,
              'snippet': snippet,
            });
          }
        }
        break;
      case 'report':
        // L0/L1 检查报告卡（2026-09-03）：AI 侧规则主路命中病例 preset_exams
        // 预置 result 后下发的结构化报告卡，确定性渲染（ecg/lab/image 三态）。
        // 工具兜底命中（report_exam_result）的 report 也在此分支收集。
        final report = _ExamReport.fromJson(ev.data);
        _pendingReports.add(report);
        break;
      case 'safety':
        if (ev.data['blocked'] == true) {
          _pending.add(
              _PendingAside.socrates('⚠️ 当前提问触发了安全策略，请换个方式问'));
        }
        break;
      case 'error':
        final m = (ev.data['message'] as String?) ?? 'AI 回复失败，请重试';
        setState(() => _streamError = m);
        break;
    }
  }

  void _flushPending() {
    for (final p in _pending) {
      _messages.add(_Msg(
        role: _Role.aside,
        aside: p,
      ));
    }
    _pending.clear();
  }

  // ─── 收尾：结束问诊 ───────────────────────────────

  Future<void> _finishSession() async {
    if (_sessionId == null) return;
    final ok = await AppFeedback.confirm(
      context,
      title: '结束问诊',
      content: '结束后将生成 OSCE 评分报告，本次问诊不可再继续。确认结束？',
      confirmText: '结束问诊',
    );
    if (!ok || !mounted) return;
    setState(() => _finishPressed = true);
    final success = await StudentService().finishSession(_sessionId!);
    if (!mounted) return;
    setState(() => _finishPressed = false);
    if (success) {
      context.pushReplacementNamed(
        RouteNames.osceResult,
        queryParameters: {'sessionId': _sessionId.toString()},
      );
    } else {
      AppFeedback.error(context, '结束问诊失败，请稍后重试');
    }
  }

  // ─── UI ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                AppBackAppBar(
                  title: _caseTitle,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.goNamed(RouteNames.studentHome),
                  action: _buildHeaderAction(),
                ),
                _buildSessionBanner(),
                Expanded(
                  child: GuideTarget(
                    anchor: GuideAnchors.studentChatList,
                    child: GestureDetector(
                      // 2026-09-03：左滑唤出「提示 / 思维树 / 引用」辅助托盘，右滑收起；
                      // 聊天区垂直滚动不受影响（水平位移超过阈值才触发）。
                      onHorizontalDragEnd: (d) => _onChatSwipe(d),
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        children: [
                          for (final m in _messages) _buildMessageBubble(m),
                          if (_streaming) _buildStreamingBubble(),
                          if (_streamError != null) _buildStreamErrorChip(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildInputBar(),
              ],
            ),
            // 左滑辅助托盘（松手 6s 自动隐藏，点按钮立即执行并收起）
            if (_trayVisible) _buildHelpTray(),
            // 空闲微互动（2026-09-04）：45s 没开口在输入框上方浮出圆角胶囊，
            // 带入场上浮 + 反复左滑手势动画；点 × 立即消失。托盘出现时让位。
            if (_idleHintShown && !_trayVisible)
              Positioned(
                left: 16,
                right: 16,
                bottom: 118,
                child: _IdleSwipeHint(
                  onReveal: () {
                    setState(() => _idleHintShown = false);
                    _revealTray();
                  },
                  onDismiss: () => setState(() => _idleHintShown = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 聊天区水平滑动：向左滑（主速度 < -260）唤出托盘；向右滑收起。
  void _onChatSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -260) {
      _revealTray();
    } else if (v > 260 && _trayVisible) {
      _hideTray();
    }
  }

  void _revealTray() {
    if (_sessionId == null || _streaming) return;
    _trayTimer?.cancel();
    setState(() => _trayVisible = true);
    // 松手后自动隐藏：6s 内未操作即收起
    _trayTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _trayVisible = false);
    });
  }

  void _hideTray() {
    _trayTimer?.cancel();
    if (mounted) setState(() => _trayVisible = false);
  }

  /// 左滑辅助托盘：提示 / 思维树 / 引用（居中小圆钮），点按即隐藏。
  Widget _buildHelpTray() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 108,
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                    color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _trayButton(
                    icon: Icons.lightbulb_outline_rounded,
                    label: '提示',
                    color: AppColors.amberOf(context),
                    onTap: _mentorBusy ? null : () => _requestHint(),
                  ),
                  _trayButton(
                    icon: Icons.account_tree_outlined,
                    label: '思维树',
                    color: AppColors.indigoOf(context),
                    onTap: _mentorBusy ? null : () => _openThinkingTree(),
                  ),
                  _trayButton(
                    icon: _showCitations
                        ? Icons.format_quote_rounded
                        : Icons.format_quote_outlined,
                    label: _showCitations ? '收起引用' : '引用',
                    color: _showCitations
                        ? AppColors.primaryOf(context)
                        : AppColors.text3Of(context),
                    onTap: _mentorBusy ? null : () => _toggleCitations(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trayButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: onTap == null ? AppColors.text4Of(context) : color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: onTap == null ? AppColors.text4Of(context) : color)),
          ],
        ),
      ),
    );
  }

  /// 「提示」：按需生成苏格拉底提示，以 aside 气泡展示（隐藏式，不刷屏）。
  Future<void> _requestHint() async {
    final sid = _sessionId;
    if (sid == null) return;
    _hideTray();
    setState(() => _mentorBusy = true);
    try {
      final data = await StudentService().getSessionMentor(sid);
      if (!mounted) return;
      final hint = data?['socratesHint'] as String?;
      if (hint == null || hint.trim().isEmpty) {
        if (mounted) AppFeedback.info(context, '导师暂无额外提示，先描述一下最困扰您的症状吧');
        return;
      }
      setState(() {
        _messages.add(_Msg(
            role: _Role.aside,
            aside: _PendingAside.socrates('💡 $hint')));
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _mentorBusy = false);
    }
  }

  /// 「思维树」：按需生成当前会话思维树，底部抽屉展示。
  Future<void> _openThinkingTree() async {
    final sid = _sessionId;
    if (sid == null) return;
    _hideTray();
    setState(() => _mentorBusy = true);
    try {
      final data = await StudentService().getSessionMentor(sid);
      if (!mounted || data == null) {
        if (mounted) AppFeedback.info(context, '思维树生成失败，请稍后再试');
        return;
      }
      final nodes = (data['nodes'] as List<dynamic>?) ?? const [];
      final edges = (data['edges'] as List<dynamic>?) ?? const [];
      if (nodes.isEmpty) {
        if (mounted) AppFeedback.info(context, '尚未积累足够的问诊信息，再问问患者试试');
        return;
      }
      if (!mounted) return;
      await _showTreeSheet(nodes, edges);
    } finally {
      if (mounted) setState(() => _mentorBusy = false);
    }
  }

  Future<void> _showTreeSheet(List<dynamic> nodes, List<dynamic> edges) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ThinkingTreeSheet(
        nodes: nodes,
        edges: edges,
        sessionStage: _stage,
      ),
    );
  }

  /// 「引用」：切换展示/隐藏各 SP 消息下的出处来源。
  void _toggleCitations() {
    _hideTray();
    final hasAny = _messages.any((m) => m.citations.isNotEmpty);
    if (!_showCitations && !hasAny) {
      AppFeedback.info(context, '当前对话暂无教材出处引用');
      return;
    }
    setState(() => _showCitations = !_showCitations);
  }

  Widget? _buildHeaderAction() {
    return GestureDetector(
      onTap: _finishPressed ? null : _finishSession,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.vermilionSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded,
                size: 13, color: AppColors.vermilionOf(context)),
            const SizedBox(width: 4),
            Text(
              _finishPressed ? '收尾中…' : '结束问诊',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.vermilionOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionBanner() {
    if (_sessionLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: AppColors.surfaceOf(context),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryOf(context)),
              ),
            ),
            const SizedBox(width: 8),
            Text('正在创建问诊会话…',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
          ],
        ),
      );
    }
    if (_sessionError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: AppColors.vermilionSoftOf(context),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_sessionError!,
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
            GestureDetector(
              onTap: _initSession,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text('重试',
                    style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 流式错误提示 chip：AI 出错 / 网络异常时给可见反馈，点击关闭，下次发送自动清除。
  Widget _buildStreamErrorChip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 40, right: 40),
      child: GestureDetector(
        onTap: () => setState(() => _streamError = null),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.vermilionSoftOf(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline,
                  size: 12, color: AppColors.vermilionOf(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_streamError ?? '',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.vermilionOf(context))),
              ),
              Icon(Icons.close,
                  size: 12, color: AppColors.vermilionOf(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 消息气泡 ────────────────────────────────────

  Widget _buildMessageBubble(_Msg m) {
    if (m.role == _Role.aside) return _buildAsideBubble(m.aside!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: m.role == _Role.student
          ? _buildStudentBubble(m.text, imagePath: m.imagePath)
          : _buildPatientBubble(m.text,
              reports: m.reports, citations: m.citations),
    );
  }

  /// 患者气泡：左侧带首字头像（宋体圆角），右侧 chat-style 气泡。
  /// 流式打字机由 _buildStreamingBubble 接管；本函数用于已稳定的入账消息。
  /// [reports] 为本轮 L0/L1 检查报告卡，按 AI 中台下发的 kind（ecg/lab/image）
  /// 确定性渲染：数据完全来自病例 preset_exams 预置 result，零幻觉。
  /// [citations] 为本轮教材出处（book/page），默认隐藏，「引用」按钮切换显示。
  Widget _buildPatientBubble(String text,
      {List<_ExamReport> reports = const [],
      List<Map<String, dynamic>> citations = const []}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _patientAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_patientName.isEmpty ? '患者' : _patientName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text2Of(context))),
                  const SizedBox(width: 6),
                  Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.text4Of(context), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('SP 模拟 · 临床一致性已校验',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.text4Of(context))),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(2),
                    topRight: const Radius.circular(14),
                    bottomRight: const Radius.circular(14),
                    bottomLeft: const Radius.circular(14),
                  ),
                  boxShadow: AppShadow.card(context),
                ),
                child: Text(text,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textOf(context),
                      height: 1.6,
                    )),
              ),
              if (reports.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildReportCards(reports),
              ],
              if (_showCitations && citations.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildCitationTags(citations),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 出处来源标签（2026-09-03）：默认隐藏，左滑托盘「引用」开启后逐条展示
  /// 《教材》+ 页码；点标签看原文片段。让 AI 回答可溯源、够严谨。
  Widget _buildCitationTags(List<Map<String, dynamic>> citations) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.primaryOf(context).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 12, color: AppColors.primaryOf(context)),
              const SizedBox(width: 4),
              Text('回答依据 · 教材出处',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOf(context),
                      letterSpacing: 0.05)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in citations)
                GestureDetector(
                  onTap: () => _showCitationDetail(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.surfaceEdgeOf(context)
                              .withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      _citationLabel(c),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.text2Of(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _citationLabel(Map<String, dynamic> c) {
    final book = (c['book'] as String?) ?? '';
    final chapter = (c['chapter'] as String?) ?? '';
    final page = c['page'];
    final pageTxt = page is num && page > 0 ? ' · P$page' : '';
    if (book.isEmpty) return chapter;
    return '《$book》$pageTxt';
  }

  void _showCitationDetail(Map<String, dynamic> c) {
    final book = (c['book'] as String?) ?? '';
    final chapter = (c['chapter'] as String?) ?? '';
    final page = c['page'];
    final snippet = (c['snippet'] as String?) ?? '';
    final pageTxt = page is num && page > 0 ? '第 $page 页' : '';
    final title = <String>[if (book.isNotEmpty) '《$book》', if (chapter.isNotEmpty) chapter, if (pageTxt.isNotEmpty) pageTxt].join(' · ');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(ctx),
        title: Text(title.isEmpty ? '教材出处' : title,
            style: TextStyle(fontSize: 15, color: AppColors.textOf(ctx))),
        content: Text(
          snippet.isEmpty ? '（该出处暂无摘录片段）' : snippet,
          style: TextStyle(
              fontSize: 13, color: AppColors.text2Of(ctx), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// L0/L1 检查报告卡：每张卡片按 kind 渲染（ecg/lab/image）。报告卡数据来自
  /// 病例预置 result（金标准），前端只做确定性渲染，零编造。
  Widget _buildReportCards(List<_ExamReport> reports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_outlined, size: 12, color: AppColors.text3Of(context)),
            const SizedBox(width: 4),
            Text('检查报告',
                style: TextStyle(
                    fontSize: 10, color: AppColors.text3Of(context), letterSpacing: 0.06)),
          ],
        ),
        const SizedBox(height: 6),
        for (final r in reports) ...[
          _buildReportCard(r),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildReportCard(_ExamReport r) {
    final kindLabel = switch (r.kind) {
      'ecg' => '心电图',
      'lab' => '化验',
      'image' => '影像',
      _ => '报告',
    };
    final kindIcon = switch (r.kind) {
      'ecg' => Icons.monitor_heart_outlined,
      'lab' => Icons.science_outlined,
      'image' => Icons.image_outlined,
      _ => Icons.description_outlined,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kindIcon, size: 14, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r.examName.isEmpty ? '检查报告' : r.examName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryOf(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(kindLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primaryOf(context),
                      letterSpacing: 0.05,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (r.kind == 'ecg') _buildEcgBody(r),
          if (r.kind == 'lab') _buildLabBody(r),
          if (r.kind == 'image') _buildImageBody(r),
          if (r.kind != 'ecg' && r.kind != 'lab' && r.kind != 'image' && r.conclusion.isNotEmpty)
            Text(r.conclusion,
                style: TextStyle(fontSize: 13, color: AppColors.textOf(context), height: 1.55)),
          if (r.imageKeys.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildImageStrip(r.imageKeys),
          ],
          if (r.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPatientImageStrip(r.imageUrls),
          ],
        ],
      ),
    );
  }

  /// 患者影像条：教师上传的自备素材（患者本人的 X 光/CT/报告单照片），点击全屏
  Widget _buildPatientImageStrip(List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.personal_injury_outlined,
                size: 12, color: AppColors.text3Of(context)),
            const SizedBox(width: 4),
            Text('患者影像资料',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.text3Of(context),
                    letterSpacing: 0.06)),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < urls.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showFullScreenImage(urls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      resolveMediaUrl(urls[i]),
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 90,
                        color: AppColors.ruleSoftOf(context),
                        child: Icon(Icons.broken_image_outlined,
                            size: 20, color: AppColors.text4Of(context)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 心电图报告卡主体：心率/节律元数据 + 结论文字。
  /// 波形 L0 模板按 ecg.pattern 选样式（本版只标"已自动判读"+心率元数据，
  /// 真实导联判读交给结论文字 + imageKeys 教材配图，避免误画误导）。
  Widget _buildEcgBody(_ExamReport r) {
    final ecg = r.ecg ?? const {};
    final rate = ecg['rate'];
    final rhythm = ecg['rhythm'];
    final pattern = ecg['pattern'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (rate is num)
              _metaChip('心率', '${rate.toInt()} bpm'),
            if (rhythm is String && rhythm.isNotEmpty)
              _metaChip('节律', rhythm == 'sinus' ? '窦性' : rhythm),
            if (pattern is String && pattern.isNotEmpty)
              _metaChip('特征', _ecgPatternLabel(pattern)),
          ],
        ),
        if (r.conclusion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(r.conclusion,
              style: TextStyle(fontSize: 13, color: AppColors.textOf(context), height: 1.55)),
        ],
      ],
    );
  }

  String _ecgPatternLabel(String pattern) => switch (pattern) {
        'st_elev_inferior' => '下壁 ST 抬高',
        'st_elev_anterior' => '前壁 ST 抬高',
        'st_depression' => 'ST 段压低',
        'normal' => '正常',
        _ => pattern,
      };

  Widget _metaChip(String k, String v) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$k ', style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
      Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
    ]);
  }

  /// 化验报告卡主体：每行 item + value+unit + ref + 异常标色（flag=H/L 标红/蓝）。
  Widget _buildLabBody(_ExamReport r) {
    if (r.table.isEmpty) {
      if (r.conclusion.isNotEmpty) {
        return Text(r.conclusion,
            style: TextStyle(fontSize: 13, color: AppColors.textOf(context), height: 1.55));
      }
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in r.table) ...[
          _buildLabRow(row),
          const SizedBox(height: 4),
        ],
        if (r.conclusion.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(r.conclusion,
              style: TextStyle(fontSize: 12, color: AppColors.text2Of(context), height: 1.5)),
        ],
      ],
    );
  }

  Widget _buildLabRow(Map<String, dynamic> row) {
    final item = (row['item'] as String?) ?? '';
    final value = row['value']?.toString() ?? '';
    final unit = (row['unit'] as String?) ?? '';
    final ref = (row['ref'] as String?) ?? '';
    final flag = (row['flag'] as String?) ?? '';
    final abnormal = flag == 'H' || flag == 'L' || flag == '↑' || flag == '↓';
    final flagColor = flag == 'H' || flag == '↑'
        ? const Color(0xFFD64545)  // 偏高·红
        : flag == 'L' || flag == '↓'
            ? const Color(0xFF3B6FB7)  // 偏低·蓝
            : AppColors.text3Of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: abnormal
            ? flagColor.withValues(alpha: 0.06)
            : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: abnormal ? flagColor.withValues(alpha: 0.35) : AppColors.surfaceEdgeOf(context).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(item,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textOf(context),
                  fontWeight: abnormal ? FontWeight.w600 : FontWeight.w400,
                )),
          ),
          Text('$value${unit.isEmpty ? '' : ' $unit'}',
              style: TextStyle(
                fontSize: 12,
                color: flagColor,
                fontWeight: abnormal ? FontWeight.w700 : FontWeight.w500,
              )),
          if (flag.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: flagColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(flag,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: flagColor)),
            ),
          ],
          if (ref.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text('参考 $ref',
                style: TextStyle(fontSize: 10, color: AppColors.text4Of(context))),
          ],
        ],
      ),
    );
  }

  /// 影像报告卡主体：报告所见/结论（教科书式叙述）。
  Widget _buildImageBody(_ExamReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('报告所见',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.text3Of(context),
              letterSpacing: 0.05,
            )),
        const SizedBox(height: 4),
        Text(r.conclusion,
            style: TextStyle(fontSize: 13, color: AppColors.textOf(context), height: 1.55)),
      ],
    );
  }

  /// 全屏查看患者影像：黑幕 + 手势缩放，点击关闭
  void _showFullScreenImage(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dialogCtx) => GestureDetector(
        onTap: () => Navigator.of(dialogCtx).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    maxScale: 6,
                    child: Center(
                      child: Image.network(
                        resolveMediaUrl(url),
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70),
                              const SizedBox(height: 10),
                              Text('图片加载中…',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7))),
                            ],
                          );
                        },
                        errorBuilder: (_, __, ___) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined,
                                size: 44, color: Colors.white38),
                            const SizedBox(height: 10),
                            Text('图片加载失败，请检查网络后重试',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.75))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: Icon(Icons.close_rounded,
                      size: 26,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 检查报告卡配图条：仅用于病例预置报告（preset_exams 金标准）内的教材配图，
  /// 横向滚动小图，点击全屏。不再用于 RAG citation 的 image_key（2026-09-03：
  /// 那会把无关章节示意图当患者影像展示，导致"开 B 超看到脑袋图"）。
  Widget _buildImageStrip(List<String> keys) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_outlined, size: 12, color: AppColors.text3Of(context)),
            const SizedBox(width: 4),
            Text('报告配图',
                style: TextStyle(
                    fontSize: 10, color: AppColors.text3Of(context),
                    letterSpacing: 0.06)),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < keys.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _KnowledgeImage(imageKey: keys[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentBubble(String text, {String? imagePath}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryOf(context),
                  AppColors.primaryOf(context).withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(2),
                bottomRight: const Radius.circular(14),
                bottomLeft: const Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOf(context).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(imagePath),
                      width: 176,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 176,
                        height: 96,
                        color: Colors.black.withValues(alpha: 0.25),
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.white70),
                      ),
                    ),
                  ),
                  if (text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (text.isNotEmpty)
                  Text(text,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onPrimaryOf(context),
                        height: 1.6,
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _studentAvatar(),
      ],
    );
  }

  Widget _patientAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryOf(context).withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(_patientInitial,
          style: TextStyle(
            fontFamily: 'NotoSerifSC',
            fontFamilyFallback: const [
              'Songti SC', 'STSong',
              'Noto Serif CJK SC', 'Source Han Serif SC',
            ],
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.primaryOf(context),
          )),
    );
  }

  Widget _studentAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.6)),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.medical_services,
          size: 16, color: AppColors.text2Of(context)),
    );
  }

  /// aside 气泡（引用 / 苏格拉底提示 / 视觉提示等），用低调灰色 chip 风格。
  Widget _buildAsideBubble(_PendingAside p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 40, right: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.amberSoftOf(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline,
                size: 12, color: AppColors.amberOf(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                // 注意：socrates 类 aside 的 payload 为 null（文案在 hint 里），
                // 不能用 payload!，否则导师提示一到就抛空指针把整页打崩。
                p.text,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.text2Of(context),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _patientAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_patientName.isEmpty ? '患者' : _patientName,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2Of(context))),
                    const SizedBox(width: 6),
                    Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.text4Of(context), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_streamingHint.isEmpty ? '正在打字…' : _streamingHint,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryOf(context))),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    boxShadow: AppShadow.card(context),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _streamingText.isEmpty ? ' ' : _streamingText,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textOf(context),
                            height: 1.6,
                          ),
                        ),
                        TextSpan(
                          text: '▌',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryOf(context),
                              fontWeight: FontWeight.w300),
                        ),
                      ],
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

  // ─── 输入栏 ─────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
            top: BorderSide(color: AppColors.ruleOf(context).withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 当前阶段小签 + 阶段快捷操作（阶段信息从横幅挪到这里，2026-09-03）
            Row(
              children: [
                _buildStagePill(),
                const SizedBox(width: 8),
                Expanded(child: _buildStageChips()),
              ],
            ),
            const SizedBox(height: 6),
            // 待发送影像预览（多模态，2026-09-08）
            if (_pickImageFile != null && _pendingImageUrl != null) ...[
              _buildPendingImagePreview(),
              const SizedBox(height: 6),
            ],
            // 一体化输入容器
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgOf(context),
                border: Border.all(
                    color: AppColors.ruleOf(context).withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: (_streaming || _imageUploading)
                        ? null
                        : _pickAndUploadImage,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _imageUploading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.text3Of(context),
                              ),
                            )
                          : Icon(Icons.add_photo_alternate_outlined,
                              size: 20, color: AppColors.text3Of(context)),
                    ),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40, maxHeight: 100),
                      child: TextField(
                        controller: _ctl,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style:
                            TextStyle(fontSize: 14, color: AppColors.textOf(context)),
                        decoration: InputDecoration(
                          hintText: '和患者对话·指挥问诊…',
                          hintStyle: TextStyle(
                              fontSize: 13.5, color: AppColors.text4Of(context)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _onSend(),
                      ),
                    ),
                  ),
                  GestureDetector(
                    // 必须走 _onSend 分发：存在待发送影像时要转 _sendImage 读取图链路。
                    // 此前直接绑 _sendMessage，而 _sendMessage 在 text 为空时直接 return，
                    // 于是「只选图不打字 → 点发送毫无反应」「带字发图 → 只发文字、图片永远
                    // 卡在待发送区」，即用户反馈的『多模态图片发不出去』（2026-09-11 修复）。
                    onTap: _streaming ? null : _onSend,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.all(4),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _streaming
                            ? AppColors.text4Of(context)
                            : AppColors.primaryOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _streaming ? Icons.hourglass_top : Icons.arrow_upward,
                        size: 16,
                        color: AppColors.onPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前问诊阶段小签：静默替换被删掉的横幅，让用户始终知道问到哪一步。
  Widget _buildStagePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
            color: AppColors.primaryOf(context).withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 11, color: AppColors.primaryOf(context)),
          const SizedBox(width: 4),
          Text(_stage,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOf(context),
              )),
        ],
      ),
    );
  }

  Widget _buildStageChips() {
    final chips = _stageChips();
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final label = chips[i];
          return GestureDetector(
            onTap: _streaming ? null : () {
              _ctl.text = label;
              _ctl.selection = TextSelection.fromPosition(
                  TextPosition(offset: label.length));
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryOf(context).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                    color: AppColors.primaryOf(context).withValues(alpha: 0.25)),
              ),
              alignment: Alignment.center,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryOf(context),
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  List<String> _stageChips() {
    if (_stage.contains('治疗')) {
      return const ['开药处方', '打吊针治疗', '建议手术', '收住院'];
    }
    if (_stage.contains('诊断')) {
      return const ['开立检查以便确诊', '给出初步诊断'];
    }
    if (_stage.contains('辅助检查')) {
      return const ['开血常规化验', '做心电图', '拍胸片/CT'];
    }
    if (_stage.contains('查体')) {
      return const ['测血压/心率', '听诊心肺'];
    }
    return const ['继续追问', '既往史', '过敏史'];
  }

  // ─── 空闲提醒（2026-09-03）────────────────────────

  /// 发送/恢复对话后重置空闲计时：45s 未开口才触发一次引导提示。
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!mounted || _sessionId == null || _streaming) return;
    _idleTimer = Timer(const Duration(seconds: 45), _onIdleTimeout);
  }

  void _onIdleTimeout() {
    if (!mounted) return;
    if (_sessionId == null || _streaming) return;
    // 一次性：本次会话只提醒一次，避免反复打扰
    if (_idleHintShown) return;
    // 微互动（2026-09-04）：仅浮出胶囊教用户「左滑唤出」，不再自动拉出托盘，
    // 让手势本身有存在感；点击胶囊即可直接唤出托盘（见 _IdleSwipeHint）。
    setState(() => _idleHintShown = true);
  }

  void _onScroll() {
    // placeholder; 预留（如未来加"未读到底"小红点）
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ────────────────────────────────────────────────────────────
// 私有类型
// ────────────────────────────────────────────────────────────

enum _Role { student, patient, aside }

/// 检查报告卡数据（AI 中台 SSE `report` 事件 payload，2026-09-03 L0/L1 重构）。
///
/// 由 consultation_graph.exam_dispatch 节点在学生开检查时按病例 presetExams
/// 预置 result 确定性下发，**不靠 LLM 现场生成**。三种 kind 各自带不同子结构：
///   - ecg：心电图（心率 + 结论 + 可选教材配图 imageKeys）
///   - lab：化验（表格行 + 结论）
///   - image：影像（报告所见 + 结论 + 可选配图）
class _ExamReport {
  final String examName;
  final String kind; // 'ecg' | 'lab' | 'image' | 'text'
  final String conclusion;
  final Map<String, dynamic>? ecg; // pattern / rate / rhythm
  final List<Map<String, dynamic>> table; // lab rows
  final List<String> imageKeys; // 教材配图（多 kind 通用）
  final List<String> imageUrls; // 教师上传的患者影像（URL 直连，多 kind 通用）

  const _ExamReport({
    required this.examName,
    required this.kind,
    required this.conclusion,
    this.ecg,
    this.table = const [],
    this.imageKeys = const [],
    this.imageUrls = const [],
  });

  factory _ExamReport.fromJson(Map<String, dynamic> data) {
    final ecg = data['ecg'];
    final rawTable = data['table'];
    final rawKeys = data['imageKeys'];
    final rawUrls = data['imageUrls'];
    return _ExamReport(
      examName: (data['examName'] as String?) ?? '',
      kind: (data['kind'] as String?) ?? 'text',
      conclusion: (data['conclusion'] as String?) ?? '',
      ecg: ecg is Map<String, dynamic> ? ecg : null,
      table: rawTable is List
          ? rawTable.whereType<Map<String, dynamic>>().toList(growable: false)
          : const [],
      imageKeys: rawKeys is List
          ? rawKeys.whereType<String>().toList(growable: false)
          : const [],
      imageUrls: rawUrls is List
          ? rawUrls.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

class _Msg {
  final _Role role;
  final String text;
  final _PendingAside? aside;
  final List<_ExamReport> reports; // L0/L1 检查报告卡（仅 SP 消息携带，随气泡渲染）
  final List<Map<String, dynamic>> citations; // 本轮教材出处（book/chapter/page/snippet）
  final String? imagePath; // 学生上传的多模态影像（本地路径，仅学生消息携带，即时预览）

  _Msg({
    required this.role,
    this.text = '',
    this.aside,
    this.reports = const [],
    this.citations = const [],
    this.imagePath,
  }) : assert(role != _Role.aside || aside != null,
            'aside 消息必须携带 aside');
}

class _PendingAside {
  final String hint;
  _PendingAside.socrates(this.hint);

  // 给 _buildAsideBubble 的便捷访问
  String get text => hint;
}

/// #5 教材配图组件：带 JWT 从后端取图（后端代理 AI 中台 /images/{key}），
/// 随 SP 回复以小图渲染，点击全屏缩放查看。
///
/// image_key 形如 `bl00020_0012_3.png`（无路径分隔符），可直接拼入 URL；
/// 取图链路：mobile → GET /api/v1/knowledge/images/{key}（Bearer JWT）
///         → backend 代理 → AI GET /images/{key} → 本地文件字节。
class _KnowledgeImage extends StatefulWidget {
  const _KnowledgeImage({required this.imageKey});

  /// RAG citation 里的 image_key
  final String imageKey;

  @override
  State<_KnowledgeImage> createState() => _KnowledgeImageState();
}

class _KnowledgeImageState extends State<_KnowledgeImage> {
  static const double _thumbW = 128;
  static const double _thumbH = 96;

  Map<String, String>? _headers; // null = token 尚未就绪
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _resolveToken();
  }

  /// 异步取 JWT；失败/为空则降级为不带鉴权请求（由后端 401 语义兜底）。
  Future<void> _resolveToken() async {
    String? token;
    try {
      token = await ApiClient.readAccessToken();
    } catch (_) {
      token = null;
    }
    if (!mounted) return;
    setState(() {
      _headers = (token == null || token.isEmpty)
          ? const {}
          : {'Authorization': 'Bearer $token'};
      _ready = true;
    });
  }

  String get _url => '${AppConstants.apiBaseUrl}/api/v1/knowledge/images/'
      '${Uri.encodeComponent(widget.imageKey)}';

  Widget _buildImage(BoxFit fit, {double? width, double? height}) {
    if (!_ready) return _loadingBox(width: width, height: height);
    return Image.network(
      _url,
      headers: _headers,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _loadingBox(width: width, height: height),
      errorBuilder: (context, error, stack) =>
          _errorBox(width: width, height: height),
    );
  }

  Widget _loadingBox({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceEdgeOf(context).withValues(alpha: 0.35),
            AppColors.surfaceEdgeOf(context).withValues(alpha: 0.15),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryOf(context),
        ),
      ),
    );
  }

  Widget _errorBox({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 22, color: AppColors.text3Of(context)),
          const SizedBox(height: 4),
          Text('影像不可用',
              style: TextStyle(fontSize: 10, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openViewer,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildImage(BoxFit.cover, width: _thumbW, height: _thumbH),
      ),
    );
  }

  /// 全屏查看：黑幕 + 手势缩放（InteractiveViewer），右上角关闭。
  void _openViewer() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (dialogCtx) {
        final mq = MediaQuery.of(dialogCtx);
        final viewW = mq.size.width - 48.0;
        final viewH = (mq.size.height - 220.0).clamp(160.0, double.infinity);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Center(
                    child: _buildImage(BoxFit.contain,
                        width: viewW, height: viewH),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogCtx).pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// 思维树抽屉（2026-09-03）：训练态不实时推送，改为按需生成展示
// ────────────────────────────────────────────────────────────

/// 按需思维树底部抽屉：把 mentor 节点（symptom/history/exam/diagnosis/...）按
/// edges 依赖渲染成缩进树；无 edges 时按类型分组平铺。只读展示，不剧透诊断结论
/// 之外的内容——socrates 提示已由「提示」按钮独立下发。
class _ThinkingTreeSheet extends StatefulWidget {
  const _ThinkingTreeSheet({
    required this.nodes,
    required this.edges,
    required this.sessionStage,
  });

  final List<dynamic> nodes;
  final List<dynamic> edges;
  final String sessionStage;

  @override
  State<_ThinkingTreeSheet> createState() => _ThinkingTreeSheetState();
}

class _ThinkingTreeSheetState extends State<_ThinkingTreeSheet> {
  static const _typeOrder = ['symptom', 'history', 'exam', 'diagnosis', 'treatment', 'cost'];
  static const _typeLabels = <String, String>{
    'symptom': '症状',
    'history': '病史',
    'exam': '检查',
    'diagnosis': '诊断',
    'treatment': '治疗',
    'cost': '费用',
  };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final items = widget.nodes.whereType<Map>().cast<Map<String, dynamic>>().toList();
    final childrenOf = <String, List<Map<String, dynamic>>>{};
    final hasParent = <String>{};
    for (final raw in widget.edges.whereType<Map>()) {
      final from = raw['from']?.toString();
      final to = raw['to']?.toString();
      if (from == null || to == null) continue;
      hasParent.add(to);
      childrenOf.putIfAbsent(from, () => []).add(items.firstWhere(
          (n) => n['id']?.toString() == to,
          orElse: () => const <String, dynamic>{}));
    }
    final roots = items.where((n) => !hasParent.contains(n['id']?.toString())).toList();
    final ordered = _sortByType(items);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.72),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ruleOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.indigoOf(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.account_tree_outlined,
                        size: 18, color: AppColors.indigoOf(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('临床思维树',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textOf(context))),
                        const SizedBox(height: 2),
                        Text('按您已问到的内容实时梳理 · 当前「${widget.sessionStage}」',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.text3Of(context))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.ruleSoftOf(context),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.text3Of(context)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: roots.isEmpty
                    ? _buildFlatList(ordered)
                    : _buildTree(roots, childrenOf, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortByType(List<Map<String, dynamic>> items) {
    int rank(Map<String, dynamic> n) {
      final t = (n['type'] as String?) ?? '';
      final i = _typeOrder.indexOf(t);
      return i < 0 ? _typeOrder.length : i;
    }

    return [...items]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// edges 不全/缺失时：按类型分组平铺，保证永远有可读输出。
  Widget _buildFlatList(List<Map<String, dynamic>> ordered) {
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final n in ordered) {
      final t = (n['type'] as String?) ?? '其他';
      byType.putIfAbsent(t, () => []).add(n);
    }
    final typeRows = <Widget>[];
    _typeOrder.forEach((t) {
      final list = byType[t];
      if (list == null || list.isEmpty) return;
      typeRows.add(_typeHeader(_typeLabels[t] ?? t));
      for (final n in list) {
        typeRows.add(Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: _nodeTile(n, depth: 1),
        ));
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: typeRows,
    );
  }

  Widget _buildTree(List<Map<String, dynamic>> roots,
      Map<String, List<Map<String, dynamic>>> childrenOf, int depth) {
    final rows = <Widget>[];
    for (final n in roots) {
      if (n.isEmpty) continue;
      rows.add(_nodeTile(n, depth: depth));
      final kids = childrenOf[n['id']?.toString()] ?? const [];
      if (kids.isNotEmpty) {
        rows.add(_buildTree(kids.where((k) => k.isNotEmpty).toList(), childrenOf, depth + 1));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _typeHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text4Of(context),
              letterSpacing: 0.08)),
    );
  }

  Widget _nodeTile(Map<String, dynamic> n, {required int depth}) {
    final label = (n['label'] as String?)?.trim();
    final type = (n['type'] as String?) ?? '';
    final status = (n['status'] as String?) ?? '';
    final cost = n['cost'];
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    final (chipLabel, chipColor) = _statusStyle(status, type);
    final isRoot = depth == 0;
    return Container(
      margin: EdgeInsets.only(left: (depth > 0 ? 18.0 : 0), bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isRoot
            ? AppColors.mossTintOf(context).withValues(alpha: 0.5)
            : AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
              color: chipColor.withValues(alpha: 0.7), width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textOf(context),
                  height: 1.35,
                )),
          ),
          if (chipLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(chipLabel,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: chipColor)),
            ),
          ],
          if (cost is num && cost > 0) ...[
            const SizedBox(width: 6),
            Text('¥${cost.toInt()}',
                style: TextStyle(
                    fontSize: 10, color: AppColors.vermilionOf(context))),
          ],
        ],
      ),
    );
  }

  /// status 语义化配色（保守映射：未知状态不标色，避免误导）。
  (String, Color) _statusStyle(String status, String type) {
    final s = status.trim();
    final ctx = context;
    if (s.isEmpty) {
      return ('', AppColors.text3Of(ctx));
    }
    if (s.contains('遗漏') || s.contains('漏问') || s.contains('未问')) {
      return ('待追问', AppColors.vermilionOf(ctx));
    }
    if (s.contains('排除')) {
      return ('已排除', AppColors.text4Of(ctx));
    }
    if (s.contains('过度') || s.contains('超支')) {
      return ('过度检查', AppColors.vermilionOf(ctx));
    }
    if (s.contains('询问') || s.contains('已问') || s.contains('完成') || s.contains('正常')) {
      return ('已覆盖', AppColors.primaryOf(ctx));
    }
    if (s.contains('错误')) {
      return ('需纠正', AppColors.vermilionOf(ctx));
    }
    return (s, AppColors.amberOf(ctx));
  }
}

/// 空闲微互动（2026-09-04 新增）：底部输入框上方浮出的圆角胶囊。
/// 入场「淡入 + 上浮」一步即止；随后左滑箭头反复循环（尾迹双箭头），
/// 克制精致地示意「向左滑动唤出提示」，点 × 立即消失。
class _IdleSwipeHint extends StatefulWidget {
  const _IdleSwipeHint({
    required this.onReveal,
    required this.onDismiss,
  });

  /// 整颗胶囊点击：收起自身并唤出辅助托盘（免去一次滑动）。
  final VoidCallback onReveal;

  /// 右上角 ✕：仅收起胶囊。
  final VoidCallback onDismiss;

  @override
  State<_IdleSwipeHint> createState() => _IdleSwipeHintState();
}

class _IdleSwipeHintState extends State<_IdleSwipeHint>
    with SingleTickerProviderStateMixin {
  static const _loopDur = Duration(milliseconds: 1500);

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _loopDur,
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// 把 [v] 平移 [lag] 后回绕到 [0,1)，用来制造一前一后两条「尾迹」箭头。
  double _lag(double v, double lag) {
    final wrapped = v - lag;
    return wrapped < 0 ? wrapped + 1 : wrapped;
  }

  /// 三角窗：随 [v] 在 [peak] 处升到 1、向两边衰减到 0（循环往返，无硬跳变）。
  double _tri(double v, double peak) {
    const width = 0.32;
    final d = (v - peak).abs();
    if (d >= width) return 0;
    return 1 - d / width;
  }

  Widget _chevron(double v, double lag,
      {double opacity = 1, Color? color}) {
    final t = _lag(v, lag);
    final dx = -9 * t;
    final opacityCurve = _tri(t, 0.28);
    final dy = 1.2 * _tri(t, 0.28); // 轻微下沉，增强「划过」手感
    return Opacity(
      opacity: opacityCurve * opacity,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Icon(Icons.chevron_left_rounded, size: 13, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.amberOf(context);
    const hint = '没思路？向左一滑，唤出「提示 · 思维树 · 引用」';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: widget.onReveal,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: amber.withValues(alpha: 0.30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 左滑尾迹（两个交错箭头，缓慢向左划过）
              SizedBox(
                width: 20,
                height: 20,
                child: AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) {
                    final v = _loop.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        _chevron(v, 0.12, opacity: 0.5),
                        _chevron(v, 0, color: amber),
                      ],
                    );
                  },
                ),
              ),
              // 手心「滑动」图标
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.swipe_left_rounded,
                    size: 14, color: amber),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(hint,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.text2Of(context),
                        height: 1.2)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.close_rounded,
                    size: 14, color: AppColors.text4Of(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
