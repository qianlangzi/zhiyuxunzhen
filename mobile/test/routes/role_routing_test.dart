import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/core/constants/app_colors.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('unauthenticated app opens the shared login',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester);
    expect(find.text('智愈寻真'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
  });

  testWidgets('student demo credentials enter the student workspace',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester);

    await tester.tap(find.text('学生'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('反馈'), findsOneWidget);
    expect(find.byType(ZyBottomBar), findsOneWidget);
  });

  testWidgets('teacher demo credentials enter the teacher workspace',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('概览'), findsOneWidget);
    expect(find.text('批阅'), findsOneWidget);
    expect(find.byType(ZyBottomBar), findsOneWidget);
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

    final Scaffold shell = tester.widget<Scaffold>(
      find.ancestor(
        of: find.byType(ZyBottomBar),
        matching: find.byType(Scaffold),
      ),
    );
    expect(shell.backgroundColor, AppColors.paper);
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

    final Scaffold shell = tester.widget<Scaffold>(
      find.ancestor(
        of: find.byType(ZyBottomBar),
        matching: find.byType(Scaffold),
      ),
    );
    expect(shell.backgroundColor, AppColors.paper);
  });

  testWidgets('student cannot enter teacher routes',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester, preferences: <String, Object>{
      'zhiyu_token': 'mock-student01-token',
      'zhiyu_username': 'student01',
      'zhiyu_role': 0,
    });

    GoRouter.of(tester.element(find.byType(ZyBottomBar))).go('/teacher/review');
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('批阅'), findsNothing);
  });

  testWidgets('teacher cannot enter student routes',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester, preferences: <String, Object>{
      'zhiyu_token': 'mock-teacher01-token',
      'zhiyu_username': 'teacher01',
      'zhiyu_role': 1,
    });

    GoRouter.of(tester.element(find.byType(ZyBottomBar)))
        .go('/student/feedback');
    await tester.pumpAndSettle();

    expect(find.text('概览'), findsOneWidget);
    expect(find.text('批阅'), findsOneWidget);
    expect(find.text('反馈'), findsNothing);
  });
}
