import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 问诊室：手机端优化为单列竖向聊天 + 可展开的辅助面板
class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late List<_UiMessage> _messages;
  bool _showPanel = false;

  @override
  void initState() {
    super.initState();
    final LearningRepository repo = ref.read(learningRepositoryProvider);
    _messages = repo.chat()
        .map((ChatMessage m) => _UiMessage.fromModel(m))
        .toList();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_UiMessage(by: 'student', text: text));
      _inputCtrl.clear();
    });
    // 模拟 SP 回复
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_UiMessage(
          by: 'sp',
          text: '好的，我尽量回答。具体是哪方面的问题？',
        ));
      });
      _scrollToBottom();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);
    final LearningRepository learningRepo = ref.watch(learningRepositoryProvider);
    final CaseModel? caseItem =
        caseRepo.byId(widget.caseId) ?? caseRepo.daily();
    final List<ReasoningNode> nodes = learningRepo.reasoning();
    final int examCost = nodes.fold<int>(
        0, (int p, ReasoningNode n) => p + (n.cost ?? 0));

    return Scaffold(
      backgroundColor: AppColors.deep,
      appBar: ZyAppBar(
        title: Text(caseItem?.title ?? '问诊室'),
        subtitle: '模拟病人对话中',
        transparent: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _showPanel
                  ? Icons.menu_book_rounded
                  : Icons.menu_book_outlined,
              color: AppColors.deepInk,
              size: 22,
            ),
            onPressed: () => setState(() => _showPanel = !_showPanel),
            tooltip: '思维路径',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // 提示条
            Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid2),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.grid3, vertical: AppDimens.grid2),
              decoration: BoxDecoration(
                color: const Color(0x33EFFFFB),
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.deepInk),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '检查费用 ¥$examCost，请优先选择低成本必要检查',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _showPanel
                    ? _ReasoningPanel(
                        nodes: nodes,
                        cost: examCost,
                        onClose: () => setState(() => _showPanel = false),
                      )
                    : _MessageList(
                        messages: _messages,
                        ctrl: _scrollCtrl,
                      ),
              ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppDimens.grid3, AppDimens.grid2, AppDimens.grid3, AppDimens.grid3),
        decoration: const BoxDecoration(
          color: Color(0x14FFFFFF),
          border: Border(
            top: BorderSide(color: Color(0x33FFFFFF), width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.deepInk, size: 26),
              onPressed: () {},
              tooltip: '快速操作',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.grid3, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入问诊问题，或提交初步诊断',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.soft,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.grid2),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _sendMessage,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.aqua,
                  foregroundColor: AppColors.deep,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiMessage {
  _UiMessage({required this.by, required this.text});

  factory _UiMessage.fromModel(ChatMessage m) =>
      _UiMessage(by: m.by, text: m.text);

  final String by;
  final String text;

  bool get isStudent => by == 'student';
  bool get isMentor => by == 'mentor';
  bool get isSp => by == 'sp';
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.ctrl});

  final List<_UiMessage> messages;
  final ScrollController ctrl;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final _UiMessage msg = messages[index];
        return _MessageBubble(message: msg);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _UiMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isStudent = message.isStudent;
    final bool isMentor = message.isMentor;

    Color bg;
    Color fg;
    Color labelColor;
    if (isStudent) {
      bg = AppColors.brand;
      fg = Colors.white;
      labelColor = const Color(0xB3FFFFFF);
    } else if (isMentor) {
      bg = const Color(0x33E05757);
      fg = AppColors.deepInk;
      labelColor = const Color(0xFFE05757);
    } else {
      bg = const Color(0x1AFFFFFF);
      fg = AppColors.deepInk;
      labelColor = const Color(0xB3EFFFFB);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid3),
      child: Align(
        alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                isStudent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  message.isStudent
                      ? '学生'
                      : message.isMentor
                          ? '智能导师'
                          : '模拟病人',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: labelColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.grid4, vertical: AppDimens.grid3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isStudent
                        ? const Radius.circular(18)
                        : Radius.zero,
                    bottomRight: isStudent
                        ? Radius.zero
                        : const Radius.circular(18),
                  ),
                  border: isMentor
                      ? Border.all(color: const Color(0x66E05757), width: 1)
                      : null,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatelessWidget {
  const _ReasoningPanel({
    required this.nodes,
    required this.cost,
    required this.onClose,
  });

  final List<ReasoningNode> nodes;
  final int cost;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.pagePadding),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              '诊断脑图',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepInk,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.deepInk, size: 20),
              onPressed: onClose,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.grid4),
        Container(
          padding: const EdgeInsets.all(AppDimens.grid4),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: Color(0xFFFFB17A)),
              const SizedBox(width: AppDimens.grid2),
              const Text(
                '当前检查费用',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepMuted,
                ),
              ),
              const Spacer(),
              Text(
                '¥$cost',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFB17A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.grid4),
        ...nodes.map((ReasoningNode n) => _ReasoningNodeTile(node: n)),
        const SizedBox(height: AppDimens.grid4),
        Container(
          padding: const EdgeInsets.all(AppDimens.grid4),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '苏格拉底提示',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: AppDimens.grid2),
              const Text(
                '一级：你是否还需要确认胸痛与活动、体位的关系？',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepInk,
                    height: 1.6),
              ),
              const Text(
                '二级：心电图 ST 段改变会如何影响你的判断？',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepInk,
                    height: 1.6),
              ),
              const Text(
                '三级：训练结束后展示标准路径并标注脱轨点。',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepInk,
                    height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasoningNodeTile extends StatelessWidget {
  const _ReasoningNodeTile({required this.node});

  final ReasoningNode node;

  @override
  Widget build(BuildContext context) {
    final _NodeStyle style = _styleFor(node.state);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.grid3),
      padding: const EdgeInsets.all(AppDimens.grid3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: style.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.grid2, vertical: 2),
            decoration: BoxDecoration(
              color: style.tagBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              node.type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: style.tagFg,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: Text(
              node.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.deepInk,
              ),
            ),
          ),
          if (node.cost != null)
            Text(
              '¥${node.cost}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.deepMuted,
              ),
            ),
          const SizedBox(width: AppDimens.grid2),
          Icon(style.icon, size: 18, color: style.iconColor),
        ],
      ),
    );
  }

  _NodeStyle _styleFor(String state) {
    switch (state) {
      case 'queried':
        return _NodeStyle(
          bg: const Color(0x14FFFFFF),
          border: const Color(0x33FFFFFF),
          tagBg: const Color(0x1AFFFFFF),
          tagFg: AppColors.deepMuted,
          icon: Icons.help_outline_rounded,
          iconColor: AppColors.deepMuted,
        );
      case 'active':
        return _NodeStyle(
          bg: const Color(0x33EFFFFB),
          border: AppColors.aqua,
          tagBg: AppColors.aqua,
          tagFg: AppColors.deep,
          icon: Icons.play_arrow_rounded,
          iconColor: AppColors.aqua,
        );
      case 'done':
        return _NodeStyle(
          bg: const Color(0x14FFFFFF),
          border: const Color(0x33FFFFFF),
          tagBg: const Color(0x1AFFFFFF),
          tagFg: AppColors.deepMuted,
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF14B8A6),
        );
      case 'next':
        return _NodeStyle(
          bg: const Color(0x330F766E),
          border: AppColors.brand,
          tagBg: AppColors.brand,
          tagFg: Colors.white,
          icon: Icons.arrow_forward_rounded,
          iconColor: AppColors.brand,
        );
      case 'warning':
        return _NodeStyle(
          bg: const Color(0x33C47A20),
          border: const Color(0xFFFFB17A),
          tagBg: const Color(0xFFFFB17A),
          tagFg: AppColors.deep,
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFFB17A),
        );
      case 'excluded':
      default:
        return _NodeStyle(
          bg: const Color(0x33E05757),
          border: const Color(0xFFE05757),
          tagBg: const Color(0xFFE05757),
          tagFg: Colors.white,
          icon: Icons.cancel_rounded,
          iconColor: const Color(0xFFE05757),
        );
    }
  }
}

class _NodeStyle {
  _NodeStyle({
    required this.bg,
    required this.border,
    required this.tagBg,
    required this.tagFg,
    required this.icon,
    required this.iconColor,
  });

  final Color bg;
  final Color border;
  final Color tagBg;
  final Color tagFg;
  final IconData icon;
  final Color iconColor;
}