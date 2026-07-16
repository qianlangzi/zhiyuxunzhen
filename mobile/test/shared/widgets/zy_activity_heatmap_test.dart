import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/data/models.dart';
import 'package:zhiyu/features/student/profile/training_activity.dart';
import 'package:zhiyu/shared/widgets/zy_activity_heatmap.dart';

import '../../helpers/test_harness.dart';

void main() {
  test('summary counts active days, completions and current streak', () {
    final DateTime end = DateTime(2026, 7, 15);
    final List<HeatmapDay> days = <HeatmapDay>[
      HeatmapDay(date: '2026-07-13', value: 1, completedCount: 1),
      HeatmapDay(date: '2026-07-14', value: 2, completedCount: 2),
      HeatmapDay(date: '2026-07-15', value: 1, completedCount: 1),
    ];
    final TrainingActivitySummary summary =
        TrainingActivitySummary.fromDays(days, endDate: end);
    expect(summary.activeDays, 3);
    expect(summary.completedCount, 4);
    expect(summary.currentStreak, 3);
  });

  testWidgets('heatmap renders 91 compact day cells and handles a tap',
      (WidgetTester tester) async {
    HeatmapDay? selected;
    await pumpPage(
      tester,
      Scaffold(
        body: ZyActivityHeatmap(
          days: const <HeatmapDay>[],
          endDate: DateTime(2026, 7, 15),
          onDayTap: (HeatmapDay day) => selected = day,
        ),
      ),
      size: phone360,
    );

    final Finder cells = find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('activity-cell-');
    });
    expect(cells, findsNWidgets(91));
    await tester.tap(
      find.byKey(const ValueKey<String>('activity-cell-2026-07-15')),
    );
    expect(selected, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
