import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/student/cases/case_detail_page.dart';
import 'package:zhiyu/features/student/cases/cases_list_page.dart';
import 'package:zhiyu/features/student/home/student_home_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('student home leads with the daily case and one primary action',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const Scaffold(body: StudentHomePage()),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('daily-20260711'), findsOneWidget);
    expect(find.text('每日一例：活动后胸闷'), findsOneWidget);
    expect(find.byType(ClinicalEvidenceAxis), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, '查看病例'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily case can be resolved by the detail presentation layer',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const CaseDetailPage(caseId: 'daily-20260711'),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('每日一例：活动后胸闷'), findsOneWidget);
    expect(find.text('8 分钟'), findsOneWidget);
    expect(find.text('病例不存在或已下架'), findsNothing);
    expect(find.widgetWithText(FilledButton, '开始问诊'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('case discovery filters clinical record rows',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const CasesListPage(),
      size: phone390,
    );

    expect(find.byType(ClinicalRecordRow), findsNWidgets(3));

    await tester.enterText(find.byType(TextField), '胸痛');
    await tester.pump();

    expect(find.text('胸痛待查'), findsOneWidget);
    expect(find.byType(ClinicalRecordRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student case surfaces remain stable at target phone widths',
      (WidgetTester tester) async {
    for (final Size size in <Size>[phone360, phone390, phone430]) {
      await pumpPage(
        tester,
        const Scaffold(body: StudentHomePage()),
        size: size,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });
}
