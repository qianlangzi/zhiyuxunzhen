import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/learning_model.dart';

/// 最近三个月 13×7 小方块训练热力图
///
/// 视觉规格：cellSize=8、cellGap=4；零值用 brandSoft，1~4 用 activity1~4；
/// 月份标签在边界显示；未来日期不可点击。
class ZyActivityHeatmap extends StatelessWidget {
  const ZyActivityHeatmap({
    super.key,
    required this.days,
    required this.endDate,
    required this.onDayTap,
  });

  final List<HeatmapDay> days;
  final DateTime endDate;
  final ValueChanged<HeatmapDay> onDayTap;

  static const double cellSize = 8;
  static const double cellGap = 4;
  static const int weekCount = 13;
  static const int daysPerWeek = 7;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime(endDate.year, endDate.month, endDate.day);
    final Map<String, HeatmapDay> byDate = <String, HeatmapDay>{
      for (final HeatmapDay day in days) day.date: day,
    };

    // 窗口起点：对齐到本周周日，向前 90 天（共 91 格）
    final int daysToSunday = DateTime.sunday - today.weekday;
    final DateTime windowEnd = today.add(Duration(days: daysToSunday));
    final DateTime windowStart = windowEnd.subtract(const Duration(days: 90));

    final List<Widget> weekColumns = <Widget>[];
    String? lastMonthLabel;
    final List<_MonthMark> monthLabels = <_MonthMark>[];

    for (int week = 0; week < weekCount; week++) {
      final List<Widget> cells = <Widget>[];
      for (int day = 0; day < daysPerWeek; day++) {
        final int index = week * daysPerWeek + day;
        final DateTime date = windowStart.add(Duration(days: index));
        final String iso = _isoDate(date);
        final HeatmapDay dayData =
            byDate[iso] ?? HeatmapDay(date: iso, value: 0);
        final bool isFuture = date.isAfter(today);

        // 收集每月首日标签
        final String monthLabel = '${date.month}月';
        if (monthLabel != lastMonthLabel) {
          monthLabels.add(_MonthMark(
            label: monthLabel,
            weekOffset: week,
          ));
          lastMonthLabel = monthLabel;
        }

        cells.add(Semantics(
          key: ValueKey<String>('activity-cell-$iso'),
          label: '$iso，完成 ${dayData.completedCount} 次训练',
          button: !isFuture,
          child: InkResponse(
            radius: 12,
            onTap: isFuture ? null : () => onDayTap(dayData),
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: colorFor(dayData.value),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ));
      }
      weekColumns.add(Padding(
        padding: EdgeInsets.only(
          right: week == weekCount - 1 ? 0 : cellGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: cellGap,
          children: cells,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MonthRow(
          labels: monthLabels,
          cellSize: cellSize,
          cellGap: cellGap,
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weekColumns,
          ),
        ),
      ],
    );
  }

  /// 按视觉强度返回颜色：0=brandSoft，1~4=activity1~4
  Color colorFor(int value) {
    switch (value) {
      case 1:
        return AppColors.activity1;
      case 2:
        return AppColors.activity2;
      case 3:
        return AppColors.activity3;
      case 4:
        return AppColors.activity4;
      default:
        return AppColors.brandSoft;
    }
  }
}

String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _MonthMark {
  const _MonthMark({required this.label, required this.weekOffset});
  final String label;
  final int weekOffset;
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.labels,
    required this.cellSize,
    required this.cellGap,
  });

  final List<_MonthMark> labels;
  final double cellSize;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final double weekWidth = cellSize + cellGap;
    return SizedBox(
      height: 14,
      child: Stack(
        children: <Widget>[
          for (final _MonthMark mark in labels)
            Positioned(
              left: mark.weekOffset * weekWidth,
              child: Text(
                mark.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.soft,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
