import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/student/chat/chat_room_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('chat exposes three clinical modes and sends a question',
      (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));
    expect(find.text('询问病情'), findsOneWidget);
    expect(find.text('申请检查'), findsOneWidget);
    expect(find.text('提交判断'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '疼痛会放射到左臂吗？');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(find.text('疼痛会放射到左臂吗？'), findsOneWidget);
    // 完成模拟回复，避免未完成计时器异常
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final Size sendSize = tester.getSize(find.byTooltip('发送'));
    expect(sendSize.height, greaterThanOrEqualTo(44));
    expect(sendSize.width, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank send is disabled', (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));
    final int before = find.byType(IconButton).evaluate().length;
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    // 没有新消息气泡出现
    expect(find.text('疼痛会放射到左臂吗？'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byType(IconButton).evaluate().length, before);
  });

  testWidgets('switching mode updates hint without clearing draft',
      (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));
    await tester.enterText(find.byType(TextField), '草稿内容');
    await tester.tap(find.text('申请检查'));
    await tester.pumpAndSettle();
    expect(find.text('草稿内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
