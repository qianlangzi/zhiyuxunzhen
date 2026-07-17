import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/teacher/assignments/assignments_page.dart';
import 'package:zhiyu/features/teacher/profile/teacher_profile_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('assignments are a deadline and status ledger',
      (WidgetTester tester) async {
    await pumpPage(tester, const AssignmentsPage());

    expect(find.byType(ClinicalHeader), findsOneWidget);
    expect(find.byType(ClinicalRecordRow), findsNWidgets(3));
    expect(find.text('今晚 22:00'), findsOneWidget);
    expect(find.textContaining('37 / 42'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新建作业'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('assignment creation validates and adds a local record',
      (WidgetTester tester) async {
    await pumpPage(tester, const AssignmentsPage(), size: phone360);

    await tester.tap(find.text('新建作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建作业'));
    await tester.pumpAndSettle();
    expect(find.text('请输入作业名称'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '循环系统问诊训练');
    await tester.enterText(find.byType(TextFormField).at(1), '临床 2203 班');
    await tester.enterText(find.byType(TextFormField).at(2), '周五 18:00');
    await tester.tap(find.text('创建作业'));
    await tester.pumpAndSettle();

    expect(find.text('作业已创建'), findsOneWidget);
    expect(find.text('循环系统问诊训练'), findsOneWidget);
    expect(find.byType(ClinicalRecordRow), findsNWidgets(4));
  });

  testWidgets('teacher profile uses real repository counts and no heatmap',
      (WidgetTester tester) async {
    await pumpPage(tester, const TeacherProfilePage());

    expect(find.text('智愈寻真'), findsOneWidget);
    expect(find.text('知语寻真'), findsNothing);
    expect(find.byType(ClinicalHeader), findsOneWidget);
    expect(find.byType(ClinicalRecordRow), findsNWidgets(3));
    expect(find.text('我的班级'), findsOneWidget);
    expect(find.byType(ZyActivityHeatmap), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('126'), findsNothing);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('teacher assignments and profile remain usable at 360px',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const AssignmentsPage(),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );
    expect(tester.takeException(), isNull);

    await pumpPage(
      tester,
      const TeacherProfilePage(),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -1400),
      10000,
    );
    await tester.pumpAndSettle();
    expect(find.text('退出登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
