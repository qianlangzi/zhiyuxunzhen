import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';
import '../../../../shared/widgets/typewriter_text.dart';
import '../../training/question_practice_screen.dart';

/// 单条错题的数据模型
///
/// 容错解析后端返回的 Map：所有字段都可能缺失或类型不符，绝不抛异常。
class MistakeEntry {
  MistakeEntry.fromJson(Map<String, dynamic> m)
      : id = (m['id'] as num?)?.toInt() ?? 0,
        typeKey = m['mistakeType'] as String? ?? '',
        resolvedStatus = (m['resolvedStatus'] as num?)?.toInt() ?? 0,
        date = m['createdAt'] as String? ?? '',
        consecutiveCorrect = (m['consecutiveCorrect'] as num?)?.toInt(),
        wrongCount = (m['wrongCount'] as num?)?.toInt(),
        focusFlag = (m['focusFlag'] as num?)?.toInt(),
        // 病例错题用 caseTitle；刷题错题用 questionTitle（题干）
        title = (m['caseTitle'] as String?) ?? (m['questionTitle'] as String?) ?? '',
        evidence = m['evidenceJson'] as String? ?? '',
        tags = ((m['knowledgeTag'] as String? ?? '')
            .split(','))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        aiAnalysis = m['aiAnalysis'] is Map
            ? Map<String, dynamic>.from(m['aiAnalysis'] as Map)
            : null;

  final int id;
  final String typeKey;

  /// 复习状态：0 未复习 / 1 已复习 / 2 已掌握（标记掌握时会被就地更新）
  int resolvedStatus;

  final String date;
  final String title;
  final String evidence;
  final List<String> tags;
  Map<String, dynamic>? aiAnalysis;

  /// 进入错题本后连续答对次数 / 累计答错次数（刷题错题闭环）
  final int? consecutiveCorrect;
  final int? wrongCount;

  /// 0普通 1需加强（连续答错>=2）
  final int? focusFlag;

  bool get mastered => resolvedStatus == 2;
  bool get reviewed => resolvedStatus == 1;
  bool get needFocus => focusFlag == 1;

  /// 是否主观题（简答/论述）：走失分维度归因，不展示临床推理五阶段
  bool get isSubjective => typeKey == 'essay';

  /// 来源分组：刷题 / 问诊(SP) / 主观题。错题本筛选条按来源一级分类，
  /// 卡片角标仍展示细分类型（诊断错误 / 漏问病史 …）。
  static const _consultTypes = {
    'diagnosis', 'history', 'exam', 'record', 'communication',
  };

  String get sourceKey {
    if (typeKey == 'practice') return 'practice';
    if (typeKey == 'essay') return 'essay';
    if (_consultTypes.contains(typeKey)) return 'consult';
    return typeKey; // 未知类型自成分组，保证不丢
  }

  /// 来源分组的中文标签
  static String labelOfSource(String sourceKey) {
    switch (sourceKey) {
      case 'practice':
        return '刷题';
      case 'consult':
        return '问诊';
      case 'essay':
        return '主观题';
      default:
        return sourceKey;
    }
  }

  /// 归因：临床推理分叉阶段（客观题）/ 失分维度（主观题）
  String get aiStage => (aiAnalysis?['stage'] as String?) ?? '';

  /// 归因：分叉点对照（学生怎么想的 → 正确路径该怎么走）
  String get aiForkPoint => (aiAnalysis?['forkPoint'] as String?) ?? '';

  /// 归因：认知偏差类型
  String get aiBiasType => (aiAnalysis?['biasType'] as String?) ?? '';

  /// 分叉阶段/失分维度的中文标签
  static String labelOfStage(String? stage) {
    switch (stage) {
      case 'information':
        return '信息采集';
      case 'hypothesis':
        return '假设形成';
      case 'differential':
        return '鉴别诊断';
      case 'workup':
        return '检查选择';
      case 'conclusion':
        return '确诊处置';
      case 'completeness':
        return '要点缺失';
      case 'logic':
        return '逻辑链断裂';
      case 'professionalism':
        return '专业性不足';
      case 'expression':
        return '表达不清';
      default:
        return '';
    }
  }

  /// 认知偏差的中文标签
  static String labelOfBias(String? bias) {
    switch (bias) {
      case 'anchoring':
        return '锚定偏差';
      case 'premature_closure':
        return '过早闭合';
      case 'availability':
        return '可得性偏差';
      case 'confirmation':
        return '确认偏误';
      case 'framing':
        return '框定效应';
      case 'incomplete':
        return '覆盖不全';
      case 'unordered':
        return '结构混乱';
      case 'unsupported':
        return '论断缺依据';
      default:
        return '';
    }
  }

  /// 临床推理五阶段（客观题归因用）
  static const List<String> reasoningStages = [
    'information',
    'hypothesis',
    'differential',
    'workup',
    'conclusion',
  ];

  String get typeLabel => labelOfType(typeKey);

  /// 错题类型英文 key -> 中文显示标签
  static String labelOfType(String? type) {
    switch (type) {
      case 'diagnosis':
        return '诊断错误';
      case 'history':
        return '漏问病史';
      case 'exam':
        return '检查错误';
      case 'record':
        return '文书问题';
      case 'communication':
        return '沟通';
      case 'practice':
        return '刷题错题';
      case 'essay':
        return '主观题';
      default:
        return type ?? '未知';
    }
  }

  /// 问诊细分筛选中文标签 -> 错题类型 key（仅在来源=问诊时的二级筛选）
  static String? keywordOf(String zh) {
    switch (zh) {
      case '诊断':
        return 'diagnosis';
      case '病史':
        return 'history';
      case '检查':
        return 'exam';
      case '文书':
        return 'record';
      case '沟通':
        return 'communication';
      default:
        return null;
    }
  }

  /// 一级来源筛选标签（错题本筛选条）
  static const List<String> sourceFilterLabels = ['全部', '刷题', '问诊', '主观题'];

  /// 问诊来源下的二级细分标签（首个为「全部」，null = 不细分）
  static const List<String> consultSubLabels = ['全部', '诊断', '病史', '检查', '文书', '沟通'];
}

/// 错题卡片 —— 成长页与错题本二级页共用
///
/// 点击展开：证据引用块 → AI 归因 → 知识点标签 → 标记已掌握。
/// AI 归因的 loading / 成功 / 降级三态由组件自治，父级只提供 [onAnalyze]。
class MistakeTile extends StatefulWidget {
  const MistakeTile({
    super.key,
    required this.entry,
    required this.onAnalyze,
    this.onMarkMastered,
    this.onDrill,
    this.compact = false,
  });

  final MistakeEntry entry;

  /// 调用 AI 归因，返回解析后的结果（null 表示服务不可用）
  final Future<Map<String, dynamic>?> Function(int id) onAnalyze;

  /// 标记已掌握回调
  final ValueChanged<MistakeEntry>? onMarkMastered;

  /// 练同类题：以该错题知识点 + AI 归因标签生成巩固练习。
  /// 为 null（如成长页简略模式）时不渲染入口。
  final Future<Map<String, dynamic>?> Function(int id)? onDrill;

  /// 紧凑模式：卡片内边距更小，用于成长页的前几条
  final bool compact;

  @override
  State<MistakeTile> createState() => _MistakeTileState();
}

class _MistakeTileState extends State<MistakeTile> {
  bool _expanded = false;
  bool _analyzing = false;
  bool _drilling = false;
  Map<String, dynamic>? _drill;

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final data = await widget.onAnalyze(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      widget.entry.aiAnalysis = data ??
          {
            'status': 'DEGRADED',
            'explanation': 'AI 归因服务暂时不可用，请稍后重试。',
          };
    });
  }

  /// 练同类题：拉巩固练习卷；失败时静默（保留归因内容可用）
  Future<void> _drillPractice() async {
    if (widget.onDrill == null) return;
    setState(() => _drilling = true);
    final data = await widget.onDrill!(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _drilling = false;
      _drill = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final mastered = e.mastered;
    final accent = mastered ? AppColors.moss : AppColors.vermilionOf(context);

    return PressableScale(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: PaperCard(
          tint: accent,
          radius: AppRadius.lg,
          padding: EdgeInsets.zero,
          accent: accent,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                widget.compact ? 14 : 16, widget.compact ? 13 : 15, 16,
                _expanded ? 14 : (widget.compact ? 13 : 15),),
            child: Opacity(
              opacity: mastered ? 0.72 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3,),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          e.typeLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.04,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (mastered)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2,),
                          decoration: BoxDecoration(
                            color: AppColors.mossTintOf(context),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '已掌握',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.primaryOf(context),),
                          ),
                        ),
                      if (e.needFocus && !mastered)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2,),
                            decoration: BoxDecoration(
                              color: AppColors.vermilionOf(context)
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              '需加强',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.vermilionOf(context),),
                            ),
                          ),
                        ),
                      const Spacer(),
                      MonoText(
                        e.date.length >= 10 ? e.date.substring(0, 10) : e.date,
                        fontSize: 11,
                        color: AppColors.text4Of(context),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 17,
                        color: AppColors.text3Of(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    e.title,
                    maxLines: _expanded ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: AppColors.textOf(context),
                    ),
                  ),
                  if (_expanded) ...[
                    if (e.evidence.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _EvidenceBlock(text: e.evidence),
                    ],
                    const SizedBox(height: 10),
                    _AiAnalysisBlock(
                      entry: e,
                      analysis: e.aiAnalysis,
                      analyzing: _analyzing,
                      onRetry: _analyze,
                      onDrill: widget.onDrill == null ? null : _drillPractice,
                      drilling: _drilling,
                      drill: _drill,
                    ),
                    if (e.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: e.tags
                            .map((t) => AppChip(label: t, type: ChipType.default_))
                            .toList(),
                      ),
                    ],
                    if (!mastered && widget.onMarkMastered != null) ...[
                      const SizedBox(height: 11),
                      AppGhostButton(
                        label: '标记为已掌握',
                        small: true,
                        icon: const Icon(Icons.check_rounded, size: 13),
                        onPressed: () => widget.onMarkMastered!(e),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 证据引用块
class _EvidenceBlock extends StatelessWidget {
  const _EvidenceBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2.5, color: AppColors.ruleOf(context)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.text3Of(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 归因区块（未分析 / 分析中 / 成功 / 降级）
class _AiAnalysisBlock extends StatelessWidget {
  const _AiAnalysisBlock({
    required this.entry,
    required this.analysis,
    required this.analyzing,
    required this.onRetry,
    this.onDrill,
    this.drilling = false,
    this.drill,
  });

  final MistakeEntry entry;
  final Map<String, dynamic>? analysis;
  final bool analyzing;
  final VoidCallback onRetry;

  /// 练同类题回调（为 null 时不渲染入口）
  final VoidCallback? onDrill;
  final bool drilling;
  final Map<String, dynamic>? drill;

  String get _stageLabel => MistakeEntry.labelOfStage(entry.aiStage);
  String get _biasLabel => MistakeEntry.labelOfBias(entry.aiBiasType);

  @override
  Widget build(BuildContext context) {
    if (analyzing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryOf(context),),
            ),
            const SizedBox(width: 9),
            MonoText('AI 归因分析中…',
                fontSize: 11, color: AppColors.text3Of(context),),
          ],
        ),
      );
    }

    if (analysis == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AppGhostButton(
          label: 'AI 归因分析',
          small: true,
          icon: const Icon(Icons.auto_awesome_rounded, size: 13),
          onPressed: onRetry,
        ),
      );
    }

    final status = (analysis!['status'] as String?) ?? 'SUCCESS';
    if (status == 'DEGRADED') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.vermilionSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 16, color: AppColors.vermilionOf(context),),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                (analysis!['explanation'] as String?) ?? 'AI 归因服务暂时不可用。',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text2Of(context)),
              ),
            ),
            GestureDetector(
              onTap: onRetry,
              child: Text('重试',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.vermilionOf(context),),),
            ),
          ],
        ),
      );
    }

    final rootCause = (analysis!['rootCause'] as String?) ?? '';
    final explanation = (analysis!['explanation'] as String?) ?? '';
    final practiceHint = (analysis!['practiceHint'] as String?) ?? '';
    final tags = (analysis!['recommendedTags'] as List?)
            ?.whereType<String>()
            .toList() ??
        const [];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.mossSoftOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 13, color: AppColors.primaryOf(context),),
              const SizedBox(width: 5),
              MonoText('AI 归因',
                  fontSize: 10,
                  color: AppColors.primaryOf(context),
                  letterSpacing: 0.06,),
            ],
          ),
          // 客观题：临床推理五阶段进度条，高亮思维分叉点
          if (!entry.isSubjective && entry.aiStage.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ForkStageBar(currentStage: entry.aiStage),
          ],
          if (_stageLabel.isNotEmpty || _biasLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                if (_stageLabel.isNotEmpty)
                  _AttributionChip(
                    label: entry.isSubjective
                        ? '失分维度 · $_stageLabel'
                        : '分叉阶段 · $_stageLabel',
                    color: AppColors.vermilionOf(context),
                  ),
                if (_biasLabel.isNotEmpty)
                  _AttributionChip(
                    label: _biasLabel,
                    color: AppColors.amberOf(context),
                  ),
              ],
            ),
          ],
          // 分叉点对照：学生怎么想的 → 正确路径该怎么走
          if (entry.aiForkPoint.isNotEmpty) ...[
            const SizedBox(height: 8),
            _aiLine(context, '思维分叉点', entry.aiForkPoint),
          ],
          if (rootCause.isNotEmpty) ...[
            const SizedBox(height: 8),
            _aiLine(context, '为什么错', rootCause),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            _aiLine(context, '怎么改', explanation),
          ],
          if (practiceHint.isNotEmpty) ...[
            const SizedBox(height: 8),
            _aiLine(context, '巩固方向', practiceHint),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: tags
                  .map((t) => AppChip(label: t, type: ChipType.moss))
                  .toList(),
            ),
          ],
          // 练同类题：把归因结论变成下一次练习
          if (onDrill != null) ...[
            const SizedBox(height: 11),
            if (drilling)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryOf(context),),
                    ),
                    const SizedBox(width: 9),
                    MonoText('正在生成巩固练习…',
                        fontSize: 11, color: AppColors.text3Of(context),),
                  ],
                ),
              )
            else if (drill == null)
              AppGhostButton(
                label: '练同类题',
                small: true,
                icon: const Icon(Icons.fitness_center_rounded, size: 13),
                onPressed: onDrill,
              )
            else
              _DrillBlock(drill: drill!, knowledgeTag: tags.isNotEmpty ? tags.first : null),
          ],
        ],
      ),
    );
  }

  Widget _aiLine(BuildContext context, String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryOf(context),
          ),
        ),
        const SizedBox(height: 2),
        // AI 归因文本打字机（ChatGPT 观感），全 app 公共组件
        TypewriterText(
          content,
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.textOf(context),
          ),
        ),
      ],
    );
  }
}

/// 临床推理五阶段进度条：高亮思维分叉点
///
/// 分叉点之前的阶段视为「已走过」（中性色），分叉点高亮（朱红），之后为未达（灰）。
class _ForkStageBar extends StatelessWidget {
  const _ForkStageBar({required this.currentStage});

  final String currentStage;

  @override
  Widget build(BuildContext context) {
    final stages = MistakeEntry.reasoningStages;
    final forkIndex = stages.indexOf(currentStage);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(stages.length, (i) {
        final isFork = i == forkIndex;
        final passed = forkIndex >= 0 && i < forkIndex;
        final color = isFork
            ? AppColors.vermilionOf(context)
            : (passed ? AppColors.moss : AppColors.text4Of(context));
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 3,
                margin: EdgeInsets.only(right: i == stages.length - 1 ? 0 : 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isFork ? 1 : 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                MistakeEntry.labelOfStage(stages[i]),
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: isFork ? FontWeight.w600 : FontWeight.w400,
                  color: isFork ? color : AppColors.text4Of(context),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// 归因标签（分叉阶段 / 认知偏差）
class _AttributionChip extends StatelessWidget {
  const _AttributionChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: color,),
      ),
    );
  }
}

/// 巩固练习结果：题目列表 + 去练习入口
class _DrillBlock extends StatelessWidget {
  const _DrillBlock({required this.drill, this.knowledgeTag});

  final Map<String, dynamic> drill;
  final String? knowledgeTag;

  @override
  Widget build(BuildContext context) {
    final questions = (drill['questions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (questions.isEmpty) {
      return MonoText('暂无匹配的巩固题',
          fontSize: 11, color: AppColors.text3Of(context),);
    }
    final firstId = (questions.first['id'] as num?)?.toInt();
    final shown = questions.length > 5 ? 5 : questions.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(
            (drill['paperTitle'] as String?) ?? '巩固练习',
            fontSize: 11,
            color: AppColors.primaryOf(context),
          ),
          const SizedBox(height: 7),
          ...List.generate(shown, (i) {
            final raw = (questions[i]['title'] as String? ?? '').trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText('${i + 1}.',
                      fontSize: 11, color: AppColors.text4Of(context),),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      raw.isEmpty ? '（题干缺失）' : raw,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: AppColors.text2Of(context),),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          AppGhostButton(
            label: '去练习',
            small: true,
            icon: const Icon(Icons.play_arrow_rounded, size: 13),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuestionPracticeScreen(
                  title: '错题巩固练习',
                  knowledgeTag: knowledgeTag,
                  initialQuestionId: firstId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
