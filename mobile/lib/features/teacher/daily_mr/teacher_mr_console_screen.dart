import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/teacher_service.dart';

/// 教师端 · 每日病历批阅台（AI 初筛 + 复核 + 班级缺陷热力图）
///
/// 「批阅台」：按期次查看学生病历，AI 置信度 ≥0.85 标记"建议采纳"，
/// 教师只需重点复核 needReview 的；点开可改分 + 写评语（最终分覆盖 AI 分）。
/// 「缺陷热力」：全班缺陷标签聚合统计，一眼定位共性短板（如"全班漏既往史"）。
class TeacherMrConsoleScreen extends ConsumerStatefulWidget {
  const TeacherMrConsoleScreen({super.key});

  @override
  ConsumerState<TeacherMrConsoleScreen> createState() =>
      _TeacherMrConsoleScreenState();
}

class _TeacherMrConsoleScreenState extends ConsumerState<TeacherMrConsoleScreen> {
  int _tab = 0;

  List<Map<String, dynamic>> _schedules = [];
  int? _scheduleId;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _defects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final schedules =
        (await TeacherService().getMrSchedules()).whereType<Map<String, dynamic>>().toList();
    if (!mounted) return;
    setState(() {
      _schedules = schedules;
      _scheduleId ??= schedules.isEmpty ? null : (schedules.first['scheduleId'] as num?)?.toInt();
      _loading = false;
    });
    _loadTabData();
  }

  Future<void> _loadTabData() async {
    final sid = _scheduleId;
    if (_tab == 0) {
      if (sid == null) return;
      final list = (await TeacherService().getMrRecords(scheduleId: sid))
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() => _records = list);
    } else {
      final list = (await TeacherService().getMrDefectStats(scheduleId: sid))
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() => _defects = list);
    }
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
              title: '每日病历批阅台',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(RouteNames.teacherHome);
                }
              },
            ),
            _buildTabs(),
            _buildScheduleBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tab == 0
                      ? _buildRecordList()
                      : _buildDefectList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Tab 与期次选择 ----------------

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _tabChip('批阅台', 0),
          const SizedBox(width: 8),
          _tabChip('缺陷热力', 1),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final active = _tab == index;
    return AppPressable(
      onTap: () {
        if (_tab == index) return;
        setState(() => _tab = index);
        _loadTabData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: active
                    ? AppColors.onPrimaryOf(context)
                    : AppColors.text2Of(context))),
      ),
    );
  }

  Widget _buildScheduleBar() {
    if (_schedules.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _schedules.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _schedules[i];
          final sid = (s['scheduleId'] as num?)?.toInt();
          final selected = sid == _scheduleId;
          final title = (s['publishDate'] as String? ?? '').replaceFirst('-', '/').substring(5);
          return AppPressable(
            onTap: sid == null ? null : () {
              setState(() => _scheduleId = sid);
              _loadTabData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryOf(context).withValues(alpha: 0.1)
                    : AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected
                        ? AppColors.primaryOf(context)
                        : AppColors.ruleOf(context),
                    width: 0.5),
              ),
              child: Text(
                '$title ${s['caseTitle'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? AppColors.primaryOf(context)
                        : AppColors.text2Of(context)),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- 批阅台列表 ----------------

  Widget _buildRecordList() {
    if (_records.isEmpty) {
      return Center(
        child: Text('这一期还没有学生提交',
            style: TextStyle(fontSize: 13, color: AppColors.text3Of(context))),
      );
    }
    final needReviewFirst = [..._records]
      ..sort((a, b) {
        final ra = (a['needReview'] as bool?) == true ? 0 : 1;
        final rb = (b['needReview'] as bool?) == true ? 0 : 1;
        return ra.compareTo(rb);
      });
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: needReviewFirst.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildRecordRow(needReviewFirst[i]),
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> r) {
    final needReview = r['needReview'] as bool? ?? false;
    final reviewed = r['reviewed'] as bool? ?? false;
    final score = (r['totalScore'] as num?)?.toDouble();
    final confidence = (r['aiConfidence'] as num?)?.toDouble();
    return AppPressable(
      onTap: () => _showReviewSheet(r),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r['studentName'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textOf(context))),
                      const SizedBox(width: 6),
                      Text('第 ${(r['version'] as num?)?.toInt() ?? 1} 版',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.text4Of(context))),
                      const Spacer(),
                      if (reviewed)
                        Text('已复核',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.moss3Of(context)))
                      else if (needReview)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.amberSoftOf(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('建议复核',
                              style: TextStyle(
                                  fontSize: 10.5, color: AppColors.amberOf(context))),
                        )
                      else
                        Text('AI 高置信',
                            style: TextStyle(
                                fontSize: 10.5, color: AppColors.moss3Of(context))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '提交于 ${r['submittedAt'] ?? '-'}'
                    '${confidence != null ? ' · AI 置信度 ${(confidence * 100).toStringAsFixed(0)}%' : ''}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.text4Of(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(score == null ? '待批' : score.toStringAsFixed(0),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: score == null
                        ? AppColors.text4Of(context)
                        : score >= 85
                            ? AppColors.moss3Of(context)
                            : score >= 70
                                ? AppColors.amberOf(context)
                                : AppColors.vermilionOf(context))),
          ],
        ),
      ),
    );
  }

  // ---------------- 复核底部弹层 ----------------

  void _showReviewSheet(Map<String, dynamic> r) {
    final scoreCtrl = TextEditingController(
        text: r['totalScore'] == null ? '' : '${(r['totalScore'] as num).toDouble()}');
    final commentCtrl = TextEditingController(text: r['teacherComment'] as String? ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r['studentName'] ?? ''} · 第 ${(r['version'] as num?)?.toInt() ?? 1} 版',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOf(context))),
            const SizedBox(height: 4),
            Text('AI 分 ${(r['aiScore'] as num?)?.toStringAsFixed(1) ?? '-'} · 置信度 ${((r['aiConfidence'] as num?)?.toDouble() ?? 0) >= 0.85 ? '高' : '一般'}',
                style: TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
            const SizedBox(height: 12),
            _buildAiReviewSummary(r),
            const SizedBox(height: 14),
            TextField(
              controller: scoreCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '最终得分（0-100，留空则维持 AI 分）',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '评语',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            AppPrimaryButton(
              label: '提交复核',
              onPressed: () async {
                final score = double.tryParse(scoreCtrl.text.trim());
                final resp = await TeacherService().reviewMrRecord(
                  recordId: (r['recordId'] as num?)?.toInt() ?? 0,
                  score: score,
                  comment: commentCtrl.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (resp != null) {
                  AppFeedback.info(context, '复核完成');
                  _loadTabData();
                } else {
                  AppFeedback.info(context, '复核失败，请稍后重试');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiReviewSummary(Map<String, dynamic> r) {
    final raw = r['reviewJson'] as String?;
    Map<String, dynamic>? review;
    if (raw != null && raw.isNotEmpty) {
      try {
        review = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (review == null) {
      return Text('暂无 AI 批阅明细',
          style: TextStyle(fontSize: 12, color: AppColors.text4Of(context)));
    }
    final comment = review['reviewComment'] as String? ?? '';
    final tags = (review['defectTags'] as List?) ?? const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 总评：$comment',
              style: TextStyle(fontSize: 12, height: 1.6,
                  color: AppColors.text2Of(context))),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags.whereType<String>())
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.vermilionSoftOf(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(t,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.vermilionOf(context))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- 缺陷热力 ----------------

  Widget _buildDefectList() {
    if (_defects.isEmpty) {
      return Center(
        child: Text('这一期还没有缺陷数据',
            style: TextStyle(fontSize: 13, color: AppColors.text3Of(context))),
      );
    }
    final maxCount = (_defects.first['count'] as num?)?.toInt() ?? 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _defects.length,
      itemBuilder: (_, i) {
        final d = _defects[i];
        final count = (d['count'] as num?)?.toInt() ?? 0;
        final students = (d['students'] as num?)?.toInt() ?? 0;
        final ratio = maxCount <= 0 ? 0.0 : count / maxCount;
        final severity = ratio >= 0.6
            ? AppColors.vermilionOf(context)
            : ratio >= 0.3
                ? AppColors.amberOf(context)
                : AppColors.text3Of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(d['tagName'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textOf(context))),
                  ),
                  Text('$count 次 · $students 人',
                      style: TextStyle(fontSize: 11.5, color: severity)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: severity,
                  backgroundColor: AppColors.ruleSoftOf(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
