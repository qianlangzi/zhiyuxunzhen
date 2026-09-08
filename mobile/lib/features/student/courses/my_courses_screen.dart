import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_service.dart';

/// 学生端 · 我的课程
///
/// 以简约纸感卡片展示已加入班级，左侧苔藓绿色带点缀。
/// 点击进入班级主页查看老师分享的学习资料与作业。
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

/// 无数字待办红点（我的课程专用）
///
/// 课程卡片只表达「有未完成任务」，不报具体数量；数量与时效提醒统一由「作业待办」页承载。
class _PendingDot extends StatelessWidget {
  const _PendingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5484D).withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  List<dynamic>? _classes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await StudentService().getMyClasses();
    if (!mounted) return;
    setState(() {
      _classes = data;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    final data = await StudentService().getMyClasses();
    if (!mounted) return;
    setState(() {
      _classes = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '我的课程', onBack: context.pop),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primaryOf(context),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final classes = _classes ?? const [];
    if (classes.isEmpty) {
      return _buildEmpty();
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: classes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildCourseCard(classes[index]),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          ),
          child: Column(
            children: [
              Icon(Icons.school_outlined,
                  size: 48, color: AppColors.primaryOf(context)),
              const SizedBox(height: 16),
              Text('还没有课程',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOf(context))),
              const SizedBox(height: 8),
              Text(
                '扫描老师分享的二维码或输入邀请码加入班级，\n这里就会展示你的所有课程。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.text3Of(context)),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: '去加入班级',
                fullWidth: true,
                onPressed: () => context.pushNamed(RouteNames.studentJoinClass),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 简约纸感课程卡片：左侧色带 + 主信息，无渐变、无蓝色、无夸张装饰
  Widget _buildCourseCard(dynamic raw) {
    final m = _mapOf(raw);
    final name = (m['name'] ?? '未命名课程').toString();
    final teacher = (m['teacherName'] ?? '未知教师').toString();
    final count = (m['studentCount'] as num?)?.toInt() ?? 0;
    final joined = m['joinedAt'] == null
        ? ''
        : _shortDate(DateTime.tryParse(m['joinedAt'].toString()));
    // 待办联动：未完成作业 + 未完成资料任务（完成后自动清零）
    // 注意：课程页只做「有/无」提示（右上角无数字红点），不展示待办数量——数量提醒统一收口在作业待办
    final pendingAssignment = (m['pendingAssignmentCount'] as num?)?.toInt() ?? 0;
    final pendingLesson = (m['pendingLessonCount'] as num?)?.toInt() ?? 0;
    final hasPending = pendingAssignment + pendingLesson > 0;

    // 卡片本体 + 右上角无数字红点：只表达「这门课还有事没做」，不报数量
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppPressable(
          onTap: () {
            final id = (m['id'] as num?)?.toInt();
            if (id == null) return;
            context
                .pushNamed(
                  RouteNames.myCourseDetail,
                  pathParameters: {'id': '$id'},
                  extra: {'name': name},
                )
                .then((_) => _refresh());
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          boxShadow: AppShadow.card(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 左侧苔藓绿色带，作为课程卡片唯一主题点缀
                Container(width: 5, color: AppColors.primaryOf(context)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SerifText(name,
                            fontSize: 17,
                            weight: FontWeight.w700,
                            height: 1.3),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 14, color: AppColors.text3Of(context)),
                            const SizedBox(width: 5),
                            Text(teacher,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.text2Of(context))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _metaText('$count 名同学'),
                            if (joined.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.text4Of(context),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _metaText('加入于 $joined'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 右侧仅保留箭头：待办提示改为卡片右上角无数字红点
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.text4Of(context)),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
          // 无数字红点：仅表示「这门课还有事没做」，不展示数量
          if (hasPending)
            const Positioned(
              top: 12,
              right: 12,
              child: IgnorePointer(child: _PendingDot()),
            ),
        ],
      );
  }

  Widget _metaText(String text) {
    return Text(text,
        style: TextStyle(fontSize: 12, color: AppColors.text3Of(context)));
  }

  Map<String, dynamic> _mapOf(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  String _shortDate(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    return '${local.year}-${_p(local.month)}-${_p(local.day)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}