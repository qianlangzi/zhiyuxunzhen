import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../training/question_practice_screen.dart';
import '../data/student_service.dart';
import '../growth/widgets/mistake_tile.dart';

/// 错题详情二级页 —— 从错题本 / 成长页点进单条错题的专属复盘空间
///
/// 职责：完整题干 + 证据引用 + AI 归因（进页自动分析）+ 巩固练习 + 标记掌握。
/// 列表卡只负责「扫一眼」，深度复盘都在这里做，避免长列表被展开项撑乱。
///
/// [entry] 由列表页以 `extra` 直接传入（同一对象引用），在页内标记掌握后
/// 返回列表时通过 [MistakeTile.onChanged] 触发父级刷新统计。
class MistakeDetailScreen extends StatefulWidget {
  const MistakeDetailScreen({super.key, required this.entry});

  final MistakeEntry entry;

  @override
  State<MistakeDetailScreen> createState() => _MistakeDetailScreenState();
}

class _MistakeDetailScreenState extends State<MistakeDetailScreen> {
  bool _analyzing = false;
  bool _drilling = false;
  Map<String, dynamic>? _drill;

  @override
  void initState() {
    super.initState();
    // 进页自动跑 AI 归因：详情页就是复盘空间，不该让用户再手动点一次。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.entry.aiAnalysis == null) _analyze();
    });
  }

  Future<void> _analyze() async {
    if (_analyzing) return;
    setState(() => _analyzing = true);
    final data = await StudentService().analyzeMistake(widget.entry.id);
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

  /// 标记已掌握：服务端成功后回填本地状态（entry 与列表页共享引用）
  Future<void> _markMastered() async {
    final ok = await StudentService().markMistakeStatus(widget.entry.id, 2);
    if (!mounted) return;
    setState(() => widget.entry.resolvedStatus = 2);
    AppFeedback.info(
      context,
      ok ? '已标记为已掌握' : '已标记（需联网后才会同步）',
    );
  }

  /// 练同类题：以错题知识点 + 归因标签生成巩固练习卷
  Future<void> _drillPractice() async {
    if (_drilling) return;
    setState(() => _drilling = true);
    final data =
        await StudentService().generateMistakeDrill(widget.entry.id, count: 5);
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
    final accent = mastered ? AppColors.primaryOf(context) : AppColors.vermilionOf(context);

    return AmbientScaffold(
      tag: '成长 · 错题复盘',
      title: '错题详情',
      onBack: () => Navigator.of(context).maybePop(),
      bottomInset: 40,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ---- 头卡：类型 / 状态徽章 + 完整题干 ----
          PaperCard(
            tint: accent,
            tintStrength: mastered ? 0.5 : 0.8,
            radius: AppRadius.lg,
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            accent: accent,
            child: Opacity(
              opacity: mastered ? 0.85 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeBadge(label: e.typeLabel, color: accent),
                      const SizedBox(width: 8),
                      _StatusChip(status: e.resolvedStatus),
                      if (e.needFocus && !mastered) ...[
                        const SizedBox(width: 6),
                        _TypeBadge(label: '需加强', color: AppColors.vermilionOf(context)),
                      ],
                      const Spacer(),
                      MonoText(
                        e.date.length >= 10 ? e.date.substring(0, 10) : e.date,
                        fontSize: 11,
                        color: AppColors.text4Of(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.7,
                      color: AppColors.textOf(context),
                    ),
                  ),
                  // 刷题错题闭环数据：累计答错 / 连续答对
                  if ((e.wrongCount ?? 0) > 0 || (e.consecutiveCorrect ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    MonoText(
                      [
                        if ((e.wrongCount ?? 0) > 0) '累计答错 ${e.wrongCount} 次',
                        if ((e.consecutiveCorrect ?? 0) > 0) '已连对 ${e.consecutiveCorrect} 次',
                      ].join(' · '),
                      fontSize: 11,
                      color: AppColors.text3Of(context),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---- 病例证据 / 题目材料 ----
          if (e.evidence.isNotEmpty) ...[
            const SizedBox(height: 14),
            PaperSectionLabel(title: '题目材料', icon: Icons.menu_book_outlined),
            const SizedBox(height: 8),
            _EvidenceBlock(text: e.evidence),
          ],

          // ---- AI 归因 ----
          const SizedBox(height: 18),
          PaperSectionLabel(
            title: 'AI 归因',
            icon: Icons.auto_awesome_rounded,
            meta: mastered ? '已掌握' : null,
          ),
          const SizedBox(height: 8),
          MistakeAiPanel(
            entry: e,
            analyzing: _analyzing,
            onRetry: _analyze,
            onDrill: _drillPractice,
            drilling: _drilling,
            drill: _drill,
          ),

          // ---- 知识点标签 ----
          if (e.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: e.tags
                  .map((t) => AppChip(label: t, type: ChipType.default_))
                  .toList(),
            ),
          ],

          // ---- 标记掌握 ----
          if (!mastered) ...[
            const SizedBox(height: 18),
            AppGhostButton(
              label: '标记为已掌握',
              icon: const Icon(Icons.check_rounded, size: 15),
              onPressed: _markMastered,
            ),
          ] else ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      size: 16, color: AppColors.primaryOf(context)),
                  const SizedBox(width: 7),
                  Text(
                    '这道题已掌握，继续保持',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 复用小组件（列表卡瘦身迁入详情页）
// ============================================================

/// 类型 / 徽章胶囊
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.04,
          color: color,
        ),
      ),
    );
  }
}

/// 复习状态胶囊：0 未复习（朱砂）/ 1 已复习（琥珀）/ 2 已掌握（主色）
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (status) {
      case 2:
        label = '已掌握';
        color = AppColors.primaryOf(context);
      case 1:
        label = '已复习';
        color = AppColors.amberOf(context);
      default:
        label = '未复习';
        color = AppColors.vermilionOf(context);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

/// 证据引用块：左侧竖线 + 浅底
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
          Container(width: 2.5, color: AppColors.primaryOf(context).withValues(alpha: 0.35)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppColors.text2Of(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 归因面板（未分析 / 分析中 / 成功 / 降级 四态）
class MistakeAiPanel extends StatelessWidget {
  const MistakeAiPanel({
    super.key,
    required this.entry,
    required this.analyzing,
    required this.onRetry,
    required this.onDrill,
    this.drilling = false,
    this.drill,
  });

  final MistakeEntry entry;
  final bool analyzing;
  final VoidCallback onRetry;
  final VoidCallback onDrill;
  final bool drilling;
  final Map<String, dynamic>? drill;

  String get _stageLabel => MistakeEntry.labelOfStage(entry.aiStage);
  String get _biasLabel => MistakeEntry.labelOfBias(entry.aiBiasType);

  @override
  Widget build(BuildContext context) {
    if (analyzing) {
      return _PendingHint(text: 'AI 归因分析中…');
    }

    final analysis = entry.aiAnalysis;
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

    final status = (analysis['status'] as String?) ?? 'SUCCESS';
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
                size: 16, color: AppColors.vermilionOf(context)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                (analysis['explanation'] as String?) ?? 'AI 归因服务暂时不可用。',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text2Of(context)),
              ),
            ),
            GestureDetector(
              onTap: onRetry,
              child: Text('重试',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.vermilionOf(context))),
            ),
          ],
        ),
      );
    }

    final rootCause = (analysis['rootCause'] as String?) ?? '';
    final explanation = (analysis['explanation'] as String?) ?? '';
    final practiceHint = (analysis['practiceHint'] as String?) ?? '';
    final tags = (analysis['recommendedTags'] as List?)
            ?.whereType<String>()
            .toList() ??
        const [];

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.mossSoftOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 客观题：临床推理五阶段进度条，高亮思维分叉点
          if (!entry.isSubjective && entry.aiStage.isNotEmpty) ...[
            _ForkStageBar(currentStage: entry.aiStage),
            const SizedBox(height: 11),
          ],
          if (_stageLabel.isNotEmpty || _biasLabel.isNotEmpty)
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
          // 分叉点对照：学生怎么想的 → 正确路径该怎么走
          if (entry.aiForkPoint.isNotEmpty) ...[
            const SizedBox(height: 10),
            _aiLine(context, '思维分叉点', entry.aiForkPoint),
          ],
          if (rootCause.isNotEmpty) ...[
            const SizedBox(height: 10),
            _aiLine(context, '为什么错', rootCause),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            _aiLine(context, '怎么改', explanation),
          ],
          if (practiceHint.isNotEmpty) ...[
            const SizedBox(height: 10),
            _aiLine(context, '巩固方向', practiceHint),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: tags
                  .map((t) => AppChip(label: t, type: ChipType.moss))
                  .toList(),
            ),
          ],
          // 练同类题：把归因结论变成下一次练习
          const SizedBox(height: 12),
          if (drilling)
            const _PendingHint(text: '正在生成巩固练习…')
          else if (drill == null)
            AppGhostButton(
              label: '练同类题',
              small: true,
              icon: const Icon(Icons.fitness_center_rounded, size: 13),
              onPressed: onDrill,
            )
          else
            _DrillBlock(
                drill: drill!,
                knowledgeTag: tags.isNotEmpty ? tags.first : null),
          const SizedBox(height: 8),
          const AiGeneratedNote(),
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
        const SizedBox(height: 3),
        // AI 归因文本打字机（ChatGPT 观感），全 app 公共组件
        TypewriterText(
          content,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.65,
            color: AppColors.textOf(context),
          ),
        ),
      ],
    );
  }
}

/// 进行中提示（分析中 / 生成中共用）
class _PendingHint extends StatelessWidget {
  const _PendingHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryOf(context),
            ),
          ),
          const SizedBox(width: 9),
          MonoText(text, fontSize: 11, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }
}

/// 临床推理五阶段进度条：高亮思维分叉点
///
/// 分叉点之前的阶段视为「已走过」（主色），分叉点高亮（朱砂），之后为未达（灰）。
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
            : (passed ? AppColors.primaryOf(context) : AppColors.text4Of(context));
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 3,
                margin: EdgeInsets.only(right: i == stages.length - 1 ? 0 : 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isFork ? 1 : (passed ? 0.55 : 0.4)),
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
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
          fontSize: 11, color: AppColors.text3Of(context));
    }
    final firstId = (questions.first['id'] as num?)?.toInt();
    final shown = questions.length > 5 ? 5 : questions.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context).withValues(alpha: 0.72),
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
                      fontSize: 11, color: AppColors.text4Of(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      raw.isEmpty ? '（题干缺失）' : raw,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppColors.text2Of(context),
                      ),
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
