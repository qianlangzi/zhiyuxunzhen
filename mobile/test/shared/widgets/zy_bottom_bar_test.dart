import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/shared/widgets/zy_bottom_bar.dart';

import '../../helpers/test_harness.dart';

void main() {
  const List<ZyTabSpec> tabs = <ZyTabSpec>[
    ZyTabSpec(
      path: '/',
      label: '首页',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    ZyTabSpec(
      path: '/cases',
      label: '病例',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
    ),
  ];

  testWidgets('bottom bar exposes selected semantics and handles taps',
      (WidgetTester tester) async {
    ZyTabSpec? tapped;
    await pumpPage(
      tester,
      Scaffold(
        bottomNavigationBar: ZyBottomBar(
          tabs: tabs,
          currentIndex: 0,
          onTap: (ZyTabSpec value) => tapped = value,
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('病例'), findsOneWidget);
    expect(find.byKey(const Key('bottom-tab-indicator')), findsOneWidget);
    await tester.tap(find.text('病例'));
    expect(tapped?.path, '/cases');
    expect(tester.takeException(), isNull);
  });
}
