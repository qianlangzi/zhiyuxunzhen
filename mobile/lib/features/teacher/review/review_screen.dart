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

/// 智能批阅
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    this.instanceId,
    this.studentName,
    this.assignmentTitle,
    this.itemProgressId,
  });

  /// 待复核的作业实例 ID（从作业管理传入）
  final Object? instanceId;

  /// 学生姓名 / 作业标题（用于顶部标题展示，避免显示壳数据）
  final String? studentName;
  final String? assignmentTitle;

  /// 组合包:任务项进度 ID，批阅定位与实际覆盖需透传到后端
  final int? itemProgressId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _currentTab = 0;
  bool _aiAssistLoading = false;
  final _scoreController = TextEditingController();
  final _commentController = TextEditingController();

  Map<String, dynamic>? _reviewData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviews());
  }

  Future<void> _loadReviews() async {
    Map<String, dynamic>? data;
    try {
      final rawId = widget.instanceId;
      final int instanceId;
      if (rawId is num) {
        instanceId = rawId.toInt();
      } else if (rawId is String) {
        instanceId = int.tryParse(rawId) ?? 0;
      } else {
        instanceId = 0;
      }
      if (instanceId > 0) {
        final raw = await TeacherService()
            .getReviewDetail(instanceId, itemProgressId: widget.itemProgressId);
        if (raw != null) {
          final total = raw['totalScore'] as num?;
          data = {
            'instanceId': instanceId,
            'latestReviewId': raw['reviewId'],
            'aiScore': total?.toInt(),
            'aiScoreLevel': raw['aiScoreLevel'],
            'reviewComment': raw['reviewComment'],
            'defaultScore': total?.toString(),
            'defaultComment': raw['reviewComment'],
            'reviewerType': raw['reviewerType'],
            'medicalRecordText': raw['medicalRecordText'],
            'deductions': raw['deductions'],
            'formatShieldPassed': raw['formatShieldPassed'],
            'formatShieldDetail': raw['formatShieldDetail'],
          };
          // 用后端真实数据回填复核表单，避免残留示例文案
          _scoreController.text = total?.toString() ?? '';
          final comment = raw['reviewComment'] as String? ?? '';
          _commentController.text = comment;
        }
      }
    } catch (e) {
      // 兜底：加载异常时也结束 loading，避免页面永久转圈、无法返回
      debugPrint('loadReviews error: $e');
    }
    if (mounted) {
      setState(() {
        _reviewData = data;
        _isLoading = false;
      });
    }
  }

  /// AI 复核辅助（复核建议 + 评语草稿，RAG 教材锚点）
  Future<void> _assistReview() async {
    if (_aiAssistLoading) return;
    setState(() => _aiAssistLoading = true);
    final data = _reviewData;
    final instanceId = (data?['instanceId'] as num?)?.toInt() ?? 1;
    final result = await TeacherService().getReviewAssist(instanceId);
    if (!mounted) return;
    setState(() => _aiAssistLoading = false);
    if (result == null) {
      AppFeedback.error(context, 'AI 暂不可用，无法生成复核建议');
      return;
    }
    final commentDraft = result['commentDraft'] as String? ?? '';
    final suggestions = (result['suggestions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (commentDraft.isNotEmpty) {
      _commentController.text = commentDraft;
    }
    _showAssistSheet(suggestions, commentDraft);
  }

  void _showAssistSheet(List<Map<String, dynamic>> suggestions, String commentDraft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SerifText('AI 复核辅助 · 仅供参考', fontSize: 17)),
                  const AppChip(label: 'AI', type: ChipType.moss),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('逐条复核 AI 批阅项，评语草稿已填入下方，可修改后再提交', fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (suggestions.isNotEmpty) ...[
                      _assistBlock('复核建议', ''),
                      ...suggestions.asMap().entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MonoText('${e.value['scoreItem'] ?? '批阅项'}',
                                      fontSize: 11, color: AppColors.primaryOf(context)),
                                ),
                                _verdictChip('${e.value['verdict'] ?? ''}'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('${e.value['reason'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.textOf(context), height: 1.6)),
                            if ((e.value['textbookRef'] as String?)?.isNotEmpty ?? false)
                              MonoText('教材：${e.value['textbookRef']}',
                                  fontSize: 11, color: AppColors.text3Of(context)),
                          ],
                        ),
                      )),
                    ],
                    if (commentDraft.isNotEmpty)
                      _assistBlock('评语草稿', commentDraft),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verdictChip(String verdict) {
    final (label, chipType) = switch (verdict) {
      'agree' => ('同意', ChipType.moss),
      'disagree' => ('争议', ChipType.vermilion),
      'uncertain' => ('存疑', ChipType.amber),
      _ => (verdict, ChipType.default_),
    };
    return AppChip(label: label, type: chipType, fontSize: 10);
  }

  Widget _assistBlock(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(title.toUpperCase(), fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.06),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(content,
                style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context), height: 1.6)),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final raw = _scoreController.text.trim();
    final score = int.tryParse(raw);
    if (raw.isEmpty || score == null) {
      AppFeedback.error(context, '请输入有效的数字分数');
      return;
    }
    if (score < 0 || score > 100) {
      AppFeedback.error(context, '分数应在 0 ~ 100 之间');
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: '提交复核',
      content: '最终成绩以教师复核为准（$score 分），提交后写入审计日志并同步给学生。确认提交？',
      confirmText: '提交',
    );
    if (!ok) return;
    if (!mounted) return;

    // Mock 模式：维持原有的模拟提交示意
    if (ApiConfig.useMockAuth) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      AppFeedback.success(context, '复核已提交 · $score 分');
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(RouteNames.teacherAssignments);
      }
      return;
    }

    // 真实模式：调用「教师人工覆盖 AI 批阅」接口，成绩/评语真正落库
    final data = _reviewData;
    final instanceId = (data?['instanceId'] as num?)?.toInt();
    final overrideFromReviewId = (data?['latestReviewId'] as num?)?.toInt();
    if (instanceId == null || overrideFromReviewId == null) {
      AppFeedback.error(context, '缺少批阅记录，无法提交复核');
      return;
    }
    final result = await TeacherService().overrideReview(
      instanceId, {
      'overrideFromReviewId': overrideFromReviewId,
      'totalScore': score,
      'reviewComment': _commentController.text.trim(),
    }, itemProgressId: widget.itemProgressId);
    if (!mounted) return;
    if (result == null) {
      AppFeedback.error(context, '复核提交失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '复核已提交 · $score 分');
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.teacherAssignments);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context),
            _buildReviewTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 90),
                      children: [
                        _buildFormatShieldResult(),
                        _buildRecordSection(),
                        _buildAiScoreCard(),
                        _buildOverrideSection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 展示学生真实大病历正文；无数据时给空态，杜绝写死示例
  Widget _buildRecordSection() {
    final data = _reviewData;
    final recordText = (data?['medicalRecordText'] as String?)?.trim() ?? '';
    if (recordText.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SerifText('大病历正文', fontSize: 13, color: AppColors.primaryOf(context)),
            const SizedBox(height: 10),
            MonoText('暂无可展示的大病历内容', fontSize: 11, color: AppColors.text3Of(context)),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SerifText('大病历正文', fontSize: 13, color: AppColors.primaryOf(context)),
          const SizedBox(height: 8),
          Text(
            recordText,
            style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context), height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final data = _reviewData;
    final studentName = widget.studentName?.isNotEmpty == true
        ? widget.studentName!
        : (data?['studentName'] as String? ?? '学生');
    final assignmentName = widget.assignmentTitle?.isNotEmpty == true
        ? widget.assignmentTitle!
        : (data?['assignmentName'] as String? ?? '作业');
    return AppBackAppBar(
      title: '$studentName · $assignmentName',
      onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherAssignments),
      action: const AppIconButton(icon: Icon(Icons.download_outlined, size: 20)),
    );
  }

  Widget _buildReviewTabs() {
    final tabs = ['大病历', 'AI 批阅', '教师复核', '思维树'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == _currentTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.primaryOf(context) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? AppColors.primaryOf(context) : AppColors.text3Of(context),
                      fontFamily: 'JetBrainsMono',
                      letterSpacing: 0.04,
                      fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFormatShieldResult() {
    final data = _reviewData;
    final shieldPassed = data?['formatShieldPassed'] as bool?;
    final shieldDetail = data?['formatShieldDetail'] as String? ?? '';

    // 后端未返回真实格式校验信息时，展示中性提示而非写死示例
    final passed = shieldPassed ?? false;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: shieldPassed == null
            ? AppColors.surfaceOf(context)
            : AppColors.mossTintOf(context),
        border: Border.all(
          color: shieldPassed == null
              ? AppColors.surfaceEdgeOf(context)
              : AppColors.mossSoftOf(context),
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            shieldPassed == null
                ? Icons.shield_outlined
                : Icons.shield,
            size: 16,
            color: shieldPassed == null
                ? AppColors.text3Of(context)
                : AppColors.primaryOf(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '格式盾牌 · ${shieldPassed == null ? "暂无校验信息" : (passed ? "通过" : "未通过")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: shieldPassed == null
                        ? AppColors.text3Of(context)
                        : (passed ? AppColors.moss : AppColors.vermilionOf(context)),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (shieldDetail.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  MonoText(shieldDetail, fontSize: 11),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiScoreCard() {
    final data = _reviewData;
    final aiScore = data?['aiScore'] as int?;
    final aiScoreLevel = data?['aiScoreLevel'] as String? ?? '';
    final deductionsRaw = (data?['deductions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final deductions = deductionsRaw.map((d) {
      final name = d['name'] as String? ?? '';
      final desc = d['description'] as String? ?? '';
      final points = d['points'] as String? ?? '-0';
      return (name, desc, points);
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryOf(context), AppColors.moss2],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: MonoText('AI REVIEW', fontSize: 10, color: AppColors.onPrimaryOf(context).withValues(alpha: 0.4), letterSpacing: 0.14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
'${aiScore?.toString() ?? '--'}',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimaryOf(context),
                      height: 1,
                      letterSpacing: -0.03,
                    ),
                  ),
                  Text(' / 100', style: TextStyle(fontSize: 14, color: AppColors.onPrimarySoftOf(context))),
                  const SizedBox(width: 8),
Text(aiScoreLevel, style: TextStyle(fontSize: 12, color: AppColors.onPrimaryLightOf(context), fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 12),
              ...deductions.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: AppColors.onPrimaryOf(context).withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppRadius.sm),
                    bottomRight: Radius.circular(AppRadius.sm),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: AppColors.onPrimarySoftOf(context)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 12, color: AppColors.onPrimaryLightOf(context), height: 1.5),
                                children: [
                                  TextSpan(text: '${d.$1} · ', style: TextStyle(color: AppColors.onPrimaryOf(context), fontWeight: FontWeight.bold)),
                                  TextSpan(text: d.$2),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            d.$3,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              color: AppColors.vermilionSoftOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
              if (deductions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: MonoText(
                    '暂无扣分明细，可参考 AI 评语',
                    fontSize: 11,
                    color: AppColors.onPrimaryLightOf(context),
                  ),
                ),
              AiGeneratedNote(color: AppColors.onPrimaryLightOf(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideSection() {
    final data = _reviewData;
    final defaultScore = data?['defaultScore']?.toString() ?? '';
    final defaultComment = data?['defaultComment'] as String? ?? '';

    // 已由 _loadReviews 用后端真实数据回填；此处仅在缺失时兜底为空串
    if (data != null && data['defaultScore'] != null && _scoreController.text.isEmpty) {
      _scoreController.text = defaultScore;
    }
    if (data != null && data['defaultComment'] != null && _commentController.text.isEmpty) {
      _commentController.text = defaultComment;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              const SizedBox(width: 6),
              Expanded(
                child: MonoText('教师复核 · 可覆盖', fontSize: 11, color: AppColors.amberOf(context), letterSpacing: 0.1),
              ),
              AppGhostButton(
                label: _aiAssistLoading ? 'AI 复核中…' : 'AI 复核辅助',
                small: true,
                onPressed: _aiAssistLoading ? null : _assistReview,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '最终成绩以教师复核为准。所有覆盖操作写入审计日志。',
            style: TextStyle(fontSize: 12, color: AppColors.text2Of(context)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const EyebrowText('调整分数'),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _scoreController,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(color: AppColors.amberOf(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(color: AppColors.amberOf(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
             MonoText('/ 100', fontSize: 11, color: AppColors.text3Of(context)),
              const Spacer(),
              AppPrimaryButton(label: '提交复核', small: true, onPressed: _submitReview),
            ],
          ),
          const SizedBox(height: 10),
          const EyebrowText('补充评语'),
          const SizedBox(height: 4),
          TextField(
            maxLines: 3,
            style: const TextStyle(fontSize: 12.5, height: 1.55),
            decoration: InputDecoration(
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
            controller: _commentController,
          ),
        ],
      ),
    );
  }
}