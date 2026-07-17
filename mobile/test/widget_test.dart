import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('renders the login entry', (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());

    expect(find.text('智愈寻真'), findsOneWidget);
    expect(find.text('知语寻真'), findsNothing);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
