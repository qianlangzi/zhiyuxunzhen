import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 班级详情
///
/// 进入某个教学班后按板块组织：作业管理 / 学情看板 / 资料。
/// 对应子功能复用既有页面（作业管理、学情看板、教材资料）。
class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.classId, this.className});

  final int classId;
  final String? className;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final name = widget.className?.trim().isNotEmpty == true
        ? widget.className!.trim()
        : '班级详情';
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: name,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.classManage),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  _sectionCard(
                    context,
                    icon: Icons.fact_check_outlined,
                    color: AppColors.vermilionOf(context),
                    bg: AppColors.vermilionSoftOf(context),
                    title: '作业管理',
                    subtitle: '发放 · 进度 · 批阅复核',
                    onTap: () => context.pushNamed(
                      RouteNames.teacherAssignments,
                      extra: {'classId': widget.classId},
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    context,
                    icon: Icons.insights_rounded,
                    color: AppColors.amberOf(context),
                    bg: AppColors.amberSoftOf(context),
                    title: '学情看板',
                    subtitle: 'AI 班级洞察 · 学习数据',
                    onTap: () => context.pushNamed(
                      RouteNames.dashboard,
                      extra: {'classId': widget.classId},
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    context,
                    icon: Icons.folder_open_rounded,
                    color: AppColors.indigoOf(context),
                    bg: AppColors.indigoSoftOf(context),
                    title: '资料',
                    subtitle: '上传课件 · 引用教材 · 音视频',
                    onTap: () => context.pushNamed(
                      RouteNames.classMaterial,
                      pathParameters: {'id': '${widget.classId}'},
                      extra: {'className': name},
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    context,
                    icon: Icons.people_alt_outlined,
                    color: AppColors.moss,
                    bg: AppColors.mossTintOf(context),
                    title: '成员管理',
                    subtitle: '查看已加入该班级的学生',
                    onTap: () => context.pushNamed(
                      RouteNames.classMembers,
                      extra: {'className': name},
                      pathParameters: {'id': '${widget.classId}'},
                    ),
                  ),
                  if (widget.classId > 0) ...[
                    const SizedBox(height: 24),
                    MonoText('班级 ID · #${widget.classId}',
                        fontSize: 10, color: AppColors.text4Of(context)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          boxShadow: AppShadow.card(context),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText(title,
                      fontSize: 16, color: AppColors.textOf(context)),
                  const SizedBox(height: 4),
                  MonoText(subtitle,
                      fontSize: 11, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
