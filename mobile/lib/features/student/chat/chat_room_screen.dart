import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// AI 问诊室
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  bool _treePanelOpen = false;
  bool _headerCollapsed = false;
  final ScrollController _scrollController = ScrollController();
  final List<_ExtraMsg> _extra = [];
  bool _spTyping = false;
  bool _showScrollToBottom = false;
  bool _sendPressed = false;

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
    setState(() {
      _extra.add(_ExtraMsg(text, _now(), _MsgSender.student));
      _inputController.clear();
      _spTyping = true;
    });
    _typingController.repeat();
    _scrollToBottom();
    // 模拟 SP 流式回复（接入后端后替换为 /api/v1/ai/chat/stream SSE）
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final reply = _mockSpReply(text);
    _typingController.stop();
    setState(() {
      _spTyping = false;
      _extra.add(_ExtraMsg(reply, _now(), _MsgSender.patient));
    });
    _scrollToBottom();
  }

  String _mockSpReply(String question) {
    if (question.contains('过敏')) return '我对青霉素过敏，以前打针起过皮疹。';
    if (question.contains('既往') || question.contains('病史')) {
      return '高血压 8 年了，没怎么规律吃药。没有糖尿病，不抽烟，偶尔喝点酒。';
    }
    if (question.contains('用药')) return '就降压药，有时候吃有时候忘。别的没吃过。';
    if (question.contains('持续') || question.contains('多久')) {
      return '疼了得有两个小时了，一直没缓过来，越来越难受。';
    }
    if (question.contains('性质') || question.contains('什么样')) {
      return '闷闷的、压着疼，像有块石头压在胸口，喘不上气。';
    }
    return '医生，我也不太会形容……就是胸口难受，出冷汗，您快帮我看看吧。';
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
                  decoration: const BoxDecoration(
                    color: AppColors.mossTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '张',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: [
                        'Songti SC',
                        'STSong',
                        'Noto Serif CJK SC',
                        'Source Han Serif SC',
                      ],
                      fontWeight: FontWeight.w600,
                      color: AppColors.moss,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '张建国 · 58 岁 男',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: const [
                        'Songti SC',
                        'STSong',
                        'Noto Serif CJK SC',
                        'Source Han Serif SC',
                      ],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ),
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
          // 展开内容：主诉 + 思维树
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
                            '建筑工人 · 主诉：胸痛 2 小时',
                            fontSize: 11,
                            color: AppColors.text3Of(context),
                          ),
                        ),
                      ),
                      _buildTreeToggle(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeToggle() {
    return GestureDetector(
      onTap: _openTreePanel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: const BoxDecoration(
          color: AppColors.mossTint,
          border: Border(
            top: BorderSide(color: AppColors.mossSoft),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 14,
              color: AppColors.moss,
            ),
            const SizedBox(width: 6),
            const MonoText(
              '临床思维树',
              fontSize: 11,
              color: AppColors.moss,
              letterSpacing: 0.04,
            ),
            const SizedBox(width: 8),
            const MonoText(
              '8 问 · 2 排除',
              fontSize: 10,
              color: AppColors.moss3,
            ),
            const Spacer(),
            const MonoText(
              '¥ 680',
              fontSize: 11,
              color: AppColors.amber,
              weight: FontWeight.w600,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.moss.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
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
            _mentorMessage(
              'AI 导师提示',
              '本病例训练重点：胸痛的鉴别诊断。注意询问疼痛性质、放射、诱因、伴随症状，并合理选择检查。',
            ),
            _patientMessage(
              '医生……我胸口疼得厉害，出冷汗，刚才干活的时候突然开始的……',
              '09:14',
            ),
            _studentMessage(
              '张师傅您好，我先了解一下。胸痛具体在哪个位置？能指给我看吗？',
              '09:15',
            ),
            _patientMessage(
              '就这里，胸骨后面，（指着胸口）一片都疼，闷闷的压着，像有石头压上来。',
              '09:15',
            ),
            _studentMessage(
              '疼痛有没有放射到其他地方？比如左肩、下颌或后背？',
              '09:16',
            ),
            _patientMessage(
              '好像串到左肩膀去了，左手也有点麻。出了一身汗，有点恶心。',
              '09:16',
            ),
            _studentMessage(
              '我先给您做个心电图，再查一下心肌酶和肌钙蛋白。',
              '09:18 · 已开检查',
            ),
            _examResultMessage(),
            ..._extra.map((m) {
              if (m.sender == _MsgSender.student) {
                return _studentMessage(m.text, m.time);
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
              color: AppColors.amberSoft,
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
      decoration: const BoxDecoration(
        color: AppColors.mossTint,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        '患',
        style: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: [
            'Songti SC',
            'STSong',
            'Noto Serif CJK SC',
            'Source Han Serif SC',
          ],
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.moss,
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
                  color: AppColors.mossTint,
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
                        child: const Icon(
                          Icons.arrow_upward,
                          size: 16,
                          color: AppColors.paper,
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
                    decoration: const BoxDecoration(
                      color: AppColors.mossTint,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.account_tree,
                      size: 15,
                      color: AppColors.moss,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '临床思维树',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: const [
                        'Songti SC',
                        'STSong',
                        'Noto Serif CJK SC',
                        'Source Han Serif SC',
                      ],
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCostCard(),
              _buildTreeSection(
                '症状 / Symptom',
                '3 已问',
                AppColors.moss,
                [
                  const _TreeNode(
                    '胸部',
                    '已询问',
                    '胸骨后压榨样疼痛 2h，放射至左肩',
                    StatusBadgeType.ok,
                  ),
                  const _TreeNode(
                    '伴随',
                    '已询问',
                    '大汗、恶心、左手麻木',
                    StatusBadgeType.ok,
                  ),
                  const _TreeNode(
                    '诱因',
                    '关键遗漏',
                    '未询问体力活动、情绪、饱餐等诱因',
                    StatusBadgeType.miss,
                    meta: '⚠ 高危遗漏 · 影响鉴别诊断',
                    miss: true,
                  ),
                ],
              ),
              _buildTreeSection(
                '病史 / History',
                '1 遗漏',
                AppColors.vermilion,
                [
                  const _TreeNode(
                    '既往',
                    '已采集',
                    '高血压 8 年，未规律服药',
                    StatusBadgeType.ok,
                  ),
                  const _TreeNode(
                    '过敏史',
                    '未采集',
                    '未询问药物过敏史',
                    StatusBadgeType.miss,
                    miss: true,
                  ),
                ],
              ),
              _buildTreeSection(
                '检查 / Exam',
                '1 过度',
                AppColors.amber,
                [
                  const _TreeNode(
                    '心电图',
                    '关键 · 已开',
                    '18 导联 · ¥120',
                    StatusBadgeType.ok,
                  ),
                  const _TreeNode(
                    '肌钙蛋白',
                    '关键 · 已开',
                    'cTnI · ¥280',
                    StatusBadgeType.ok,
                  ),
                  const _TreeNode(
                    '心肌酶谱',
                    '建议复查',
                    '¥280 · 与肌钙蛋白重复，可优化',
                    StatusBadgeType.warn,
                    warn: true,
                  ),
                ],
              ),
              _buildTreeSection(
                '诊断 / Diagnosis',
                '待鉴别',
                AppColors.text3Of(context),
                [
                  const _TreeNode(
                    'ACS',
                    '高度怀疑',
                    '急性下壁+右室心梗可能',
                    StatusBadgeType.ok,
                  ),
                  const _TreeNode(
                    '主动脉夹层',
                    '待排除',
                    '需 D-二聚体 / 胸主动脉 CTA 排除',
                    StatusBadgeType.warn,
                  ),
                  const _TreeNode(
                    '肺栓塞',
                    '可能性低',
                    '无危险因素，待 Wells 评估',
                    StatusBadgeType.neutral,
                    neutral: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
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
                    '¥ 680',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: const [
                        'Songti SC',
                        'STSong',
                        'Noto Serif CJK SC',
                        'Source Han Serif SC',
                      ],
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
                    '阈值 ¥1,000',
                    fontSize: 11,
                    color: AppColors.text3Of(context),
                  ),
                  const SizedBox(height: 2),
                  const MonoText(
                    '68% 已用',
                    fontSize: 11,
                    color: AppColors.amber,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            value: 0.68,
            height: 4,
            backgroundColor: AppColors.amber.withValues(alpha: 0.2),
            foregroundColor: AppColors.amber,
            radius: 2,
          ),
          const SizedBox(height: 6),
          const MonoText(
            '已开 3 项检查 · 心电图 / 心肌酶 / 肌钙蛋白（模拟费用 · 不真实扣费）',
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
    Color leftColor = AppColors.moss;
    Color bgColor = AppColors.surfaceOf(context);
    if (node.miss) {
      leftColor = AppColors.vermilion;
      bgColor = AppColors.vermilionSoft;
    } else if (node.warn) {
      leftColor = AppColors.amber;
      bgColor = AppColors.amberSoft;
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
enum _MsgSender { student, patient }

class _ExtraMsg {
  final String text;
  final String time;
  final _MsgSender sender;

  const _ExtraMsg(this.text, this.time, this.sender);
}
