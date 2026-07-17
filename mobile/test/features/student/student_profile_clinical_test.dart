import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/student/profile/student_profile_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('student profile uses a clinical identity and record structure',
      (WidgetTester tester) async {
    await pumpPage(tester, const StudentProfilePage());

    expect(find.text('智愈寻真'), findsOneWidget);
    expect(find.text('知语寻真'), findsNothing);
    expect(find.byType(ClinicalHeader), findsOneWidget);
    expect(find.byType(ClinicalRecordRow), findsNWidgets(2));
    expect(find.byType(ZyActivityHeatmap), findsOneWidget);
    expect(find.byType(ZyCard), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('student profile remains stable across target phone widths',
      (WidgetTester tester) async {
    for (final Size size in <Size>[phone360, phone390, phone430]) {
      await pumpPage(
        tester,
        const StudentProfilePage(),
        size: size,
        textScaler: const TextScaler.linear(1.3),
      );

      expect(find.byType(ZyActivityHeatmap), findsOneWidget);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1600),
        10000,
      );
      await tester.pumpAndSettle();
      expect(find.text('退出登录'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });
}
