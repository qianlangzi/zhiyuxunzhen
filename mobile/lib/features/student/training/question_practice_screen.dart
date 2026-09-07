import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 基础题作答页（按筛选条件逐题作答）
///
/// 支持单选 / 多选 / 填空 / 简答 / 论述。
/// 传入 department/knowledgeTag/difficulty/questionType 组合筛选。
/// 通过分页逐题加载（pageSize=1），提交后显示解析，点击“下一题”继续。
/// 作答状态（已做/对错/所选答案）由后端按账户持久化，可在回顾时直接展示。
class QuestionPracticeScreen extends ConsumerStatefulWidget {
  const QuestionPracticeScreen({
    super.key,
    this.title = '基础题训练',
    this.department,
    this.knowledgeTag,
    this.difficulty,
    this.questionType,
    this.initialQuestionId,
  });

  final String title;
  final String? department;
  final String? knowledgeTag;
  final int? difficulty;
  final String? questionType;

  /// 指定要打开的题目：进入时定位到该题（用于题库列表点击具体题目回顾）。
  /// 为空则自动跳到当前筛选下首个「未做」的题。
  final int? initialQuestionId;

  @override
  ConsumerState<QuestionPracticeScreen> createState() => _QuestionPracticeScreenState();
}

class _QuestionPracticeScreenState extends ConsumerState<QuestionPracticeScreen> {
  int _pageNum = 1;
  bool _isLoading = true;
  bool _hasMore = true;
  Map<String, dynamic>? _current;
  int? _selected;
  Set<int> _multiSelected = {};
  final TextEditingController _blankCtl = TextEditingController();
  Map<String, dynamic>? _result;
  bool _submitting = false;
  int _currentIndex = 0;
  int _total = 0;
  bool _showNavigator = false;

  /// 预取的下一题（避免切题时转圈等待）
  Map<String, dynamic>? _cachedNext;

  @override
  void dispose() {
    _blankCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// 进入时定位题目：
  /// - 指定了 [initialQuestionId]：跳到该题（题库列表点具体题目回顾）；
  /// - 否则：跳到当前筛选下首个「未做」的题（账户级，来自后端学生作答记录）。
  ///
  /// 已做状态由后端 /api/v1/student/questions 回填的 answered 字段判断，
  /// 不再依赖设备本地存储，避免跨账户串号、以及“重启后跳回已做题”的问题。
  Future<void> _bootstrap() async {
    int idx = -1;
    int total = 0;
    if (widget.initialQuestionId != null) {
      final targetId = widget.initialQuestionId!;
      final (i, t) = await _scan(
          (q) => (q['id'] as num?)?.toInt() == targetId);
      idx = i;
      total = t;
    }
    if (idx < 0) {
      final (i, t) = await _scan((q) => q['answered'] != true);
      idx = i;
      total = t;
      if (idx < 0) idx = 0; // 全部已做 -> 回到第 1 题供回顾
    }
    if (!mounted) return;
    final target = (idx + 1).clamp(1, total > 0 ? total : 1);
    setState(() {
      _pageNum = target.toInt();
      _currentIndex = _pageNum - 1;
      _total = total;
    });
    _loadQuestion();
  }

  /// 分页扫描满足 [pred] 的第一题，返回 (全局下标, 总数)；无匹配返回 (-1, total)。
  Future<(int, int)> _scan(bool Function(Map<String, dynamic>) pred) async {
    var pageNum = 1;
    const batch = 100;
    var total = 0;
    while (true) {
      final data = await StudentService().getQuestions(
        pageNum: pageNum,
        pageSize: batch,
        department: widget.department,
        knowledgeTag: widget.knowledgeTag,
        difficulty: widget.difficulty,
        questionType: widget.questionType,
      );
      if (!mounted) return (-1, 0);
      final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      total = (data?['total'] as num?)?.toInt() ?? 0;
      for (var i = 0; i < list.length; i++) {
        if (pred(list[i])) return ((pageNum - 1) * batch + i, total);
      }
      if (pageNum * batch >= total) break;
      pageNum++;
    }
    return (-1, total);
  }

  String get _questionType => (_current?['questionType'] as String?) ?? 'single_choice';
  bool get _isMulti => _questionType == 'multiple_choice';
  bool get _isBlank => _questionType == 'fill_blank';
  bool get _isShortAnswer => _questionType == 'short_answer';
  bool get _isEssay => _questionType == 'essay';
  /// 简答 / 论述：主观题，需人工对照参考答案
  bool get _isManual => _isShortAnswer || _isEssay;
  /// 单选 / 判断：点选即自动提交
  bool get _isAutoSubmit => _questionType == 'single_choice' || _questionType == 'judgment';

  Future<void> _loadQuestion() async {
    setState(() {
      _isLoading = true;
      _resetAnswer();
    });
    final data = await StudentService().getQuestions(
      pageNum: _pageNum,
      pageSize: 1,
      department: widget.department,
      knowledgeTag: widget.knowledgeTag,
      difficulty: widget.difficulty,
      questionType: widget.questionType,
    );
    final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    final cur = list.isNotEmpty ? list.first : null;
    // 本次前往已做题（回顾）：直接把此前作答的对错/答案/解析呈现出来
    final existing = _existingResultOf(cur);
    setState(() {
      _current = cur;
      _hasMore = _pageNum < total;
      _total = total;
      _isLoading = false;
      _resetAnswer();
      if (existing != null) {
        _result = existing;
        _applyMyAnswer(cur!);
      }
    });
    _prefetchNext();
  }

  /// 若该题当前学生已作答，构造可直接展示的结果面板数据
  Map<String, dynamic>? _existingResultOf(Map<String, dynamic>? q) {
    if (q == null || q['answered'] != true) return null;
    return {
      'isCorrect': q['correct'],
      'selectedAnswer': q['myAnswer'],
      'correctAnswer': q['answer'],
      'explanation': q['explanation'],
    };
  }

  /// 把学生已作答案回填到输入控件，便于回顾时展示对错
  void _applyMyAnswer(Map<String, dynamic> q) {
    final my = (q['myAnswer'] as String?) ?? '';
    if (_isMulti) {
      _multiSelected = my
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    } else if (_isBlank || _isManual) {
      _blankCtl.text = my;
    } else {
      _selected = int.tryParse(my);
    }
  }

  /// 后台预取下一题，让「下一题」几乎秒切
  Future<void> _prefetchNext() async {
    final next = _pageNum + 1;
    if (_cachedNext != null || _total == 0) return;
    final data = await StudentService().getQuestions(
      pageNum: next,
      pageSize: 1,
      department: widget.department,
      knowledgeTag: widget.knowledgeTag,
      difficulty: widget.difficulty,
      questionType: widget.questionType,
    );
    if (!mounted || next != _pageNum + 1) return; // 已切页则丢弃过期缓存
    final list = (data?['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (list.isNotEmpty) setState(() => _cachedNext = list.first);
  }

  void _resetAnswer() {
    _selected = null;
    _multiSelected = {};
    _blankCtl.clear();
    _result = null;
    _submitting = false;
  }

  Future<void> _submit({bool autoAdvance = false}) async {
    if (_isBlank || _isManual) {
      if (_blankCtl.text.trim().isEmpty) {
        AppFeedback.info(context, '请先填写答案');
        return;
      }
    } else if (_isMulti) {
      if (_multiSelected.isEmpty) {
        AppFeedback.info(context, '请至少选择一个答案');
        return;
      }
    } else if (_selected == null) {
      AppFeedback.info(context, '请先选择一个答案');
      return;
    }

    final String answer;
    if (_isMulti) {
      final list = _multiSelected.toList()..sort();
      answer = list.join(',');
    } else if (_isBlank || _isManual) {
      answer = _blankCtl.text.trim();
    } else {
      answer = '$_selected';
    }

    setState(() => _submitting = true);
    final result = await StudentService().submitQuestion(
      questionId: ((_current?['id'] as num?) ?? 0).toInt(),
      selectedAnswer: answer,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _submitting = false;
      _current = {...?_current, 'answered': true, 'myAnswer': answer};
    });
    // 作答状态由后端落库；主观题 isCorrect 为 null，不走“自动进入下一题”
    if (autoAdvance && result?['isCorrect'] == true && _hasMore) {
      AppFeedback.success(context, '回答正确');
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted && _result != null) _next();
      });
    }
  }

  void _next() {
    if (!_hasMore) return;
    final cached = _cachedNext;
    final existing = cached != null ? _existingResultOf(cached) : null;
    setState(() {
      _pageNum++;
      _currentIndex++;
      _cachedNext = null; // 消费缓存
      _resetAnswer();
      if (cached != null) {
        _current = cached;
        if (existing != null) {
          _result = existing;
          _applyMyAnswer(cached);
        }
        _isLoading = false;
        _hasMore = _pageNum < _total;
      } else {
        _isLoading = true;
      }
    });
    if (cached == null) {
      _loadQuestion();
    } else {
      _prefetchNext();
    }
  }

  void _prev() {
    if (_currentIndex <= 0) return;
    setState(() {
      _pageNum--;
      _currentIndex--;
      _cachedNext = null;
      _resetAnswer();
    });
    _loadQuestion();
  }

  void _jumpTo(int oneBased) {
    if (oneBased < 1 || oneBased > _total) return;
    setState(() {
      _pageNum = oneBased;
      _currentIndex = oneBased - 1;
      _cachedNext = null;
    });
    _loadQuestion();
  }

  /// 单选/判断：点选即自动提交
  void _onOptionTap(int idx) {
    if (_result != null || _submitting) return;
    setState(() => _selected = idx);
    if (_isAutoSubmit) _submit(autoAdvance: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: widget.title, onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _current == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              SerifText('当前筛选下暂无题目', fontSize: 15, color: AppColors.text2Of(context)),
                              const SizedBox(height: 4),
                              Text('可调整筛选条件后重试',
                                  style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
                            ],
                          ),
                        )
                      : _buildQuestion(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _current!;
    final resolved = _result != null;
    final isCorrect = _result?['isCorrect'] == true;
    final selfAssess = _result?['isCorrect'] == null;
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final typeLabel = _isMulti
        ? '多选'
        : (_isBlank
            ? '填空'
            : (_isShortAnswer
                ? '简答'
                : (_isEssay
                    ? '论述'
                    : (q['questionType'] == 'judgment' ? '判断' : '单选'))));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Row(
          children: [
            AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
            const SizedBox(width: 6),
            AppChip(label: typeLabel, type: ChipType.indigo),
            const SizedBox(width: 6),
            AppChip(label: difficultyLabel, type: ChipType.amber),
            const Spacer(),
            MonoText('第 ${_currentIndex + 1} 题', fontSize: 11, color: AppColors.text4Of(context), weight: FontWeight.w700),
          ],
        ),
        if (_total > 1) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showNavigator = !_showNavigator),
            child: Row(
              children: [
                Icon(_showNavigator ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16, color: AppColors.primaryOf(context)),
                const SizedBox(width: 4),
                MonoText('跳转题号', fontSize: 11, color: AppColors.primaryOf(context), weight: FontWeight.w600),
                const Spacer(),
                MonoText('${_currentIndex + 1}/$_total', fontSize: 10, color: AppColors.text4Of(context)),
              ],
            ),
          ),
          if (_showNavigator) ...[
            const SizedBox(height: 8),
            _buildNumberGrid(),
          ],
        ],
        const SizedBox(height: 16),
        Text(
          q['title'] as String? ?? '',
          style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textOf(context)),
        ),
        const SizedBox(height: 18),
        if (_isMulti)
          ...options.asMap().entries.map((e) => _multiOptionTile(e.key, e.value, resolved, isCorrect))
        else if (_isBlank || _isManual)
          _blankField(
            _result?['isCorrect'],
            maxLines: _isEssay ? 7 : (_isShortAnswer ? 4 : 1),
            placeholder: _isManual ? '请输入你的作答，提交后对照参考答案' : '请输入答案',
          )
        else
          ...options.asMap().entries.map((e) => _optionTile(e.key, e.value, resolved, isCorrect)),
        const SizedBox(height: 14),
        if (resolved) ...[
          _answerPanel(isCorrect, selfAssess: selfAssess),
          if (!_hasMore) ...[
            const SizedBox(height: 14),
            AppGhostButton(
              label: '已完成练习',
              fullWidth: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ] else if (!_isAutoSubmit)
          AppGradientButton(
            label: '提交答案',
            color: AppColors.primaryOf(context),
            height: 48,
            loading: _submitting,
            onPressed: () => _submit(),
          ),
        if (_total > 1) ...[
          const SizedBox(height: 16),
          _buildNavRow(),
        ],
      ],
    );
  }

  /// 上 / 下一题切换，可自由跳题查看
  Widget _buildNavRow() {
    return Row(
      children: [
        Expanded(
          child: _navButton('上一题', Icons.chevron_left_rounded,
              enabled: _currentIndex > 0, onPressed: _currentIndex > 0 ? _prev : null),
        ),
        Expanded(
          child: _navButton('下一题', Icons.chevron_right_rounded,
              iconTrailing: true, enabled: _hasMore, onPressed: _hasMore ? _next : null),
        ),
      ],
    );
  }

  Widget _navButton(String label, IconData icon,
      {required bool enabled, required VoidCallback? onPressed, bool iconTrailing = false}) {
    final fg = enabled ? AppColors.primaryOf(context) : AppColors.text4Of(context);
    final borderColor = enabled ? AppColors.primaryOf(context).withValues(alpha: 0.4) : AppColors.surfaceEdgeOf(context);
    final child = iconTrailing
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
            const SizedBox(width: 2),
            Icon(icon, size: 18, color: fg),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          ]);
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(child: child),
      ),
    );
  }

  /// 题号导航网格：点击直接跳转到对应题
  Widget _buildNumberGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var n = 1; n <= _total; n++)
          GestureDetector(
            onTap: () => _jumpTo(n),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (n - 1) == _currentIndex
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceOf(context),
                border: Border.all(
                  color: (n - 1) == _currentIndex
                      ? AppColors.primaryOf(context)
                      : AppColors.surfaceEdgeOf(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 12,
                  color: (n - 1) == _currentIndex
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text2Of(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _multiOptionTile(int idx, String text, bool resolved, bool isCorrect) {
    final correctAnswer = _result?['correctAnswer'] as String? ?? '';
    final correctSet = correctAnswer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final isSelected = _multiSelected.contains(idx);
    final isCorrectOption = resolved && correctSet.contains('$idx');

    Color bg = AppColors.surfaceOf(context);
    Color border = AppColors.surfaceEdgeOf(context);
    Color fg = AppColors.textOf(context);

    if (resolved) {
      if (isCorrectOption) {
        bg = AppColors.mossTintOf(context);
        border = AppColors.primaryOf(context);
        fg = AppColors.primaryOf(context);
      } else if (isSelected) {
        bg = AppColors.vermilionSoftOf(context);
        border = AppColors.vermilionOf(context);
        fg = AppColors.vermilionOf(context);
      }
    } else if (isSelected) {
      bg = AppColors.mossTintOf(context);
      border = AppColors.primaryOf(context);
      fg = AppColors.primaryOf(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: resolved
            ? null
            : () => setState(() {
                  if (_multiSelected.contains(idx)) {
                    _multiSelected.remove(idx);
                  } else {
                    _multiSelected.add(idx);
                  }
                }),
        child: PressableScale(
          enabled: !resolved,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isSelected || resolved ? 1.5 : 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: isSelected || isCorrectOption ? border : AppColors.ruleOf(context), width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: (isSelected || isCorrectOption)
                    ? Center(child: Icon(Icons.check, size: 13, color: isCorrectOption ? AppColors.primaryOf(context) : border))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: fg))),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _blankField(bool? outcome,
    {int maxLines = 1, String placeholder = '请输入答案'}) {
  // outcome：null=未判/主观题自评 -> 中性；true=答对；false=答错
  final resolved = outcome != null;
  final borderColor = resolved
      ? (outcome == true ? AppColors.primaryOf(context) : AppColors.vermilionOf(context))
      : AppColors.surfaceEdgeOf(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(
            color: borderColor,
            width: resolved ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: TextField(
          controller: _blankCtl,
          enabled: !resolved,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
            border: InputBorder.none,
          ),
        ),
      ),
        if (resolved) ...[
          const SizedBox(height: 8),
          Text('你的答案：${_result?['selectedAnswer'] ?? ''}',
              style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
        ],
      ],
    );
  }

  Widget _answerPanel(bool isCorrect, {bool selfAssess = false}) {
    final accent = selfAssess
        ? AppColors.amberOf(context)
        : (isCorrect ? AppColors.primaryOf(context) : AppColors.vermilionOf(context));
    final bg = selfAssess
        ? AppColors.amberSoftOf(context)
        : (isCorrect ? AppColors.mossTintOf(context) : AppColors.vermilionSoftOf(context));
    final title = selfAssess
        ? '参考答案（请自行对照核对）'
        : (isCorrect ? '回答正确' : '回答错误');
    final icon = selfAssess
        ? Icons.rate_review_outlined
        : (isCorrect ? Icons.check_circle : Icons.cancel);
    final explanation = (_result?['explanation'] as String?) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: accent)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '参考答案：${_formatCorrectAnswer(_result?['correctAnswer'] ?? '')}',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textOf(context)),
          ),
          if (!isCorrect && !selfAssess) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.library_books_outlined, size: 14, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '已加入错题本 · 连续做对 2 次将自动标记为已掌握',
                      style: TextStyle(fontSize: 11.5, color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (explanation.isNotEmpty)
            TypewriterText(
              explanation,
              style: TextStyle(
                  fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context)),
            )
          else
            Text(
              '该题暂无官方解析，请对照教材与参考答案自行理解。',
              style: TextStyle(
                  fontSize: 12, height: 1.6, color: AppColors.text3Of(context)),
            ),
        ],
      ),
    );
  }

  String _formatCorrectAnswer(String raw) {
    if (!_isMulti) return raw;
    final options = (_current?['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final indices = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (options.isEmpty) return raw;
    return indices.map((i) {
      final idx = int.tryParse(i);
      if (idx == null || idx < 0 || idx >= options.length) return i;
      return '$i.${options[idx]}';
    }).join('、');
  }

  Widget _optionTile(int idx, String text, bool resolved, bool isCorrect) {
    final correctAnswer = _result?['correctAnswer'] as String?;
    final isSelected = _selected == idx;
    final isCorrectOption = resolved && correctAnswer == '$idx';
    Color bg = AppColors.surfaceOf(context);
    Color border = AppColors.surfaceEdgeOf(context);
    Color fg = AppColors.textOf(context);

    if (resolved) {
      if (isCorrectOption) {
        bg = AppColors.mossTintOf(context);
        border = AppColors.primaryOf(context);
        fg = AppColors.primaryOf(context);
      } else if (isSelected) {
        bg = AppColors.vermilionSoftOf(context);
        border = AppColors.vermilionOf(context);
        fg = AppColors.vermilionOf(context);
      }
    } else if (isSelected) {
      bg = AppColors.mossTintOf(context);
      border = AppColors.primaryOf(context);
      fg = AppColors.primaryOf(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: resolved ? null : () => _onOptionTap(idx),
        child: PressableScale(
          enabled: !resolved,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isSelected || resolved ? 1.5 : 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: isSelected || isCorrectOption ? border : AppColors.ruleOf(context), width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: (isSelected || isCorrectOption)
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isCorrectOption ? AppColors.primaryOf(context) : border,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: fg))),
              if (resolved && isCorrectOption)
                Icon(Icons.check_circle, size: 16, color: AppColors.primaryOf(context)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
