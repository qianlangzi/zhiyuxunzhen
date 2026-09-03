import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 班级成员管理 —— 展示进入该班级的学生列表。
class ClassMembersScreen extends ConsumerStatefulWidget {
  const ClassMembersScreen({
    super.key,
    required this.classId,
    this.className,
  });

  final int classId;
  final String? className;

  @override
  ConsumerState<ClassMembersScreen> createState() => _ClassMembersScreenState();
}

class _ClassMembersScreenState extends ConsumerState<ClassMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> data = [];
    try {
      data = await TeacherService().getClassMembers(widget.classId);
    } catch (e) {
      debugPrint('loadMembers error: $e');
    }
    if (!mounted) return;
    setState(() {
      _members = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.className?.trim().isNotEmpty == true
        ? widget.className!.trim()
        : '班级成员';
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
                  : context.goNamed(RouteNames.classDetail),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: MonoText('${_members.length} 名学生',
                              fontSize: 11, color: AppColors.text3Of(context)),
                        ),
                        Expanded(
                          child: _members.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.group_outlined,
                                          size: 40,
                                          color: AppColors.text4Of(context)),
                                      const SizedBox(height: 12),
                                      Text('暂无学生加入',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.text3Of(context))),
                                      const SizedBox(height: 4),
                                      const MonoText(
                                          '将班级邀请码分享给学生即可进班',
                                          fontSize: 11),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 8, 20, 40),
                                  itemCount: _members.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, i) =>
                                      _memberCard(_members[i]),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final realName =
        (m['realName'] as String?)?.trim().isNotEmpty == true
            ? (m['realName'] as String).trim()
            : '同学';
    final sub = <String>[
      if ((m['grade'] as String?)?.trim().isNotEmpty == true)
        (m['grade'] as String).trim(),
      if ((m['className'] as String?)?.trim().isNotEmpty == true)
        (m['className'] as String).trim(),
      if ((m['username'] as String?)?.trim().isNotEmpty == true)
        '@${(m['username'] as String).trim()}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.indigoSoftOf(context),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              realName.characters.first,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.indigoOf(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SerifText(realName,
                    fontSize: 14, color: AppColors.textOf(context)),
                if (sub.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.text3Of(context)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}