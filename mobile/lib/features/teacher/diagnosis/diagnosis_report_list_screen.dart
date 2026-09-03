import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 学情诊断报告列表（P1-1）
///
/// 教师可基于真实聚合统计 + AI 归纳生成「全体学生」学情诊断报告，
/// 报告持久化后在此列表按时间倒序展示，点击查看详情、可删除。
class DiagnosisReportListScreen extends StatefulWidget {
  const DiagnosisReportListScreen({super.key});

  @override
  State<DiagnosisReportListScreen> createState() =>
      _DiagnosisReportListScreenState();
}

class _DiagnosisReportListScreenState
    extends State<DiagnosisReportListScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await TeacherService().getDiagnosisReports();
    if (!mounted) return;
    setState(() {
      _reports = data ?? [];
      _isLoading = false;
    });
  }

  Future<void> _generate() async {
    if (_generating) return;
    final ok = await AppFeedback.confirm(
      context,
      title: '生成学情诊断报告',
      content: '将基于当前全部学生的真实作业/批阅/OSCE/错题统计，生成一份「全体学生」学情诊断报告并保存。',
      confirmText: '生成',
    );
    if (!ok) return;
    setState(() => _generating = true);
    final close = AppFeedback.showLoading(context, label: 'AI 正在生成报告…');
    final res = await TeacherService().generateDiagnosisReport();
    close();
    if (!mounted) return;
    setState(() => _generating = false);
    if (res.data == null) {
      AppFeedback.error(context, res.message.isEmpty ? '生成失败' : res.message);
      return;
    }
    AppFeedback.success(context, '报告已生成');
    await _load();
    final id = (res.data!['id'] as num?)?.toInt();
    if (id != null) {
      context.pushNamed(RouteNames.diagnosisReportDetail, pathParameters: {'id': '$id'});
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await AppFeedback.confirm(
      context,
      title: '删除报告',
      content: '删除后不可恢复，确定删除「${r['title']}」吗？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    await TeacherService().deleteDiagnosisReport((r['id'] as num).toInt());
    if (!mounted) return;
    AppFeedback.success(context, '已删除');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '学情诊断报告',
              onBack: () => context.canPop() ? context.pop() : null,
              action: AppGhostButton(
                label: _generating ? '生成中…' : '生成报告',
                small: true,
                onPressed: _generating ? null : _generate,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: MonoText(
                '基于真实作业 / 批阅 / OSCE / 错题统计 · 可反复生成仲裁日期之前的历史快照',
                fontSize: 10,
                color: AppColors.text4Of(context),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.ruleSoftOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assessment_outlined,
                  size: 30, color: AppColors.text4Of(context)),
            ),
            const SizedBox(height: 16),
            SerifText('暂无诊断报告', fontSize: 16, color: AppColors.text2Of(context)),
            const SizedBox(height: 6),
            MonoText('点击右上角「生成报告」，即可生成并保存一份全体学生学情诊断报告',
                fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildCard(_reports[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> r) {
    final id = (r['id'] as num?)?.toInt() ?? 0;
    final source = r['source'] as String? ?? 'AI';
    final status = r['status'] as String? ?? 'SUCCESS';
    final createdAt = r['createdAt'] as String? ?? '';
    final sourceAi = source == 'AI';

    return PressableScale(
      child: GestureDetector(
        onTap: () => context.pushNamed(
          RouteNames.diagnosisReportDetail,
          pathParameters: {'id': '$id'},
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: sourceAi
                          ? AppColors.mossSoftOf(context)
                          : AppColors.amberSoftOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 20,
                      color: sourceAi
                          ? AppColors.primaryOf(context)
                          : AppColors.amberOf(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['title'] as String? ?? '学情诊断报告',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOf(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            MonoText(
                              status == 'DEGRADED'
                                  ? 'AI 不可用 · 统计快照'
                                  : 'AI 归纳',
                              fontSize: 10,
                              color: status == 'DEGRADED'
                                  ? AppColors.amberOf(context)
                                  : AppColors.primaryOf(context),
                            ),
                            const SizedBox(width: 8),
                            MonoText(_formatTime(createdAt),
                                fontSize: 10, color: AppColors.text3Of(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _delete(r),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.ruleSoftOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.text3Of(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.length < 16) return iso;
    final body = iso.replaceFirst('T', ' ');
    return body.substring(0, 16);
  }
}