import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';
import '../../../../shared/widgets/typewriter_text.dart';

/// 单条错题的数据模型
///
/// 容错解析后端返回的 Map：所有字段都可能缺失或类型不符，绝不抛异常。
class MistakeEntry {
  MistakeEntry.fromJson(Map<String, dynamic> m)
      : id = (m['id'] as num?)?.toInt() ?? 0,
        typeKey = m['mistakeType'] as String? ?? '',
        resolvedStatus = (m['resolvedStatus'] as num?)?.toInt() ?? 0,
        date = m['createdAt'] as String? ?? '',
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

  bool get mastered => resolvedStatus == 2;
  bool get reviewed => resolvedStatus == 1;

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
      default:
        return type ?? '未知';
    }
  }

  /// 筛选中文标签 -> API 类型 key
  static String? keywordOf(String zh) {
    switch (zh) {
      case '诊断':
        return 'diagnosis';
      case '病史':
        return 'history';
      case '检查':
        return 'exam';
      case '病历':
        return 'record';
      case '沟通':
        return 'communication';
      case '刷题':
        return 'practice';
      default:
        return null;
    }
  }

  /// 全部筛选标签
  static const List<String> filterLabels = ['全部', '诊断', '病史', '检查', '病历', '沟通', '刷题'];
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
    this.compact = false,
  });

  final MistakeEntry entry;

  /// 调用 AI 归因，返回解析后的结果（null 表示服务不可用）
  final Future<Map<String, dynamic>?> Function(int id) onAnalyze;

  /// 标记已掌握回调
  final ValueChanged<MistakeEntry>? onMarkMastered;

  /// 紧凑模式：卡片内边距更小，用于成长页的前几条
  final bool compact;

  @override
  State<MistakeTile> createState() => _MistakeTileState();
}

class _MistakeTileState extends State<MistakeTile> {
  bool _expanded = false;
  bool _analyzing = false;

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
                                fontSize: 10, color: AppColors.moss,),
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
                      analysis: e.aiAnalysis,
                      analyzing: _analyzing,
                      onRetry: _analyze,
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
    required this.analysis,
    required this.analyzing,
    required this.onRetry,
  });

  final Map<String, dynamic>? analysis;
  final bool analyzing;
  final VoidCallback onRetry;

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
