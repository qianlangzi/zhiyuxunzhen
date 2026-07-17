import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/core/theme/app_theme.dart';
import 'package:zhiyu/features/student/cases/case_detail_page.dart';
import 'package:zhiyu/features/student/cases/cases_list_page.dart';
import 'package:zhiyu/features/student/home/student_home_page.dart';
import 'package:zhiyu/features/student/student_shell.dart';
import 'package:zhiyu/features/teacher/cases/case_market_page.dart';
import 'package:zhiyu/features/teacher/overview/teacher_overview_page.dart';
import 'package:zhiyu/features/teacher/teacher_shell.dart';

import '../helpers/test_harness.dart';

const Map<String, Object> _studentPreferences = <String, Object>{
  'zhiyu_token': 'mock-student01-token',
  'zhiyu_username': 'student01',
  'zhiyu_role': 0,
};

const Map<String, Object> _teacherPreferences = <String, Object>{
  'zhiyu_token': 'mock-teacher01-token',
  'zhiyu_username': 'teacher01',
  'zhiyu_role': 1,
};

const double _topInset = 32;

void main() {
  group('secondary route back stacks', () {
    testWidgets('student home case detail returns to student home',
        (WidgetTester tester) async {
      await pumpZhiyuApp(tester, preferences: _studentPreferences);
      expect(find.byType(StudentHomePage), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, '查看病例'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CaseDetailPage), findsOneWidget);

      await _expectCanPopAndPop(tester, find.byType(CaseDetailPage));

      expect(find.byType(StudentHomePage), findsOneWidget);
      expect(find.text('病例训练工作台'), findsOneWidget);
    });

    testWidgets('student case list detail returns to the case list',
        (WidgetTester tester) async {
      await pumpZhiyuApp(tester, preferences: _studentPreferences);
      await tester.tap(find.text('病例').last);
      await tester.pumpAndSettle();
      expect(find.byType(CasesListPage), findsOneWidget);

      await tester.tap(find.text('慢阻肺急性加重'));
      await tester.pumpAndSettle();
      expect(find.byType(CaseDetailPage), findsOneWidget);

      await _expectCanPopAndPop(tester, find.byType(CaseDetailPage));

      expect(find.byType(CasesListPage), findsOneWidget);
      expect(find.text('病例发现'), findsOneWidget);
    });

    testWidgets('invalid case return action opens the case list',
        (WidgetTester tester) async {
      await pumpZhiyuApp(tester, preferences: _studentPreferences);
      final BuildContext context = tester.element(find.byType(StudentHomePage));
      GoRouter.of(context).go('/student/case/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('病例不可用'), findsOneWidget);
      await tester.tap(find.text('返回病例列表'));
      await tester.pumpAndSettle();

      expect(find.byType(CasesListPage), findsOneWidget);
      expect(find.text('病例发现'), findsOneWidget);
    });

    testWidgets('teacher market opened from overview returns to overview',
        (WidgetTester tester) async {
      await pumpZhiyuApp(tester, preferences: _teacherPreferences);
      expect(find.byType(TeacherOverviewPage), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('病例广场'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('病例广场'));
      await tester.pumpAndSettle();
      expect(find.byType(CaseMarketPage), findsOneWidget);

      await _expectCanPopAndPop(tester, find.byType(CaseMarketPage));

      expect(find.byType(TeacherOverviewPage), findsOneWidget);
    });
  });

  group('shell top safe area', () {
    testWidgets('StudentShell consumes non-zero top padding for its child',
        (WidgetTester tester) async {
      const Key probeKey = ValueKey<String>('student-shell-top-probe');
      await _pumpShellWithTopInset(
        tester,
        initialLocation: '/',
        shellBuilder: (Widget child) => StudentShell(child: child),
        probeKey: probeKey,
      );

      expect(tester.getTopLeft(find.byKey(probeKey)).dy, _topInset);
      expect(find.text('remaining top: 0'), findsOneWidget);
    });

    testWidgets('TeacherShell consumes non-zero top padding for its child',
        (WidgetTester tester) async {
      const Key probeKey = ValueKey<String>('teacher-shell-top-probe');
      await _pumpShellWithTopInset(
        tester,
        initialLocation: '/teacher',
        shellBuilder: (Widget child) => TeacherShell(child: child),
        probeKey: probeKey,
      );

      expect(tester.getTopLeft(find.byKey(probeKey)).dy, _topInset);
      expect(find.text('remaining top: 0'), findsOneWidget);
    });
  });
}

Future<void> _expectCanPopAndPop(WidgetTester tester, Finder page) async {
  final NavigatorState navigator = Navigator.of(tester.element(page));
  expect(navigator.canPop(), isTrue);
  navigator.pop();
  await tester.pumpAndSettle();
}

Future<void> _pumpShellWithTopInset(
  WidgetTester tester, {
  required String initialLocation,
  required Widget Function(Widget child) shellBuilder,
  required Key probeKey,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: initialLocation,
        builder: (BuildContext context, GoRouterState state) => shellBuilder(
          _TopInsetProbe(key: probeKey),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  tester.view.physicalSize = phone390;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            padding: const EdgeInsets.only(top: _topInset),
            viewPadding: const EdgeInsets.only(top: _topInset),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

class _TopInsetProbe extends StatelessWidget {
  const _TopInsetProbe({super.key});

  @override
  Widget build(BuildContext context) {
    final double remainingTop = MediaQuery.paddingOf(context).top;
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 160,
        height: 24,
        child: Text('remaining top: ${remainingTop.toStringAsFixed(0)}'),
      ),
    );
  }
}
