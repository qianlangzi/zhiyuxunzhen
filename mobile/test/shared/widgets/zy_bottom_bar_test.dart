import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/core/constants/app_colors.dart';
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

  testWidgets('bottom bar uses icons, Chinese labels, and a bottom indicator',
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
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    final Text inactiveLabel = tester.widget<Text>(find.text('病例'));
    expect(inactiveLabel.style?.color, AppColors.graphite);

    final Finder indicator = find.byKey(const Key('bottom-tab-indicator'));
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator).height, lessThanOrEqualTo(3));
    expect(
      tester.getRect(indicator).top,
      greaterThan(tester.getRect(find.text('首页')).bottom),
    );

    final Finder pillBackground = find.byWidgetPredicate((Widget widget) {
      final Decoration? decoration = switch (widget) {
        Container(:final decoration) => decoration,
        AnimatedContainer(:final decoration) => decoration,
        _ => null,
      };
      return decoration is BoxDecoration &&
          decoration.color == AppColors.actionSoft;
    });
    expect(pillBackground, findsNothing);

    await tester.tap(find.text('病例'));
    expect(tapped?.path, '/cases');
    expect(tester.takeException(), isNull);
  });

  testWidgets('each tab is accessible and at least 44px tall',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpPage(
      tester,
      Scaffold(
        bottomNavigationBar: ZyBottomBar(
          tabs: tabs,
          currentIndex: 0,
          onTap: (_) {},
        ),
      ),
    );

    final Finder homeTab = find.byKey(const Key('bottom-tab-0'));
    final Finder casesTab = find.byKey(const Key('bottom-tab-1'));

    expect(homeTab, findsOneWidget);
    expect(casesTab, findsOneWidget);
    expect(tester.getSize(homeTab).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(homeTab).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(casesTab).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(casesTab).width, greaterThanOrEqualTo(44));
    final SemanticsNode homeSemantics = tester.getSemantics(homeTab);
    expect(homeSemantics.label, '首页');
    expect(homeSemantics.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(homeSemantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(
      homeSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    final SemanticsNode casesSemantics = tester.getSemantics(casesTab);
    expect(casesSemantics.label, '病例');
    expect(casesSemantics.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(casesSemantics.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(
      casesSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('long Chinese labels do not overflow at 360px and 1.3x text',
      (WidgetTester tester) async {
    const List<ZyTabSpec> longTabs = <ZyTabSpec>[
      ZyTabSpec(
        path: '/',
        label: '首页',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      ZyTabSpec(
        path: '/cases',
        label: '病例复盘与分析',
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
      ),
      ZyTabSpec(
        path: '/chat',
        label: '问诊',
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
      ),
      ZyTabSpec(
        path: '/feedback',
        label: '反馈',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
      ),
      ZyTabSpec(
        path: '/profile',
        label: '我的',
        icon: Icons.person_outline,
        activeIcon: Icons.person,
      ),
    ];

    await pumpPage(
      tester,
      Scaffold(
        bottomNavigationBar: ZyBottomBar(
          tabs: longTabs,
          currentIndex: 0,
          onTap: (_) {},
        ),
      ),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    final Text longLabel = tester.widget(find.text('病例复盘与分析'));
    expect(longLabel.maxLines, 1);
    expect(longLabel.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
