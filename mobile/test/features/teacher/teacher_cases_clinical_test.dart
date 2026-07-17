import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/teacher/cases/case_config_page.dart';
import 'package:zhiyu/features/teacher/cases/case_market_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('teacher clinical cases', () {
    testWidgets('configuration is a labeled clinical form and case register',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseConfigPage());

      expect(find.byType(ClinicalHeader), findsOneWidget);
      final Finder configScrollable = find
          .descendant(
            of: find.byKey(const ValueKey<String>('case-config-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final String section in <String>[
        '基本信息',
        '模拟病人',
        '教学目标',
        '预览',
        '已配置病例',
      ]) {
        await tester.scrollUntilVisible(
          find.text(section),
          200,
          scrollable: configScrollable,
        );
        expect(
          find.ancestor(
            of: find.text(section),
            matching: find.byType(ClinicalSectionHeader),
          ),
          findsOneWidget,
        );
      }
      for (final String label in <String>[
        '学生将看到的简短病例摘要',
        '难度',
        '知识点标签',
        '配合程度',
        '沟通特点',
        '初步诊断',
        '主诉',
        '患者年龄',
        '病例标题',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          -200,
          scrollable: configScrollable,
        );
        expect(find.text(label), findsOneWidget);
      }

      await tester.scrollUntilVisible(
        find.text('已配置病例'),
        240,
        scrollable: configScrollable,
      );

      final List<ClinicalRecordRow> rows = tester
          .widgetList<ClinicalRecordRow>(find.byType(ClinicalRecordRow))
          .toList();
      expect(rows, hasLength(3));
      expect(rows.first.leadingLabel, '呼吸系统');
      expect(rows.first.title, '慢阻肺急性加重');
      expect(rows.first.subtitle, contains('进阶 · 15 分钟'));
      expect(rows.first.statusLabel, '已认证');
      expect(rows.last.statusLabel, '草稿');
      expect(find.widgetWithText(FilledButton, '保存配置'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('configuration validates title and saves a valid form',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseConfigPage(), size: phone360);

      await tester.tap(find.widgetWithText(FilledButton, '保存配置'));
      await tester.pumpAndSettle();
      expect(find.text('请输入病例标题'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('case-config-title')),
        '胸痛三联鉴别',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存配置'));
      await tester.pumpAndSettle();

      expect(find.text('演示配置已保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('market is a searchable source register with reference action',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseMarketPage(), size: phone360);

      expect(find.byType(ClinicalHeader), findsOneWidget);
      expect(find.byType(ClinicalSectionHeader), findsOneWidget);
      final List<ClinicalRecordRow> rows = tester
          .widgetList<ClinicalRecordRow>(find.byType(ClinicalRecordRow))
          .toList();
      expect(rows, hasLength(3));
      expect(rows.first.leadingLabel, '心血管');
      expect(rows.first.subtitle, contains('来源：心内科教研组'));
      expect(rows.first.subtitle, contains('难度：高阶'));
      expect(rows.first.subtitle, contains('已认证'));
      expect(rows.first.statusLabel, '引用病例');

      await tester.tap(find.byType(ClinicalRecordRow).first);
      await tester.pumpAndSettle();

      final ClinicalRecordRow referenced = tester
          .widgetList<ClinicalRecordRow>(find.byType(ClinicalRecordRow))
          .first;
      expect(referenced.statusLabel, '已引用');
      expect(referenced.onTap, isNull);
      expect(find.text('病例已加入你的病例库'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('market filters the repository list by query and department',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseMarketPage());

      await tester.enterText(
        find.byKey(const ValueKey<String>('case-market-search')),
        '胸痛',
      );
      await tester.pump();
      expect(find.byType(ClinicalRecordRow), findsOneWidget);
      expect(find.text('胸痛三联鉴别训练'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('case-market-search')),
        '',
      );
      await tester.tap(find.text('呼吸系统'));
      await tester.pump();
      expect(find.byType(ClinicalRecordRow), findsOneWidget);
      expect(find.text('发热伴咳嗽分层问诊'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('configuration and market fit 360px at text scale 1.3',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const CaseConfigPage(),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(find.widgetWithText(FilledButton, '保存配置'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpPage(
        tester,
        const CaseMarketPage(),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
      );
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1000),
        10000,
      );
      await tester.pumpAndSettle();
      expect(find.text('引用病例'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening market from configuration preserves the back stack',
        (WidgetTester tester) async {
      await pumpZhiyuApp(tester, preferences: <String, Object>{
        'zhiyu_token': 'mock-teacher01-token',
        'zhiyu_username': 'teacher01',
        'zhiyu_role': 1,
      });

      await tester.tap(find.text('病例').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '保存配置'), findsOneWidget);

      final Finder configScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('病例广场'),
        320,
        scrollable: configScrollable,
      );
      await tester.tap(find.text('病例广场'));
      await tester.pumpAndSettle();
      expect(find.byType(CaseMarketPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CaseConfigPage), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '保存配置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
