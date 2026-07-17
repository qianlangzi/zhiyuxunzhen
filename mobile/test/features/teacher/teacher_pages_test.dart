import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/teacher/assignments/assignments_page.dart';
import 'package:zhiyu/features/teacher/cases/case_config_page.dart';
import 'package:zhiyu/features/teacher/cases/case_market_page.dart';
import 'package:zhiyu/features/teacher/overview/teacher_overview_page.dart';
import 'package:zhiyu/features/teacher/profile/teacher_profile_page.dart';
import 'package:zhiyu/features/teacher/review/review_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('teacher pages', () {
    testWidgets('overview starts with actionable teaching work',
        (WidgetTester tester) async {
      await pumpPage(tester, const TeacherOverviewPage());
      expect(find.text('今天需要处理的事'), findsOneWidget);
      expect(find.text('待复核'), findsWidgets);
      expect(find.text('作业进度'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('班级薄弱点'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('班级薄弱点'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Faculty'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview lays out at 360 390 and 430',
        (WidgetTester tester) async {
      for (final Size size in const <Size>[phone360, phone390, phone430]) {
        await pumpPage(tester, const TeacherOverviewPage(), size: size);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -1200),
          10000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('case configuration is a labeled form with one save action',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseConfigPage());
      expect(find.text('病例配置'), findsOneWidget);
      expect(find.text('基本信息'), findsOneWidget);
      final Finder configScrollable = find
          .descendant(
            of: find.byKey(const ValueKey<String>('case-config-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('教学目标'),
        200,
        scrollable: configScrollable,
      );
      expect(find.text('教学目标'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '保存配置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('case market uses readable rows with one primary action',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseMarketPage());
      expect(find.text('病例广场'), findsOneWidget);
      expect(find.text('引用病例'), findsWidgets);
      expect(find.text('查看详情'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('case config rejects empty title on save',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseConfigPage(), size: phone360);
      await tester.tap(find.text('保存配置'));
      await tester.pumpAndSettle();
      expect(find.text('请输入病例标题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('case config accepts a valid title on save',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseConfigPage(), size: phone360);
      await tester.enterText(find.byType(TextFormField).at(0), '胸痛三联鉴别');
      await tester.pump();
      await tester.tap(find.text('保存配置'));
      await tester.pumpAndSettle();
      expect(find.text('演示配置已保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('case market marks a row as referenced',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseMarketPage(), size: phone360);
      await tester.tap(find.text('引用病例').first);
      await tester.pumpAndSettle();
      expect(find.text('已引用'), findsOneWidget);
      expect(find.text('病例已加入你的病例库'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('assignments show status and deadline as ledger records',
        (WidgetTester tester) async {
      await pumpPage(tester, const AssignmentsPage());
      expect(find.text('作业登记'), findsOneWidget);
      expect(find.text('班级任务'), findsOneWidget);
      expect(find.textContaining('提交 37 / 42'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.scrollUntilVisible(
        find.text('格式规则'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('格式规则'), findsOneWidget);
      expect(find.text('查看规则'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('assignment creation validates and adds a local row',
        (WidgetTester tester) async {
      await pumpPage(tester, const AssignmentsPage(), size: phone360);
      await tester.tap(find.text('新建作业'));
      await tester.pumpAndSettle();
      expect(find.text('作业名称'), findsOneWidget);
      expect(find.text('班级'), findsOneWidget);
      expect(find.text('截止日期'), findsOneWidget);
      expect(find.text('创建作业'), findsOneWidget);
      // Submit empty → validation error
      await tester.tap(find.text('创建作业'));
      await tester.pumpAndSettle();
      expect(find.text('请输入作业名称'), findsOneWidget);
      // Enter valid title → success
      await tester.enterText(find.byType(TextFormField).at(0), '新训练作业');
      await tester.pump();
      await tester.tap(find.text('创建作业'));
      await tester.pumpAndSettle();
      expect(find.text('作业已创建'), findsOneWidget);
      expect(find.text('新训练作业'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review opens a draggable detail sheet with explicit actions',
        (WidgetTester tester) async {
      await pumpPage(tester, const ReviewPage());
      expect(find.text('待复核'), findsWidgets);
      await _openFirstReview(tester);
      expect(find.text('批阅详情'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('通过'),
        180,
        scrollable: _sheetScrollable(),
      );
      expect(find.text('通过'), findsOneWidget);
      expect(find.text('退回修改'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review approve closes sheet and marks row reviewed',
        (WidgetTester tester) async {
      await pumpPage(tester, const ReviewPage());
      await _openFirstReview(tester);
      await tester.scrollUntilVisible(
        find.text('通过'),
        180,
        scrollable: _sheetScrollable(),
      );
      await tester.tap(find.text('通过'));
      await tester.pumpAndSettle();
      expect(find.text('批阅详情'), findsNothing);
      expect(find.text('复核结果已提交'), findsOneWidget);
      expect(find.text('已复核'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review return closes sheet and marks row for revision',
        (WidgetTester tester) async {
      await pumpPage(tester, const ReviewPage());
      await _openFirstReview(tester);
      await tester.scrollUntilVisible(
        find.text('通过'),
        180,
        scrollable: _sheetScrollable(),
      );
      await tester.tap(find.text('退回修改'));
      await tester.pumpAndSettle();
      expect(find.text('批阅详情'), findsNothing);
      expect(find.text('已退回修改'), findsOneWidget);
      expect(find.text('待修改'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review sheet can be dragged down to dismiss',
        (WidgetTester tester) async {
      await pumpPage(tester, const ReviewPage());
      await _openFirstReview(tester);
      expect(find.text('批阅详情'), findsOneWidget);
      await tester.drag(find.text('批阅详情'), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('批阅详情'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review sheet actions stay reachable at 360 and text scale 1.3',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const ReviewPage(),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
      );
      await _openFirstReview(tester);
      await tester.scrollUntilVisible(
        find.text('通过'),
        200,
        scrollable: _sheetScrollable(),
      );
      await tester.tap(find.text('通过'));
      await tester.pumpAndSettle();
      expect(find.text('复核结果已提交'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('teacher profile shares identity structure without heatmap',
        (WidgetTester tester) async {
      await pumpPage(tester, const TeacherProfilePage());
      expect(find.text('智愈寻真'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('教师'), findsOneWidget);
      expect(find.text('教学概况'), findsOneWidget);
      expect(find.text('最近三个月'), findsNothing);
      final Finder cells = find.byWidgetPredicate((Widget widget) {
        final Key? key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('activity-cell-');
      });
      expect(cells, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('teacher profile routes to assignments and logs out',
        (WidgetTester tester) async {
      await pumpZhiyuApp(tester, preferences: <String, Object>{
        'zhiyu_token': 'mock-teacher01-token',
        'zhiyu_username': 'teacher01',
        'zhiyu_role': 1,
      });
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的班级'));
      await tester.pumpAndSettle();
      expect(find.text('作业登记'), findsOneWidget);
      expect(find.text('班级任务'), findsOneWidget);

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      expect(find.text('智愈寻真'), findsOneWidget);
      expect(find.text('知语寻真'), findsNothing);
      expect(find.text('账号'), findsOneWidget);
    });
  });
}

Future<void> _openFirstReview(WidgetTester tester) async {
  final Finder firstRow = find.byType(ClinicalRecordRow).first;
  await tester.ensureVisible(firstRow);
  await tester.tap(firstRow);
  await tester.pumpAndSettle();
}

Finder _sheetScrollable() {
  return find
      .descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      )
      .first;
}
