import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../data/student_service.dart';

/// 个性化学习路径（P0-1 学习路径真实化）
///
/// 由学习教练 Agent 基于「本人真实薄弱点 + 错题 + 候选资源」生成，
/// 展示：知识水平诊断 → 递进路径步骤（知识点诊断 → 教材复习 → 简单病例 → 标准病例 → 综合病例）。
class LearningPathScreen extends ConsumerStatefulWidget {
  const LearningPathScreen({super.key});

  @override
  ConsumerState<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends ConsumerState<LearningPathScreen> {
  Map<String, dynamic>? _path;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final data = await StudentService().generateLearningPath();
    if (!mounted) return;
    // 先算真实步数（不能依赖 _steps：_path 此刻还没更新，会永远埋成 0）
    final stepCount =
        ((data?['pathSteps'] as List<dynamic>?) ?? const []).length;
    setState(() {
      _path = data;
      _isLoading = false;
      if (data == null) _error = 'AI 暂不可用，无法生成学习路径';
    });
    // 试用埋点（P2-3）：记录路径生成动作
    StudentService().track('learning_path_generate',
        detail: data == null ? 'failed' : 'steps=$stepCount');
  }

  List<dynamic> get _steps =>
      ((_path?['pathSteps'] as List<dynamic>?) ?? const []);

  List<dynamic> get _textSteps =>
      ((_path?['recommendedSteps'] as List<dynamic>?) ?? const []);

  List<String> get _weakTags => ((_path?['weakKnowledgeTags'] as List<dynamic>?)
          ?.whereType<String>()
          .toList()) ??
      const [];

  /// 教材溯源证据（P1-5 可追溯证据展示）
  List<dynamic> get _citations =>
      ((_path?['citations'] as List<dynamic>?) ?? const []);

  final Set<int> _expandedEvidences = {};

  String _stageLabel(String stage) {
    switch (stage) {
      case 'knowledge_diagnosis':
        return '知识点诊断';
      case 'textbook':
        return '教材复习';
      case 'simple_case':
        return '简单病例';
      case 'standard_case':
        return '标准病例';
      case 'comprehensive_case':
        return '综合病例';
      default:
        return '学习步骤';
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
              title: '我的学习路径',
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined,
                size: 40, color: AppColors.text4Of(context)),
            const SizedBox(height: 12),
            Text(_error ?? '加载失败',
                style: TextStyle(
                    fontSize: 14, color: AppColors.text3Of(context))),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: '重新生成',
              small: true,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_path?['diagnosis'] != null &&
              (_path!['diagnosis'] as String).trim().isNotEmpty)
            _buildDiagnosisCard(),
          if (_weakTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildWeakTags(),
          ],
          const SizedBox(height: 16),
          if (_steps.isNotEmpty)
            ..._steps.asMap().entries.map((e) => _buildStepCard(e.key, e.value))
          else if (_textSteps.isNotEmpty)
            ..._textSteps.asMap().entries.map((e) => _buildTextStep(e.key, e.value)),
          if (_citations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEvidenceSection(),
          ],
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOf(context),
                side: BorderSide(color: AppColors.surfaceEdgeOf(context)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重新生成路径'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 知识水平诊断卡 ----------

  Widget _buildDiagnosisCard() {
    final diagnosis = (_path!['diagnosis'] as String).trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOf(context).withValues(alpha: 0.10),
            AppColors.surfaceOf(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_outlined,
                  size: 18, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              SerifText('AI 知识水平诊断',
                  fontSize: 15, color: AppColors.textOf(context)),
            ],
          ),
          const SizedBox(height: 10),
          // AI 诊断文本打字机（公共组件）
          TypewriterText(
            diagnosis,
            style: TextStyle(
                fontSize: 13, height: 1.6, color: AppColors.text2Of(context)),
          ),
        ],
      ),
    );
  }

  // ---------- 薄弱点标签 ----------

  Widget _buildWeakTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText('薄弱知识点', fontSize: 10, color: AppColors.text4Of(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weakTags
              .map((t) => AppChip(label: t, type: ChipType.vermilion))
              .toList(),
        ),
      ],
    );
  }

  // ---------- 递进路径步骤卡 ----------

  Widget _buildStepCard(int index, dynamic step) {
    final s = step is Map ? step : const <String, dynamic>{};
    final stage = (s['stage'] as String?) ?? '';
    final title = (s['title'] as String?)?.trim() ?? '步骤 ${index + 1}';
    final goal = (s['goal'] as String?)?.trim() ?? '';
    final detail = (s['detail'] as String?)?.trim() ?? '';
    final evidence = (s['evidence'] as String?)?.trim() ?? '';
    final target = (s['targetMetric'] as String?)?.trim() ?? '';
    final resources = (s['resources'] as List<dynamic>?) ?? const [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onPrimaryOf(context),
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SerifText(title,
                      fontSize: 15, color: AppColors.textOf(context)),
                ),
                AppChip(label: _stageLabel(stage), type: ChipType.moss),
              ],
            ),
            if (goal.isNotEmpty) ...[
              const SizedBox(height: 10),
              _metaRow(
                  icon: Icons.flag_outlined,
                  iconColor: AppColors.primaryOf(context),
                  text: goal),
            ],
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              _metaRow(
                  icon: Icons.notes_rounded,
                  iconColor: AppColors.text3Of(context),
                  text: detail),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 6),
              _metaRow(
                  icon: Icons.link_rounded,
                  iconColor: AppColors.vermilionOf(context),
                  text: '依据 · $evidence'),
            ],
            if (target.isNotEmpty) ...[
              const SizedBox(height: 6),
              _metaRow(
                  icon: Icons.task_alt_rounded,
                  iconColor: AppColors.primaryOf(context),
                  text: '完成标准 · $target'),
            ],
            if (resources.isNotEmpty) ...[
              const SizedBox(height: 10),
              const DottedDivider(),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: resources
                    .whereType<Map>()
                    .map((r) => AppChip(
                          label:
                              '${_resTypeLabel((r['type'] as String?) ?? '')} · ${(r['title'] as String?) ?? ''}',
                          type: ChipType.default_,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resTypeLabel(String type) {
    switch (type) {
      case 'textbook':
        return '教材';
      case 'question':
        return '题';
      case 'case':
        return '病例';
      default:
        return type;
    }
  }

  // ---------- 兼容旧版文本步骤 ----------

  Widget _buildTextStep(int index, dynamic text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryOf(context),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onPrimaryOf(context),
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${text}',
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.text2Of(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 证据溯源（P1-5 可追溯证据展示） ----------

  Widget _buildEvidenceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.source_outlined, size: 18, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              SerifText('证据溯源 · 教材引用',
                  fontSize: 14, color: AppColors.textOf(context)),
              const Spacer(),
              MonoText('${_citations.length} 条',
                  fontSize: 10, color: AppColors.text4Of(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '每条路径建议均由教材原文支撑，可展开查看出处与原文片段。',
            style: TextStyle(
                fontSize: 11, color: AppColors.text3Of(context)),
          ),
          const SizedBox(height: 8),
          ..._citations.asMap().entries.map((e) => _buildCitation(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildCitation(int index, dynamic c) {
    final cit = c is Map ? c : const <String, dynamic>{};
    final book = (cit['book_name'] as String?)?.trim() ?? '未知教材';
    final chapter = (cit['chapter'] as String?)?.trim() ?? '';
    final page = cit['page_number'];
    final subject = (cit['subject'] as String?)?.trim() ?? '';
    final text = (cit['chunk_text'] as String?)?.trim() ?? '';
    final expanded = _expandedEvidences.contains(index);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          setState(() {
            if (expanded) {
              _expandedEvidences.remove(index);
            } else {
              _expandedEvidences.add(index);
            }
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgOf(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SerifText(book,
                        fontSize: 13, color: AppColors.textOf(context)),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.text4Of(context),
                  ),
                ],
              ),
              if (chapter.isNotEmpty || page != null || subject.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (chapter.isNotEmpty) chapter,
                    if (page != null) '第 $page 页',
                    if (subject.isNotEmpty) subject,
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 11, color: AppColors.text4Of(context)),
                ),
              ],
              if (expanded && text.isNotEmpty) ...[
                const SizedBox(height: 8),
                const DottedDivider(),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.text2Of(context)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12.5, height: 1.5, color: AppColors.text2Of(context)),
          ),
        ),
      ],
    );
  }
}
