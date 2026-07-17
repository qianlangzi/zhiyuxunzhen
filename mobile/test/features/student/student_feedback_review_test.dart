import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/core/theme/app_theme.dart';
import 'package:zhiyu/features/student/feedback/feedback_page.dart';
import 'package:zhiyu/features/student/feedback/mistakes_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('feedback leads with an action before score evidence',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const FeedbackPage(),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    const String conclusion = '下一轮先补强诊断逻辑：完成「心衰问诊补救病例」。';
    expect(find.text(conclusion), findsOneWidget);
    expect(find.text('能力证据'), findsOneWidget);
    expect(find.text('诊断逻辑'), findsOneWidget);
    expect(find.text('68 / 100'), findsOneWidget);
    expect(find.text('待补强'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    expect(find.byType(ZyCard), findsNothing);

    final double conclusionTop = tester.getTopLeft(find.text(conclusion)).dy;
    final double evidenceTop = tester.getTopLeft(find.text('能力证据')).dy;
    expect(conclusionTop, lessThan(evidenceTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback suggestions are routable clinical record rows',
      (WidgetTester tester) async {
    await _pumpRoutedPage(
      tester,
      initialLocation: '/feedback',
      pagePath: '/feedback',
      page: const FeedbackPage(),
    );

    expect(find.byType(ClinicalRecordRow), findsNWidgets(3));
    await tester.tap(find.text('心衰问诊补救病例'));
    await tester.pumpAndSettle();
    expect(find.text('病例目标页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review records expose evidence source status and next step',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const MistakesPage(),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('胸痛病例误判为胃炎'), findsOneWidget);
    expect(find.text('错误依据'), findsWidgets);
    expect(find.text('遗漏胸骨后压榨痛、出汗和心电图检查。'), findsOneWidget);
    expect(find.text('来源 / 标签'), findsWidgets);
    expect(find.text('诊断错误 · 胸痛鉴别'), findsOneWidget);
    expect(find.text('状态'), findsWidgets);
    expect(find.text('待复盘'), findsWidgets);
    expect(find.text('下一步'), findsWidgets);
    expect(find.text('重做病例并补录诊断依据'), findsWidgets);
    expect(find.byType(ZyCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review filters keep pending and completed records distinct',
      (WidgetTester tester) async {
    await pumpPage(tester, const MistakesPage());

    await tester.tap(find.text('待复盘').first);
    await tester.pumpAndSettle();
    expect(find.text('胸痛病例误判为胃炎'), findsOneWidget);
    expect(find.text('优先选择高价 CT'), findsOneWidget);
    expect(find.text('慢阻肺病例未追问夜间憋醒'), findsNothing);

    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(find.text('慢阻肺病例未追问夜间憋醒'), findsOneWidget);
    expect(find.text('胸痛病例误判为胃炎'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review next step keeps the existing case navigation',
      (WidgetTester tester) async {
    await _pumpRoutedPage(
      tester,
      initialLocation: '/mistakes',
      pagePath: '/mistakes',
      page: const MistakesPage(),
    );

    await tester.tap(find.text('重做病例并补录诊断依据').first);
    await tester.pumpAndSettle();
    expect(find.text('病例目标页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRoutedPage(
  WidgetTester tester, {
  required String initialLocation,
  required String pagePath,
  required Widget page,
}) async {
  tester.view.physicalSize = phone390;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: pagePath, builder: (_, __) => page),
      GoRoute(
        path: '/student/cases',
        builder: (_, __) => const Scaffold(body: Text('病例目标页')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
