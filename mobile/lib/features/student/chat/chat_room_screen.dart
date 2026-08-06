import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';

/// AI 问诊室
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  bool _treePanelOpen = false;
  bool _headerCollapsed = false;
  final ScrollController _scrollController = ScrollController();
  final List<_ExtraMsg> _extra = [];
  bool _spTyping = false;
  bool _showScrollToBottom = false;
  bool _sendPressed = false;

  // ---- API 状态 ----
  bool _isLoading = true;
  int? _sessionId;
  int? _caseId;
  Map<String, dynamic>? _sessionData;
  final List<_ChatMessage> _messages = [];
  // 思维树 / 阶段 / 苏格拉底提示（来自 chat_workflow SSE 聚合）
  List<Map<String, dynamic>> _treeNodes = [];
  List<Map<String, dynamic>> _treeEdges = [];
  String _stage = '主诉采集';
  String? _socratesHint;
  double _totalExamCost = 0.0;
  bool _isFinishing = false;

  late final AnimationController _typingController;
  late final AnimationController _panelController;
  late final Animation<double> _panelAnimation;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );
    _scrollController.addListener(_onScroll);
    // 初始化默认消息（硬编码 fallback）
    _initDefaultMessages();
    // 尝试加载 API 数据
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _typingController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  // ---- 患者信息 getter（优先从 API 数据读取，fallback 为硬编码） ----

  String get _patientDisplayName {
    if (_sessionData != null) {
      final name = _sessionData!['patientName'] as String? ?? '张建国';
      final age = _sessionData!['patientAge'] as int? ?? 58;
      final gender = _sessionData!['patientGender'] as String? ?? '男';
      return '$name · $age 岁 $gender';
    }
    return '张建国 · 58 岁 男';
  }

  String get _patientAvatarChar {
    if (_sessionData != null) {
      final name = _sessionData!['patientName'] as String? ?? '张建国';
      return name.isNotEmpty ? name.characters.first : '张';
    }
    return '张';
  }

  String get _chiefComplaintText {
    if (_sessionData != null) {
      final occupation = _sessionData!['occupation'] as String? ?? '建筑工人';
      final complaint = _sessionData!['chiefComplaint'] as String? ?? '胸痛 2 小时';
      return '$occupation · 主诉：$complaint';
    }
    return '建筑工人 · 主诉：胸痛 2 小时';
  }

  // ---- 初始化默认消息（硬编码 fallback） ----

  void _initDefaultMessages() {
    _messages.addAll(const [
      _ChatMessage(
        type: _MsgType.mentor,
        label: 'AI 导师提示',
        text: '本病例训练重点：胸痛的鉴别诊断。注意询问疼痛性质、放射、诱因、伴随症状，并合理选择检查。',
      ),
      _ChatMessage(
        type: _MsgType.patient,
        text: '医生……我胸口疼得厉害，出冷汗，刚才干活的时候突然开始的……',
        time: '09:14',
      ),
      _ChatMessage(
        type: _MsgType.student,
        text: '张师傅您好，我先了解一下。胸痛具体在哪个位置？能指给我看吗？',
        time: '09:15',
      ),
      _ChatMessage(
        type: _MsgType.patient,
        text: '就这里，胸骨后面，（指着胸口）一片都疼，闷闷的压着，像有石头压上来。',
        time: '09:15',
      ),
      _ChatMessage(
        type: _MsgType.student,
        text: '疼痛有没有放射到其他地方？比如左肩、下颌或后背？',
        time: '09:16',
      ),
      _ChatMessage(
        type: _MsgType.patient,
        text: '好像串到左肩膀去了，左手也有点麻。出了一身汗，有点恶心。',
        time: '09:16',
      ),
      _ChatMessage(
        type: _MsgType.student,
        text: '我先给您做个心电图，再查一下心肌酶和肌钙蛋白。',
        time: '09:18 · 已开检查',
      ),
      _ChatMessage(type: _MsgType.examResult),
    ]);
  }

  // ---- 启动 / 加载会话 ----

  /// 从路由 queryParameters / extra 读取 caseId
  void _readCaseIdFromRoute() {
    if (_caseId != null) return;
    final state = GoRouterState.of(context);
    final qs = state.uri.queryParameters['caseId'];
    if (qs != null && qs.isNotEmpty) {
      final parsed = int.tryParse(qs);
      if (parsed != null && parsed > 0) {
        _caseId = parsed;
        return;
      }
    }
    final extra = state.extra;
    if (extra is Map) {
      final cid = extra['caseId'];
      if (cid is int) {
        _caseId = cid;
      } else if (cid is String) {
        final parsed = int.tryParse(cid);
        if (parsed != null && parsed > 0) _caseId = parsed;
      }
    }
  }

  Future<void> _initSession() async {
    _readCaseIdFromRoute();
    final service = StudentService();
    final result = await service.startSession(
      caseId: _caseId ?? 1,
      assignmentInstanceId: null,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _sessionId = result['sessionId'] as int?;
        _sessionData = result;
        _isLoading = false;
        // 接口可能返回初始 stage / 思维树
        final stage = result['stage'] as String?;
        if (stage != null && stage.isNotEmpty) _stage = stage;
        final nodes = result['treeNodes'] as List<dynamic>?;
        if (nodes != null) {
          _treeNodes = nodes
              .map((n) => Map<String, dynamic>.from(n as Map))
              .toList();
          _totalExamCost = _computeExamCost();
        }
        final edges = result['treeEdges'] as List<dynamic>?;
        if (edges != null) {
          _treeEdges = edges
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        final socrates = result['socratesHint'] as String?;
        if (socrates != null && socrates.isNotEmpty) _socratesHint = socrates;
        // 如果 API 返回了消息数据，替换硬编码消息
        final apiMessages = result['messages'] as List<dynamic>?;
        if (apiMessages != null && apiMessages.isNotEmpty) {
          _messages.clear();
          for (final msg in apiMessages) {
            final sender = msg['sender'] as String?;
            final content = msg['content'] as String?;
            final time = msg['time'] as String?;
            if (sender == 'mentor') {
              _messages.add(
                _ChatMessage(
                  type: _MsgType.mentor,
                  label: msg['label'] as String? ?? 'AI 导师提示',
                  text: content ?? '',
                ),
              );
            } else if (sender == 'patient') {
              _messages.add(
                _ChatMessage(
                  type: _MsgType.patient,
                  text: content ?? '',
                  time: time ?? _now(),
                ),
              );
            } else if (sender == 'student') {
              _messages.add(
                _ChatMessage(
                  type: _MsgType.student,
                  text: content ?? '',
                  time: time ?? _now(),
                ),
              );
            } else if (sender == 'exam_result') {
              _messages.add(const _ChatMessage(type: _MsgType.examResult));
            }
          }
        }
      });
    } else {
      setState(() => _isLoading = false);
    }
    // 如果 result == null，保留硬编码 fallback 数据
  }

  /// 结束问诊 → 跳转 OSCE 结果页
  Future<void> _finishSession() async {
    if (_sessionId == null) {
      AppFeedback.error(context, '问诊会话尚未就绪，请稍候');
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: '结束问诊',
      content: '结束后将生成 OSCE 评分报告，本次问诊不可再继续。确认结束？',
      confirmText: '结束问诊',
    );
    if (!ok || !mounted) return;
    setState(() => _isFinishing = true);
    final success = await StudentService().finishSession(_sessionId!);
    if (!mounted) return;
    setState(() => _isFinishing = false);
    if (success) {
      context.pushReplacementNamed(
        RouteNames.osceResult,
        queryParameters: {'sessionId': _sessionId.toString()},
      );
    } else {
      AppFeedback.error(context, '结束问诊失败，请稍后重试');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    final show = current < max - 100;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  String _now() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _openTreePanel() {
    setState(() => _treePanelOpen = true);
    _panelController.forward();
  }

  void _closeTreePanel() {
    _panelController.reverse().then((_) {
      if (mounted) setState(() => _treePanelOpen = false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      AppFeedback.info(context, '请输入问诊内容');
      return;
    }
    if (_sessionId == null) {
      AppFeedback.error(context, '问诊会话尚未就绪，请稍候');
      return;
    }
    setState(() {
      _extra.add(_ExtraMsg(text, _now(), _MsgSender.student));
      _inputController.clear();
      _spTyping = true;
    });
    _typingController.repeat();
    _scrollToBottom();
    // 调用后端同步问诊接口（Spring Boot 转发至 AI 中台）
    final data = await StudentService().sendMessage(
      sessionId: _sessionId!,
      message: text,
    );
    if (!mounted) return;
    _typingController.stop();
    final reply = (data?['reply'] as String?) ?? '';
    setState(() => _spTyping = false);
    if (reply.isEmpty) {
      AppFeedback.error(context, '问诊回复失败，请重试');
      _scrollToBottom();
      return;
    }
    setState(() {
      _extra.add(_ExtraMsg(reply, _now(), _MsgSender.patient));
      // 解析思维树 / 阶段 / 苏格拉底提示
      final nodes = data?['treeNodes'] as List<dynamic>?;
      if (nodes != null) {
        _treeNodes = nodes
            .map((n) => Map<String, dynamic>.from(n as Map))
            .toList();
        _totalExamCost = _computeExamCost();
      }
      final edges = data?['treeEdges'] as List<dynamic>?;
      if (edges != null) {
        _treeEdges = edges
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      final stage = data?['stage'] as String?;
      if (stage != null && stage.isNotEmpty) _stage = stage;
      final socrates = data?['socratesHint'] as String?;
      if (socrates != null && socrates.isNotEmpty) {
        _socratesHint = socrates;
        // 苏格拉底提示作为导师消息插入聊天流
        _extra.add(_ExtraMsg(socrates, _now(), _MsgSender.mentor));
      }
    });
    _scrollToBottom();
  }

  void _onQuickAction(String action) {
    if (action.startsWith('+')) {
      if (action.contains('检查')) {
        AppFeedback.info(context, '检查申请：请在问诊中描述指征后开立（演示版）');
      } else {
        _pickImage();
      }
      return;
    }
    _inputController.text = action;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _extra.add(
          _ExtraMsg('已上传影像：${picked.name}', _now(), _MsgSender.student),
        );
      });
      _scrollToBottom();
      if (!mounted) return;
      AppFeedback.success(context, '影像已上传，AI 将结合影像反馈（演示版）');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, '影像上传失败：$e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 报告条目: P2 #8 — widget 可能在回调前被 dispose，此时访问 _scrollController 不安全
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildChatHeader(),
            Expanded(child: _buildChatStream()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ─── 可收起头部 ─────────────────────────────────────

  Widget _buildChatHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          bottom: BorderSide(color: AppColors.ruleOf(context)),
        ),
      ),
      child: Column(
        children: [
          // 顶栏：返回 + 头像 + 姓名 + 收起按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                AppIconButton(
                  icon: const Icon(Icons.chevron_left, size: 24),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.goNamed(RouteNames.studentHome),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.mossTintOf(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
_patientAvatarChar,
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: [
                        'Songti SC',
                        'STSong',
                        'Noto Serif CJK SC',
                        'Source Han Serif SC',
                      ],
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOf(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _patientDisplayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ),
                // 结束问诊按钮
                GestureDetector(
                  onTap: _isFinishing ? null : _finishSession,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.vermilionSoftOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: _isFinishing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(AppColors.vermilion),
                            ),
                          )
                        : const MonoText(
                            '结束问诊',
                            fontSize: 11,
                            color: AppColors.vermilion,
                            weight: FontWeight.w600,
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(
                    () => _headerCollapsed = !_headerCollapsed,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AnimatedRotation(
                      turns: _headerCollapsed ? 0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 展开内容：主诉 + 阶段进度 + 思维树
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _headerCollapsed
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 56,
                          right: 16,
                          bottom: 8,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: MonoText(
                            _chiefComplaintText,
                            fontSize: 11,
                            color: AppColors.text3Of(context),
                          ),
                        ),
                      ),
                      _buildStageProgress(),
                      _buildTreeToggle(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 问诊阶段进度条（主诉采集 → 诊断 共 8 阶段）
  Widget _buildStageProgress() {
    const stages = [
      '主诉采集',
      '现病史',
      '既往史',
      '过敏史',
      '家族史',
      '个人史',
      '查体',
      '诊断',
    ];
    final currentIdx = stages.indexOf(_stage);
    final activeIdx = currentIdx < 0 ? 0 : currentIdx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          top: BorderSide(color: AppColors.ruleSoftOf(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MonoText('问诊阶段',
                  fontSize: 10,
                  color: AppColors.text3Of(context),
                  letterSpacing: 0.08),
              MonoText(_stage,
                  fontSize: 11,
                  color: AppColors.primaryOf(context),
                  weight: FontWeight.w600),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                final filled = i ~/ 2 < activeIdx;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: filled
                        ? AppColors.primaryOf(context)
                        : AppColors.ruleSoftOf(context),
                  ),
                );
              }
              final idx = i ~/ 2;
              final done = idx < activeIdx;
              final current = idx == activeIdx;
              final color = done || current
                  ? AppColors.primaryOf(context)
                  : AppColors.text4Of(context);
              return Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: current
                      ? AppColors.primaryOf(context)
                      : (done
                          ? AppColors.primaryOf(context).withValues(alpha: 0.15)
                          : AppColors.ruleSoftOf(context)),
                  shape: BoxShape.circle,
                  border: current
                      ? null
                      : Border.all(color: color, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${idx + 1}',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'JetBrainsMono',
                    color: current
                        ? AppColors.onPrimaryOf(context)
                        : color,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeToggle() {
    final nodeCount = _treeNodes.length;
    final missCount =
        _treeNodes.where((n) => _isMissStatus(n['status'] as String?)).length;
    return GestureDetector(
      onTap: _openTreePanel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.mossTintOf(context),
          border: Border(
            top: BorderSide(color: AppColors.mossSoftOf(context)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 14,
              color: AppColors.primaryOf(context),
            ),
            const SizedBox(width: 6),
            MonoText(
              '临床思维树',
              fontSize: 11,
              color: AppColors.primaryOf(context),
              letterSpacing: 0.04,
            ),
            const SizedBox(width: 8),
            MonoText(
              '$nodeCount 节点 · $missCount 遗漏',
              fontSize: 10,
              color: AppColors.moss3,
            ),
            const Spacer(),
            if (_totalExamCost > 0)
              MonoText(
                '¥ ${_totalExamCost.toStringAsFixed(0)}',
                fontSize: 11,
                color: AppColors.amber,
                weight: FontWeight.w600,
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.primaryOf(context).withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  bool _isMissStatus(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s.contains('遗漏') || s.contains('未采集') || s.contains('未询问');
  }

  double _computeExamCost() {
    return _treeNodes.fold<double>(
      0,
      (sum, n) => sum + ((n['cost'] as num?)?.toDouble() ?? 0),
    );
  }

  // ─── 聊天流 ──────────────────────────────────────────

  Widget _buildChatStream() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // 动态消息列表（来自 _messages 或 API 数据）
            ..._messages.map((m) => _buildMessageWidget(m)),
            // 动态追加的消息（发送按钮触发）
            ..._extra.map((m) {
              if (m.sender == _MsgSender.student) {
                return _studentMessage(m.text, m.time);
              }
              if (m.sender == _MsgSender.mentor) {
                return _mentorMessage('AI 导师提示', m.text);
              }
              return _patientMessage(m.text, m.time);
            }),
            if (_spTyping) _patientTypingMessage(),
          ],
        ),
        // 滚动到底按钮
        if (_showScrollToBottom)
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildScrollToBottomButton(),
          ),
        // 思维树面板（滑入动画）
        if (_treePanelOpen) _buildAnimatedTreePanel(screenWidth),
      ],
    );
  }

  /// 根据 _ChatMessage 类型渲染对应的消息 widget
  Widget _buildMessageWidget(_ChatMessage msg) {
    switch (msg.type) {
      case _MsgType.mentor:
        return _mentorMessage(msg.label ?? '', msg.text ?? '');
      case _MsgType.patient:
        return _patientMessage(msg.text ?? '', msg.time ?? '');
      case _MsgType.student:
        return _studentMessage(msg.text ?? '', msg.time ?? '');
      case _MsgType.examResult:
        return _examResultMessage();
    }
  }

  Widget _buildScrollToBottomButton() {
    return GestureDetector(
      onTap: _scrollToBottom,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Icon(
          Icons.keyboard_double_arrow_down,
          size: 18,
          color: AppColors.text2Of(context),
        ),
      ),
    );
  }

  // ─── 患者打字指示器 ──────────────────────────────────

  Widget _patientTypingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _patientAvatarSmall(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '患者',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.moss3,
                  ),
                ),
                const SizedBox(height: 4),
                _buildTypingDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_typingController.value + i * 0.15) % 1.0;
            final opacity =
                (0.3 + 0.5 * (1 - (phase - 0.5).abs() * 2)).clamp(0.2, 0.8);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.text4Of(context)
                      .withValues(alpha: opacity.toDouble()),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ─── 导师消息 ────────────────────────────────────────

  Widget _mentorMessage(String label, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.88,
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.amberSoftOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 9, color: AppColors.amber),
                    const SizedBox(width: 4),
                    MonoText(
                      label.toUpperCase(),
                      fontSize: 9,
                      color: AppColors.amber,
                      letterSpacing: 0.1,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: _parseRichText(content),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textOf(context),
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _parseRichText(String text) {
    final spans = <InlineSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int start = 0;
    for (final match in boldRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  // ─── 患者消息 ────────────────────────────────────────

  Widget _patientAvatarSmall() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '患',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryOf(context),
        ),
      ),
    );
  }

  Widget _patientMessage(String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _patientAvatarSmall(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '患者',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.moss3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    MonoText(
                      time,
                      fontSize: 10,
                      color: AppColors.text4Of(context),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textOf(context),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 学生消息 ────────────────────────────────────────

  Widget _studentMessage(String text, String time) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MonoText(
                time,
                fontSize: 10,
                color: AppColors.text4Of(context),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.mossTintOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textOf(context),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _examResultMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: _mentorMessage(
        '检查结果返回',
        '''
**心电图（18 导联）** · ¥120
II、III、aVF 导联 ST 段抬高 0.2-0.4 mV
V3R-V5R ST 段抬高 0.15 mV

**肌钙蛋白 I** · ¥280
cTnI 3.8 ng/mL ↑（参考 < 0.04）

**引用：**《内科学》第9版 · P247
''',
      ),
    );
  }

  // ─── 输入区 ──────────────────────────────────────────

  Widget _buildInputArea() {
    final quickActions = [
      '疼痛性质？',
      '持续多久？',
      '既往史',
      '用药史',
      '+ 开检查',
      '+ 上传影像',
    ];
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 快捷操作
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickActions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  return _buildQuickActionChip(quickActions[i]);
                },
              ),
            ),
            const SizedBox(height: 8),
            // 一体化输入容器
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 上传按钮
                  GestureDetector(
                    onTap: _pickImage,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                  // 输入框
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 100,
                      ),
                      child: TextField(
                        controller: _inputController,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textOf(context),
                        ),
                        decoration: InputDecoration(
                          hintText: '输入问诊内容…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.text4Of(context),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 发送按钮
                  GestureDetector(
                    onTapDown: (_) => setState(() => _sendPressed = true),
                    onTapUp: (_) {
                      setState(() => _sendPressed = false);
                      _sendMessage();
                    },
                    onTapCancel: () => setState(() => _sendPressed = false),
                    child: AnimatedScale(
                      scale: _sendPressed ? 0.85 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOf(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward,
                          size: 16,
                          color: AppColors.onPrimaryOf(context),
                        ),
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

  Widget _buildQuickActionChip(String label) {
    return GestureDetector(
      onTap: () => _onQuickAction(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgOf(context),
          border: Border.all(color: AppColors.ruleOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.text2Of(context),
          ),
        ),
      ),
    );
  }

  // ─── 思维树面板（滑入动画） ──────────────────────────

  Widget _buildAnimatedTreePanel(double screenWidth) {
    final panelWidth = screenWidth * 0.9;
    return Stack(
      children: [
        // 半透明遮罩
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _panelAnimation,
            builder: (context, _) => GestureDetector(
              onTap: _closeTreePanel,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black
                    .withValues(alpha: 0.4 * _panelAnimation.value),
              ),
            ),
          ),
        ),
        // 面板内容
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: panelWidth,
          child: AnimatedBuilder(
            animation: _panelAnimation,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(
                  (1 - _panelAnimation.value) * panelWidth,
                  0,
                ),
                child: Material(
                  color: AppColors.surfaceOf(context),
                  elevation: 8 * _panelAnimation.value,
                  child: _buildTreePanelContent(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTreePanelContent() {
    return Column(
      children: [
        // 面板标题栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(
              bottom: BorderSide(color: AppColors.ruleOf(context)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.mossTintOf(context),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.account_tree,
                      size: 15,
                      color: AppColors.primaryOf(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '临床思维树',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ],
              ),
              AppIconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _closeTreePanel,
              ),
            ],
          ),
        ),
        // 面板内容
        Expanded(
          child: _treeNodes.isEmpty
              ? _buildEmptyTree()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildTreeSections(),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyTree() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('思维树将在问诊后生成',
              style: TextStyle(fontSize: 13, color: AppColors.text3Of(context))),
          if (_socratesHint != null) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberSoftOf(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MonoText('苏格拉底提示',
                      fontSize: 10,
                      color: AppColors.amber,
                      letterSpacing: 0.1),
                  const SizedBox(height: 6),
                  Text(_socratesHint!,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textOf(context),
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTreeSections() {
    final widgets = <Widget>[];
    // 费用卡（基于节点 cost 累计）
    widgets.add(_buildCostCard());
    // 苏格拉底提示
    if (_socratesHint != null && _socratesHint!.isNotEmpty) {
      widgets.add(_buildSocratesCard());
    }
    // 按 type 分组渲染
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in _treeNodes) {
      final type = (n['type'] as String?) ?? 'symptom';
      groups.putIfAbsent(type, () => []).add(n);
    }
    const typeMeta = <String, (String, Color)>{
      'symptom': ('症状 / Symptom', AppColors.moss3),
      'history': ('病史 / History', AppColors.vermilion),
      'exam': ('检查 / Exam', AppColors.amber),
      'diagnosis': ('诊断 / Diagnosis', AppColors.indigo),
      'cost': ('费用 / Cost', AppColors.amber),
    };
    for (final entry in groups.entries) {
      final meta = typeMeta[entry.key] ?? ('${entry.key}', AppColors.text3Of(context));
      final nodes = entry.value.map(_mapNodeToTreeNode).toList();
      final missCnt =
          nodes.where((n) => n.miss).length;
      final countStr = missCnt > 0 ? '$missCnt 遗漏' : '${nodes.length} 已采集';
      widgets.add(_buildTreeSection(
        meta.$1,
        countStr,
        meta.$2,
        nodes,
      ));
    }
    return widgets;
  }

  Widget _buildSocratesCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 12, color: AppColors.amber),
              const SizedBox(width: 4),
              const MonoText('苏格拉底提示',
                  fontSize: 10,
                  color: AppColors.amber,
                  letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 6),
          Text(_socratesHint!,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textOf(context),
                  height: 1.5)),
        ],
      ),
    );
  }

  /// 将 mentor 返回的节点 Map 转换为 _TreeNode
  _TreeNode _mapNodeToTreeNode(Map<String, dynamic> n) {
    final label = (n['label'] as String?) ?? '';
    final status = (n['status'] as String?) ?? '';
    final evidence = n['evidence'] as String?;
    final cost = (n['cost'] as num?)?.toDouble() ?? 0;
    final textBuf = StringBuffer(label);
    if (cost > 0) textBuf.write(' · ¥${cost.toStringAsFixed(0)}');
    final meta = (evidence != null && evidence.isNotEmpty) ? evidence : null;
    final lower = status.toLowerCase();
    final isMiss = lower.contains('遗漏') ||
        lower.contains('未采集') ||
        lower.contains('未询问');
    final isWarn = lower.contains('过度') ||
        lower.contains('复查') ||
        lower.contains('待排除') ||
        lower.contains('错误');
    final isNeutral = lower.contains('已排除') || lower.contains('可能性低');
    final badgeType = isMiss
        ? StatusBadgeType.miss
        : isWarn
            ? StatusBadgeType.warn
            : isNeutral
                ? StatusBadgeType.neutral
                : StatusBadgeType.ok;
    return _TreeNode(
      label.isEmpty ? (n['id'] as String? ?? '节点') : label,
      status.isEmpty ? '已采集' : status,
      textBuf.toString(),
      badgeType,
      meta: meta,
      miss: isMiss,
      warn: isWarn,
      neutral: isNeutral,
    );
  }

  Widget _buildCostCard() {
    // 从节点累计费用（type=exam 或带 cost 字段）
    final total = _computeExamCost();
    const threshold = 1000.0;
    final ratio = total / threshold;
    final examCount =
        _treeNodes.where((n) => (n['type'] as String?) == 'exam').length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MonoText(
                    '检查累计费用',
                    fontSize: 11,
                    color: AppColors.amber,
                    letterSpacing: 0.06,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥ ${total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MonoText(
                    '阈值 ¥${threshold.toStringAsFixed(0)}',
                    fontSize: 11,
                    color: AppColors.text3Of(context),
                  ),
                  const SizedBox(height: 2),
                  MonoText(
                    '${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}% 已用',
                    fontSize: 11,
                    color: AppColors.amber,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            value: ratio.clamp(0.0, 1.0),
            height: 4,
            backgroundColor: AppColors.amber.withValues(alpha: 0.2),
            foregroundColor: AppColors.amber,
            radius: 2,
          ),
          const SizedBox(height: 6),
          MonoText(
            '已开 $examCount 项检查（模拟费用 · 不真实扣费）',
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSection(
    String title,
    String count,
    Color countColor,
    List<_TreeNode> nodes,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MonoText(
                  title,
                  fontSize: 10,
                  color: AppColors.text3Of(context),
                  letterSpacing: 0.12,
                ),
                MonoText(count, fontSize: 10, color: countColor),
              ],
            ),
          ),
          ...nodes.map((n) => _buildTreeNode(n)),
        ],
      ),
    );
  }

  Widget _buildTreeNode(_TreeNode node) {
    Color leftColor = AppColors.primaryOf(context);
    Color bgColor = AppColors.surfaceOf(context);
    if (node.miss) {
      leftColor = AppColors.vermilion;
      bgColor = AppColors.vermilionSoftOf(context);
    } else if (node.warn) {
      leftColor = AppColors.amber;
      bgColor = AppColors.amberSoftOf(context);
    } else if (node.neutral) {
      leftColor = AppColors.text4Of(context);
      bgColor = AppColors.surfaceOf(context);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: leftColor),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MonoText(
                      node.type,
                      fontSize: 10,
                      color: AppColors.text3Of(context),
                      letterSpacing: 0.06,
                    ),
                    AppStatusBadge(label: node.status, type: node.statusType),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  node.text,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text2Of(context),
                    height: 1.4,
                  ),
                ),
                if (node.meta != null) ...[
                  const SizedBox(height: 4),
                  MonoText(
                    node.meta!,
                    fontSize: 10,
                    color: AppColors.text3Of(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeNode {
  final String type;
  final String status;
  final String text;
  final StatusBadgeType statusType;
  final String? meta;
  final bool miss;
  final bool warn;
  final bool neutral;

  const _TreeNode(
    this.type,
    this.status,
    this.text,
    this.statusType, {
    this.meta,
    this.miss = false,
    this.warn = false,
    this.neutral = false,
  });
}

/// 动态追加的问诊消息（发送按钮触发）
enum _MsgSender { student, patient, mentor }

class _ExtraMsg {
  final String text;
  final String time;
  final _MsgSender sender;

  const _ExtraMsg(this.text, this.time, this.sender);
}

/// 统一的消息模型（支持初始消息和 API 消息）
enum _MsgType { mentor, patient, student, examResult }

class _ChatMessage {
  final _MsgType type;
  final String? text;
  final String? time;
  final String? label;

  const _ChatMessage({
    required this.type,
    this.text,
    this.time,
    this.label,
  });
}
