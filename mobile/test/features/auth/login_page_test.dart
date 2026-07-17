import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('presents the clinical brand and one compact login form',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());

    expect(find.byType(Image), findsOneWidget);
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('智愈寻真 Logo'), findsOneWidget);
    handle.dispose();
    expect(find.text('智愈寻真'), findsOneWidget);
    expect(find.text('知语寻真'), findsNothing);
    expect(find.byType(ZySegmentedControl<String>), findsOneWidget);
    expect(find.text('学生'), findsOneWidget);
    expect(find.text('教师'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('登录学生端'), findsNothing);
    expect(find.textContaining('SECURE CLINICAL NODE'), findsNothing);
    expect(find.textContaining('联系所在教研组管理员'), findsNothing);

    final List<TextFormField> fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller?.text, 'teacher01');
    expect(fields[1].controller?.text, '123456');
  });

  testWidgets('switches demo identity without creating separate role cards',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());

    await tester.tap(find.text('学生'));
    await tester.pump();

    final List<TextFormField> fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller?.text, 'student01');
    expect(fields[1].controller?.text, '123456');
    expect(find.byType(Card), findsNothing);
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

  testWidgets('password visibility control has a clear accessible label',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());

    final Finder passwordInput = find.descendant(
      of: find.byType(TextFormField).at(1),
      matching: find.byType(EditableText),
    );
    EditableText passwordField = tester.widget<EditableText>(passwordInput);
    expect(passwordField.obscureText, isTrue);
    expect(find.byTooltip('显示密码'), findsOneWidget);

    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();

    passwordField = tester.widget<EditableText>(passwordInput);
    expect(passwordField.obscureText, isFalse);
    expect(find.byTooltip('隐藏密码'), findsOneWidget);
  });

  testWidgets('shows loading state and disables submit while signing in',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());
    // 无效但格式合法的凭证：触发 600ms 登录流程，最终就地显示错误，不会 context.go
    await tester.enterText(find.byType(TextFormField).at(0), 'wronguser');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.text('登录'));
    await tester.pump(); // 登录已开始，loading=true，600ms 未到
    expect(find.text('正在登录'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final FilledButton button =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.pumpAndSettle(); // 完成 600ms，登录失败，就地显示错误
    expect(find.text('账号或密码错误，演示账号见登录页'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remains usable at 360px with 1.3 text scaling',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const LoginPage(),
      size: phone360,
      textScaler: TextScaler.linear(1.3),
    );

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
