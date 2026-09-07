import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 每日病历 · 打卡日历（LeetCode 打开风格）
///
/// 按月份网格展示全年打卡情况：已提交的日期点亮，底部统计连续天数与累计完成数。
class MrCalendarScreen extends ConsumerStatefulWidget {
  const MrCalendarScreen({super.key});

  @override
  ConsumerState<MrCalendarScreen> createState() => _MrCalendarScreenState();
}

class _MrCalendarScreenState extends ConsumerState<MrCalendarScreen> {
  int _year = DateTime.now().year;
  bool _loading = true;

  Set<String> _days = {};
  int _streak = 0;
  int _totalDone = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await StudentService().dailyMrCalendar(year: _year);
    if (!mounted) return;
    setState(() {
      _days = ((data?['days'] as List?) ?? const [])
          .whereType<String>()
          .toSet();
      _streak = (data?['streak'] as num?)?.toInt() ?? 0;
      _totalDone = (data?['totalDone'] as num?)?.toInt() ?? 0;
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
            AppBackAppBar(
              title: '打卡日历',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _buildSummary(),
                        const SizedBox(height: 12),
                        _buildYearSwitch(),
                        const SizedBox(height: 12),
                        for (var m = 1; m <= 12; m++) ...[
                          _buildMonth(m),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _metric('$_streak', '连续天数',
                AppColors.amberOf(context)),
          ),
          Container(width: 0.5, height: 36, color: AppColors.ruleOf(context)),
          Expanded(
            child: _metric('$_totalDone', '累计完成（份）',
                AppColors.moss3Of(context)),
          ),
          Container(width: 0.5, height: 36, color: AppColors.ruleOf(context)),
          Expanded(
            child: _metric('${_days.length}', '今年打卡（天）',
                AppColors.primaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
      ],
    );
  }

  Widget _buildYearSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            setState(() => _year -= 1);
            _load();
          },
        ),
        const SizedBox(width: 8),
        Text('$_year 年',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context))),
        const SizedBox(width: 8),
        AppIconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _year >= DateTime.now().year
              ? null
              : () {
                  setState(() => _year += 1);
                  _load();
                },
        ),
      ],
    );
  }

  Widget _buildMonth(int month) {
    final daysInMonth = DateTime(_year, month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = _year == now.year && month == now.month;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$month 月',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2Of(context))),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Row(
              children: [
                for (var d = 1; d <= daysInMonth; d++) ...[
                  if (d > 1) const SizedBox(width: 2),
                  Expanded(
                    child: Builder(builder: (_) {
                      final date =
                          DateTime(_year, month, d).toIso8601String().substring(0, 10);
                      final isFuture = DateTime(_year, month, d).isAfter(now);
                      final hit = _days.contains(date);
                      final isToday = isCurrentMonth && d == now.day;
                      Color color;
                      if (hit) {
                        color = AppColors.moss3Of(context);
                      } else if (isFuture) {
                        color = AppColors.ruleSoftOf(context);
                      } else {
                        color = AppColors.ruleOf(context).withValues(alpha: 0.4);
                      }
                      return Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                          border: isToday
                              ? Border.all(
                                  color: AppColors.primaryOf(context), width: 1)
                              : null,
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
