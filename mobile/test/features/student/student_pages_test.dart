import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyu/data/models.dart';
import 'package:zhiyu/data/repositories/content_repository.dart';
import 'package:zhiyu/data/sources/mock_data.dart';
import 'package:zhiyu/features/student/cases/case_detail_page.dart';
import 'package:zhiyu/features/student/cases/cases_list_page.dart';
import 'package:zhiyu/features/student/feedback/feedback_page.dart';
import 'package:zhiyu/features/student/feedback/mistakes_page.dart';
import 'package:zhiyu/features/student/home/student_home_page.dart';
import 'package:zhiyu/features/student/profile/student_profile_page.dart';

import '../../helpers/test_harness.dart';

class _EmptyMistakesRepository extends LearningRepository {
  @override
  List<MistakeItem> mistakes() => const <MistakeItem>[];
}

void main() {
  group('student pages', () {
    testWidgets('home prioritizes one training action and has no heatmap',
        (WidgetTester tester) async {
      await pumpPage(tester, const StudentHomePage());
      expect(find.text('今天的训练'), findsOneWidget);
      expect(find.text('继续训练'), findsOneWidget);
      expect(find.text('最近训练'), findsOneWidget);
      expect(find.text('待复盘'), findsOneWidget);
      expect(find.text('学习热力图'), findsNothing);
      expect(find.text('MedEd Training'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('home lays out on 360, 390 and 430 without overflow',
        (WidgetTester tester) async {
      for (final Size size in const <Size>[phone360, phone390, phone430]) {
        await pumpPage(tester, const StudentHomePage(), size: size);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -800),
          10000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('cases use searchable compact rows',
        (WidgetTester tester) async {
      await pumpPage(tester, const CasesListPage());
      expect(find.widgetWithText(TextField, '搜索病例、症状或诊断'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('心血管'), findsOneWidget);
      expect(find.text('开始问诊'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cases show empty state and clear filters',
        (WidgetTester tester) async {
      await pumpPage(tester, const CasesListPage());
      await tester.enterText(
        find.byType(TextField),
        'zzzz不存在zzzz',
      );
      await tester.pump();
      expect(find.text('没有找到匹配病例'), findsOneWidget);
      await tester.tap(find.text('清除筛选'));
      await tester.pumpAndSettle();
      expect(find.text('没有找到匹配病例'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('case detail has a stable start action',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseDetailPage(caseId: 'chest-pain'));
      expect(find.text('患者概况'), findsOneWidget);
      expect(find.text('训练目标'), findsOneWidget);
      expect(find.text('开始问诊'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('case detail lays out at 360 with text scale 1.3',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const CaseDetailPage(caseId: 'chest-pain'),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
      );
      await tester.fling(
        find.byType(ListView),
        const Offset(0, -600),
        10000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid case id shows error with return action',
        (WidgetTester tester) async {
      await pumpPage(tester, const CaseDetailPage(caseId: 'does-not-exist'));
      expect(find.text('病例不存在或已下架'), findsOneWidget);
      expect(find.text('重新加载'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('feedback starts with a concise conclusion',
        (WidgetTester tester) async {
      await pumpPage(tester, const FeedbackPage());
      expect(find.text('本次表现'), findsOneWidget);
      expect(find.text('下一步建议'), findsOneWidget);
      expect(find.textContaining('MedEd'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('feedback lays out at 360 with text scale 1.3',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const FeedbackPage(),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
      );
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -800),
        10000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('mistakes can filter pending review items',
        (WidgetTester tester) async {
      await pumpPage(tester, const MistakesPage());
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('待复盘'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      await tester.tap(find.text('待复盘'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('mistakes show empty state when no pending review',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const MistakesPage(),
        overrides: <Override>[
          learningRepositoryProvider
              .overrideWithValue(_EmptyMistakesRepository()),
        ],
      );
      await tester.tap(find.text('待复盘'));
      await tester.pumpAndSettle();
      expect(find.text('当前没有待复盘内容'), findsOneWidget);
      expect(find.text('浏览病例'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mistakes lay out at 360 with text scale 1.3',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const MistakesPage(),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
      );
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -600),
        10000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('student profile owns the compact three-month heatmap',
        (WidgetTester tester) async {
      await pumpPage(tester, const StudentProfilePage());
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('训练天数'), findsOneWidget);
      expect(find.text('连续天数'), findsOneWidget);
      expect(find.text('完成次数'), findsOneWidget);
      expect(find.text('最近三个月'), findsOneWidget);
      final Finder cells = find.byWidgetPredicate((Widget widget) {
        final Key? key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('activity-cell-');
      });
      expect(cells, findsNWidgets(91));
      expect(tester.takeException(), isNull);
    });

    testWidgets('student profile heatmap reveals day detail on tap',
        (WidgetTester tester) async {
      await pumpPage(tester, const StudentProfilePage());
      // 取最近一个有训练记录的天（today，必在热力图窗口内），保证测试不依赖星期
      final HeatmapDay active = MockData.heatmapDays
          .lastWhere((HeatmapDay day) => day.completedCount > 0);
      final Finder cell =
          find.byKey(ValueKey<String>('activity-cell-${active.date}'));
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(find.text('完成 ${active.completedCount} 次训练'), findsOneWidget);
      await tester.drag(find.byType(BottomSheet), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('student profile lays out at 360 390 and 430',
        (WidgetTester tester) async {
      for (final Size size in const <Size>[phone360, phone390, phone430]) {
        await pumpPage(tester, const StudentProfilePage(), size: size);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -1200),
          10000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
