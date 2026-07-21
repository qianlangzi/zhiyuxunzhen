import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/register_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('student registration shows the secure common fields',
      (WidgetTester tester) async {
    await pumpPage(tester, const RegisterPage());

    expect(find.text('创建账号'), findsOneWidget);
    expect(find.byType(ZySegmentedControl<int>), findsOneWidget);
    expect(find.text('学生'), findsOneWidget);
    expect(find.text('教师'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('执业医师证号或教师工号'), findsNothing);
    expect(find.widgetWithText(FilledButton, '注册学生账号'), findsOneWidget);
  });

  testWidgets('teacher registration requires credentials and department',
      (WidgetTester tester) async {
    await pumpPage(tester, const RegisterPage());

    await tester.tap(find.text('教师'));
    await tester.pump();

    expect(find.byType(TextFormField), findsNWidgets(8));
    expect(find.text('教师资质'), findsOneWidget);
    expect(find.text('执业医师证号或教师工号'), findsOneWidget);
    expect(find.text('所属科室'), findsOneWidget);
    expect(find.textContaining('审核通过前不能使用教师业务功能'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '提交教师注册申请'),
        findsOneWidget);
  });

  testWidgets('rejects mismatched confirmation password',
      (WidgetTester tester) async {
    await pumpPage(tester, const RegisterPage());

    final List<TextFormField> fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    await tester.enterText(find.byWidget(fields[4]), 'study2026');
    await tester.enterText(find.byWidget(fields[5]), 'study2027');
    final Finder submit = find.widgetWithText(FilledButton, '注册学生账号');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('两次输入的密码不一致'), findsOneWidget);
  });

  testWidgets('successful registration returns to login and prefills username',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester);

    await tester.tap(find.text('没有账号？注册'));
    await tester.pumpAndSettle();

    final List<TextFormField> fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    await tester.enterText(find.byWidget(fields[0]), '李同学');
    await tester.enterText(find.byWidget(fields[1]), 'student02');
    await tester.enterText(find.byWidget(fields[2]), '18500000003');
    await tester.enterText(find.byWidget(fields[3]), '123456');
    await tester.enterText(find.byWidget(fields[4]), 'study2026');
    await tester.enterText(find.byWidget(fields[5]), 'study2026');

    final Finder submit = find.widgetWithText(FilledButton, '注册学生账号');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('注册成功，请使用新账号登录'), findsOneWidget);
    final List<TextFormField> loginFields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(loginFields.first.controller?.text, 'student02');
    expect(find.text('没有账号？注册'), findsOneWidget);
  });
}
