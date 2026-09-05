import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';
import '../training/question_practice_screen.dart';
import 'learning_path_screen.dart';

/// 薄弱点推荐 · 知识点导流 + 逐题巩固
///
/// 结构（对照学习通 / 牛客的“先选薄弱点，再进刷题”体验）：
/// - 顶部双筛选：题型 × 知识点，全部取自后端返回的真实数据动态生成（非硬编码）；
/// - 主体为“薄弱知识点卡片”导流列表：每张卡片展示知识点名、薄弱原因/含错次数、
///   推荐教材、推荐题数；点击卡片（或“开始补练”）进入该知识点的逐题刷题页。
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({super.key});

  @override
  ConsumerState<RecommendationScreen> createState() =>
      _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  List<_WeaknessCard> _cards = [];
  bool _isLoading = true;

  // AI 学情诊断（P0-3）：{overall, items[], source, status}
  Map<String, dynamic>? _diagnosis;
  bool _diagnosisLoading = false;

  // 双筛选：类型存原始 questionType 码，null=全部
  String? _typeFilter;
  String? _tagFilter;

  static const List<String> _typeOrder = [
    'single_choice',
    'multiple_choice',
    'judgment',
    'fill_blank',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getRecommendations();
    if (!mounted) return;
    final cards = <_WeaknessCard>[];
    for (final r in data ?? []) {
      if (r is! Map) continue;
      final rec = r;
      final tag = (rec['knowledgeTag'] as String? ?? '').trim();
      if (tag.isEmpty) continue;
      final questions = ((rec['questions'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .toList();
      cards.add(_WeaknessCard(
        tag: tag,
        reason: _firstNonEmpty(rec, const ['reason', 'weaknessReason']),
        textbook: _firstNonEmpty(rec, const ['textbookRef', 'textbook']),
        errorCount: _firstInt(rec, const ['errorCount', 'wrongCount', 'count']),
        questions: questions,
      ));
    }
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
    _loadDiagnosis();
  }

  /// 加载 AI 学情诊断（后台并行，失败不影响推荐主列表）
  Future<void> _loadDiagnosis() async {
    setState(() => _diagnosisLoading = true);
    final d = await StudentService().getAiDiagnosis();
    if (!mounted) return;
    setState(() {
      _diagnosis = d;
      _diagnosisLoading = false;
    });
  }

  // ---------- 字段安全取值 ----------

  String _firstNonEmpty(Map rec, List<String> keys) {
    for (final k in keys) {
      final v = rec[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  int _firstInt(Map rec, List<String> keys) {
    for (final k in keys) {
      final v = rec[k];
      final n = v is num ? v.toInt() : int.tryParse('$v');
      if (n != null && n > 0) return n;
    }
    return 0;
  }

  // ---------- 动态筛选选项（来自后端真实数据） ----------

  List<String> get _tagOptions {
    final seen = <String>{};
    for (final c in _cards) {
      seen.add(c.tag);
    }
    return seen.toList();
  }

  List<String> get _typeOptions {
    final seen = <String>{};
    for (final c in _cards) {
      seen.addAll(c.questionTypes);
    }
    final ordered = _typeOrder.where(seen.contains).toList();
    for (final t in seen) {
      if (!ordered.contains(t)) ordered.add(t);
    }
    return ordered;
  }

  // ---------- 筛选后的卡片 ----------

  List<_WeaknessCard> get _filteredCards {
    return _cards.where((c) {
      final tagOk = _tagFilter == null || c.tag == _tagFilter;
      final typeOk =
          _typeFilter == null || c.questionTypes.contains(_typeFilter);
      return tagOk && typeOk;
    }).toList();
  }

  void _applyType(String? v) {
    setState(() => _typeFilter = v);
  }

  void _applyTag(String? v) {
    setState(() => _tagFilter = v);
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'multiple_choice':
        return '多选';
      case 'fill_blank':
        return '填空';
      case 'judgment':
        return '判断';
      default:
        return '单选';
    }
  }

  // ---------- 导流：进入知识点刷题 ----------

  void _openPractice(_WeaknessCard card) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuestionPracticeScreen(
        title: '${card.tag} · 巩固训练',
        knowledgeTag: card.tag,
        questionType: _typeFilter,
      ),
    ));
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
              title: '薄弱点推荐',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.mistakes),
              action: AppIconButton(
                icon: const Icon(Icons.route_outlined, size: 20),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const LearningPathScreen()),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _cards.isEmpty
                      ? _buildEmpty()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available,
                size: 40, color: AppColors.text4Of(context)),
            const SizedBox(height: 12),
            Text('暂无薄弱知识点',
                style:
                    TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
            const SizedBox(height: 4),
            MonoText('完成问诊评估或刷题后会自动生成推荐',
                fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cards = _filteredCards;
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off_outlined,
                          size: 40, color: AppColors.text4Of(context)),
                      const SizedBox(height: 10),
                      SerifText('当前筛选下暂无薄弱点',
                          fontSize: 15, color: AppColors.text2Of(context)),
                      const SizedBox(height: 4),
                      Text('可调整上方筛选条件',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.text4Of(context))),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    ..._buildDiagnosisSections(),
                    ...cards.map(_cardWidget),
                  ],
                ),
        ),
      ],
    );
  }

  // ---------- AI 学情诊断区块（P0-3） ----------

  List<Widget> _buildDiagnosisSections() {
    // 加载中：顶部显示轻量占位
    if (_diagnosisLoading) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PaperCard(
            tint: AppColors.primaryOf(context),
            radius: AppRadius.lg,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('AI 学情诊断生成中…',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.text3Of(context))),
              ],
            ),
          ),
        ),
      ];
    }

    final d = _diagnosis;
    if (d == null || d.isEmpty) return const [];

    final overall = (d['overall'] as String? ?? '').trim();
    final items = ((d['items'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .toList();
    if (overall.isEmpty && items.isEmpty) return const [];

    final isAi = (d['source'] as String? ?? '') == 'AI';
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PaperCard(
          tint: AppColors.primaryOf(context),
          tintStrength: 0.8,
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(16),
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
                    child: Icon(Icons.psychology_alt_outlined,
                        size: 15, color: AppColors.onPrimaryOf(context)),
                  ),
                  const SizedBox(width: 8),
                  SerifText('AI 学情诊断',
                      fontSize: 14, color: AppColors.textOf(context)),
                  const Spacer(),
                  AppChip(
                    label: isAi ? 'AI 归因' : '统计推断',
                    type: isAi ? ChipType.moss : ChipType.default_,
                  ),
                ],
              ),
              if (overall.isNotEmpty) ...[
                const SizedBox(height: 10),
                // AI 总评打字机（公共组件）
                TypewriterText(
                  overall,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppColors.text2Of(context)),
                ),
              ],
              if (items.isNotEmpty) ...[
                const SizedBox(height: 12),
                const DottedDivider(),
                const SizedBox(height: 4),
                ...items.map((it) => _buildDiagnosisItem(it)),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildDiagnosisItem(Map it) {
    final tag = (it['knowledgeTag'] as String? ?? '').trim();
    final rootCause = (it['rootCause'] as String? ?? '').trim();
    final suggestion = (it['suggestion'] as String? ?? '').trim();
    final statScore = it['statScore'];
    final score = statScore is num ? statScore.toDouble() : double.tryParse('$statScore');
    if (tag.isEmpty && rootCause.isEmpty && suggestion.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SerifText(tag.isEmpty ? '未标注知识点' : tag,
                    fontSize: 12.5, color: AppColors.textOf(context)),
              ),
              if (score != null) ...[
                const SizedBox(width: 8),
                MonoText(
                  '掌握度 ${(score * 100).round()}%',
                  fontSize: 10,
                  color: score < 0.5
                      ? AppColors.vermilionOf(context)
                      : AppColors.text3Of(context),
                ),
              ],
            ],
          ),
          if (rootCause.isNotEmpty) ...[
            const SizedBox(height: 4),
            _metaRow(
              icon: Icons.feedback_outlined,
              iconColor: AppColors.vermilionOf(context),
              text: '根因 · $rootCause',
            ),
          ],
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 4),
            _metaRow(
              icon: Icons.tips_and_updates_outlined,
              iconColor: AppColors.primaryOf(context),
              text: '建议 · $suggestion',
            ),
          ],
        ],
      ),
    );
  }

  // ---------- 顶部双筛选（题型 + 知识点） ----------

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.bgOf(context),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chipRow(
            label: '题型',
            icon: Icons.quiz_outlined,
            options: _typeOptions,
            selected: _typeFilter,
            labeler: _typeLabel,
            onTap: _applyType,
          ),
          const SizedBox(height: 2),
          _chipRow(
            label: '知识点',
            icon: Icons.lightbulb_outline_rounded,
            options: _tagOptions,
            selected: _tagFilter,
            labeler: (o) => o,
            onTap: _applyTag,
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required String label,
    required IconData icon,
    required List<String> options,
    required String? selected,
    required String Function(String) labeler,
    required void Function(String?) onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          child: Row(
            children: [
              Icon(icon, size: 13, color: AppColors.text3Of(context)),
              const SizedBox(width: 4),
              MonoText(label, fontSize: 10, color: AppColors.text3Of(context)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('全部', selected == null, () => onTap(null)),
                ...options.map((o) =>
                    _filterChip(labeler(o), selected == o, () => onTap(o))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 筛选 chip：最小触发高度 44，保证 Min Touch Target
  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    final Color fg =
        active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context);
    final Color bg =
        active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border:
              Border.all(color: active ? bg : AppColors.surfaceEdgeOf(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: fg,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ---------- 薄弱知识点卡片（导流入口） ----------

  Widget _cardWidget(_WeaknessCard c) {
    final count = c.typeCount(_typeFilter);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        tint: AppColors.primaryOf(context),
        radius: AppRadius.lg,
        padding: const EdgeInsets.all(16),
        onTap: () => _openPractice(c),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(label: c.tag, type: ChipType.moss),
                    const SizedBox(width: 8),
                    const AppChip(label: '薄弱点', type: ChipType.vermilion),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18, color: AppColors.text3Of(context)),
                  ],
                ),
                const SizedBox(height: 12),
                if (c.reason.isNotEmpty) ...[
                  _metaRow(
                    icon: Icons.feedback_outlined,
                    iconColor: AppColors.vermilionOf(context),
                    text: '薄弱原因 · ${c.reason}',
                  ),
                  const SizedBox(height: 8),
                ] else if (c.errorCount > 0) ...[
                  _metaRow(
                    icon: Icons.replay_circle_filled_outlined,
                    iconColor: AppColors.vermilionOf(context),
                    text: '含错次数 · ${c.errorCount}',
                  ),
                  const SizedBox(height: 8),
                ],
                if (c.textbook.isNotEmpty)
                  _metaRow(
                    icon: Icons.menu_book_outlined,
                    iconColor: AppColors.primaryOf(context),
                    text: '推荐教材 · ${c.textbook}',
                  ),
                const SizedBox(height: 14),
                const DottedDivider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MonoText(
                      count > 0 ? '推荐 $count 道题' : '暂无推荐题',
                      fontSize: 11,
                      color: AppColors.text3Of(context),
                    ),
                    AppPrimaryButton(
                      label: count > 0 ? '开始补练 $count 道' : '开始补练',
                      small: true,
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      onPressed: () => _openPractice(c),
                    ),
                  ],
                ),
              ],
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

/// 单个薄弱知识点卡片模型
class _WeaknessCard {
  final String tag;
  final String reason;
  final String textbook;
  final int errorCount;
  final List<Map> questions;

  _WeaknessCard({
    required this.tag,
    required this.reason,
    required this.textbook,
    required this.errorCount,
    required this.questions,
  });

  /// 该知识点涉及的题型（真实来源：后端题目）。
  Set<String> get questionTypes => questions
      .map((q) => (q['questionType'] as String? ?? 'single_choice'))
      .toSet();

  /// 在给定题型筛选下的推荐题数。
  int typeCount(String? type) {
    if (type == null) return questions.length;
    return questions
        .where((q) => (q['questionType'] as String? ?? 'single_choice') == type)
        .length;
  }
}
