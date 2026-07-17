import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/shared/widgets/zy_empty_state.dart';
import 'package:zhiyu/shared/widgets/zy_skeleton.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('empty state explains the reason and offers one next step',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var actionCount = 0;

    await pumpPage(
      tester,
      Scaffold(
        body: ZyEmptyState(
          title: '当前筛选条件下没有病例',
          detail: '清除筛选后即可查看全部可训练病例。',
          actionLabel: '清除筛选',
          onAction: () => actionCount += 1,
        ),
      ),
    );

    expect(find.text('当前筛选条件下没有病例'), findsOneWidget);
    expect(find.text('清除筛选后即可查看全部可训练病例。'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '当前筛选条件下没有病例。清除筛选后即可查看全部可训练病例。',
      ),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget);

    final Size actionSize = tester.getSize(find.byType(FilledButton));
    expect(actionSize.width, greaterThanOrEqualTo(44));
    expect(actionSize.height, greaterThanOrEqualTo(44));

    await tester.tap(find.text('清除筛选'));
    await tester.pump();
    expect(actionCount, 1);
    semantics.dispose();
  });

  testWidgets('error state announces a concrete reason and can reload',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var retryCount = 0;

    await pumpPage(
      tester,
      Scaffold(
        body: ZyErrorState(
          message: '网络连接已断开，请检查网络后重试。',
          onRetry: () => retryCount += 1,
        ),
      ),
    );

    expect(find.text('暂时无法加载'), findsOneWidget);
    expect(find.text('网络连接已断开，请检查网络后重试。'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);

    final SemanticsNode errorSemantics = tester.getSemantics(
      find.bySemanticsLabel(
        '暂时无法加载。网络连接已断开，请检查网络后重试。',
      ),
    );
    expect(errorSemantics.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    expect(errorSemantics.label, contains('网络连接已断开'));

    await tester.tap(find.text('重新加载'));
    await tester.pump();
    expect(retryCount, 1);
    semantics.dispose();
  });

  testWidgets('long Chinese empty state does not overflow at 360px and 1.3x',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      Scaffold(
        body: ZyEmptyState(
          title: '当前筛选条件下没有符合训练要求的呼吸系统病例记录',
          detail: '可以清除科室、难度与关键词筛选，然后重新查看全部可训练病例。',
          actionLabel: '清除全部筛选并重新查看病例',
          onAction: () {},
        ),
      ),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('record skeleton mirrors a clinical record and announces loading',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpPage(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: ZyRecordSkeleton(itemCount: 2),
        ),
      ),
      size: phone360,
    );

    expect(find.byType(ZySkeletonLine), findsNWidgets(8));
    expect(
      tester.getSize(find.byType(ZyRecordSkeleton)).height,
      greaterThanOrEqualTo(104),
    );

    final SemanticsNode loadingSemantics = tester.getSemantics(
      find.bySemanticsLabel('记录加载中'),
    );
    expect(loadingSemantics.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reduced motion disables all skeleton transitions',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpPage(
      tester,
      const Scaffold(
        body: Column(
          children: <Widget>[
            ZySkeletonLine(width: 120),
            ZySkeletonBlock(height: 48),
          ],
        ),
      ),
      disableAnimations: true,
    );

    final List<AnimatedOpacity> transitions = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    expect(transitions, hasLength(2));
    expect(
      transitions.map((AnimatedOpacity transition) => transition.duration),
      everyElement(Duration.zero),
    );
    expect(find.bySemanticsLabel('内容加载中'), findsNWidgets(2));
    semantics.dispose();
  });
}
