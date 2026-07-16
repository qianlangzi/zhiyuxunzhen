import 'package:flutter/widgets.dart';
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

void main() {
  final Map<String, Widget> pages = <String, Widget>{
    '登录': const LoginPage(),
    '学生首页': const StudentHomePage(),
    '病例列表': const CasesListPage(),
    '病例详情': const CaseDetailPage(caseId: 'chest-pain'),
    '问诊室': const ChatRoomPage(caseId: 'chest-pain'),
    '能力反馈': const FeedbackPage(),
    '错题复盘': const MistakesPage(),
    '学生我的': const StudentProfilePage(),
    '教师概览': const TeacherOverviewPage(),
    '病例配置': const CaseConfigPage(),
    '病例广场': const CaseMarketPage(),
    '作业': const AssignmentsPage(),
    '批阅': const ReviewPage(),
    '教师我的': const TeacherProfilePage(),
  };

  for (final MapEntry<String, Widget> entry in pages.entries) {
    testWidgets('${entry.key} fits 360x800 at 1.3 text scale',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        entry.value,
        size: phone360,
        textScaler: TextScaler.linear(1.3),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
