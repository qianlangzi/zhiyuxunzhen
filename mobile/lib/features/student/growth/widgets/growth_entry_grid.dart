import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';

/// 成长子级入口方块（2×2 网格）
///
/// 成长页定位「只讲进步，不做报表」：能力画像 / 训练概览 / 待复盘 / 学习档案
/// 全部下沉为二级页，本组件只保留统一入口，控制首页信息密度。
/// [meta] 展示一行状态副文本（如「6 条待处理」）；[badge] 非空时
/// 在右上角画数字角标（如待复盘条数），空态不显示。
class GrowthEntryGrid extends StatelessWidget {
  const GrowthEntryGrid({super.key, required this.entries});

  final List<GrowthEntryItem> entries;

  @override
  Widget build(BuildContext context) {
    // 固定 2 列；条目数为奇数时末位补占位，保持方块对齐
    final rows = <List<GrowthEntryItem?>>[];
    for (var i = 0; i < entries.length; i += 2) {
      rows.add([
        entries[i],
        i + 1 < entries.length ? entries[i + 1] : null,
      ]);
    }
    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (final item in row) ...[
                Expanded(
                  child: item == null
                      ? const SizedBox.shrink()
                      : _EntryCard(item: item),
                ),
                if (item != row.last) const SizedBox(width: 10),
              ],
            ],
          ),
          if (row != rows.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class GrowthEntryItem {
  const GrowthEntryItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.meta,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// 一行状态副文本（可空）
  final String? meta;

  /// 数字角标（可空；如待复盘条数）
  final int? badge;

  final VoidCallback onTap;
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.item});

  final GrowthEntryItem item;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      tint: item.color,
      radius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      onTap: item.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientIconBadge(
                  icon: item.icon, color: item.color, size: 36),
              const SizedBox(height: 9),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              if (item.meta != null) ...[
                const SizedBox(height: 3),
                Text(
                  item.meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.text4Of(context),
                  ),
                ),
              ],
            ],
          ),
          // 数字角标：有待复盘时提示「点进来有活干」
          if ((item.badge ?? 0) > 0)
            Positioned(
              top: -4,
              right: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.vermilionOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${item.badge! > 99 ? '99+' : item.badge!}',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryOf(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
