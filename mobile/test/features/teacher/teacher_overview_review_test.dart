import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/data/models.dart';
import 'package:zhiyu/data/repositories/content_repository.dart';
import 'package:zhiyu/features/teacher/overview/teacher_overview_page.dart';
import 'package:zhiyu/features/teacher/review/review_page.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('teacher clinical overview and review flow', () {
    testWidgets(
        'overview leads with todays work, one compact band and one primary action',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const TeacherOverviewPage(),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );

      expect(find.text('今天需要处理的事'), findsOneWidget);
      final Finder stats = find.byKey(const ValueKey<String>(
        'teacher-overview-stat-band',
      ));
      expect(stats, findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('待复核')),
          findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('风险争议')),
          findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('班级完成率')),
          findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('2')),
          findsNWidgets(2));
      expect(find.descendant(of: stats, matching: find.text('86%')),
          findsOneWidget);

      expect(
        find.widgetWithText(FilledButton, '处理最高风险记录'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(ZyCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview review register uses stable clinical risk ordering',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const TeacherOverviewPage(),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );

      final Finder register = find.byKey(
        const ValueKey<String>('teacher-review-register'),
      );
      final List<ClinicalRecordRow> rows = tester
          .widgetList<ClinicalRecordRow>(
            find.descendant(
              of: register,
              matching: find.byType(ClinicalRecordRow),
            ),
          )
          .toList();
      expect(
        rows.map((ClinicalRecordRow row) => row.title),
        <String>[
          '孙同学 · 诊断推理训练',
          '周同学 · 病史采集训练',
          '钱同学 · 胸痛问诊训练',
          '李同学 · 心衰问诊训练',
          '赵同学 · 呼吸问诊训练',
          '吴同学 · 用药核对训练',
        ],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('review register keeps the same stable risk ordering',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const ReviewPage(),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );

      final List<ClinicalRecordRow> rows = tester
          .widgetList<ClinicalRecordRow>(find.byType(ClinicalRecordRow))
          .toList();
      expect(
        rows.map((ClinicalRecordRow row) => row.title),
        <String>[
          '孙同学 · 诊断推理训练',
          '周同学 · 病史采集训练',
          '钱同学 · 胸痛问诊训练',
          '李同学 · 心衰问诊训练',
          '赵同学 · 呼吸问诊训练',
          '吴同学 · 用药核对训练',
        ],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'detail uses only existing review evidence and a local teacher opinion',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const ReviewPage(),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );
      await _openFirstReview(tester);

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      final Finder evidenceAxis = find.byType(ClinicalEvidenceAxis);
      expect(evidenceAxis, findsOneWidget);
      expect(
        find.descendant(
          of: evidenceAxis,
          matching: find.text('诊断依据前后冲突，需要人工确认。'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: evidenceAxis, matching: find.text('评分记录')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: evidenceAxis, matching: find.text('评分 91 分')),
        findsOneWidget,
      );
      expect(find.text('有争议项'), findsWidgets);
      expect(
        find.descendant(of: evidenceAxis, matching: find.text('尚未填写')),
        findsOneWidget,
      );
      expect(find.textContaining('AI'), findsNothing);
      expect(find.textContaining('截止'), findsNothing);
      expect(find.text('学生答案'), findsNothing);

      final Finder sheetScrollable = _sheetScrollable();
      final Finder opinionField = find.byKey(
        const ValueKey<String>('review-opinion-field'),
      );
      await tester.scrollUntilVisible(
        opinionField,
        160,
        scrollable: sheetScrollable,
      );
      await tester.enterText(opinionField, '建议补充鉴别诊断依据');
      await tester.pump();
      expect(find.text('建议补充鉴别诊断依据'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail can be dragged down to dismiss',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const ReviewPage(),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );
      await _openFirstReview(tester);

      await tester.drag(find.text('批阅详情'), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('批阅详情'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('approve submits while return reports the missing endpoint',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const ReviewPage(),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );
      await _openFirstReview(tester);
      await tester.scrollUntilVisible(
        find.text('通过'),
        180,
        scrollable: _sheetScrollable(),
      );
      await tester.tap(find.text('通过'));
      await tester.pumpAndSettle();

      final ClinicalRecordRow approved = tester
          .widgetList<ClinicalRecordRow>(find.byType(ClinicalRecordRow))
          .singleWhere(
            (ClinicalRecordRow row) => row.title == '孙同学 · 诊断推理训练',
          );
      expect(approved.statusLabel, '有争议项');
      expect(find.text('复核结果已提交'), findsOneWidget);

      final Finder pendingRow = find.byWidgetPredicate(
        (Widget widget) =>
            widget is ClinicalRecordRow && widget.title == '钱同学 · 胸痛问诊训练',
      );
      await tester.ensureVisible(pendingRow);
      await tester.tap(pendingRow);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('通过'),
        180,
        scrollable: _sheetScrollable(),
      );
      await tester.tap(find.text('退回修改'));
      await tester.pumpAndSettle();

      final ClinicalRecordRow returned = tester
          .widgetList<ClinicalRecordRow>(find.byType(ClinicalRecordRow))
          .singleWhere(
            (ClinicalRecordRow row) => row.title == '钱同学 · 胸痛问诊训练',
          );
      expect(returned.statusLabel, '待复核');
      expect(find.text('退回修改接口尚未实现，本次未修改数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail actions remain reachable at 360 and text scale 1.3',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        const ReviewPage(),
        size: phone360,
        textScaler: const TextScaler.linear(1.3),
        overrides: <Override>[
          teachingRepositoryProvider.overrideWithValue(
            _OrderedTeachingRepository(),
          ),
        ],
      );
      await _openFirstReview(tester);
      await tester.scrollUntilVisible(
        find.text('通过'),
        180,
        scrollable: _sheetScrollable(),
      );
      await tester.tap(find.text('通过'));
      await tester.pumpAndSettle();

      expect(find.text('复核结果已提交'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _openFirstReview(WidgetTester tester) async {
  final Finder firstRow = find.byType(ClinicalRecordRow).first;
  await tester.ensureVisible(firstRow);
  await tester.tap(firstRow);
  await tester.pumpAndSettle();
  expect(find.text('批阅详情'), findsOneWidget);
}

Finder _sheetScrollable() {
  return find
      .descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      )
      .first;
}

class _OrderedTeachingRepository extends TeachingRepository {
  @override
  List<ReviewItem> reviewQueue() => const <ReviewItem>[
        ReviewItem(
          id: 1,
          student: '赵同学',
          assignment: '呼吸问诊训练',
          score: 84,
          issue: '体征记录缺少呼吸音描述。',
          status: '已初步批阅',
        ),
        ReviewItem(
          id: 2,
          student: '钱同学',
          assignment: '胸痛问诊训练',
          score: 78,
          issue: '现病史遗漏放射痛方向。',
          status: '待复核',
        ),
        ReviewItem(
          id: 3,
          student: '孙同学',
          assignment: '诊断推理训练',
          score: 91,
          issue: '诊断依据前后冲突，需要人工确认。',
          status: '有争议项',
        ),
        ReviewItem(
          id: 4,
          student: '李同学',
          assignment: '心衰问诊训练',
          score: 80,
          issue: '夜间阵发性呼吸困难未确认。',
          status: '待复核',
        ),
        ReviewItem(
          id: 5,
          student: '周同学',
          assignment: '病史采集训练',
          score: 87,
          issue: '用药史与过敏史记录存在矛盾。',
          status: '有争议项',
        ),
        ReviewItem(
          id: 6,
          student: '吴同学',
          assignment: '用药核对训练',
          score: 95,
          issue: '记录完整，等待归档。',
          status: '已复核',
        ),
      ];
}
