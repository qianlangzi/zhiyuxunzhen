import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';
import 'widgets/paper_config_form.dart';
import 'self_test_record_store.dart';
import 'self_test_history_screen.dart';

/// AI 组卷练习页（P2-4 学生自测卷）
///
/// 一键生成个性化自测卷（AI 选题组卷，薄弱点优先 + 难度进阶），逐题作答并实时判题，
/// 全部完成后展示自测成绩单。AI 不可用时后端自动规则组卷兜底。
///
/// 2026-09 重构要点：
/// 1. 支持「上一题 / 答题卡」自由跳题：每题判题结果按题缓存（_results），切题恢复
///    选中态与解析；已判分题锁定不可改，未判分题不锁进度，保证成绩口径一致；
/// 2. 成绩落盘从 build() 移出，仅在「完成自测」时显式触发一次并 await，杜绝重复/丢失；
/// 3. 判题接口返回失败（null）提示错误、不锁题，可重试，避免重复点提交重复判题；
/// 4. 正确 / 错误等颜色全部走 Of(context) 语义色，夜间模式自动提亮。
class PaperPracticeScreen extends ConsumerStatefulWidget {
  const PaperPracticeScreen({
    super.key,
    this.title = 'AI 组卷自测',
    this.focusTags = const [],
    this.difficulty,
    this.count = 10,
  });

  final String title;
  final List<String> focusTags;
  final int? difficulty;
  final int count;

  @override
  ConsumerState<PaperPracticeScreen> createState() => _PaperPracticeScreenState();
}

class _PaperPracticeScreenState extends ConsumerState<PaperPracticeScreen> {
  bool _configDone = false;
  bool _generating = false;
  bool _isLoading = true;
  String? _error;
  String? _taskId;
  int _pollTick = 0;
  Map<String, dynamic>? _paper;
  List<Map<String, dynamic>> _questions = const [];

  /// 每题判题结果（与 _questions 一一对应，未判分为 null）
  List<Map<String, dynamic>?> _results = const [];

  // 当前答题状态
  int _index = 0;
  Map<String, dynamic>? _result;
  int? _selected;
  Set<int> _multiSelected = {};
  final TextEditingController _blankCtl = TextEditingController();
  bool _submitting = false;
  int _correctCount = 0;

  /// 每题分值（来自组卷配置），本地打分用
  double _scorePerQuestion = 2;

  @override
  void dispose() {
    _blankCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _configDone = false;
  }

  Future<void> _startGenerate(PaperConfig cfg) async {
    setState(() {
      _configDone = true;
      _generating = true;
      _error = null;
      _isLoading = true;
      _taskId = null;
      _pollTick = 0;
      _index = 0;
      _result = null;
      _selected = null;
      _multiSelected = {};
      _correctCount = 0;
      _scorePerQuestion = cfg.scorePerQuestion;
    });
    final t = await StudentService().submitPaperTask(
      count: cfg.count,
      difficulty: cfg.difficulty,
      questionTypes: cfg.questionTypes,
      departments: cfg.departments,
      knowledgeTags: cfg.knowledgeTags,
    );
    if (!mounted) return;
    final tid = (t?['taskId'] as String?) ?? (t?['id'] as String?);
    if (tid == null) {
      setState(() {
        _isLoading = false;
        _generating = false;
        _error = '提交组卷任务失败，请稍后重试';
      });
      return;
    }
    setState(() => _taskId = tid);
    const maxTick = 60;
    while (_pollTick < maxTick) {
      await Future<void>.delayed(const Duration(seconds: 2));
      _pollTick++;
      final task = await StudentService().getPaperTask(tid);
      if (!mounted) return;
      final status = (task?['status'] as String?) ?? 'PENDING';
      if (status == 'SUCCEEDED') {
        final paper = task?['paper'] as Map<String, dynamic>?;
        final list = (paper?['questions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) {
          setState(() {
            _isLoading = false;
            _generating = false;
            _error = '题库暂无可用题目，无法生成自测卷';
          });
          return;
        }
        StudentService().track('paper_generate', detail: '${(paper?['weakTags'] as List<dynamic>?)?.join(',')}');
        setState(() {
          _paper = paper;
          _questions = list;
          _results = List<Map<String, dynamic>?>.filled(list.length, null);
          _isLoading = false;
          _generating = false;
        });
        return;
      }
      if (status == 'FAILED_FINAL' || status == 'FAILED_RETRYABLE') {
        setState(() {
          _isLoading = false;
          _generating = false;
          _error = (task?['errorMessage'] as String?) ?? '组卷失败，请重试';
        });
        return;
      }
      if (mounted && _generating) setState(() {});
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _generating = false;
        _error = _taskId != null ? '组卷超时，请稍后重试（任务号 $_taskId）' : '组卷超时，请稍后重试';
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _configDone = false;
      _isLoading = false;
      _paper = null;
      _questions = const [];
      _results = const [];
      _index = 0;
      _result = null;
      _selected = null;
      _multiSelected = {};
      _blankCtl.clear();
      _correctCount = 0;
    });
  }

  Map<String, dynamic>? get _current => _index < _questions.length ? _questions[_index] : null;

  String get _questionType => (_current?['questionType'] as String?) ?? 'single_choice';
  bool get _isMulti => _questionType == 'multiple_choice';
  bool get _isBlank => _questionType == 'fill_blank';
  bool get _isFinished => _index >= _questions.length;

  /// 当前题是否已判分（用于上一题回看时锁定）
  bool get _currentResolved =>
      _index >= 0 && _index < _results.length && _results[_index] != null;

  /// 已判分题数
  int get _answeredCount => _results.where((r) => r != null).length;

  /// 交卷：所有题均判分后进入成绩单并落盘一次
  bool get _canFinish => _questions.isNotEmpty && _answeredCount >= _questions.length;

  /// 判分成功后缓存本题结果（保留选中态供红绿标识展示，切题时由 _restoreSelection 重置）
  void _cacheResult(int qIndex, Map<String, dynamic> result) {
    setState(() {
      _results[qIndex] = result;
      _result = result;
      if (result['isCorrect'] == true) _correctCount++;
    });
  }

  /// 跳到指定题；若该题已判分则恢复展示（选项着绿色/红色并展示解析）
  void _jumpTo(int target) {
    if (target < 0 || target >= _questions.length) return;
    final cached = _results[target];
    setState(() {
      _index = target;
      _result = cached;
      _restoreSelection(cached);
    });
  }

  /// 从缓存恢复选项选中状态（仅展示用；判分后选项本身不可再点）
  void _restoreSelection(Map<String, dynamic>? cached) {
    _selected = null;
    _multiSelected = {};
    _blankCtl.clear();
    if (cached == null) return;
    final raw = (cached['selectedAnswer'] as String?) ?? '';
    if (_isBlank) {
      _blankCtl.text = raw;
      return;
    }
    if (_isMulti) {
      _multiSelected = raw
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toSet();
      return;
    }
    _selected = int.tryParse(raw.trim());
  }

  Future<void> _submit() async {
    if (_isBlank) {
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
    } else if (_isBlank) {
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

    // 判题失败：提示错误且不锁题，可重试；防止 result null 时反复点提交重复判题
    if (result == null || result.isEmpty) {
      setState(() => _submitting = false);
      AppFeedback.error(context, '判题失败，请检查网络后重试');
      return;
    }

    final qIndex = _index;
    _cacheResult(qIndex, result);
    setState(() => _submitting = false);

    // 全部答完：提示可进入成绩单（成绩由 _finish 落盘一次）
    if (_answeredCount >= _questions.length) {
      AppFeedback.success(context, '全部作答完成，可交卷查看成绩');
    }
  }

  /// 成绩单入口：保存记录（唯一落盘点）后展示
  Future<void> _finish() async {
    final total = _questions.length;
    if (total == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    final source = (_paper?['source'] as String?) ?? 'RULE';
    final score = _scorePerQuestion * _correctCount;
    final totalScore = _scorePerQuestion * total;
    await SelfTestRecordStore.add(SelfTestRecord(
      epoch: DateTime.now().millisecondsSinceEpoch,
      score: score,
      totalScore: totalScore,
      correct: _correctCount,
      count: total,
      scorePerQuestion: _scorePerQuestion,
      source: source,
      questionTypes: const [],
    ));
    if (!mounted) return;
    setState(() => _index = _questions.length); // 展示成绩单
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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _generating) return _buildGenerating();
    if (!_configDone && _error == null) return _buildConfig();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
            const SizedBox(height: 12),
            SerifText(_error!, fontSize: 15, color: AppColors.text2Of(context)),
            const SizedBox(height: 16),
            AppGhostButton(label: '重新配置', fullWidth: false, onPressed: _retry),
          ],
        ),
      );
    }
    if (_isFinished) {
      return _buildSummary();
    }
    return _buildQuestion();
  }

  Widget _buildConfig() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [PaperConfigForm(onSubmit: _startGenerate)],
    );
  }

  Widget _buildGenerating() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 16),
        SerifText('AI 正在组卷…', fontSize: 15, color: AppColors.textOf(context)),
        const SizedBox(height: 6),
        Text('已生成 ${_pollTick * 2}s · 请稍候',
            style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
      ]),
    );
  }

  Widget _buildProgressHeader() {
    final progress = _questions.isEmpty ? 0.0 : ((_index + 1) / _questions.length).clamp(0.0, 1.0);
    final source = (_paper?['source'] as String?) ?? 'RULE';
    final isAi = source == 'AI';
    final isResolvedCurrent = _currentResolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isAi ? Icons.auto_awesome : Icons.rule,
                size: 14, color: isAi ? AppColors.primaryOf(context) : AppColors.amberOf(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                (_paper?['paperTitle'] as String?) ?? 'AI 组卷自测',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2Of(context)),
              ),
            ),
            MonoText('${_index + 1}/${_questions.length} 题',
                fontSize: 11,
                color: AppColors.text4Of(context),
                weight: FontWeight.w700),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppColors.paper2Of(context),
                  valueColor: AlwaysStoppedAnimation(
                      isAi ? AppColors.primaryOf(context) : AppColors.amberOf(context)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isResolvedCurrent)
              AppStatusBadge(label: '已作答', type: StatusBadgeType.done)
            else
              AppStatusBadge(label: '待作答', type: StatusBadgeType.neutral),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final q = _current!;
    final resolved = _result != null;
    final isCorrect = _result?['isCorrect'] == true;
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final typeLabel = _isMulti ? '多选' : (_isBlank ? '填空' : (q['questionType'] == 'judgment' ? '判断' : '单选'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        _buildProgressHeader(),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.subject_outlined,
                size: 12, color: AppColors.text4Of(context)),
            const SizedBox(width: 4),
            MonoText(q['knowledgeTag'] as String? ?? '综合',
                fontSize: 11, color: AppColors.text4Of(context)),
            const SizedBox(width: 10),
            Icon(Icons.tune_rounded,
                size: 12, color: AppColors.text4Of(context)),
            const SizedBox(width: 4),
            MonoText('$typeLabel · $difficultyLabel',
                fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          q['title'] as String? ?? '',
          style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textOf(context)),
        ),
        const SizedBox(height: 18),
        if (_isMulti)
          ...options.asMap().entries.map((e) => _multiOptionTile(e.key, e.value, resolved, isCorrect))
        else if (_isBlank)
          _blankField(resolved, isCorrect)
        else
          ...options.asMap().entries.map((e) => _optionTile(e.key, e.value, resolved, isCorrect)),
        const SizedBox(height: 14),
        if (resolved) ...[
          _answerPanel(isCorrect),
          const SizedBox(height: 14),
        ],
        _buildBottomBar(),
        if (_questions.length > 1) ...[
          const SizedBox(height: 12),
          _bottomNav(),
        ],
      ],
    );
  }

  /// 底部主操作（随题状态变化）
  Widget _buildBottomBar() {
    final resolved = _result != null;
    final isLast = _index == _questions.length - 1;
    if (!resolved) {
      return AppGradientButton(
        label: '提交答案',
        color: AppColors.primaryOf(context),
        height: 48,
        loading: _submitting,
        onPressed: _submit,
      );
    }
    if (isLast) {
      // 最后一题判分后：可交卷则进成绩单；还有未答则引导到答题卡补答
      if (_canFinish) {
        return AppPrimaryButton(
          label: '完成自测 · 查看成绩',
          fullWidth: true,
          icon: const Icon(Icons.emoji_events_outlined, size: 16),
          onPressed: _finish,
        );
      }
      return AppGhostButton(
        label: '还有 ${_questions.length - _answeredCount} 题未答，去补答',
        fullWidth: true,
        icon: const Icon(Icons.grid_view_rounded, size: 16),
        onPressed: _showPalette,
      );
    }
    // 非最后一题已判分：下一题
    return AppPrimaryButton(
      label: '下一题',
      fullWidth: true,
      icon: const Icon(Icons.arrow_forward, size: 16),
      onPressed: () => _jumpTo(_index + 1),
    );
  }

  /// 底部导航：上一题 + 答题卡（回看/跳题）
  Widget _bottomNav() {
    final primary = AppColors.primaryOf(context);
    final fg = _index > 0 ? primary : AppColors.text4Of(context);
    final borderColor = _index > 0
        ? primary.withValues(alpha: 0.4)
        : AppColors.surfaceEdgeOf(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _index > 0 ? () => _jumpTo(_index - 1) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chevron_left_rounded, size: 18, color: fg),
                  const SizedBox(width: 2),
                  Text('上一题',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: () => _showPalette(),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border.all(color: primary.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grid_view_rounded, size: 16, color: primary),
                  const SizedBox(width: 6),
                  MonoText('答题卡 $_answeredCount/${_questions.length}',
                      fontSize: 12, color: primary, weight: FontWeight.w600),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 16, color: primary),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 答题卡底部弹层：题号 + 已答状态，可跳转
  void _showPalette() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final primary = AppColors.primaryOf(sheetCtx);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(sheetCtx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SerifText('答题卡', fontSize: 16, color: AppColors.textOf(sheetCtx), weight: FontWeight.w700),
                  const Spacer(),
                  MonoText('已答 $_answeredCount/${_questions.length}',
                      fontSize: 11, color: primary, weight: FontWeight.w700),
                  if (_canFinish) ...[
                    const SizedBox(width: 8),
                    MonoText('可交卷', fontSize: 11, color: AppColors.vermilionOf(sheetCtx), weight: FontWeight.w700),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _questions.length; i++)
                  _paletteCell(sheetCtx, i),
              ]),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppGhostButton(
                      label: '关闭',
                      fullWidth: true,
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ),
                  if (_canFinish) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppPrimaryButton(
                        label: '完成自测',
                        fullWidth: true,
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          _finish();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _paletteCell(BuildContext sheetCtx, int i) {
    final isAnswered = _results[i] != null;
    final isCurrent = i == _index;
    final primary = AppColors.primaryOf(sheetCtx);
    return GestureDetector(
      onTap: () {
        Navigator.of(sheetCtx).pop();
        _jumpTo(i);
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCurrent
              ? primary.withValues(alpha: 0.15)
              : (isAnswered
                  ? AppColors.mossTintOf(sheetCtx)
                  : AppColors.ruleSoftOf(sheetCtx)),
          border: Border.all(
            color: isCurrent
                ? primary
                : (isAnswered
                    ? primary.withValues(alpha: 0.5)
                    : AppColors.surfaceEdgeOf(sheetCtx)),
            width: isCurrent ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? primary
                    : (isAnswered
                        ? AppColors.primaryOf(sheetCtx)
                        : AppColors.text3Of(sheetCtx)),
              ),
            ),
            if (isAnswered && !isCurrent)
              Icon(Icons.check, size: 10, color: AppColors.primaryOf(sheetCtx)),
          ],
        ),
      ),
    );
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
        onTap: resolved ? null : () => setState(() => _selected = idx),
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

  Widget _blankField(bool resolved, bool isCorrect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(
              color: resolved ? (isCorrect ? AppColors.primaryOf(context) : AppColors.vermilionOf(context)) : AppColors.surfaceEdgeOf(context),
              width: resolved ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: TextField(
            controller: _blankCtl,
            enabled: !resolved,
            style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
            decoration: InputDecoration(
              hintText: '请输入答案',
              hintStyle: TextStyle(fontSize: 14, color: AppColors.text4Of(context)),
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

  Widget _answerPanel(bool isCorrect) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.mossTintOf(context) : AppColors.vermilionSoftOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 18, color: isCorrect ? AppColors.primaryOf(context) : AppColors.vermilionOf(context)),
              const SizedBox(width: 6),
              Text(isCorrect ? '回答正确' : '回答错误',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isCorrect ? AppColors.primaryOf(context) : AppColors.vermilionOf(context))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '正确答案：${_formatCorrectAnswer(_result?['correctAnswer'] ?? '')}',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textOf(context)),
          ),
          const SizedBox(height: 6),
          Text(_result?['explanation'] as String? ?? '',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context))),
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

  Widget _buildSummary() {
    final total = _questions.length;
    final accuracy = total == 0 ? 0.0 : _correctCount / total;
    final pass = accuracy >= 0.6;
    final score = _scorePerQuestion * _correctCount;
    final totalScore = _scorePerQuestion * total;
    final source = (_paper?['source'] as String?) ?? 'RULE';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            children: [
              Icon(pass ? Icons.emoji_events_outlined : Icons.trending_up,
                  size: 40, color: pass ? AppColors.amberOf(context) : AppColors.primaryOf(context)),
              const SizedBox(height: 6),
              MonoText(source == 'AI' ? 'AI 组卷' : '规则组卷',
                  fontSize: 9, color: AppColors.text4Of(context)),
              const SizedBox(height: 6),
              SerifText('自测完成', fontSize: 18, color: AppColors.textOf(context), weight: FontWeight.w700),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: pass ? AppColors.mossTintOf(context) : AppColors.vermilionSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(score.toStringAsFixed(0),
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                            color: pass ? AppColors.primaryOf(context) : AppColors.vermilionOf(context))),
                    MonoText(' / $totalScore 分', fontSize: 13, color: AppColors.text3Of(context)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stat('$_correctCount', '答对', AppColors.primaryOf(context)),
                  _stat('$total', '总题数', AppColors.indigoOf(context)),
                  _stat('${(accuracy * 100).toStringAsFixed(0)}%', '正确率', AppColors.amberOf(context)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                pass ? '表现不错，继续保持！可回到「学习路径」针对薄弱点巩固。'
                    : '正确率还需提升，建议查看本卷错题解析后，进入「学习路径」针对性复习。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: '逐题回顾解析',
          fullWidth: true,
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          onPressed: () => _jumpTo(0),
        ),
        const SizedBox(height: 8),
        AppGhostButton(
          label: '查看往期自测记录',
          fullWidth: true,
          icon: const Icon(Icons.insights_outlined, size: 16),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const SelfTestHistoryScreen(),
          )),
        ),
        const SizedBox(height: 8),
        AppGhostButton(
          label: '再练一卷',
          fullWidth: true,
          onPressed: _retry,
        ),
        const SizedBox(height: 8),
        AppGhostButton(
          label: '返回',
          fullWidth: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }
}
