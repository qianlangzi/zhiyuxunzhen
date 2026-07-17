import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/student/chat/chat_room_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('chat resolves the daily case into a compact patient summary',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const ChatRoomPage(caseId: 'daily-20260711'),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('每日一例：活动后胸闷'), findsOneWidget);
    expect(find.text('daily-20260711'), findsOneWidget);
    final Text summary = tester.widget<Text>(
      find.text('男，59 岁，活动后胸闷 3 个月，近 1 周加重。既往高血压 8 年。'),
    );
    expect(summary.maxLines, 2);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(find.text('病例不存在或已下架'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat exposes three clinical modes and sends a question',
      (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));

    expect(find.text('询问病情'), findsOneWidget);
    expect(find.text('申请检查'), findsOneWidget);
    expect(find.text('提交判断'), findsOneWidget);
    expect(find.text('智能导师'), findsOneWidget);
    expect(find.textContaining('继续追问夜间憋醒'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '疼痛会放射到左臂吗？');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(find.text('疼痛会放射到左臂吗？'), findsOneWidget);

    // 完成模拟回复，避免未完成计时器异常。
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final Size sendSize = tester.getSize(find.byTooltip('发送'));
    expect(sendSize.height, greaterThanOrEqualTo(44));
    expect(sendSize.width, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat modes expose tap and selected semantics',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));

    SemanticsNode question = tester.getSemantics(find.bySemanticsLabel('询问病情'));
    SemanticsNode examination =
        tester.getSemantics(find.bySemanticsLabel('申请检查'));

    expect(question.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(
      question.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(examination.hasFlag(SemanticsFlag.isSelected), isFalse);

    await tester.tap(find.text('申请检查'));
    await tester.pumpAndSettle();

    question = tester.getSemantics(find.bySemanticsLabel('询问病情'));
    examination = tester.getSemantics(find.bySemanticsLabel('申请检查'));
    expect(question.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(examination.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(
      examination.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('reasoning sheet presents the clinical evidence axis',
      (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));

    await tester.tap(find.byTooltip('思维路径'));
    await tester.pumpAndSettle();

    expect(find.byType(ClinicalEvidenceAxis), findsOneWidget);
    expect(find.text('气促'), findsOneWidget);
    expect(find.text('胸部 CT'), findsOneWidget);
    expect(find.text('¥525'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('关闭思维路径'));
    await tester.pumpAndSettle();
  });

  testWidgets('composer stays safe and the message list remains scrollable',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const ChatRoomPage(caseId: 'chest-pain'),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(
      find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isNot(false));

    for (int index = 0; index < 5; index++) {
      await tester.enterText(
          find.byType(TextField), '补充问题 ${index + 1}：请说明症状变化。');
      await tester.tap(find.byTooltip('发送'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    final Finder messageScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final ScrollableState scrollable =
        tester.state<ScrollableState>(messageScrollable);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(
      scrollable.position.maxScrollExtent - scrollable.position.pixels,
      lessThanOrEqualTo(44),
    );

    final double beforeDrag = scrollable.position.pixels;
    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pump();
    expect(scrollable.position.pixels, lessThan(beforeDrag));
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank send is disabled', (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));
    final Finder sendButton = find.ancestor(
      of: find.byIcon(Icons.send_rounded),
      matching: find.byType(IconButton),
    );
    final IconButton send = tester.widget<IconButton>(sendButton);
    expect(send.onPressed, isNull);

    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(find.text('疼痛会放射到左臂吗？'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching mode updates hint without clearing draft',
      (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));
    await tester.enterText(find.byType(TextField), '草稿内容');
    await tester.tap(find.text('申请检查'));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '草稿内容');
    expect(field.decoration?.hintText, '输入希望申请的检查…');
    expect(tester.takeException(), isNull);
  });
}
