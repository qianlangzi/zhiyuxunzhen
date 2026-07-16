import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_motion.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

enum ChatActionMode { question, examination, assessment }

/// 问诊室：浅色沉浸式对话 + 三种临床动作
class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late List<_UiMessage> _messages;
  ChatActionMode _mode = ChatActionMode.question;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    final LearningRepository repo = ref.read(learningRepositoryProvider);
    _messages =
        repo.chat().map((ChatMessage m) => _UiMessage.fromModel(m)).toList();
    _inputCtrl.addListener(_updateCanSend);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _updateCanSend() {
    final bool next = _inputCtrl.text.trim().isNotEmpty;
    if (next != _canSend) setState(() => _canSend = next);
  }

  String get _hintText => switch (_mode) {
        ChatActionMode.question => '向患者询问病情…',
        ChatActionMode.examination => '输入希望申请的检查…',
        ChatActionMode.assessment => '提交你的初步判断…',
      };

  bool get _isNearBottom =>
      !_scrollCtrl.hasClients ||
      _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 120;

  void _appendMessage(_UiMessage message) {
    final bool shouldFollow = _isNearBottom;
    setState(() => _messages.add(message));
    if (shouldFollow) _scrollToBottom();
  }

  void _sendMessage() {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _appendMessage(_UiMessage(by: 'student', text: text, mode: _mode));
    _inputCtrl.clear();
    // 模拟 SP 回复
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _appendMessage(_UiMessage(
        by: 'sp',
        text: '好的，我尽量回答。具体是哪方面的问题？',
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: AppMotion.standard(context),
        curve: AppMotion.standardCurve,
      );
    });
  }

  void _openReasoningSheet() {
    final LearningRepository learningRepo =
        ref.read(learningRepositoryProvider);
    final List<ReasoningNode> nodes = learningRepo.reasoning();
    final int examCost =
        nodes.fold<int>(0, (int p, ReasoningNode n) => p + (n.cost ?? 0));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _ReasoningSheet(
        nodes: nodes,
        cost: examCost,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);
    final CaseModel? caseItem = caseRepo.byId(widget.caseId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ZyAppBar(
        title: caseItem?.title ?? '问诊室',
        subtitle: '模拟病人对话中',
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, size: 22),
            tooltip: '思维路径',
            onPressed: _openReasoningSheet,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _MessageList(
                messages: _messages,
                ctrl: _scrollCtrl,
              ),
            ),
            _Composer(
              controller: _inputCtrl,
              mode: _mode,
              canSend: _canSend,
              hintText: _hintText,
              onModeChanged: (ChatActionMode mode) =>
                  setState(() => _mode = mode),
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.mode,
    required this.canSend,
    required this.hintText,
    required this.onModeChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final ChatActionMode mode;
  final bool canSend;
  final String hintText;
  final ValueChanged<ChatActionMode> onModeChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.surface,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding,
              AppDimens.grid3, AppDimens.pagePadding, AppDimens.grid3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ZySegmentedControl<ChatActionMode>(
                value: mode,
                segments: const <ZySegment<ChatActionMode>>[
                  ZySegment<ChatActionMode>(
                      value: ChatActionMode.question, label: '询问病情'),
                  ZySegment<ChatActionMode>(
                      value: ChatActionMode.examination, label: '申请检查'),
                  ZySegment<ChatActionMode>(
                      value: ChatActionMode.assessment, label: '提交判断'),
                ],
                onChanged: onModeChanged,
              ),
              const SizedBox(height: AppDimens.grid3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusControl),
                      ),
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: hintText,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.grid3,
                            vertical: AppDimens.grid3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.grid2),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton.filled(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      tooltip: '发送',
                      style: IconButton.styleFrom(
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      itemBuilder: (BuildContext context, int index) =>
          _MessageBubble(message: messages[index]),
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

    final Color bg;
    final Color fg;
    final String label;
    if (isStudent) {
      bg = AppColors.brand;
      fg = Colors.white;
      label = '学生';
    } else if (isMentor) {
      bg = AppColors.amberSoft;
      fg = AppColors.warning;
      label = '智能导师';
    } else {
      bg = Colors.white;
      fg = AppColors.ink;
      label = '模拟病人';
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
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isMentor ? AppColors.warning : AppColors.soft,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.grid4, vertical: AppDimens.grid3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppDimens.radiusCard),
                    topRight: const Radius.circular(AppDimens.radiusCard),
                    bottomLeft: isStudent
                        ? const Radius.circular(AppDimens.radiusCard)
                        : const Radius.circular(2),
                    bottomRight: isStudent
                        ? const Radius.circular(2)
                        : const Radius.circular(AppDimens.radiusCard),
                  ),
                  border: isMentor
                      ? Border.all(color: AppColors.warning, width: 0.5)
                      : null,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

class _ReasoningSheet extends StatelessWidget {
  const _ReasoningSheet({required this.nodes, required this.cost});

  final List<ReasoningNode> nodes;
  final int cost;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('思维路径', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.grid3),
            Row(
              children: <Widget>[
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: AppDimens.grid2),
                const Text('当前检查费用', style: AppTextStyles.caption),
                const Spacer(),
                Text('¥$cost',
                    style: AppTextStyles.h3.copyWith(color: AppColors.warning)),
              ],
            ),
            const SizedBox(height: AppDimens.grid4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: nodes.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: AppDimens.grid2),
                itemBuilder: (BuildContext context, int index) =>
                    _ReasoningNodeTile(node: nodes[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasoningNodeTile extends StatelessWidget {
  const _ReasoningNodeTile({required this.node});

  final ReasoningNode node;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ZyChip(node.type, tone: ZyChipTone.neutral, small: true),
        const SizedBox(width: AppDimens.grid3),
        Expanded(
          child: Text(node.label, style: AppTextStyles.body),
        ),
        if (node.cost != null)
          Text('¥${node.cost}', style: AppTextStyles.caption),
      ],
    );
  }
}

class _UiMessage {
  const _UiMessage({
    required this.by,
    required this.text,
    this.mode = ChatActionMode.question,
  });

  factory _UiMessage.fromModel(ChatMessage m) =>
      _UiMessage(by: m.by, text: m.text);

  final String by;
  final String text;
  final ChatActionMode mode;

  bool get isStudent => by == 'student';
  bool get isMentor => by == 'mentor';
  bool get isSp => by == 'sp';
}
