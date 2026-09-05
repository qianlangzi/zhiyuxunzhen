import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/student/growth/growth_stats.dart';
import 'app_widgets.dart';
import 'heatmap_grid.dart';
import 'paper_surfaces.dart';

/// 学习热力卡 —— 全 App 唯一的热力图容器
///
/// 此前存在两套重复实现：`shared/widgets/heatmap_grid.dart` 的 HeatmapCard（力扣月列风格）
/// 与 `shared/widgets/activity_heatmap.dart` 的 ActivityHeatmap（84 天方块墙）。
/// 二者数据源相同、口径不同，造成成长页与学习档案页各显示一张、用户困惑。
/// 现统一为 [StudyHeatmapCard]，底层复用 [HeatmapGrid]，后者已删除。
class StudyHeatmapCard extends StatelessWidget {
  const StudyHeatmapCard({
    super.key,
    this.activityDays,
    this.stats,
    this.onDetail,
    this.dense = false,
  });

  /// 原始活动数据 `{'date': '2026-08-29', 'completedCount': 3}`
  final List<dynamic>? activityDays;

  /// 已聚合的统计（为空时内部自行聚合）
  final GrowthStats? stats;

  /// 右上角「详情」回调
  final VoidCallback? onDetail;

  /// 精简模式：隐藏三宫格指标行，只在头部给一句摘要。
  ///
  /// 成长页已经用 Hero 卡承担了「连续 / 累计」两个主指标，
  /// 热力卡再摆一排数字就是重复轰炸，故提供此开关。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = stats ?? GrowthStats.fromOverview({'activityDays': activityDays});
    final year = DateTime.now().year;

    return PaperCard(
      tint: AppColors.primaryOf(context),
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.auto_graph_rounded,
                color: AppColors.primaryOf(context),
                size: 30,
                iconSize: 16,
              ),
              const SizedBox(width: 9),
              Text(
                '学习热力',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              const Spacer(),
              MonoText(
                dense
                    ? '$year · 本月 ${s.thisMonthTrainings} 次 · 活跃 ${s.activeDays} 天'
                    : '$year · 累计 ${s.totalTrainings} 次',
                fontSize: 11,
                color: AppColors.text3Of(context),
              ),
              if (onDetail != null) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onDetail,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(Icons.chevron_right,
                      size: 16, color: AppColors.text4Of(context),),
                ),
              ],
            ],
          ),
          if (!dense) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                _metric(context, '本月', '${s.thisMonthTrainings}'),
                _divider(context),
                _metric(context, '最长连续', '${s.longestStreakDays} 天'),
                _divider(context),
                _metric(context, '活跃', '${s.activeDays} 天'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          HeatmapGrid(activityDays: activityDays),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('少',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.text4Of(context),),),
              const SizedBox(width: 6),
              for (var i = 0; i < 5; i++) ...[
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.heatOf(context, i),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (i < 4) const SizedBox(width: 3),
              ],
              const SizedBox(width: 6),
              Text('多',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.text4Of(context),),),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.1,
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: kCjkMonoFallback,
              color: AppColors.textOf(context),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style:
                TextStyle(fontSize: 10.5, color: AppColors.text4Of(context)),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 16,
        color: AppColors.ruleOf(context).withValues(alpha: 0.7),
      );
}
