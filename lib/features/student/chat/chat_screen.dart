import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final int caseId;
  const ChatScreen({super.key, required this.caseId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Initial SP greeting
    _messages.add(const _Message(
      sender: 'SP',
      text: '你好，我是今天的模拟患者。请问你准备好开始问诊了吗？',
      isMe: false,
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_Message(sender: '我', text: text, isMe: true));
      _isTyping = true;
    });
    _msgCtrl.clear();

    // Simulate SP response
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_Message(
          sender: 'SP',
          text: _mockResponse(text),
          isMe: false,
        ));
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 问诊室'),
        actions: [
          // Show thinking tree
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, size: 20),
            onPressed: () => _showThinkingTree(context),
            tooltip: '临床思维树',
          ),
        ],
      ),
      body: Column(
        children: [
          // OSCE score bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('采集 85% · 逻辑 70% · 沟通 90% · 人文 88%',
                      style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
                Text('费用 ¥860',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isTyping && i == _messages.length) {
                  return const _TypingIndicator();
                }
                final msg = _messages[i];
                return _ChatBubble(message: msg);
              },
            ),
          ),
          // Input bar
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.borderLight),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, size: 22),
                    onPressed: () {},
                    tooltip: '上传影像',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: '输入问诊内容…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        filled: false,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mockResponse(String input) {
    if (input.contains('胸痛')) {
      return '胸痛大概从2小时前开始的，在胸口正中偏左的位置，像有东西压着。没有向其他位置放射。';
    }
    if (input.contains('检查')) {
      return '好的，我同意做这个检查。医生，这个检查大概多少钱？';
    }
    if (input.contains('诊断')) {
      return '嗯…那这到底是什么问题呢？严重吗？';
    }
    return '我明白了。还有其他需要问我的吗？';
  }

  void _showThinkingTree(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('临床思维决策树',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const _TreeNode(
                label: '胸痛', type: 'symptom', status: 'asked'),
            const _TreeNode(
                label: '既往史', type: 'history', status: 'pending'),
            const _TreeNode(
                label: '心电图', type: 'exam', status: 'ordered'),
            const _TreeNode(
                label: '急性冠脉综合征',
                type: 'diagnosis',
                status: 'critical_miss'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructiveLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.destructive, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('⚠️ 高危遗漏：尚未考虑急性冠脉综合征',
                        style: TextStyle(
                            color: AppColors.destructive, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  final String sender, text;
  final bool isMe;
  const _Message(
      {required this.sender, required this.text, required this.isMe});
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isMe ? AppColors.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight:
                message.isMe ? Radius.zero : const Radius.circular(16),
            bottomLeft:
                !message.isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: message.isMe ? null : Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.sender,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: message.isMe
                        ? Colors.white70
                        : AppColors.primary)),
            const SizedBox(height: 4),
            Text(message.text,
                style: TextStyle(
                    fontSize: 15,
                    color: message.isMe ? Colors.white : null)),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: Radius.zero),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SP 正在输入', style: TextStyle(fontSize: 13, color: AppColors.fgDimLight)),
            SizedBox(width: 8),
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeNode extends StatelessWidget {
  final String label, type, status;
  const _TreeNode(
      {required this.label, required this.type, required this.status});

  IconData get icon {
    switch (type) {
      case 'symptom': return Icons.healing;
      case 'history': return Icons.history;
      case 'exam': return Icons.biotech;
      case 'diagnosis': return Icons.medical_services;
      default: return Icons.circle;
    }
  }

  Color get color {
    switch (status) {
      case 'asked': case 'ordered': return AppColors.accent;
      case 'pending': return AppColors.fgDimLight;
      case 'critical_miss': return AppColors.destructive;
      default: return AppColors.fgDimLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
