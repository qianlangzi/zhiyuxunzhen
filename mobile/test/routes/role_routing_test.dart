import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('unauthenticated app opens the shared login',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester);
    expect(find.text('知语寻真'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
  });

  testWidgets('persisted student opens the student five-tab workspace',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester, preferences: <String, Object>{
      'zhiyu_token': 'mock-student01-token',
      'zhiyu_username': 'student01',
      'zhiyu_role': 0,
    });
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('病例'), findsOneWidget);
    expect(find.text('反馈'), findsOneWidget);
    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('persisted teacher opens the teacher five-tab workspace',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester, preferences: <String, Object>{
      'zhiyu_token': 'mock-teacher01-token',
      'zhiyu_username': 'teacher01',
      'zhiyu_role': 1,
    });
    expect(find.text('概览'), findsOneWidget);
    expect(find.text('病例'), findsOneWidget);
    expect(find.text('作业'), findsOneWidget);
    expect(find.text('批阅'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
