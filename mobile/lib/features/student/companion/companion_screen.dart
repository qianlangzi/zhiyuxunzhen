import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';
import 'companion_conversation_provider.dart';
import 'companion_history_drawer.dart';

/// AI 学伴页（P1-2，学习陪伴）
/// 平辈陪伴式对话，角色区别于 SP（标准病人）：闲聊 + 基于学生错题/进度给策略建议。
/// 支持流式逐字输出（SSE）。
class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  final TextEditingController _ctl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_CompanionMsg> _messages = [];
  bool _loading = false;

  /// 发送防抖：单条消息在途标记。同一时刻只允许一条对话请求，
  /// 避免连点发送/新建产生重复消息、重复建会话（"发你好没反应"的并发诱因之一）。
  bool _sending = false;

  /// 流是否已收到 done。看门狗据此判断"后台一直没回应"而主动收敛，
  /// 否则后端 SseEmitter 0 超时 + LLM 卡住会无限转圈。
  bool _streamDone = false;

  String _streamingText = '';
  bool _streamingDegraded = false;
  String? _streamError;

  /// 越界内容被安全策略拦截（DEFLECT）：仅回 safety 事件、无 message。
  /// 前端此前未消费该事件导致"发消息没回答"，这里显式透出原因。
  String? _streamBlockedReason;

  /// 待发送图片（base64 data URL）；多模态附加
  String? _pendingImage;

  /// SSE 请求取消令牌：页面销毁时取消，避免连接挂到超时才释放
  CancelToken? _streamCancel;

  /// 会话历史管理：当前会话
  int? _conversationId;
  String _conversationTitle = 'AI 学伴';

  static const _samples = [
    '最近问诊总是漏问既往史，好焦虑，我该怎么练？',
    '帮我制定一个 7 天复习计划，重点补薄弱点',
    '今天刷题错了好多，感觉坚持不下去了',
    '心衰知识点总是记不住，有什么记忆技巧？',
  ];

  @override
  void initState() {
    super.initState();
    // 进入页面即续接上次会话，避免每次都是新对话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreLastConversation();
    });
  }

  /// 恢复上次会话：读缓存会话ID与历史，无则显示开场问候
  Future<void> _restoreLastConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getInt(_lastConvKey);
      final lastTitle = prefs.getString(_lastConvTitleKey);
      if (!mounted) return;
      if (lastId != null) {
        setState(() {
          _conversationId = lastId;
          _conversationTitle = lastTitle ?? 'AI 学伴';
          // 保留开场问候占位，若缓存无历史则用户可继续新开
        });
        _loadMessages(lastId);
        return;
      }
    } catch (_) {
      // 缓存读取失败则走默认开场
    }
    if (!mounted) return;
    StudentService().track('companion_open');
    setState(() {
      _messages.add(
        _CompanionMsg(
          '嗨，我是你的 AI 学伴～ 学习累了、卡住了、或想聊聊学习方法，都可以找我。'
          '我也会结合你的错题和薄弱点给建议。今天想从哪儿开始？',
          isGreeting: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    // 取消未完成的 SSE 连接，否则后端 SseEmitter(0L) 会一直挂到前端超时
    _streamCancel?.cancel('page disposed');
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final raw = _ctl.text.trim();
    final image = _pendingImage;
    if (raw.isEmpty && image == null) return;
    // 发送防抖：上一轮请求在途时丢弃本次输入，避免重复消息 / 重复建会话
    if (_sending) return;
    _sending = true;
    _streamDone = false;
    // 纯图消息给默认提示，保证后端 message 非空校验通过
    final text = image != null && raw.isEmpty ? '请帮我分析这张图片' : raw;
    _ctl.clear();
    setState(() {
      final hasText = text.isNotEmpty;
      _messages.add(
        _CompanionMsg(
          text,
          isUser: true,
          image: image,
          isImageOnly: image != null && !hasText,
        ),
      );
      _pendingImage = null;
      _loading = true;
      _streamingText = '';
      _streamingDegraded = false;
      _streamError = null;
      _streamBlockedReason = null;
    });
    _scrollToBottom();

    try {
      // 会话历史：首次发送自动建会话，并落地用户消息
      final wasNew = _conversationId == null;
      final convId = await _ensureConversation();
      if (convId != null) {
        await _persistMessage(convId, 'user', text, image);
      }

      // 组装历史（最近 10 轮），支持多轮追问。
      // 排除开场问候语（isGreeting）：问候是 UI 交互提示，非真实对话轮次。
      // 若把"assistant 问候 + 首条 user"作为新会话唯一历史，会产生没有 user 起头的
      // 非法消息序列（assistant 先于首个 user），导致新对话模型拒绝/返回空——开新对话
      // 无法正常使用的根因。
      final history = _messages
          .where((m) => !m.isPending && !m.isGreeting)
          .map(
            (m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            },
          )
          .toList()
        ..removeLast(); // 去掉刚加的当前问题（纯图消息保留空占位便于对齐）

      await _companionStream(text, history,
          imageUrl: image, conversationId: convId);
      if (!mounted) return;
      final reply = _streamingText.trim();
      setState(() {
        // 被安全策略拦截时无 message：透出拦截原因，而非"开小差"
        final blocked = _streamBlockedReason;
        if (reply.isEmpty) {
          _messages.add(
            _CompanionMsg(
              blocked ??
                  (_streamError ?? '抱歉，AI 学伴暂时开小差了，请稍后重试。'),
              isError: blocked == null,
            ),
          );
        } else {
          _messages.add(_CompanionMsg(reply, degraded: _streamingDegraded));
        }
        _streamingText = '';
        _streamingDegraded = false;
        _streamError = null;
        _streamBlockedReason = null;
      });
      // 会话历史：将学伴回复落地到当前会话
      final currentConv = _conversationId;
      if (currentConv != null && reply.isNotEmpty) {
        await _persistMessage(currentConv, 'assistant', reply);
      }
      // 新会话首个来回成功后，用首问作为标题自动重命名（替代恒为"新对话"）
      if (wasNew && currentConv != null && reply.isNotEmpty) {
        await _autoRename(currentConv, text);
      }
      _scrollToBottom();
    } finally {
      // 无论成功/异常/超时，都结束在途标记并收起加载态，绝不让 UI 卡在转圈
      _sending = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 首问作为标题：命中式截取首条用户消息为新会话命名（ChatGPT 初始命名风格）。
  /// 失败静默，标题保持默认"新对话"，不影响对话主流程。
  Future<void> _autoRename(int convId, String text) async {
    final title = _deriveTitle(text);
    if (title.isEmpty) return;
    try {
      await ref
          .read(companionConversationsProvider.notifier)
          .rename(convId, title);
    } catch (_) {
      return; // 后端失败已回滚，保留原标题
    }
    if (!mounted) return;
    setState(() => _conversationTitle = title);
    await _rememberConversation(); // 同步缓存标题，重进页面续接时不再回退"新对话"
  }

  /// 从用户消息推导标题：取首行、去首尾空白、超过 20 字截断。
  String _deriveTitle(String text) {
    final clean = text.trim().split('\n').first.trim();
    if (clean.isEmpty) return '';
    return clean.length > 20 ? '${clean.substring(0, 20)}…' : clean;
  }

  Future<void> _companionStream(
    String text,
    List<Map<String, String>> history, {
    String? imageUrl,
    int? conversationId,
  }) async {
    final token = CancelToken();
    _streamCancel = token;
    // 流看门狗：后端 SseEmitter 不超时，若 LLM/代理一直没产出、也没收尾，
    // 到点主动取消本次连接并透出超时原因，避免"发你好没反应"的无限转圈。
    final watchdog = Timer(const Duration(seconds: 90), () {
      if (!_streamDone) {
        _streamCancel?.cancel('companion stream watchdog');
        if (mounted) {
          setState(() => _streamError = '学伴回复超时，请稍后重试');
        }
      }
    });
    try {
      await for (final ev in StudentService().companionStream(
        message: text,
        history: history,
        imageUrl: imageUrl,
        conversationId: conversationId,
        cancelToken: token,
      )) {
        if (!mounted) return;
        switch (ev.event) {
          case 'message':
            final delta = (ev.data['delta'] as String?) ?? '';
            if (delta.isNotEmpty) {
              setState(() => _streamingText += delta);
              _scrollToBottom();
            }
          case 'status':
            final degraded = ev.data['degraded'] == true;
            if (degraded) {
              setState(() => _streamingDegraded = true);
            }
          case 'safety':
            if (ev.data['blocked'] == true) {
              setState(() {
                _streamBlockedReason =
                    (ev.data['reason'] as String?)?.trim() ??
                        '涉及真实诊疗/处方内容，请以学习视角提问';
              });
            }
          case 'error':
            final msg = (ev.data['message'] as String?)?.trim();
            if (msg != null && msg.isNotEmpty) {
              setState(() => _streamError = msg);
            }
          case 'done':
            _streamDone = true;
            break;
        }
      }
    } finally {
      watchdog.cancel();
      if (_streamCancel == token) _streamCancel = null;
    }
  }

  /// 选择本地图片，转成 base64 data URL 待发送
  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final Uint8List bytes = await file.readAsBytes();
      final mime = file.mimeType == 'image/png' ? 'image/png' : 'image/jpeg';
      setState(
        () => _pendingImage = 'data:$mime;base64,${base64Encode(bytes)}',
      );
    } catch (_) {
      // 取消或读取失败：静默忽略
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      endDrawer: _sideHistoryDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: _conversationTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.studentHome),
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '会话历史',
                    onPressed: _openHistory,
                    icon: Icon(
                      Icons.history,
                      size: 20,
                      color: AppColors.textOf(context),
                    ),
                  ),
                  IconButton(
                    tooltip: '新开对话',
                    onPressed: _newConversation,
                    icon: Icon(
                      Icons.add_comment_outlined,
                      size: 20,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty && !_loading
                  ? _buildEmpty()
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      children: [
                        for (final m in _messages) _buildMessage(m),
                        if (_loading && _streamingText.isNotEmpty)
                          _buildStreamingBubble(),
                      ],
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  /// 新开对话：清空当前消息并重新开场，相当于豆包/ChatGPT 的「新对话」
  /// 防抖：上一轮请求在途时不响应（_sending），避免快速连点建出一堆新会话；
  /// 同时取消可能还在挂着的 SSE 流，防止页面残留转圈。
  void _newConversation() {
    if (_sending) return;
    _streamCancel?.cancel('new conversation');
    _ctl.clear();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_lastConvKey);
      prefs.remove(_lastConvTitleKey);
    });
    setState(() {
      _conversationId = null;
      _conversationTitle = 'AI 学伴';
      _messages.clear();
      _pendingImage = null;
      _streamingText = '';
      _streamingDegraded = false;
      _streamError = null;
      _streamDone = false;
      _loading = false;
      _messages.add(
        _CompanionMsg(
          '嗨，我是你的 AI 学伴～ 学习累了、卡住了、或想聊聊学习方法，都可以找我。'
          '我也会结合你的错题和薄弱点给建议。今天想从哪儿开始？',
          isGreeting: true,
        ),
      );
    });
  }

  /// 打开会话历史（从右侧侧边划出）
  void _openHistory() {
    Scaffold.of(context).openEndDrawer();
  }

  /// 组装侧边会话栏入口：宽度约占屏宽 82%，圆润边角
  Widget _sideHistoryDrawer() {
    final width = MediaQuery.of(context).size.width * 0.82;
    return SizedBox(
      width: width,
      child: CompanionHistoryDrawer(
        currentId: _conversationId,
        onSelect: (id, title) {
          setState(() {
            _conversationId = id;
            _conversationTitle = title;
          });
          _rememberConversation();
          _loadMessages(id);
        },
      ),
    );
  }

  /// 会话缓存键：用于重新进入时恢复上次会话
  static const _lastConvKey = 'last_companion_conv_id';
  static const _lastConvTitleKey = 'last_companion_conv_title';

  /// 记录"上次会话"，供重新进入时续接
  Future<void> _rememberConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastConvKey, _conversationId!);
      await prefs.setString(_lastConvTitleKey, _conversationTitle);
    } catch (_) {
      // 缓存失败不影响对话
    }
  }

  /// 确保存在当前会话：不存在则经 provider 新建（后端 CRUD + 本地兜底）
  Future<int?> _ensureConversation() async {
    if (_conversationId != null) {
      await _rememberConversation();
      return _conversationId;
    }
    final c = await ref.read(companionConversationsProvider.notifier).create();
    if (!mounted) return null;
    setState(() {
      _conversationId = c.id;
      _conversationTitle = c.title;
    });
    await _rememberConversation();
    return c.id;
  }

  /// 消息本地缓存键前缀（会话级，shared_preferences JSON 数组）
  static const _msgCachePrefix = 'companion_msgs_v1_';

  /// 将一轮对话落地到当前会话
  ///
  /// 优先写入后端（保证换设备 / 清缓存后历史可恢复），同时保留本地缓存作为
  /// 离线兜底浏览。此前只写本地，后端 messages 接口形同虚设、历史恒为空。
  Future<void> _persistMessage(
    int convId,
    String role,
    String text, [
    String? image,
  ]) async {
    await StudentService().addCompanionMessage(
      convId,
      role: role,
      content: text,
      imageUrl: image,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_msgCachePrefix$convId';
      final cur = prefs.getString(key);
      final list = List<Map<String, dynamic>>.from(
        (cur != null && cur.isNotEmpty)
            ? (jsonDecode(cur) as List).cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[],
      );
      list.add({
        'role': role,
        'content': text,
        if (image != null && image.isNotEmpty) 'image': image,
      });
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {
      // 本地缓存失败不影响对话流程
    }
  }

  /// 切换会话时加载历史：后端优先，本地缓存兜底
  ///
  /// 修复切到「无本地缓存」的会话时不清空界面、导致上一会话消息串台的问题。
  Future<void> _loadMessages(int convId) async {
    final data = await StudentService().getCompanionMessages(convId, pageSize: 50);
    if (!mounted) return;
    final raw = (data?['list'] as List<dynamic>?) ??
        (data?['records'] as List<dynamic>?);
    if (raw != null && raw.isNotEmpty) {
      final loaded = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(
            (e) => _CompanionMsg(
              e['content'] as String? ?? '',
              isUser: e['sender'] == 'user',
              image: e['imageUrl'] as String?,
              isImageOnly: (e['imageUrl'] as String?) != null &&
                  (e['content'] as String? ?? '').isEmpty,
            ),
          )
          .toList();
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
        _loading = false;
        _streamingText = '';
        _pendingImage = null;
      });
      _scrollToBottom();
      return;
    }
    // 后端无记录（新会话 / 离线）→ 回落到本地缓存
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final cached = prefs.getString('$_msgCachePrefix$convId');
    setState(() {
      _messages.clear();
      _loading = false;
      _streamingText = '';
      _pendingImage = null;
      if (cached != null && cached.isNotEmpty) {
        _messages.addAll((jsonDecode(cached) as List)
            .cast<Map<String, dynamic>>()
            .map(
              (e) => _CompanionMsg(
                e['content'] as String? ?? '',
                isUser: e['role'] == 'user',
                image: e['image'] as String?,
                isImageOnly: (e['image'] as String?) != null &&
                    (e['content'] as String? ?? '').isEmpty,
              ),
            ));
      }
    });
    _scrollToBottom();
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.forum_outlined,
          size: 44,
          color: AppColors.primaryOf(context),
        ),
        const SizedBox(height: 12),
        Center(
          child: SerifText(
            '和学伴聊聊天',
            fontSize: 17,
            color: AppColors.textOf(context),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: MonoText(
            'AI COMPANION',
            fontSize: 10,
            color: AppColors.text4Of(context),
          ),
        ),
        const SizedBox(height: 20),
        ..._samples.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                _ctl.text = s;
                _send();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 15,
                      color: AppColors.primaryOf(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.text2Of(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 气泡最大宽度：按屏幕宽度取比例，避免小屏（320dp）上固定 300~320 导致溢出
  double get _bubbleMaxWidth =>
      (MediaQuery.of(context).size.width - 32) * 0.82;

  /// base64 图片解码缓存
  ///
  /// 此前直接在 build 里 base64Decode，流式回复期间每次 setState（逐字刷新）
  /// 都会重新解码整张图（约 300KB~1MB），发图后严重掉帧。
  final Map<String, Uint8List> _imageCache = {};

  Uint8List? _decodeImage(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final cached = _imageCache[dataUrl];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(dataUrl.split(',').last);
      _imageCache[dataUrl] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _buildStreamingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: _bubbleMaxWidth),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          '$_streamingText▌',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textOf(context),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(_CompanionMsg msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          constraints: BoxConstraints(maxWidth: _bubbleMaxWidth),
          decoration: BoxDecoration(
            color: AppColors.primaryOf(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.image != null) ...[
                Builder(
                  builder: (_) {
                    final bytes = _decodeImage(msg.image);
                    if (bytes == null) return const SizedBox.shrink();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.memory(
                        bytes,
                        width: 200,
                        cacheWidth: 400,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
                if (!msg.isImageOnly) const SizedBox(height: 8),
              ],
              if (!msg.isImageOnly)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.onPrimaryOf(context),
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: _bubbleMaxWidth),
        decoration: BoxDecoration(
          color: msg.isError
              ? AppColors.vermilionSoftOf(context)
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textOf(context),
                height: 1.5,
              ),
            ),
            if (!msg.isGreeting && !msg.isError) const AiGeneratedNote(),
            if (msg.degraded) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: AppColors.text4Of(context),
                  ),
                  const SizedBox(width: 4),
                  MonoText(
                    '模型暂不可用 · 规则兜底',
                    fontSize: 9,
                    color: AppColors.text4Of(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border:
            Border(top: BorderSide(color: AppColors.surfaceEdgeOf(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImage != null) ...[
            Builder(
              builder: (_) {
                final bytes = _decodeImage(_pendingImage);
                if (bytes == null) return const SizedBox.shrink();
                return Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.memory(
                          bytes,
                          width: 72,
                          height: 72,
                          cacheWidth: 144,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _pendingImage = null),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.text2Of(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.bgOf(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          Row(
            children: [
              GestureDetector(
                onTap: _loading ? null : _pickImage,
                child: PressableScale(
                  enabled: !_loading,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(
                      _pendingImage != null
                          ? Icons.image_outlined
                          : Icons.add_photo_alternate_outlined,
                      size: 22,
                      color: AppColors.primaryOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _ctl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '和学伴聊聊学习 / 心情…',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.text4Of(context),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.bgOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loading ? null : _send,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _loading
                        ? AppColors.text4Of(context)
                        : AppColors.primaryOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _loading ? Icons.hourglass_top : Icons.arrow_upward,
                    size: 20,
                    color: AppColors.onPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompanionMsg {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isPending;
  final bool degraded;
  final String? image;
  final bool isImageOnly;
  final bool isGreeting;

  _CompanionMsg(
    this.text, {
    this.isUser = false,
    this.isError = false,
    this.degraded = false,
    this.image,
    this.isImageOnly = false,
    this.isGreeting = false,
  }) : isPending = false;
}
