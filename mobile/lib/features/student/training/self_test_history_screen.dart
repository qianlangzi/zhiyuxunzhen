import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import 'self_test_record_store.dart';

/// 往期自测记录页（P2-4）：本地记录列表 + 分数折线图
///
/// 后端自测历史接口补齐前，数据来自本地 shared_preferences 缓存。
class SelfTestHistoryScreen extends StatefulWidget {
  const SelfTestHistoryScreen({super.key});
  @override
  State<SelfTestHistoryScreen> createState() => _SelfTestHistoryScreenState();
}

class _SelfTestHistoryScreenState extends State<SelfTestHistoryScreen> {
  List<SelfTestRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await SelfTestRecordStore.load();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '往期自测'),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? _buildEmpty()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined, size: 48, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          SerifText('暂无自测记录', fontSize: 15, color: AppColors.text2Of(context)),
          const SizedBox(height: 4),
          Text('完成一次「AI 组卷自测」后，这里会记录你的分数',
              style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // 折线图：时间正序，最多展示最近 20 次
    final series = _records.reversed.toList();
    final shown = series.length > 20 ? series.sublist(series.length - 20) : series;
    final maxScore = shown.fold<double>(0, (m, r) => r.totalScore > m ? r.totalScore : m);
    final chartMax = maxScore <= 0 ? 100.0 : maxScore;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SerifText('分数趋势', fontSize: 14, color: AppColors.textOf(context), weight: FontWeight.w700),
                const Spacer(),
                MonoText('共 ${_records.length} 次', fontSize: 10, color: AppColors.text4Of(context)),
              ]),
              const SizedBox(height: 14),
              // 概览数值
              Row(children: [
                _overview('最近得分', _records.first.score, AppColors.primaryOf(context)),
                _overview('最高分', _records.map((r) => r.score).reduce((a, b) => a > b ? a : b), AppColors.amberOf(context)),
                _overview('平均分', _avg(_records.map((r) => r.score)), AppColors.indigoOf(context)),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: shown.length < 2
                    ? Center(
                        child: MonoText('完成 2 次自测后展示趋势', fontSize: 11, color: AppColors.text4Of(context)),
                      )
                    : _buildLineChart(shown, chartMax),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          SerifText('历史记录', fontSize: 15, color: AppColors.textOf(context), weight: FontWeight.w700),
          const Spacer(),
        ]),
        const SizedBox(height: 4),
        for (final r in _records) _recordTile(r),
      ],
    );
  }

  Widget _overview(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value.toStringAsFixed(0),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }

  double _avg(Iterable<double> vals) {
    final list = vals.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  Widget _buildLineChart(List<SelfTestRecord> shown, double chartMax) {
    final spots = [
      for (var i = 0; i < shown.length; i++)
        FlSpot(i.toDouble(), shown[i].score.clamp(0, chartMax)),
    ];
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: chartMax > 20 ? chartMax / 4 : 5,
          getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.ruleSoftOf(context), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) {
                if (v % (chartMax / 4).roundToDouble() != 0 && v != chartMax) {
                  return const SizedBox.shrink();
                }
                return MonoText(v.toStringAsFixed(0), fontSize: 9,
                    color: AppColors.text4Of(context));
              },
              interval: chartMax > 20 ? chartMax / 4 : 5,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primaryOf(context),
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.primaryOf(context),
                strokeWidth: 0,
              ),
              checkToShowDot: (spot, bar) => true,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryOf(context).withValues(alpha: 0.10),
            ),
          ),
        ],
        minY: 0,
        maxY: chartMax,
      ),
    );
  }

  Widget _recordTile(SelfTestRecord r) {
    final t = DateTime.fromMillisecondsSinceEpoch(r.epoch);
    final date = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final isAi = r.source == 'AI';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isAi ? AppColors.primaryOf(context) : AppColors.amberOf(context)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(isAi ? Icons.auto_awesome : Icons.rule,
                size: 20, color: isAi ? AppColors.primaryOf(context) : AppColors.amberOf(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(r.score.toStringAsFixed(0),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: r.score >= r.totalScore * 0.6
                              ? AppColors.primaryOf(context)
                              : AppColors.vermilionOf(context))),
                  MonoText(' / ${r.totalScore.toStringAsFixed(0)} 分',
                      fontSize: 12, color: AppColors.text3Of(context)),
                  const SizedBox(width: 8),
                  if (isAi)
                    MonoText('AI 组卷', fontSize: 9, color: AppColors.primaryOf(context))
                  else
                    MonoText('规则组卷', fontSize: 9, color: AppColors.amberOf(context)),
                ]),
                const SizedBox(height: 3),
                Text('答对 ${r.correct}/${r.count} · 正确率 ${(r.accuracy * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MonoText(time, fontSize: 11, color: AppColors.text4Of(context)),
              MonoText(date, fontSize: 10, color: AppColors.text4Of(context)),
            ],
          ),
        ],
      ),
    );
  }
}