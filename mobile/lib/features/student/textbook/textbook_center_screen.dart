import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 教材中心
class TextbookCenterScreen extends ConsumerStatefulWidget {
  const TextbookCenterScreen({super.key});

  @override
  ConsumerState<TextbookCenterScreen> createState() => _TextbookCenterScreenState();
}

class _TextbookCenterScreenState extends ConsumerState<TextbookCenterScreen> {
  final _filters = ['全部', '心血管内科', '综合', '基础医学', '呼吸内科'];
  String _selectedFilter = '全部';
  String _query = '';
  List<Map<String, dynamic>> _textbooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _filterKeyword {
    if (_selectedFilter == '全部') return null;
    return _selectedFilter;
  }

  Future<void> _load() async {
    final data = await StudentService().getTextbooks(
      department: _filterKeyword,
      keyword: _query.trim().isEmpty ? null : _query.trim(),
    );
    if (!mounted) return;
    setState(() {
      _textbooks = (data?['list'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      _isLoading = false;
    });
  }

  Future<void> _openSearch() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchDialog(initialQuery: _query),
    );
    if (result != null) {
      setState(() => _query = result);
      _isLoading = true;
      _load();
    }
  }

  void _showDetail(Map<String, dynamic> tb) {
    final tags = parseTags(tb['knowledgeTags']);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SerifText(tb['title'] as String? ?? '教材',
                        fontSize: 18),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Icon(Icons.close, size: 20, color: AppColors.text3Of(context)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MonoText(
                '${tb['edition'] ?? ''} · ${tb['author'] ?? ''} · ${tb['publisher'] ?? ''}',
                fontSize: 11,
                color: AppColors.text3Of(context),
              ),
              const SizedBox(height: 12),
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags
                      .map((t) => AppChip(label: t, type: ChipType.moss))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                tb['description'] as String? ?? '暂无简介',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.text2Of(context),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  MonoText('共 ${tb['chapterCount'] ?? 0} 章',
                      fontSize: 11, color: AppColors.text3Of(context)),
                  const Spacer(),
                  AppPrimaryButton(
                    label: '去刷对应基础题',
                    small: true,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.pushNamed(RouteNames.questionTraining);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
              title: '教材中心',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
              action: AppIconButton(
                icon: const Icon(Icons.search, size: 20),
                onPressed: _openSearch,
              ),
            ),
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _textbooks.isEmpty
                      ? const Center(child: Text('暂无教材'))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
                          children: _textbooks
                              .map((tb) => _textbookCard(tb))
                              .toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final active = _filters[i] == _selectedFilter;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = _filters[i]);
              _isLoading = true;
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceOf(context),
                border: Border.all(
                  color: active
                      ? AppColors.primaryOf(context)
                      : AppColors.ruleOf(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: active
                        ? AppColors.onPrimaryOf(context)
                        : AppColors.text2Of(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _textbookCard(Map<String, dynamic> tb) {
    final tags = parseTags(tb['knowledgeTags']);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetail(tb),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Center(
                child: Icon(Icons.menu_book_rounded,
                    size: 22, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText(tb['title'] as String? ?? '教材', fontSize: 15),
                  const SizedBox(height: 4),
                  MonoText(
                    '${tb['edition'] ?? ''} · ${tb['author'] ?? ''} · ${tb['department'] ?? ''}',
                    fontSize: 10,
                    color: AppColors.text3Of(context),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags
                        .take(4)
                        .map((t) => AppChip(label: t, type: ChipType.default_))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MonoText('${tb['chapterCount'] ?? 0} 章',
                fontSize: 10, color: AppColors.text4Of(context)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right,
                size: 16, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }
}

/// 解析知识点标签 JSON（兼容 List 与 String 两种存储）
List<String> parseTags(dynamic json) {
  if (json is List) {
    return json.cast<String>();
  }
  if (json is String && json.isNotEmpty) {
    try {
      final list = json.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      return list.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {}
  }
  return [];
}

/// 搜索对话框
class _SearchDialog extends StatefulWidget {
  final String initialQuery;
  const _SearchDialog({required this.initialQuery});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final _ctl = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      title: Text(
        '搜索教材',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context)),
      ),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '书名 / 作者 / 知识点',
          hintStyle: TextStyle(color: AppColors.text4Of(context)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
          ),
        ),
        style: TextStyle(color: AppColors.textOf(context)),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text('清除',
              style: TextStyle(color: AppColors.text3Of(context))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctl.text),
          child: Text(
            '搜索',
            style: TextStyle(
                color: AppColors.primaryOf(context),
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}