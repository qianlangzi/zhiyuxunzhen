import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';
import 'package:zhiyu/features/student/cases/case_detail_page.dart';
import 'package:zhiyu/features/student/cases/cases_list_page.dart';
import 'package:zhiyu/features/student/chat/chat_room_page.dart';
import 'package:zhiyu/features/student/feedback/feedback_page.dart';
import 'package:zhiyu/features/student/feedback/mistakes_page.dart';
import 'package:zhiyu/features/student/home/student_home_page.dart';
import 'package:zhiyu/features/student/profile/student_profile_page.dart';
import 'package:zhiyu/features/teacher/assignments/assignments_page.dart';
import 'package:zhiyu/features/teacher/cases/case_config_page.dart';
import 'package:zhiyu/features/teacher/cases/case_market_page.dart';
import 'package:zhiyu/features/teacher/overview/teacher_overview_page.dart';
import 'package:zhiyu/features/teacher/profile/teacher_profile_page.dart';
import 'package:zhiyu/features/teacher/review/review_page.dart';

import '../helpers/test_harness.dart';

const double _safeTop = 24;
const double _safeBottom = 34;
const double _keyboardInset = 300;

void main() {
  final Map<
      String,
      ({
        Widget page,
        String landmark,
        String topLandmark,
        String endLandmark,
        Finder scrollView,
      })> pages = <String,
      ({
    Widget page,
    String landmark,
    String topLandmark,
    String endLandmark,
    Finder scrollView,
  })>{
    '登录': (
      page: const LoginPage(),
      landmark: '账号',
      topLandmark: '智愈寻真',
      endLandmark: '登录',
      scrollView: find.byType(SingleChildScrollView),
    ),
    '学生首页': (
      page: const StudentHomePage(),
      landmark: '推荐训练',
      topLandmark: '智愈寻真',
      endLandmark: '胸痛待查',
      scrollView: find.byType(CustomScrollView),
    ),
    '病例列表': (
      page: const CasesListPage(),
      landmark: '病例发现',
      topLandmark: '智愈寻真',
      endLandmark: '上消化道出血',
      scrollView: find.byType(CustomScrollView),
    ),
    '病例详情': (
      page: const CaseDetailPage(caseId: 'chest-pain'),
      landmark: '病例详情',
      topLandmark: '病例详情',
      endLandmark: '先补齐症状演变、危险因素与既往史。',
      scrollView: find.byType(ListView),
    ),
    '问诊室': (
      page: const ChatRoomPage(caseId: 'chest-pain'),
      landmark: '胸痛待查',
      topLandmark: '胸痛待查',
      endLandmark: '你已经问到端坐呼吸线索，建议继续追问夜间憋醒。',
      scrollView: find.byType(ListView),
    ),
    '能力反馈': (
      page: const FeedbackPage(),
      landmark: '能力反馈',
      topLandmark: '智愈寻真',
      endLandmark: '血常规判读关卡',
      scrollView: find.byType(CustomScrollView),
    ),
    '错题复盘': (
      page: const MistakesPage(),
      landmark: '出错场景与改进线索',
      topLandmark: '智愈寻真',
      endLandmark: '优先选择高价 CT',
      scrollView: find.byType(CustomScrollView),
    ),
    '学生我的': (
      page: const StudentProfilePage(),
      landmark: '学习概况',
      topLandmark: '智愈寻真',
      endLandmark: '退出登录',
      scrollView: find.byType(CustomScrollView),
    ),
    '教师概览': (
      page: const TeacherOverviewPage(),
      landmark: '今天需要处理的事',
      topLandmark: '智愈寻真',
      endLandmark: '病例广场',
      scrollView: find.byType(CustomScrollView),
    ),
    '病例配置': (
      page: const CaseConfigPage(),
      landmark: '病例配置',
      topLandmark: '智愈寻真',
      endLandmark: '上消化道出血',
      scrollView: find.byKey(const ValueKey<String>('case-config-scroll')),
    ),
    '病例广场': (
      page: const CaseMarketPage(),
      landmark: '病例广场',
      topLandmark: '智愈寻真',
      endLandmark: '黑便与贫血综合病例',
      scrollView: find.byKey(const ValueKey<String>('case-market-scroll')),
    ),
    '作业': (
      page: const AssignmentsPage(),
      landmark: '作业登记',
      topLandmark: '智愈寻真',
      endLandmark: '现病史时间线',
      scrollView: find.byType(CustomScrollView),
    ),
    '批阅': (
      page: const ReviewPage(),
      landmark: '批阅登记',
      topLandmark: '智愈寻真',
      endLandmark: '周同学 · 慢阻肺急性加重',
      scrollView: find.byType(CustomScrollView),
    ),
    '教师我的': (
      page: const TeacherProfilePage(),
      landmark: '教学概况',
      topLandmark: '智愈寻真',
      endLandmark: '退出登录',
      scrollView: find.byType(CustomScrollView),
    ),
  };

  for (final MapEntry<
      String,
      ({
        Widget page,
        String landmark,
        String topLandmark,
        String endLandmark,
        Finder scrollView,
      })> entry in pages.entries) {
    testWidgets(
      '${entry.key} reaches its end at 360x800 with text scale and safe areas',
      (WidgetTester tester) async {
        final bool usesShellSafeArea = entry.key != '登录';
        await _pumpWithDeviceMetrics(
          tester,
          entry.value.page,
          useShellSafeArea: usesShellSafeArea,
        );

        expect(find.text(entry.value.landmark), findsAtLeastNWidgets(1));
        final Element pageElement =
            tester.element(find.byWidget(entry.value.page));
        expect(
          MediaQuery.paddingOf(pageElement).top,
          usesShellSafeArea ? 0 : _safeTop,
        );
        expect(MediaQuery.viewPaddingOf(pageElement).bottom, _safeBottom);

        final Rect topRect = tester.getRect(
          find.text(entry.value.topLandmark).first,
        );
        final Finder endFinder = await _reachScrollableEnd(
          tester,
          scrollView: entry.value.scrollView,
          endLandmark: entry.value.endLandmark,
          pageName: entry.key,
        );
        final Rect endRect = tester.getRect(endFinder);

        expect(
          topRect.top,
          greaterThanOrEqualTo(_safeTop),
          reason: '${entry.key} content must stay below the top safe area',
        );
        expect(
          endRect.bottom,
          lessThanOrEqualTo(phone360.height - _safeBottom + 1),
          reason:
              '${entry.key} end content must stay above the bottom safe area',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('login submit remains reachable above a 300px keyboard',
      (WidgetTester tester) async {
    const LoginPage page = LoginPage();
    await _pumpWithDeviceMetrics(
      tester,
      page,
      keyboardInset: _keyboardInset,
    );

    final Element pageElement = tester.element(find.byWidget(page));
    expect(MediaQuery.viewInsetsOf(pageElement).bottom, _keyboardInset);
    expect(MediaQuery.viewPaddingOf(pageElement).bottom, _safeBottom);
    expect(MediaQuery.paddingOf(pageElement).bottom, 0);

    await tester.tap(find.byType(TextFormField).last);
    await tester.pumpAndSettle();
    await _reachScrollableEnd(
      tester,
      scrollView: find.byType(SingleChildScrollView),
      endLandmark: '登录',
      pageName: '登录键盘场景',
    );

    final Finder submit = find.widgetWithText(FilledButton, '登录');
    expect(submit.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(submit).bottom,
      lessThanOrEqualTo(phone360.height - _keyboardInset + 1),
      reason: 'login submit must not be covered by the keyboard',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat composer remains reachable above a 300px keyboard',
      (WidgetTester tester) async {
    const ChatRoomPage page = ChatRoomPage(caseId: 'chest-pain');
    await _pumpWithDeviceMetrics(
      tester,
      page,
      keyboardInset: _keyboardInset,
      useShellSafeArea: true,
    );

    final Element pageElement = tester.element(find.byWidget(page));
    expect(MediaQuery.viewInsetsOf(pageElement).bottom, _keyboardInset);
    expect(MediaQuery.viewPaddingOf(pageElement).bottom, _safeBottom);
    expect(MediaQuery.paddingOf(pageElement).bottom, 0);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await _reachScrollableEnd(
      tester,
      scrollView: find.byType(ListView),
      endLandmark: '你已经问到端坐呼吸线索，建议继续追问夜间憋醒。',
      pageName: '问诊室键盘场景',
    );

    final Finder composer = find.byType(TextField);
    final Finder send = find.byTooltip('发送');
    expect(composer.hitTestable(), findsOneWidget);
    expect(send.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(composer).bottom,
      lessThanOrEqualTo(phone360.height - _keyboardInset + 1),
      reason: 'chat composer must not be covered by the keyboard',
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpWithDeviceMetrics(
  WidgetTester tester,
  Widget page, {
  double keyboardInset = 0,
  bool useShellSafeArea = false,
}) {
  return pumpPage(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: phone360,
        padding: EdgeInsets.only(
          top: _safeTop,
          bottom: keyboardInset == 0 ? _safeBottom : 0,
        ),
        viewPadding: const EdgeInsets.only(
          top: _safeTop,
          bottom: _safeBottom,
        ),
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
        disableAnimations: true,
        textScaler: const TextScaler.linear(1.3),
      ),
      child: useShellSafeArea ? SafeArea(bottom: false, child: page) : page,
    ),
    size: phone360,
    textScaler: const TextScaler.linear(1.3),
  );
}

Future<Finder> _reachScrollableEnd(
  WidgetTester tester, {
  required Finder scrollView,
  required String endLandmark,
  required String pageName,
}) async {
  expect(scrollView, findsOneWidget,
      reason: '$pageName needs one main scroll view');
  final Finder scrollable =
      find.descendant(of: scrollView, matching: find.byType(Scrollable)).first;
  expect(scrollable, findsOneWidget, reason: '$pageName needs a Scrollable');

  final ScrollableState state = tester.state<ScrollableState>(scrollable);
  expect(state.axisDirection, AxisDirection.down);
  expect(state.position.hasContentDimensions, isTrue);

  final Finder endFinder = find.text(endLandmark);
  await tester.scrollUntilVisible(
    endFinder,
    280,
    scrollable: scrollable,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();

  for (int pass = 0; pass < 12 && state.position.extentAfter > 1; pass += 1) {
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }

  expect(
    state.position.extentAfter,
    lessThanOrEqualTo(1),
    reason: '$pageName must reach the actual end of its main scroll view',
  );
  expect(find.text(endLandmark), findsAtLeastNWidgets(1));
  expect(
    find.text(endLandmark).hitTestable(),
    findsAtLeastNWidgets(1),
    reason: '$pageName end landmark must be visible after scrolling',
  );
  return endFinder.last;
}
