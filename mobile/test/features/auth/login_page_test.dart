import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('uses the existing logo and one neutral login action',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());
    expect(find.byType(Image), findsOneWidget);
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('知语寻真 Logo'), findsOneWidget);
    handle.dispose();
    expect(find.text('知语寻真'), findsOneWidget);
    expect(find.text('学生'), findsOneWidget);
    expect(find.text('教师'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.textContaining('登录学生端'), findsNothing);
    expect(find.textContaining('SECURE CLINICAL NODE'), findsNothing);
  });

  testWidgets('shows inline errors for empty credentials',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.text('登录'));
    await tester.pump();
    expect(find.text('请输入账号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
  });

  testWidgets('shows loading state and disables submit while signing in',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());
    // 无效但格式合法的凭证：触发 600ms 登录流程，最终失败走 SnackBar，不会 context.go
    await tester.enterText(find.byType(TextFormField).at(0), 'wronguser');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.text('登录'));
    await tester.pump(); // 登录已开始，loading=true，600ms 未到
    expect(find.text('正在登录'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final FilledButton button =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.pumpAndSettle(); // 完成 600ms，登录失败，显示错误 SnackBar
    expect(tester.takeException(), isNull);
  });
}
