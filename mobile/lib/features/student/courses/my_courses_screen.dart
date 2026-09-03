import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_service.dart';

/// 学生端 · 我的课程（学习通式独立页）
///
/// 学生通过老师分享的二维码/邀请码加入班级后，这里以课程卡片形式展示
/// 已加入的所有班级（多对多），点进卡片查看老师分享的资料与作业（闭环）。
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
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
    final bg = AppColors.bgOf(context);
    return Scaffold(
      backgroundColor: bg,
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
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _buildCourseCard(classes[index], index % _grads.length),
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

  Widget _buildCourseCard(dynamic raw, int colorIndex) {
    final m = _mapOf(raw);
    final name = (m['name'] ?? '未命名课程').toString();
    final teacher = (m['teacherName'] ?? '未知教师').toString();
    final count = (m['studentCount'] as num?)?.toInt() ?? 0;
    final joined = m['joinedAt'] == null
        ? ''
        : _shortDate(DateTime.tryParse(m['joinedAt'].toString()));

    return AppPressable(
      onTap: () => context.pushNamed(
        RouteNames.myCourseDetail,
        extra: {'classId': (m['id'] as num).toInt(), 'name': name},
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _grads[colorIndex],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadow.lifted(context),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(Icons.menu_book_rounded,
                  size: 96, color: Colors.white.withValues(alpha: 0.12)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.school_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.9)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    teacher,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _metaChip(Icons.groups_outlined, '$count 名同学', context),
                      if (joined.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _metaChip(Icons.schedule, '加入于 $joined', context),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5, color: Colors.white.withValues(alpha: 0.95))),
        ],
      ),
    );
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

  static const List<List<Color>> _grads = [
    [Color(0xFF4A6CFE), Color(0xFF7C93FF)],
    [Color(0xFF22B573), Color(0xFF6FD5A0)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFF06B6D4), Color(0xFF22D3EE)],
  ];
}