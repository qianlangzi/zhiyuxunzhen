import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 每日病历 · 批阅报告页
///
/// 展示 AI 结构化批阅结果：总分 + 九段得分条 + 逐段缺陷清单 + AI 总评，
/// 支持多版本切换（修订迭代对比）；教师复核分优先于 AI 分展示。
class MrReportScreen extends ConsumerStatefulWidget {
  const MrReportScreen({super.key, required this.scheduleId});

  final int scheduleId;

  @override
  ConsumerState<MrReportScreen> createState() => _MrReportScreenState();
}

class _MrReportScreenState extends ConsumerState<MrReportScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final detail = await StudentService().getDailyMrDetail(widget.scheduleId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _records =>
      ((_detail?['myRecords'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((r) => ((r['status'] as num?)?.toInt() ?? 0) >= 1)
          .toList();

  Map<String, dynamic>? get _current {
    if (_records.isEmpty) return null;
    final idx = _selectedIndex.clamp(0, _records.length - 1);
    return _records[idx];
  }

  Map<String, dynamic>? get _review {
    final raw = _current?['reviewJson'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  double get _finalScore {
    final t = (_current?['totalScore'] as num?)?.toDouble();
    return t ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '批阅报告',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : records.isEmpty
                      ? Center(
                          child: Text('还没有提交记录',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.text3Of(context))))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          children: [
                            if (records.length > 1) _buildVersionChips(),
                            _buildScoreCard(),
                            const SizedBox(height: 12),
                            _buildSegmentList(),
                            const SizedBox(height: 12),
                            _buildCommentCard(),
                            const SizedBox(height: 12),
                            if ((_detail?['referenceRecord'] as String?)?.isNotEmpty == true)
                              _buildReferenceCard(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 版本切换 ----------------

  Widget _buildVersionChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _records.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = _records[i];
          final selected = i == _selectedIndex;
          return AppPressable(
            onTap: () => setState(() => _selectedIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
              ),
              child: Text(
                '第 ${(r['version'] as num?)?.toInt() ?? i + 1} 版',
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text2Of(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- 总分卡 ----------------

  Widget _buildScoreCard() {
    final reviewed = _current?['teacherComment'] != null;
    final confidence = (_current?['aiConfidence'] as num?)?.toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: (_finalScore / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: _scoreColor(_finalScore),
                    backgroundColor: AppColors.ruleSoftOf(context),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_finalScore.toStringAsFixed(0),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textOf(context))),
                    Text('分', style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reviewed ? '教师已复核' : 'AI 批阅',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context))),
                const SizedBox(height: 6),
                if (confidence != null)
                  Text(
                    confidence >= 0.85
                        ? 'AI 判定置信度高，供参考'
                        : 'AI 置信度一般，以教师复核为准',
                    style: TextStyle(fontSize: 12, color: AppColors.text3Of(context)),
                  ),
                const SizedBox(height: 6),
                Text(
                  '第 ${( _current?['version'] as num?)?.toInt() ?? 1} 版 · '
                  '${_current?['submittedAt'] ?? ''}',
                  style: TextStyle(fontSize: 11.5, color: AppColors.text4Of(context)),
                ),
                const SizedBox(height: 10),
                AppGhostButton(
                  label: '再写一版，把缺陷改掉',
                  onPressed: () async {
                    await context.pushNamed(RouteNames.mrWorkshop,
                        pathParameters: {'scheduleId': '${widget.scheduleId}'});
                    _load();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 85) return AppColors.moss3Of(context);
    if (score >= 70) return AppColors.amberOf(context);
    return AppColors.vermilionOf(context);
  }

  // ---------------- 九段得分 ----------------

  Widget _buildSegmentList() {
    final segs = ((_review?['segments'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (segs.isEmpty) {
      return AppCard(
        child: Text('该版本暂无 AI 批阅明细（AI 不可用时提交，待教师人工批阅）',
            style: TextStyle(fontSize: 12.5, color: AppColors.text3Of(context))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('九段得分',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context))),
          const SizedBox(height: 12),
          for (final seg in segs) ...[
            _buildSegmentRow(seg),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentRow(Map<String, dynamic> seg) {
    final name = _segName(seg['key'] as String? ?? '');
    final score = (seg['score'] as num?)?.toDouble() ?? 0;
    final full = (seg['full'] as num?)?.toDouble() ?? 100;
    final ratio = full <= 0 ? 0.0 : (score / full).clamp(0.0, 1.0);
    final defects = (seg['defects'] as List?) ?? const [];
    final comment = seg['comment'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name,
                style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context))),
            const Spacer(),
            Text('${score.toStringAsFixed(0)}/$full',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _scoreColor(full <= 0 ? 0 : score / full * 100))),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            color: _scoreColor(ratio * 100),
            backgroundColor: AppColors.ruleSoftOf(context),
          ),
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(comment,
              style: TextStyle(fontSize: 11.5, height: 1.5,
                  color: AppColors.text3Of(context))),
        ],
        for (final d in defects.whereType<Map<String, dynamic>>()) ...[
          const SizedBox(height: 5),
          _buildDefectChip(d),
        ],
      ],
    );
  }

  Widget _buildDefectChip(Map<String, dynamic> d) {
    final level = (d['level'] as num?)?.toInt() ?? 1;
    final color = level >= 3
        ? AppColors.vermilionOf(context)
        : level == 2
            ? AppColors.amberOf(context)
            : AppColors.text3Of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d['msg'] as String? ?? d['tag'] as String? ?? '',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          if ((d['suggest'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text('建议：${d['suggest']}',
                style: TextStyle(fontSize: 11, height: 1.5,
                    color: AppColors.text3Of(context))),
          ],
        ],
      ),
    );
  }

  String _segName(String key) {
    const map = {
      'chief_complaint': '主诉',
      'history_present': '现病史',
      'history_past': '既往史',
      'physical_exam': '体格检查',
      'auxiliary_exam': '辅助检查',
      'diagnosis': '初步诊断',
      'diagnosis_basis': '诊断依据',
      'differential': '鉴别诊断',
      'treatment_plan': '诊疗计划',
    };
    return map[key] ?? key;
  }

  // ---------------- 总评 ----------------

  Widget _buildCommentCard() {
    final ai = _review?['reviewComment'] as String? ?? '';
    final teacher = _current?['teacherComment'] as String?;
    if (ai.isEmpty && (teacher == null || teacher.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teacher?.isNotEmpty == true) ...[
            Row(
              children: [
                Icon(Icons.school_rounded, size: 15, color: AppColors.primaryOf(context)),
                const SizedBox(width: 6),
                Text('教师点评',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context))),
              ],
            ),
            const SizedBox(height: 6),
            Text(teacher!,
                style: TextStyle(fontSize: 12.5, height: 1.6,
                    color: AppColors.text2Of(context))),
            if (ai.isNotEmpty) const SizedBox(height: 12),
          ],
          if (ai.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.amberOf(context)),
                const SizedBox(width: 6),
                Text('AI 总评',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context))),
              ],
            ),
            const SizedBox(height: 6),
            Text(ai,
                style: TextStyle(fontSize: 12.5, height: 1.6,
                    color: AppColors.text2Of(context))),
            const AiGeneratedNote(),
          ],
        ],
      ),
    );
  }

  // ---------------- 参考病历 ----------------

  Widget _buildReferenceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 15, color: AppColors.moss3Of(context)),
              const SizedBox(width: 6),
              Text('参考病历（已解锁）',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context))),
            ],
          ),
          const SizedBox(height: 8),
          Text(_detail?['referenceRecord'] as String? ?? '',
              style: TextStyle(fontSize: 12.5, height: 1.7,
                  color: AppColors.text2Of(context))),
        ],
      ),
    );
  }
}
