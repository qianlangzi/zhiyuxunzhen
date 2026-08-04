import 'package:flutter_test/flutter_test.dart';

import 'package:zhiyu_xunzhen/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ZhiyuApp());
    expect(find.byType(ZhiyuApp), findsOneWidget);
  });
}