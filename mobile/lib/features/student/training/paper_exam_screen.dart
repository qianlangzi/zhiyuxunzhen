import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// ⚠️ 已废弃：本页为早期「整卷考试」原型，与 PaperPracticeScreen
/// （AI 组卷自测，现行唯一入口）功能重叠但交互不同：本页采用「全部作答后统一判分」，
/// PaperPracticeScreen 采用「逐题作答即时判分 + 答题卡 + 成绩落盘」。
///
/// 结论（2026-09 审查）：本文件无任何路由 / import 引用，属于死代码。
/// - 若需要「真考试（先整卷作答、后交卷统一判分）」形态，应基于本页思路在
///   PaperPracticeScreen 上新增「考试模式」并补齐：上一题回填答案、成绩移出 build、
///   判分失败可重试、语义色适配；
/// - 否则可整文件删除。避免两套逻辑并行维护。
enum PaperExamStatus { configuring, answering, grading, finished }

@Deprecated('已被 PaperPracticeScreen 取代，无引用；如需整卷考试模式请基于本页思路重建')
class PaperExamScreen extends ConsumerStatefulWidget {
  const PaperExamScreen({super.key, this.title = 'AI 组卷考试', this.examTaskId});
  final String title;
  final String? examTaskId;
  @override
  ConsumerState<PaperExamScreen> createState() => _PaperExamScreenState();
}

class _PaperExamScreenState extends ConsumerState<PaperExamScreen> {
  PaperExamStatus _status = PaperExamStatus.configuring;
  String? _error;
  List<Map<String, dynamic>> _questions = const [];
  final List<Map<String, dynamic>> _answers = [];
  final List<Map<String, dynamic>> _results = [];
  int _index = 0;
  int? _selected;
  Set<int> _multiSelected = {};
  final TextEditingController _blankCtl = TextEditingController();
  int _correctCount = 0;
  int _total = 0;

  @override
  void dispose() {
    _blankCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  Future<void> _loadQuestions() async {
    if (widget.examTaskId == null) {
      setState(() {
        _error = '缺少组卷任务';
        _status = PaperExamStatus.configuring;
      });
      return;
    }
    final task = await StudentService().getPaperTask(widget.examTaskId!);
    if (!mounted) return;
    final paper = task?['paper'] as Map<String, dynamic>?;
    final list = (paper?['questions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    if (list.isEmpty) {
      setState(() {
        _error = '题库暂无可用题目';
        _status = PaperExamStatus.configuring;
      });
      return;
    }
    setState(() {
      _questions = list;
      _total = list.length;
      _answers.addAll(List.generate(list.length, (_) => <String, dynamic>{}));
      _status = PaperExamStatus.answering;
    });
  }

  Map<String, dynamic>? get _current =>
      _index < _questions.length ? _questions[_index] : null;
  String get _questionType =>
      (_current?['questionType'] as String?) ?? 'single_choice';
  bool get _isMulti => _questionType == 'multiple_choice';
  bool get _isBlank => _questionType == 'fill_blank';

  bool get _currentAnswered {
    if (_isBlank) return (_blankCtl.text.trim().isNotEmpty);
    if (_isMulti) return _multiSelected.isNotEmpty;
    return _selected != null;
  }

  String get _currentAnswerText {
    if (_isBlank) return _blankCtl.text.trim();
    if (_isMulti) {
      final l = _multiSelected.toList()..sort();
      return l.join(',');
    }
    return '$_selected';
  }

  void _saveCurrent() => _answers[_index] = {'answer': _currentAnswerText};

  void _next() {
    _saveCurrent();
    setState(() {
      _index++;
      _selected = null;
      _multiSelected = {};
      _blankCtl.clear();
    });
  }

  void _prev() {
    setState(() {
      if (_index > 0) _index--;
      _selected = null;
      _multiSelected = {};
      _blankCtl.clear();
    });
  }

  /// 交卷：逐题判题（调用判题接口，不依赖题目自带答案），出分 + 收集解析
  Future<void> _submitPaper() async {
    _saveCurrent();
    setState(() => _status = PaperExamStatus.grading);
    _results.clear();
    _correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final ans = (_answers[i]['answer'] as String?) ?? '';
      final res = await StudentService().submitQuestion(
        questionId: ((q['id'] as num?) ?? 0).toInt(),
        selectedAnswer: ans,
      );
      if (!mounted) return;
      final core = res?['isCorrect'] == true;
      _results.add({
        'isCorrect': core,
        'correctAnswer': res?['correctAnswer'] ?? '',
        'explanation': res?['explanation'] ?? '',
        'selectedAnswer': ans,
        'title': q['title'] ?? '',
        'options': q['options'] ?? const [],
        'questionType': q['questionType'] ?? '',
        'knowledgeTag': q['knowledgeTag'] ?? '',
      });
      if (core) _correctCount++;
    }
    if (!mounted) return;
    setState(() => _status = PaperExamStatus.finished);
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
    switch (_status) {
      case PaperExamStatus.configuring:
        return _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: AppColors.text4Of(context)),
                    const SizedBox(height: 12),
                    SerifText(_error!, fontSize: 15, color: AppColors.text2Of(context)),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator());
      case PaperExamStatus.answering:
        return _buildAnswering();
      case PaperExamStatus.grading:
        return const Center(child: CircularProgressIndicator());
      case PaperExamStatus.finished:
        return _buildResult();
    }
  }

  Widget _buildAnswering() {
    final q = _current!;
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final difficulty = q['difficulty'] as int? ?? 2;
    final difficultyLabel = difficulty == 1 ? '简单' : (difficulty == 3 ? '困难' : '标准');
    final typeLabel = _isMulti
        ? '多选'
        : (_isBlank ? '填空' : (q['questionType'] == 'judgment' ? '判断' : '单选'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              MonoText('考试中 · 提交后可查看答案与解析', fontSize: 11, color: AppColors.text4Of(context)),
              const Spacer(),
              MonoText('第 ${_index + 1}/$_total 题', fontSize: 11, color: AppColors.text4Of(context), weight: FontWeight.w700),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_index + 1) / _total,
          minHeight: 4,
          backgroundColor: AppColors.paper2Of(context),
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              Row(
                children: [
                  AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
                  const SizedBox(width: 6),
                  AppChip(label: typeLabel, type: ChipType.indigo),
                  const SizedBox(width: 6),
                  AppChip(label: difficultyLabel, type: ChipType.amber),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                q['title'] as String? ?? '',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              const SizedBox(height: 18),
              if (_isMulti)
                ...options.asMap().entries.map((e) => _choiceTile(e.key, e.value, multi: true))
              else if (_isBlank)
                _blankTile()
              else
                ...options.asMap().entries.map((e) => _choiceTile(e.key, e.value, multi: false)),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_index > 0) ...[
                    AppGhostButton(label: '上一题', fullWidth: false, onPressed: _prev),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _index < _total - 1
                        ? AppPrimaryButton(
                            label: '下一题',
                            fullWidth: true,
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            onPressed: _currentAnswered ? _next : null,
                          )
                        : AppGradientButton(
                            label: '交卷',
                            color: AppColors.vermilionOf(context),
                            height: 48,
                            onPressed: _currentAnswered ? _submitPaper : null,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceTile(int idx, String text, {required bool multi}) {
    final isSelected = multi ? _multiSelected.contains(idx) : _selected == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          if (multi) {
            if (isSelected) {
              _multiSelected.remove(idx);
            } else {
              _multiSelected.add(idx);
            }
          } else {
            _selected = idx;
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mossTintOf(context) : AppColors.surfaceOf(context),
            border: Border.all(
              color: isSelected ? AppColors.primaryOf(context) : AppColors.surfaceEdgeOf(context),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.ruleOf(context), width: 1.5),
                  shape: multi ? BoxShape.rectangle : BoxShape.circle,
                ),
                child: isSelected
                    ? Center(child: Icon(Icons.check, size: 13, color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 14, color: AppColors.textOf(context))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blankTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context), width: 1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: TextField(
        controller: _blankCtl,
        style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: '请输入答案', border: InputBorder.none),
      ),
    );
  }

  Widget _buildResult() {
    final accuracy = _total == 0 ? 0.0 : _correctCount / _total;
    final pass = accuracy >= 0.6;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            children: [
              Icon(pass ? Icons.emoji_events_outlined : Icons.trending_up, size: 40, color: pass ? AppColors.amberOf(context) : AppColors.primary),
              const SizedBox(height: 10),
              SerifText('考试完成', fontSize: 18, color: AppColors.textOf(context), weight: FontWeight.w700),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stat('$_correctCount', '答对', AppColors.primary),
                  _stat('$_total', '总题数', AppColors.indigoOf(context)),
                  _stat('${(accuracy * 100).toStringAsFixed(0)}%', '正确率', AppColors.amberOf(context)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ..._results.asMap().entries.map((e) => _analysisCard(e.key, e.value)),
        const SizedBox(height: 18),
        AppPrimaryButton(label: '返回', fullWidth: true, onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }

  Widget _analysisCard(int i, Map<String, dynamic> r) {
    final ok = r['isCorrect'] == true;
    final options = (r['options'] as List<dynamic>?)?.cast<String>() ?? const [];
    final correctRaw = (r['correctAnswer'] as String?) ?? '';
    final isMulti = r['questionType'] == 'multiple_choice';
    final correctText = isMulti ? _formatMulti(correctRaw, options) : correctRaw;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(
          color: ok ? AppColors.primary.withValues(alpha: 0.4) : AppColors.vermilionOf(context).withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, size: 17, color: ok ? AppColors.primary : AppColors.vermilionOf(context)),
              const SizedBox(width: 6),
              MonoText('第 ${i + 1} 题', fontSize: 11, color: AppColors.text4Of(context)),
              const Spacer(),
              Text(ok ? '正确' : '错误', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? AppColors.primary : AppColors.vermilionOf(context))),
            ],
          ),
          const SizedBox(height: 6),
          Text(r['title'] as String? ?? '', style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textOf(context))),
          const SizedBox(height: 8),
          Text('你的答案：${r['selectedAnswer'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.text2Of(context))),
          const SizedBox(height: 2),
          Text('正确答案：$correctText', style: TextStyle(fontSize: 12, color: ok ? AppColors.primary : AppColors.vermilionOf(context))),
          if ((r['explanation'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text('解析：${r['explanation']}', style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context))),
          ],
        ],
      ),
    );
  }

  String _formatMulti(String raw, List<String> options) {
    if (options.isEmpty) return raw;
    final indices = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return indices
        .map((i) {
          final idx = int.tryParse(i);
          if (idx == null || idx < 0 || idx >= options.length) return i;
          return '$i.${options[idx]}';
        })
        .join('、');
  }

  Widget _stat(String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }
}