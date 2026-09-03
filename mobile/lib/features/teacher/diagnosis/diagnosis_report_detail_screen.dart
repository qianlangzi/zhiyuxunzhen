import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/teacher_service.dart';

/// 学情诊断报告详情（P1-1）
///
/// 展示某份已生成的学情诊断报告：头部元信息 + AI 归纳 + 真实统计快照
/// （作业完成率/平均分等 stats、OSCE 维度均分、班级共性错题）。
class DiagnosisReportDetailScreen extends StatefulWidget {
  const DiagnosisReportDetailScreen({super.key, required this.reportId});

  final int reportId;

  @override
  State<DiagnosisReportDetailScreen> createState() =>
      _DiagnosisReportDetailScreenState();
}

class _DiagnosisReportDetailScreenState
    extends State<DiagnosisReportDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await TeacherService().getDiagnosisReportDetail(widget.reportId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  Map<String, dynamic> get _summary =>
      (_data?['summary'] as Map<String, dynamic>?) ?? {};

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
              action: _data == null
                  ? null
                  : AppGhostButton(
                      label: '刷新',
                      small: true,
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _load();
                      },
                    ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? _empty('报告不存在或已删除')
                      : SingleChildScrollView(
                          padding:
                              const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 40),
                          child: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          MonoText(msg, fontSize: 12, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final status = _data?['status'] as String? ?? 'SUCCESS';
    final degraded = status == 'DEGRADED';
    final ai = (_summary['ai'] as Map<String, dynamic>?) ?? {};
    final stats = (_summary['stats'] as List<dynamic>?) ?? [];
    final osce = (_summary['osceScores'] as Map<String, dynamic>?) ?? {};
    final mistakes = (_summary['commonMistakes'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(degraded),
        if (!degraded && ai.isNotEmpty) _buildAiSection(ai),
        if (stats.isNotEmpty) _buildStats(stats),
        if (osce.isNotEmpty) _buildOsce(osce),
        if (mistakes.isNotEmpty) _buildMistakes(mistakes),
        if (!degraded && ai.isEmpty && stats.isEmpty)
          MonoText('该报告仅有元信息，无可展示内容',
              fontSize: 12, color: AppColors.text3Of(context)),
      ],
    );
  }

  Widget _buildHeader(bool degraded) {
    final source = _data?['source'] as String? ?? 'AI';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: SerifText(
                  _data?['title'] as String? ?? '学情诊断报告',
                  fontSize: 17,
                ),
              ),
              AppChip(
                label: degraded ? '统计快照' : 'AI 归纳',
                type: degraded ? ChipType.amber : ChipType.moss,
                fontSize: 10,
              ),
            ],
          ),
          const SizedBox(height: 6),
          MonoText('来源：${source == 'AI' ? 'AI 归纳' : '规则统计'}',
              fontSize: 11, color: AppColors.text3Of(context)),
          const SizedBox(height: 4),
          MonoText('生成于 ${_formatTime(_data?['createdAt'] as String? ?? '')}',
              fontSize: 11, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _buildAiSection(Map<String, dynamic> ai) {
    final weaknessAnalysis = ai['weaknessAnalysis'] as String? ?? '';
    final focus = ai['recommendedFocus'] as String? ?? '';
    final suggestions =
        (ai['teachingSuggestions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('AI 归纳'),
        if (weaknessAnalysis.isNotEmpty)
          _block('薄弱点分析', weaknessAnalysis),
        if (suggestions.isNotEmpty) ...[
          _block('教学建议', ''),
          ...suggestions.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  border:
                      Border.all(color: AppColors.surfaceEdgeOf(context)),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonoText('建议 ${e.key + 1} · ${e.value['topic'] ?? ''}',
                        fontSize: 11, color: AppColors.primaryOf(context)),
                    const SizedBox(height: 6),
                    Text('${e.value['suggestion'] ?? ''}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textOf(context),
                            height: 1.6)),
                    MonoText('依据：${e.value['evidence'] ?? ''}',
                        fontSize: 11, color: AppColors.text3Of(context)),
                  ],
                ),
              )),
        ],
        if (focus.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EyebrowText('优先整改方向',
                    color: AppColors.onPrimarySoftOf(context)),
                const SizedBox(height: 6),
                Text(focus,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onPrimaryOf(context),
                        height: 1.6)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStats(List<dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('统计概览'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: stats.map((s) {
            final m = s as Map<String, dynamic>;
            final label = m['label'] as String? ?? '';
            final value = m['value'] as String? ?? '';
            return Container(
              width: (MediaQuery.of(context).size.width - 62) / 2,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.surfaceEdgeOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText(label, fontSize: 10,
                      color: AppColors.text3Of(context)),
                  const SizedBox(height: 6),
                  Text(value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryOf(context),
                      )),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOsce(Map<String, dynamic> osce) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('OSCE 维度均分'),
        ...osce.entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.surfaceEdgeOf(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textOf(context))),
                  ),
                  AppChip(label: '${e.value}', type: ChipType.indigo, fontSize: 11),
                ],
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMistakes(List<dynamic> mistakes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('班级共性错题'),
        ...mistakes.map((m) {
          final map = m as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    map['description'] as String? ?? '',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textOf(context)),
                  ),
                ),
                const SizedBox(width: 10),
                AppChip(label: '${map['count'] ?? 0} 次', type: ChipType.amber, fontSize: 10),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          SerifText(t, fontSize: 14),
        ],
      ),
    );
  }

  Widget _block(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(title.toUpperCase(),
              fontSize: 11,
              color: AppColors.primaryOf(context),
              letterSpacing: 0.06),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(content,
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textOf(context), height: 1.6)),
          ],
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.length < 16) return iso;
    final body = iso.replaceFirst('T', ' ');
    return body.substring(0, 16);
  }
}