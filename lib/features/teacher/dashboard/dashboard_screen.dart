import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('学情看板')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // OSCE average
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('班级 OSCE 四维均分', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barGroups: [
                          _bar('病史采集', 78, AppColors.primary),
                          _bar('诊断逻辑', 68, AppColors.warning),
                          _bar('沟通技巧', 85, AppColors.accent),
                          _bar('人文关怀', 82, AppColors.primaryLight),
                        ],
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: _bottomTitle)),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 36)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Completion rate
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('作业完成率趋势', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: _weekTitle)),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 36)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 72), FlSpot(1, 78),
                              FlSpot(2, 75), FlSpot(3, 82),
                              FlSpot(4, 87),
                            ],
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Common errors
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('高频错误 Top 5', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _ErrorRow(1, '未考虑急性冠脉综合征', '68%', 0.68),
                  const Divider(height: 16),
                  _ErrorRow(2, '过敏史采集不完整', '45%', 0.45),
                  const Divider(height: 16),
                  _ErrorRow(3, '不必要检查过多', '32%', 0.32),
                  const Divider(height: 16),
                  _ErrorRow(4, '主诉格式不规范', '28%', 0.28),
                  const Divider(height: 16),
                  _ErrorRow(5, '鉴别诊断缺失', '22%', 0.22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  BarChartGroupData _bar(String label, double y, Color color) {
    return BarChartGroupData(
      x: {'病史采集': 0, '诊断逻辑': 1, '沟通技巧': 2, '人文关怀': 3}[label]!,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  static Widget _bottomTitle(double value, TitleMeta meta) {
    const titles = ['病史采集', '诊断逻辑', '沟通技巧', '人文关怀'];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(titles[value.toInt()],
          style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
    );
  }

  static Widget _weekTitle(double value, TitleMeta meta) {
    const weeks = ['W1', 'W2', 'W3', 'W4', 'W5'];
    return Text(weeks[value.toInt()],
        style: const TextStyle(fontSize: 11));
  }
}

class _ErrorRow extends StatelessWidget {
  final int rank;
  final String desc;
  final String pct;
  final double ratio;
  const _ErrorRow(this.rank, this.desc, this.pct, this.ratio);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 24,
            child: Text('$rank',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.fgDimLight))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.mutedLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                  ratio > 0.5 ? AppColors.destructive : AppColors.warning),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 36,
            child: Text(pct,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.right)),
      ],
    );
  }
}
