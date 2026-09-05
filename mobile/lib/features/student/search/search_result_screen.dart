import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import '../textbook/textbook_center_screen.dart';

/// 全局智能检索结果页（教材 + 基础题 + 病例）
class SearchResultScreen extends ConsumerStatefulWidget {
  final String initialKeyword;
  const SearchResultScreen({super.key, this.initialKeyword = ''});

  @override
  ConsumerState<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends ConsumerState<SearchResultScreen> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initialKeyword);
  Map<String, dynamic>? _result;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword.isNotEmpty) {
      _search(widget.initialKeyword);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final result = await StudentService().searchResources(keyword.trim());
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
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
              title: '智能检索',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
            ),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _result == null
                      ? const Center(child: Text('输入关键词，检索教材、基础题与病例'))
                      : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: AppSearchField(
        controller: _ctl,
        hintText: '搜索教材 / 知识点 / 病例',
        onSubmitted: _search,
        onClear: () => setState(() => _result = null),
        height: 44,
      ),
    );
  }

  Widget _buildResults() {
    final textbooks = (_result?['textbooks'] as List<dynamic>?) ?? const [];
    final questions = (_result?['questions'] as List<dynamic>?) ?? const [];
    final cases = (_result?['cases'] as List<dynamic>?) ?? const [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (textbooks.isNotEmpty) _section('教材 · ${textbooks.length}'),
        ...textbooks.map((e) => _textbookRow(e as Map<String, dynamic>)),
        if (questions.isNotEmpty) _section('基础题 · ${questions.length}'),
        ...questions.map((e) => _questionRow(e as Map<String, dynamic>)),
        if (cases.isNotEmpty) _section('病例 · ${cases.length}'),
        ...cases.map((e) => _caseRow(e as Map<String, dynamic>)),
        if (textbooks.isEmpty && questions.isEmpty && cases.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('未找到相关结果')),
          ),
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: AppSectionHeader(title: title),
    );
  }

  Widget _textbookRow(Map<String, dynamic> tb) {
    final tags = parseTags(tb['knowledgeTags']);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.mossTintOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_rounded, size: 20, color: AppColors.primary),
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

  Widget _questionRow(Map<String, dynamic> q) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.questionTraining),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(),
        child: Row(
          children: [
            AppChip(label: q['knowledgeTag'] as String? ?? '综合', type: ChipType.moss),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                q['title'] as String? ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textOf(context)),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _caseRow(Map<String, dynamic> c) {
    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.chat,
        queryParameters: {'caseId': '${c['id']}'},
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['title'] as String? ?? '',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  MonoText('${c['department'] ?? ''} · ${c['creatorName'] ?? ''}',
                      fontSize: 10, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: AppColors.surfaceOf(context),
      border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
  }
}