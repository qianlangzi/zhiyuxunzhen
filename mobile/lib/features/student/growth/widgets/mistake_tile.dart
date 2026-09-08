import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';
import '../../../../routes/route_names.dart';

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

/// 错题列表卡 —— 错题本与成长页「待复盘」共用
///
/// 只负责「扫一眼」：类型 + 状态徽章 + 题干摘要 + 日期。
/// 点击进入错题详情二级页做深度复盘（AI 归因 / 巩固练习 / 标记掌握），
/// 不再在列表里内联展开，长列表不会被撑乱。
class MistakeTile extends StatelessWidget {
  const MistakeTile({
    super.key,
    required this.entry,
    this.compact = false,
    this.onChanged,
  });

  final MistakeEntry entry;

  /// 紧凑模式：内边距更小，用于成长页的前几条
  final bool compact;

  /// 从详情页返回后回调（标记掌握 / 状态变化时通知列表刷新统计）
  final VoidCallback? onChanged;

  Future<void> _open(BuildContext context) async {
    await context.pushNamed(RouteNames.mistakeDetail, extra: entry);
    if (!context.mounted) return;
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final mastered = e.mastered;
    // 已掌握走主色（跟主题预设走，不再硬编码 moss）；
    // 未掌握按复习状态分色：未复习朱砂 / 已复习琥珀。
    final accent = mastered
        ? AppColors.primaryOf(context)
        : (e.reviewed
            ? AppColors.amberOf(context)
            : AppColors.vermilionOf(context));

    return PressableScale(
      child: PaperCard(
        tint: accent,
        tintStrength: mastered ? 0.35 : 0.7,
        radius: AppRadius.lg,
        padding: EdgeInsets.zero,
        accent: accent,
        onTap: () => _open(context),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              compact ? 14 : 16, compact ? 12 : 14, compact ? 12 : 14,
              compact ? 12 : 14,),
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
                    if (mastered) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded,
                          size: 14, color: AppColors.primaryOf(context)),
                    ] else if (e.needFocus) ...[
                      const SizedBox(width: 6),
                      Container(
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
                    ],
                    const Spacer(),
                    MonoText(
                      e.date.length >= 10 ? e.date.substring(0, 10) : e.date,
                      fontSize: 11,
                      color: AppColors.text4Of(context),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.text4Of(context)),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppColors.textOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
