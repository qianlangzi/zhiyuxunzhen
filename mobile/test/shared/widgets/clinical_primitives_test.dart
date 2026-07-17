import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/core/constants/app_colors.dart';
import 'package:zhiyu/shared/widgets/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('clinical header wraps long Chinese on a narrow screen',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[
            ClinicalHeader(
              productName: '智愈寻真',
              title: '待复核的呼吸系统临床问诊记录与证据整理',
              caseId: 'CASE-2026-0716-0008',
              dateLabel: '2026年7月16日',
              identityLabel: '内科教学学生',
              action: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
                tooltip: '更多操作',
              ),
            ),
          ],
        ),
      ),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('智愈寻真'), findsOneWidget);
    expect(find.text('CASE-2026-0716-0008'), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clinical header reserves action blue for the case index',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      const Scaffold(
        body: ClinicalHeader(
          productName: '智愈寻真',
          title: '当前病例',
          caseId: 'CASE-008',
          dateLabel: '2026年7月16日',
          identityLabel: '内科教学学生',
        ),
      ),
    );

    final Text caseId = tester.widget<Text>(find.text('CASE-008'));
    final Text date = tester.widget<Text>(find.text('2026年7月16日'));
    final Text identity = tester.widget<Text>(find.text('内科教学学生'));

    expect(caseId.style?.color, AppColors.action);
    expect(date.style?.color, AppColors.weak);
    expect(identity.style?.color, AppColors.weak);
  });

  testWidgets('section header keeps a long description readable at 360px',
      (WidgetTester tester) async {
    await pumpPage(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[
            ClinicalSectionHeader(
              title: '临床证据轴',
              description: '按已记录、待补问、高风险与已完成的状态连续整理当前病例信息',
              action: TextButton(
                onPressed: () {},
                child: const Text('查看全部证据'),
              ),
            ),
          ],
        ),
      ),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('临床证据轴'), findsOneWidget);
    expect(find.text('查看全部证据'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('record row is at least 52px tall and tappable across the row',
      (WidgetTester tester) async {
    var tapCount = 0;
    await pumpPage(
      tester,
      Scaffold(
        body: ClinicalRecordRow(
          leadingLabel: 'CASE-008\n14:30',
          title: '患者夜间阵发性呼吸困难并伴有心悸，需要继续补充危险因素',
          statusLabel: '待补问',
          statusTone: ClinicalEvidenceTone.action,
          onTap: () => tapCount += 1,
        ),
      ),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    final Finder row = find.byType(ClinicalRecordRow);
    final Rect rowRect = tester.getRect(row);
    expect(rowRect.height, greaterThanOrEqualTo(52));
    expect(tester.takeException(), isNull);

    await tester.tapAt(Offset(rowRect.right - 4, rowRect.center.dy));
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('record row exposes content, text status and tap semantics',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpPage(
      tester,
      Scaffold(
        body: ClinicalRecordRow(
          leadingLabel: 'REV-021',
          title: '张同学的肺栓塞鉴别诊断',
          statusLabel: '高风险',
          statusTone: ClinicalEvidenceTone.risk,
          onTap: () {},
        ),
      ),
    );

    final SemanticsData data =
        tester.getSemantics(find.byType(ClinicalRecordRow)).getSemanticsData();
    expect(data.label, contains('REV-021'));
    expect(data.label, contains('张同学的肺栓塞鉴别诊断'));
    expect(data.label, contains('高风险'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('evidence axis renders four text-labelled node tones',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpPage(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: ClinicalEvidenceAxis(
            nodes: <ClinicalEvidenceNode>[
              ClinicalEvidenceNode(
                label: '主诉与现病史',
                detail: '夜间阵发性呼吸困难，坐起后缓解',
                statusLabel: '已记录',
                tone: ClinicalEvidenceTone.neutral,
              ),
              ClinicalEvidenceNode(
                label: '危险因素',
                detail: '需要继续确认近期长途旅行与手术史',
                statusLabel: '待补问',
                tone: ClinicalEvidenceTone.action,
              ),
              ClinicalEvidenceNode(
                label: '警示信息',
                detail: '突发胸痛与血氧饱和度下降需优先处理',
                statusLabel: '高风险',
                tone: ClinicalEvidenceTone.risk,
              ),
              ClinicalEvidenceNode(
                label: '支持证据',
                detail: '心电图与心肌标志物检查已完成',
                statusLabel: '已完成',
                tone: ClinicalEvidenceTone.success,
              ),
            ],
          ),
        ),
      ),
      size: phone360,
      textScaler: const TextScaler.linear(1.3),
    );

    for (final String status in <String>[
      '已记录',
      '待补问',
      '高风险',
      '已完成',
    ]) {
      expect(find.text(status), findsOneWidget);
      expect(find.bySemanticsLabel(status), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
