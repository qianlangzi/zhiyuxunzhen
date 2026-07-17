import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_motion.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

enum ChatActionMode { question, examination, assessment }

/// 问诊室：保留三种临床动作，并将对话整理为可扫描的问诊记录。
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
    _messages = repo
        .chat()
        .map((ChatMessage item) => _UiMessage.fromModel(item))
        .toList();
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

    // 模拟标准化病人回复；计时器只更新当前仍挂载的问诊页。
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _appendMessage(
        const _UiMessage(
          by: 'sp',
          text: '好的，我尽量回答。具体是哪方面的问题？',
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final double target = _scrollCtrl.position.maxScrollExtent;
      final Duration duration = AppMotion.standard(context);
      if (duration == Duration.zero) {
        _scrollCtrl.jumpTo(target);
        return;
      }
      _scrollCtrl.animateTo(
        target,
        duration: duration,
        curve: AppMotion.standardCurve,
      );
    });
  }

  void _openReasoningSheet() {
    final LearningRepository repository = ref.read(learningRepositoryProvider);
    final List<ReasoningNode> nodes = repository.reasoning();
    final int examCost = nodes.fold<int>(
      0,
      (int total, ReasoningNode node) => total + (node.cost ?? 0),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (BuildContext context) => _ReasoningSheet(
        nodes: nodes,
        cost: examCost,
      ),
    );
  }

  CaseModel? _resolveCase(CaseRepository repository) {
    final CaseModel? listedCase = repository.byId(widget.caseId);
    if (listedCase != null) return listedCase;

    // 每日病例不在 all()/byId() 合同中，仅在展示层做兼容解析。
    final CaseModel daily = repository.daily();
    return daily.id == widget.caseId ? daily : null;
  }

  @override
  Widget build(BuildContext context) {
    final CaseRepository caseRepository = ref.watch(caseRepositoryProvider);
    final CaseModel? caseItem = _resolveCase(caseRepository);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: ZyAppBar(
        title: caseItem?.title ?? '问诊室',
        subtitle: caseItem == null ? '模拟病人对话中' : '问诊记录 · ${caseItem.duration}',
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
            if (caseItem != null) _PatientSummary(caseItem: caseItem),
            Expanded(
              child: _MessageList(
                messages: _messages,
                controller: _scrollCtrl,
              ),
            ),
            _Composer(
              controller: _inputCtrl,
              mode: _mode,
              canSend: _canSend,
              hintText: _hintText,
              onModeChanged: (ChatActionMode mode) {
                setState(() => _mode = mode);
              },
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientSummary extends StatelessWidget {
  const _PatientSummary({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final String summary = caseItem.summary ?? caseItem.chief;
    return Semantics(
      container: true,
      label: '患者摘要，病例 ${caseItem.id}，$summary',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          AppDimens.grid3,
          AppDimens.pagePadding,
          AppDimens.grid3,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(color: AppColors.rule, width: 1),
          ),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppDimens.grid2,
                runSpacing: AppDimens.grid,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    caseItem.id,
                    style: AppTextStyles.data.copyWith(color: AppColors.action),
                  ),
                  Text(
                    '${caseItem.department} · ${caseItem.difficulty} · ${caseItem.duration}',
                    style:
                        AppTextStyles.data.copyWith(color: AppColors.graphite),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.grid),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.grid3,
            AppDimens.grid2,
            AppDimens.grid3,
            AppDimens.grid2,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.rule, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ModeSelector(
                value: mode,
                onChanged: onModeChanged,
              ),
              const SizedBox(height: AppDimens.grid2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: hintText,
                        filled: true,
                        fillColor: AppColors.field,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.grid3,
                          vertical: AppDimens.grid3,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusControl),
                          borderSide: const BorderSide(color: AppColors.rule),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusControl),
                          borderSide: const BorderSide(color: AppColors.action),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.grid2),
                  SizedBox(
                    width: AppDimens.touchTarget,
                    height: AppDimens.touchTarget,
                    child: IconButton.filled(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      tooltip: '发送',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusControl),
                        ),
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

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.value, required this.onChanged});

  final ChatActionMode value;
  final ValueChanged<ChatActionMode> onChanged;

  static const List<(ChatActionMode, String)> _items =
      <(ChatActionMode, String)>[
    (ChatActionMode.question, '询问病情'),
    (ChatActionMode.examination, '申请检查'),
    (ChatActionMode.assessment, '提交判断'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusControl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.rule),
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        ),
        child: Row(
          children: List<Widget>.generate(_items.length, (int index) {
            final (ChatActionMode mode, String label) = _items[index];
            final bool selected = mode == value;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: label,
                onTap: () => onChanged(mode),
                child: ExcludeSemantics(
                  child: Material(
                    color: selected ? AppColors.actionSoft : AppColors.surface,
                    child: InkWell(
                      onTap: () => onChanged(mode),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppDimens.touchTarget,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.grid,
                          vertical: AppDimens.grid2,
                        ),
                        decoration: BoxDecoration(
                          border: index == _items.length - 1
                              ? null
                              : const Border(
                                  right: BorderSide(color: AppColors.rule),
                                ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (selected) ...<Widget>[
                              const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: AppColors.action,
                              ),
                              const SizedBox(width: AppDimens.grid),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.data.copyWith(
                                  color: selected
                                      ? AppColors.action
                                      : AppColors.graphite,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.controller});

  final List<_UiMessage> messages;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.grid3,
        AppDimens.pagePadding,
        AppDimens.grid4,
      ),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) =>
          _MessageEntry(message: messages[index]),
    );
  }
}

class _MessageEntry extends StatelessWidget {
  const _MessageEntry({required this.message});

  final _UiMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isStudent = message.isStudent;
    final bool isMentor = message.isMentor;
    final String label = isStudent
        ? '学生'
        : isMentor
            ? '智能导师'
            : '模拟病人';
    final Color accent = isStudent
        ? AppColors.action
        : isMentor
            ? AppColors.warning
            : AppColors.graphite;
    final Color background = isStudent
        ? AppColors.actionSoft
        : isMentor
            ? AppColors.warningSoft
            : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid3),
      child: Align(
        alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.86,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.grid3,
              AppDimens.grid2,
              AppDimens.grid3,
              AppDimens.grid3,
            ),
            decoration: BoxDecoration(
              color: background,
              border: Border(
                left: isStudent
                    ? const BorderSide(color: AppColors.rule)
                    : BorderSide(color: accent, width: 2),
                right: isStudent
                    ? BorderSide(color: accent, width: 2)
                    : const BorderSide(color: AppColors.rule),
                top: const BorderSide(color: AppColors.rule),
                bottom: const BorderSide(color: AppColors.rule),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isStudent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTextStyles.data.copyWith(color: accent),
                ),
                const SizedBox(height: AppDimens.grid),
                Text(
                  message.text,
                  textAlign: isStudent ? TextAlign.right : TextAlign.left,
                  style: AppTextStyles.body,
                ),
              ],
            ),
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.grid4,
            AppDimens.pagePadding,
            AppDimens.grid3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('思维路径', style: AppTextStyles.h2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: '关闭思维路径',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: AppDimens.grid3, color: AppColors.ink),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '路径内检查预计费用',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Text(
                    '¥$cost',
                    style: AppTextStyles.title.copyWith(color: AppColors.risk),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.grid4),
              const ClinicalSectionHeader(
                title: '证据与判断',
                description: '按已记录、待推进和风险节点查看当前推理。',
              ),
              const SizedBox(height: AppDimens.grid2),
              Expanded(
                child: SingleChildScrollView(
                  child: ClinicalEvidenceAxis(
                    nodes: nodes.map(_evidenceNode).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ClinicalEvidenceNode _evidenceNode(ReasoningNode node) {
    final (ClinicalEvidenceTone tone, String status) = switch (node.state) {
      'queried' || 'done' => (ClinicalEvidenceTone.success, '已记录'),
      'active' => (ClinicalEvidenceTone.action, '当前线索'),
      'next' => (ClinicalEvidenceTone.action, '待推进'),
      'warning' => (ClinicalEvidenceTone.risk, '需权衡'),
      'excluded' => (ClinicalEvidenceTone.neutral, '已排除'),
      _ => (ClinicalEvidenceTone.neutral, '待确认'),
    };
    return ClinicalEvidenceNode(
      label: node.label,
      detail: node.cost == null ? node.type : '${node.type} · 预计 ¥${node.cost}',
      statusLabel: status,
      tone: tone,
    );
  }
}

class _UiMessage {
  const _UiMessage({
    required this.by,
    required this.text,
    this.mode = ChatActionMode.question,
  });

  factory _UiMessage.fromModel(ChatMessage message) {
    return _UiMessage(by: message.by, text: message.text);
  }

  final String by;
  final String text;
  final ChatActionMode mode;

  bool get isStudent => by == 'student';
  bool get isMentor => by == 'mentor';
}
