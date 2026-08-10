import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import '../textbook/textbook_center_screen.dart';

/// 薄弱知识点推荐（基础题 + 教材）
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({super.key});

  @override
  ConsumerState<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  List<dynamic> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getRecommendations();
    if (mounted) {
      setState(() {
        _recommendations = data ?? [];
        _isLoading = false;
      });
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
              title: '薄弱点推荐',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.mistakes),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recommendations.isEmpty
                      ? _buildEmpty()
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 40),
                          children: _recommendations
                              .map((r) => _recommendBlock(r as Map<String, dynamic>))
                              .toList(),
                        ),
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
            Icon(Icons.event_available, size: 40, color: AppColors.text4Of(context)),
            const SizedBox(height: 12),
            Text('暂无薄弱知识点', style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
            const SizedBox(height: 4),
            MonoText('完成问诊评估后会自动生成推荐', fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _recommendBlock(Map<String, dynamic> r) {
    final tag = r['knowledgeTag'] as String? ?? '综合';
    final questions = (r['questions'] as List<dynamic>?) ?? const [];
    final textbooks = (r['textbooks'] as List<dynamic>?) ?? const [];
    final aiAdvice = r['aiAdvice'] as String?;
    final aiPriority = (r['aiPriority'] as List<dynamic>?)?.cast<String>() ?? const [];
    final aiStudyPlan = r['aiStudyPlan'] as String?;
    final aiMistakesNote = r['aiMistakesNote'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            children: [
              AppChip(label: tag, type: ChipType.vermilion),
              const SizedBox(width: 8),
              MonoText('${questions.length} 题 · ${textbooks.length} 本教材',
                  fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
        ),
        if (aiAdvice != null && aiAdvice.isNotEmpty) _aiPanel(
          tag: tag,
          advice: aiAdvice,
          priority: aiPriority,
          studyPlan: aiStudyPlan,
          mistakesNote: aiMistakesNote,
        ),
        if (questions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Row(
              children: [
                const Icon(Icons.quiz_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                MonoText('推荐基础题', fontSize: 11, color: AppColors.text2Of(context)),
              ],
            ),
          ),
          ...questions.map((e) => _questionRow(e as Map<String, dynamic>)),
        ],
        if (textbooks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 14, color: AppColors.indigo),
                const SizedBox(width: 6),
                MonoText('对应教材', fontSize: 11, color: AppColors.text2Of(context)),
              ],
            ),
          ),
          ...textbooks.map((e) => _textbookRow(e as Map<String, dynamic>)),
        ],
        if (questions.isEmpty && textbooks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border.all(color: AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: MonoText('该知识点暂无推荐练习', fontSize: 11, color: AppColors.text3Of(context)),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _aiPanel({
    required String tag,
    required String advice,
    required List<String> priority,
    String? studyPlan,
    String? mistakesNote,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.mossTintOf(context), AppColors.surfaceOf(context)],
        ),
        border: Border.all(color: AppColors.primaryOf(context).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              MonoText('AI 智能建议', fontSize: 11, color: AppColors.primary),
              const Spacer(),
              AppChip(label: 'AI', type: ChipType.moss, fontSize: 10),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            advice,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textOf(context)),
          ),
          if (priority.isNotEmpty) ...[
            const SizedBox(height: 10),
            MonoText('优先复习', fontSize: 10, color: AppColors.text3Of(context)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: priority
                  .map((p) => AppChip(label: p, type: ChipType.moss))
                  .toList(),
            ),
          ],
          if (studyPlan != null && studyPlan.isNotEmpty) ...[
            const SizedBox(height: 10),
            _aiLine('学习路径', studyPlan),
          ],
          if (mistakesNote != null && mistakesNote.isNotEmpty && mistakesNote != '无') ...[
            const SizedBox(height: 8),
            _aiLine('错题提示', mistakesNote),
          ],
        ],
      ),
    );
  }

  Widget _aiLine(String label, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText(label, fontSize: 10, color: AppColors.text3Of(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            content,
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.text2Of(context)),
          ),
        ),
      ],
    );
  }

  Widget _questionRow(Map<String, dynamic> q) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.questionTraining),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AppChip(
              label: '${q['questionType'] == 'judgment' ? '判断' : '单选'}',
              type: ChipType.default_,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                q['title'] as String? ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textOf(context)),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _textbookRow(Map<String, dynamic> tb) {
    final tags = parseTags(tb['knowledgeTags']);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.indigoSoftOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_rounded, size: 20, color: AppColors.indigo),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SerifText(tb['title'] as String? ?? '', fontSize: 14),
                const SizedBox(height: 4),
                MonoText('${tb['edition'] ?? ''} · ${tb['author'] ?? ''}',
                    fontSize: 10, color: AppColors.text3Of(context)),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags
                        .take(3)
                        .map((t) => AppChip(label: t, type: ChipType.default_))
                        .toList(),
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