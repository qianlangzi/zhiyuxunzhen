import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';

/// 薄弱知识点 Top 卡 —— 学习档案 / 能力画像子页共用
///
/// 从 LearningArchiveScreen 抽出为共享组件：能力画像子页同样要呈现
/// 「薄弱在哪」，避免同一份 UI 写两遍后口径漂移。
/// [onAiDiagnosis] 非空时右上角出现「AI 诊断」入口（跳薄弱点推荐页）。
class WeaknessListCard extends StatelessWidget {
  const WeaknessListCard({
    super.key,
    required this.weaknesses,
    this.maxCount = 5,
    this.onAiDiagnosis,
  });

  /// 薄弱点列表（GET /student/weaknesses 原始条目）
  final List<dynamic> weaknesses;

  /// 最多展示条数
  final int maxCount;

  /// 「AI 诊断」入口回调，null 时隐藏入口
  final VoidCallback? onAiDiagnosis;

  @override
  Widget build(BuildContext context) {
    if (weaknesses.isEmpty) return const SizedBox.shrink();
    final items = weaknesses.take(maxCount).toList();
    return PaperCard(
      tint: AppColors.vermilionOf(context),
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.psychology_outlined,
                color: AppColors.vermilionOf(context),
                size: 34,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '薄弱知识点 Top',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                ),
              ),
              if (onAiDiagnosis != null)
                GestureDetector(
                  onTap: onAiDiagnosis,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('AI 诊断',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.primaryOf(context))),
                      Icon(Icons.chevron_right,
                          size: 15, color: AppColors.primaryOf(context)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((e) {
            final w =
                e.value is Map ? e.value as Map : const <String, dynamic>{};
            final tag = (w['knowledgeTag'] as String?) ?? '知识点';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 21,
                    height: 21,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.vermilionOf(context)
                              .withValues(alpha: 0.18),
                          AppColors.vermilionOf(context)
                              .withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.vermilionOf(context),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(tag,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.text2Of(context))),
                  ),
                  Icon(Icons.chevron_right,
                      size: 15, color: AppColors.text4Of(context)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
