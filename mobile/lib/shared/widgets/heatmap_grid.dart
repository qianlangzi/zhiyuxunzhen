import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 热力图网格（力扣同款：列=周，行=周一~周日，横向滑动，跨年时年份淡入淡出）
///
/// 只负责「格子」本身，外层容器请用统一的 [StudyHeatmapCard]，
/// 避免同一份数据出现多套热力图实现。
class HeatmapGrid extends StatefulWidget {
  final List<dynamic>? activityDays;

  const HeatmapGrid({super.key, this.activityDays});

  @override
  State<HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<HeatmapGrid> {
  static const double _gap = 3; // 格子间距
  static const double _cell = 12; // 格子大小（力扣风格，紧凑）
  static const int _monthCount = 12; // 显示最近 12 个月
  static const double _monthLabelHeight = 14; // 顶部月份标签行高
  static const double _monthDividerWidth = 16; // 月份分隔区宽度

  final ScrollController _scroll = ScrollController();

  // 月份视图数据：每月一个，含日历网格
  late List<_MonthView> _months;
  // 每月内容起始 X 坐标（累计宽度）
  late List<double> _monthStartX;
  // 当前滑动可见区域跨越的年份（用于顶部淡入淡出）
  int _leftYear = 0;
  int _rightYear = 0;
  bool _leftVisible = false;
  bool _rightVisible = false;

  @override
  void initState() {
    super.initState();
    _build();
    _scroll.addListener(_onScroll);
    // 初始定位到最右（当前月）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityDays != widget.activityDays) {
      _build();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// 按 yyyy-MM-dd 聚合 completedCount
  Map<String, int> _countByDate() {
    final result = <String, int>{};
    final days = widget.activityDays;
    if (days == null) return result;
    for (final d in days) {
      final m = d as Map<String, dynamic>;
      final dateStr = m['date'] as String? ?? '';
      final count = (m['completedCount'] as num?)?.toInt() ?? 0;
      if (dateStr.isNotEmpty) result[dateStr] = count;
    }
    return result;
  }

  void _build() {
    final today = DateTime.now();
    final counts = _countByDate();
    final isMock = widget.activityDays == null;
    final rnd = [0, 0, 0, 1, 1, 2, 2, 3, 4];

    _months = [];
    // 从当前月往前推 _monthCount 个月，生成每月日历视图
    for (int i = _monthCount - 1; i >= 0; i--) {
      final month = DateTime(today.year, today.month - i, 1);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      // 当前月只显示到今天为止，今天之后不出格子
      final lastDay = (month.year == today.year && month.month == today.month)
          ? today.day
          : daysInMonth;
      // 1 号是周几（0=周一 ... 6=周日）
      final offset = (month.weekday - DateTime.monday) % 7;
      // 需要的列数（每周一列），只覆盖到今天
      final rows = ((offset + lastDay) / 7).ceil();

      // 生成展平等级：长度为 rows*7，每天落在正确星期位置，无效位置为 -1
      final levels = List<int>.filled(rows * 7, -1);
      for (int d = 0; d < lastDay; d++) {
        final date = DateTime(month.year, month.month, d + 1);
        final key = _fmt(date);
        int lvl;
        if (isMock) {
          final idx = date.day + date.month * 7 + date.year;
          lvl = idx % 10 > 4 ? rnd[(idx * 3 + 1) % rnd.length] : 0;
        } else {
          lvl = _levelFor(counts[key] ?? 0);
        }
        levels[offset + d] = lvl;
      }

      _months.add(_MonthView(
        year: month.year,
        month: month.month,
        offset: offset,
        daysInMonth: daysInMonth,
        rows: rows,
        levels: levels,
      ));
    }

    // 计算每月内容的起始 X 坐标（周宽 = rows * (cell+gap)，月份间加分隔）
    _monthStartX = [];
    double x = 0;
    for (int i = 0; i < _months.length; i++) {
      _monthStartX.add(x);
      final monthWidth = _months[i].rows * (_cell + _gap);
      x += monthWidth + (i == _months.length - 1 ? 0 : _monthDividerWidth);
    }
  }

  int _levelFor(int count) {
    if (count == 0) return 0;
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 3;
    return 4;
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;
    final viewport = _scroll.position.viewportDimension;

    // 找到当前可见区域覆盖的月份，取两端的年份
    int startMonth = 0;
    int endMonth = 0;
    for (int i = 0; i < _monthStartX.length; i++) {
      if (_monthStartX[i] <= offset) startMonth = i;
      if (_monthStartX[i] <= offset + viewport) endMonth = i;
    }
    startMonth = startMonth.clamp(0, _months.length - 1);
    endMonth = endMonth.clamp(0, _months.length - 1);

    final leftYear = _months[startMonth].year;
    final rightYear = _months[endMonth].year;
    final crossYear = leftYear != rightYear;
    setState(() {
      _leftYear = _leftVisible ? _leftYear : leftYear;
      _rightYear = rightYear;
      _leftVisible = crossYear;
      _rightVisible = crossYear;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.heatOf(context, 0),
      AppColors.heatOf(context, 1),
      AppColors.heatOf(context, 2),
      AppColors.heatOf(context, 3),
      AppColors.heatOf(context, 4),
    ];
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    const shownWeekday = {0, 1, 2, 3, 4, 5, 6}; // 周一~周日全部显示
    const weekdayIndex = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6};

    // 顶部月份标签行高（用于星期标签与格子顶部对齐）
    const double labelH = _monthLabelHeight;

    // 左侧星期标签列：行结构与格子完全一致（每行 _cell，底部 gap），逐行对齐
    final weekdayColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int wd = 0; wd < 7; wd++)
          Padding(
            padding: EdgeInsets.only(bottom: wd == 6 ? 0 : _gap),
            child: Container(
              height: _cell,
              alignment: Alignment.centerLeft,
              child: shownWeekday.contains(wd)
                  ? Text(
                      weekdayLabels[weekdayIndex[wd]!],
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.text4Of(context),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );

    // 按月份分块：每个月份块 = 月份标签 + 转置日历网格（列=周，行=周一到周日）
    final monthBlocks = <Widget>[];
    for (int g = 0; g < _months.length; g++) {
      final mv = _months[g];
      final isLast = g == _months.length - 1;

      // 转置网格：每列是一周，列内 7 行从上到下为周一到周日
      final grid = Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(mv.rows, (week) {
          return Padding(
            padding: EdgeInsets.only(right: week == mv.rows - 1 ? 0 : _gap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (wd) {
                final idx = week * 7 + wd; // wd: 0=周一 ... 6=周日
                final lvl = mv.levels[idx];
                // 无效位置（今天之后 / 月初空位）用透明占位，保持 7 行对齐
                return Padding(
                  padding: EdgeInsets.only(bottom: wd == 6 ? 0 : _gap),
                  child: Container(
                    width: _cell,
                    height: _cell,
                    decoration: BoxDecoration(
                      color: lvl < 0 ? Colors.transparent : colors[lvl.clamp(0, colors.length - 1)],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      );

      // 月份块（含顶部月份标签）
      monthBlocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: labelH,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '${mv.month}月',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.text4Of(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            grid,
          ],
        ),
      );

      // 月份之间加分隔线（最后一个月份后不加）
      if (!isLast) {
        monthBlocks.add(
          Container(
            width: _monthDividerWidth,
            alignment: Alignment.center,
            child: Column(
              children: [
                const SizedBox(height: labelH + 4),
                Container(
                  width: 1,
                  height: _cell * 7 + _gap * 6,
                  color: AppColors.surfaceEdgeOf(context),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 横向内容：月份块水平排列
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: monthBlocks,
    );

    return SizedBox(
      height: labelH + 4 + _cell * 7 + _gap * 6, // 月份标签行 + 7 行格子
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: labelH + 4),
            child: weekdayColumn,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: content,
                ),
                // 左上角：上一年（跨年时淡入淡出）
                Positioned(
                  top: 0,
                  left: 0,
                  child: AnimatedOpacity(
                    opacity: _leftVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$_leftYear',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
                // 右上角：下一年（跨年时淡入淡出）
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _rightVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$_rightYear',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单月日历视图数据
class _MonthView {
  final int year;
  final int month;
  final int offset; // 1 号落在周几（0=周一 ... 6=周日）
  final int daysInMonth;
  final int rows; // 该月需要的行数
  final List<int> levels; // 展平等级，非本月日期为 -1

  const _MonthView({
    required this.year,
    required this.month,
    required this.offset,
    required this.daysInMonth,
    required this.rows,
    required this.levels,
  });
}
