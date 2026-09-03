import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 主观题（简答/论述）AI 批改页（教师端）
///
/// 完整业务闭环：
///  1. 加载任务上下文（题目 / 学生答案 / 评分要点 / 关联 ID）；
///  2. 点击「AI 批阅」→ 实时调用 AI 中台，结果落库并更新任务项为「待复核(4)」；
///  3. 教师查看 AI 评分 / 维度 / 依据 / 改进建议，可修改分数与评语；
///  4. 点击「确认提交」→ 教师复核落库（TEACHER），任务项状态置为「已完成(5)」。
///
/// 数据真实性约束：
///  - 无 mock 数据兜底；后端返回空 / 数据不可用时统一展示「暂无数据」；
///  - AI 结果不造假，评分要点为空时由 AI 按通用医学要点评阅并在界面明示。
class EssayReviewScreen extends ConsumerStatefulWidget {
  const EssayReviewScreen({
    super.key,
    required this.itemProgressId,
    this.studentName,
    this.assignmentTitle,
  });

  /// 组合包:任务项进度 ID（主观题所在任务项），来自批阅队列
  final int itemProgressId;
  final String? studentName;
  final String? assignmentTitle;

  @override
  ConsumerState<EssayReviewScreen> createState() => _EssayReviewScreenState();
}

class _EssayReviewScreenState extends ConsumerState<EssayReviewScreen> {
  // ---- 任务上下文加载 ----
  bool _taskLoading = true;
  Map<String, dynamic>? _task;

  // ---- AI 批阅 ----
  bool _aiLoading = false;
  bool _submitting = false;
  Map<String, dynamic>? _aiResult;

  // ---- 输入 ----
  final _scoreController = TextEditingController();
  final _commentController = TextEditingController();
  final _scoringPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTask());
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    _scoringPointsController.dispose();
    super.dispose();
  }

  /// 加载主观题批阅任务上下文（题目/答案/关联 ID）
  Future<void> _loadTask() async {
    Map<String, dynamic>? data;
    try {
      data = await TeacherService().getEssayTask(widget.itemProgressId);
    } catch (e) {
      debugPrint('loadEssayTask error: $e');
      data = null;
    }
    if (!mounted) return;
    setState(() {
      _task = data;
      _taskLoading = false;
    });
    if (data != null) {
      // 回填可编辑内容：评分要点（可空，AI 会按通用医学要点评阅）
      final points = data['scoringPoints'] as String?;
      if (points != null && points.isNotEmpty) {
        _scoringPointsController.text = points;
      }
    }
  }

  /// 触发 AI 主观题批阅：结果实时落库 + 任务项状态 → 待复核(4)
  Future<void> _runAiReview() async {
    if (_aiLoading || _aiResult != null) return;
    final task = _task;
    if (task == null) return;

    final question = task['question'] as String? ?? '';
    final studentAnswer = task['studentAnswer'] as String? ?? '';
    if (question.trim().isEmpty || studentAnswer.trim().isEmpty) {
      AppFeedback.error(context, '缺少题目或学生作答，无法批阅');
      return;
    }

    setState(() => _aiLoading = true);
    Map<String, dynamic>? result;
    try {
      result = await TeacherService().essayReview({
        'question': question,
        'scoringPoints': _scoringPointsController.text.trim(),
        'studentAnswer': studentAnswer,
        if (task['instanceId'] is num)
          'instanceId': (task['instanceId'] as num).toInt(),
        'itemProgressId': widget.itemProgressId,
        if (task['questionId'] is num)
          'questionId': (task['questionId'] as num).toInt(),
        if (task['studentId'] is num)
          'studentId': (task['studentId'] as num).toInt(),
      });
    } catch (e) {
      debugPrint('essayReview error: $e');
      result = null;
    }
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      if (result != null) {
        _aiResult = result;
        final total = result['totalScore'] as num?;
        if (total != null) _scoreController.text = _fmtScore(total);
        final comment = result['reviewComment'] as String?;
        if (comment != null && comment.isNotEmpty) {
          _commentController.text = comment;
        }
      }
    });
    if (result == null) {
      AppFeedback.error(context, 'AI 批阅失败，请稍后重试');
    }
  }

  /// 教师确认提交：复核落库（TEACHER）+ 任务项状态 → 已完成(5)
  Future<void> _confirmSubmit() async {
    if (_submitting) return;
    final aiResult = _aiResult;
    if (aiResult == null) {
      AppFeedback.error(context, '请先完成 AI 批阅后再确认提交');
      return;
    }
    final task = _task;
    final instanceId = (aiResult['instanceId'] as num?)?.toInt() ??
        (task?['instanceId'] as num?)?.toInt();
    final overrideFromReviewId = (aiResult['reviewId'] as num?)?.toInt();
    if (instanceId == null || instanceId <= 0 || overrideFromReviewId == null) {
      AppFeedback.error(context, '缺少批阅记录，无法提交复核');
      return;
    }

    final scoreText = _scoreController.text.trim();
    final score = int.tryParse(scoreText);
    if (scoreText.isEmpty || score == null) {
      AppFeedback.error(context, '请输入有效的数字分数');
      return;
    }
    if (score < 0 || score > 100) {
      AppFeedback.error(context, '分数应在 0 ~ 100 之间');
      return;
    }

    final ok = await AppFeedback.confirm(
      context,
      title: '确认提交',
      content: '最终成绩以教师复核为准（$score 分），提交后写入批阅记录并同步给学生。确认提交？',
      confirmText: '提交',
    );
    if (!ok || !mounted) return;

    // mock 隔离：非真实模式不允许提交（页面在 mock 下本就展示「暂无数据」）
    if (ApiConfig.useMockAuth) {
      AppFeedback.error(context, '当前为 mock 模式，暂不支持提交');
      return;
    }

    setState(() => _submitting = true);
    Map<String, dynamic>? result;
    try {
      result = await TeacherService().overrideReview(
        instanceId,
        {
          'overrideFromReviewId': overrideFromReviewId,
          'totalScore': score,
          'reviewComment': _commentController.text.trim(),
        },
        itemProgressId: widget.itemProgressId,
      );
    } catch (e) {
      debugPrint('confirmSubmit error: $e');
      result = null;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      // 失败保留页面内容，允许重试
      AppFeedback.error(context, '提交失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '已提交 · $score 分');
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.teacherAssignments);
    }
  }

  String _fmtScore(num n) {
    if (n == n.roundToDouble() && n is! double) return n.toInt().toString();
    final d = n.toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final studentName =
        widget.studentName?.isNotEmpty == true ? widget.studentName! : '学生';
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '$studentName · 主观题批改',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.teacherAssignments),
            ),
            Expanded(
              child: _taskLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final task = _task;
    if (task == null) {
      // 后端返回空 / 任务不可用 → 统一「暂无数据」，不展示任何伪造内容
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.ruleSoftOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined,
                  size: 30, color: AppColors.text4Of(context)),
            ),
            const SizedBox(height: 16),
            SerifText('暂无数据', fontSize: 16, color: AppColors.text2Of(context)),
            const SizedBox(height: 6),
            MonoText('未找到该主观题批阅任务，或数据尚未生成',
                fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
      );
    }

    final question = task['question'] as String? ?? '（未提供题目）';
    final studentAnswer = task['studentAnswer'] as String? ?? '';
    final hasAi = _aiResult != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _buildTaskHeader(task),
        const SizedBox(height: 12),
        _buildSectionCard('题目', question),
        const SizedBox(height: 10),
        _buildSectionCard(
          '学生作答',
          studentAnswer.isEmpty ? '（学生尚未作答）' : studentAnswer,
          muted: !hasAi,
        ),
        const SizedBox(height: 10),
        _buildScoringPointsCard(),
        const SizedBox(height: 10),
        if (hasAi) ..._buildAiResult(ai: _aiResult!) else _buildAiGate(),
        if (hasAi) ...[
          const SizedBox(height: 10),
          _buildTeacherConfirmCard(),
        ],
      ],
    );
  }

  Widget _buildTaskHeader(Map<String, dynamic> task) {
    final assignmentTitle = task['assignmentTitle'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryOf(context), AppColors.moss2],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.onPrimaryOf(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.edit_note_rounded,
                size: 20, color: AppColors.onPrimaryOf(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (assignmentTitle.isNotEmpty)
                  SerifText(assignmentTitle,
                      fontSize: 14, color: AppColors.onPrimaryOf(context)),
                const SizedBox(height: 2),
                MonoText('主观题 · AI 批改',
                    fontSize: 10, color: AppColors.onPrimaryLightOf(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, String content, {bool muted = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SerifText(title, fontSize: 13, color: AppColors.primaryOf(context)),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: muted
                  ? AppColors.text3Of(context)
                  : AppColors.textOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringPointsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(
            color: _aiResult != null
                ? AppColors.surfaceEdgeOf(context)
                : AppColors.amberOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '评分要点（可选）',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context)),
              ),
              const AppChip(label: 'AI 参考', type: ChipType.moss, fontSize: 10),
            ],
          ),
          const SizedBox(height: 4),
          MonoText('留空时 AI 将按通用医学要点评阅，可在此补充后重新触发',
              fontSize: 10, color: AppColors.text3Of(context)),
          const SizedBox(height: 10),
          TextField(
            controller: _scoringPointsController,
            maxLines: 4,
            minLines: 3,
            enabled: _aiResult == null,
            style: const TextStyle(fontSize: 12.5, height: 1.6),
            decoration: InputDecoration(
              hintText: '例如：\n要点完整性（40分）\n逻辑性（30分）\n专业性（30分）……',
              filled: true,
              fillColor: AppColors.bgOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.ruleOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.ruleOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.amberOf(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI 结果展示：评分 + 维度 + 依据 + 改进建议 + 错误明细
  List<Widget> _buildAiResult({required Map<String, dynamic> ai}) {
    final total = ai['totalScore'] as num?;
    final comment = ai['reviewComment'] as String? ?? '';
    final dimensions =
        (ai['dimensions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    final mistakes =
        (ai['mistakes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryOf(context), AppColors.moss2],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  total == null ? '-' : _fmtScore(total),
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontFamilyFallback: const [
                      'Songti SC',
                      'STSong',
                      'Noto Serif CJK SC'
                    ],
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimaryOf(context),
                    height: 1,
                  ),
                ),
                Text(' / 100',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onPrimaryLightOf(context)
                            .withValues(alpha: 0.9))),
                const SizedBox(width: 8),
                if (comment.isNotEmpty)
                  Expanded(
                    child: Text(
                      comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.onPrimaryLightOf(context)
                              .withValues(alpha: 0.9)),
                    ),
                  ),
              ],
            ),
            if (dimensions.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...dimensions.map((d) => _dimensionRow(d)),
            ],
          ],
        ),
      ),
      if (mistakes.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.vermilionSoftOf(context),
            border:
                Border.all(color: AppColors.vermilionOf(context).withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoText('错误明细 · 扣分',
                  fontSize: 11,
                  color: AppColors.vermilionOf(context),
                  letterSpacing: 0.06),
              const SizedBox(height: 8),
              ...mistakes.asMap().entries.map((e) => Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: e.key > 0
                        ? BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: AppColors.vermilionOf(context)
                                      .withValues(alpha: 0.45)),
                            ),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${e.value['location'] ?? ''} · ${e.value['comment'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: AppColors.textOf(context)),
                              ),
                            ),
                            if ((e.value['deduction'] as num?) != null)
                              Text(
                                '-${_fmtScore(e.value['deduction'] as num)}',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontFamilyFallback: kCjkMonoFallback,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.vermilionOf(context),
                                ),
                              ),
                          ],
                        ),
                        if (((e.value['type'] as String?)?.isNotEmpty ??
                                false) ||
                            ((e.value['severity'] as String?)?.isNotEmpty ??
                                false))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: MonoText(
                              [
                                e.value['type'],
                                e.value['severity'],
                              ]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(' · '),
                              fontSize: 10,
                              color: AppColors.text3Of(context),
                            ),
                          ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _dimensionRow(Map<String, dynamic> d) {
    final name = d['name'] as String? ?? '维度';
    final score = d['score'] as num?;
    final maxScore = d['maxScore'] as num?;
    final basis = d['basis'] as String? ?? '';
    final suggestion = d['suggestion'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryOf(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimaryOf(context))),
              ),
              if (score != null)
                Text(
                  '${_fmtScore(score)} / ${maxScore == null ? '-' : _fmtScore(maxScore)}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: kCjkMonoFallback,
                    fontSize: 12,
                    color: AppColors.onPrimaryLightOf(context),
                  ),
                ),
            ],
          ),
          if (basis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('依据：$basis',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.onPrimaryLightOf(context)
                        .withValues(alpha: 0.9))),
          ],
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('建议：$suggestion',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.onPrimaryLightOf(context)
                        .withValues(alpha: 0.9))),
          ],
        ],
      ),
    );
  }

  Widget _buildAiGate() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(color: AppColors.amberOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, size: 26, color: AppColors.amberOf(context)),
          const SizedBox(height: 8),
          Text(
            'AI 批改',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context)),
          ),
          const SizedBox(height: 4),
          Text(
            '点击后 AI 将按评分要点对学生作答进行维度评分并生成评语',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.text3Of(context),
                height: 1.5),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: _aiLoading ? 'AI 批阅中…' : 'AI 批阅',
            onPressed: _aiLoading ? null : _runAiReview,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherConfirmCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(color: AppColors.amberOf(context), style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit, size: 12, color: AppColors.amberOf(context)),
              SizedBox(width: 6),
              Text('教师复核 · 可覆盖',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.amberOf(context),
                      letterSpacing: 0.1)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '可修改 AI 分数与评语，最终成绩以教师复核为准。',
            style: TextStyle(
                fontSize: 12, color: AppColors.text3Of(context)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('调整分数',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textOf(context))),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _scoreController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context)),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: AppColors.surfaceOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(color: AppColors.amberOf(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(color: AppColors.amberOf(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('/ 100',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.text3Of(context))),
              const Spacer(),
              AppPrimaryButton(
                label: _submitting ? '提交中…' : '确认提交',
                small: true,
                onPressed: _submitting ? null : _confirmSubmit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('补充评语',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textOf(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _commentController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12.5, height: 1.55),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.ruleOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.amberOf(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
