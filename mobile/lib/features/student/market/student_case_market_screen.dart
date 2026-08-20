import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../common/data/case_market_api.dart';

/// 学生端病例广场 · 选择病例开始 AI 问诊
class StudentCaseMarketScreen extends ConsumerStatefulWidget {
  const StudentCaseMarketScreen({super.key});

  @override
  ConsumerState<StudentCaseMarketScreen> createState() =>
      _StudentCaseMarketScreenState();
}

class _StudentCaseMarketScreenState
    extends ConsumerState<StudentCaseMarketScreen> {
  int _currentFilter = 0;
  final _filters = ['全部', '心血管', '呼吸', '消化', '内分泌', '高评分'];
  String _query = '';
  List<_CaseMarketItem> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCases());
  }

  Future<void> _loadCases() async {
    final resp = await CaseMarketApi().getCaseList(pageNum: 1, pageSize: 50);
    if (!mounted) return;
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data!['list'] as List<dynamic>?;
      setState(() {
        _cases = (list ?? [])
            .map((c) => _CaseMarketItem.fromJson(c as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _cases = [];
        _isLoading = false;
      });
      if (resp.message.isNotEmpty) {
        AppFeedback.info(context, resp.message);
      }
    }
  }

  List<_CaseMarketItem> get _filtered {
    if (_cases.isEmpty) return [];
    final kw = _filters[_currentFilter];
    final q = _query.trim().toLowerCase();
    return _cases.where((c) {
      bool match = true;
      switch (kw) {
        case '高评分':
          match = c.ratingAvg >= 4.8;
        case '全部':
          match = true;
        default:
          match = c.department == kw;
      }
      if (match && q.isNotEmpty) {
        match = c.title.toLowerCase().contains(q) ||
            c.creatorName.toLowerCase().contains(q) ||
            c.knowledgeTags.toLowerCase().contains(q);
      }
      return match;
    }).toList();
  }

  Future<void> _openSearch() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchDialog(initialQuery: _query),
    );
    if (result != null) {
      setState(() => _query = result);
    }
  }

  void _startCase(int caseId) {
    context.pushNamed(
      RouteNames.chat,
      queryParameters: {'caseId': caseId.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '病例广场',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.studentHome),
              action: AppIconButton(
                icon: const Icon(Icons.search, size: 20),
                onPressed: _openSearch,
              ),
            ),
            _buildFilterBar(),
            if (_query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    MonoText('搜索「$_query」· ${list.length} 条',
                        fontSize: 11, color: AppColors.text3Of(context)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _query = ''),
                      child: const MonoText('清除',
                          fontSize: 11, color: AppColors.vermilion),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off,
                                  size: 40, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              Text('暂无可用病例',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.text3Of(context))),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(top: 6, bottom: 100),
                          children: list
                              .map((c) => _caseCard(c))
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
          final active = i == _currentFilter;
          return GestureDetector(
            onTap: () => setState(() => _currentFilter = i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _caseCard(_CaseMarketItem c) {
    final coverPalette = _coverPaletteOf(c.department);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1F1C).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // —— 封面 ——
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: coverPalette.$1,
              border: Border(bottom: BorderSide(color: coverPalette.$2)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoText(
                        '${c.department} · ${c.difficultyLabel}',
                        fontSize: 10,
                        color: coverPalette.$3,
                        letterSpacing: 0.12,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.title,
                        style: TextStyle(
                          fontFamily: 'NotoSerifSC',
                          fontFamilyFallback: [
                            'Songti SC',
                            'STSong',
                            'Noto Serif CJK SC',
                            'Source Han Serif SC',
                          ],
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOf(context),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // —— 详情 ——
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MonoText(c.creatorName.isEmpty ? '匿名教师' : c.creatorName,
                        fontSize: 11, color: AppColors.text3Of(context)),
                    if (c.knowledgeTags.isNotEmpty) ...[
                      MonoText(' · ',
                          fontSize: 11, color: AppColors.text3Of(context)),
                      Expanded(
                        child: MonoText(c.knowledgeTags,
                            fontSize: 11,
                            color: AppColors.text3Of(context)),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                const DottedDivider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        MonoText('引用 ',
                            fontSize: 11,
                            color: AppColors.text3Of(context)),
                        MonoText('${c.referenceCount}',
                            fontSize: 11,
                            color: AppColors.textOf(context),
                            weight: FontWeight.w600),
                        const SizedBox(width: 12),
                        MonoText('★ ${c.ratingAvg.toStringAsFixed(1)}',
                            fontSize: 11, color: AppColors.amber),
                      ],
                    ),
                    Builder(
                      builder: (btnCtx) => AppPrimaryButton(
                        label: '开始问诊',
                        small: true,
                        onPressed: () => _startCase(c.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _coverPaletteOf(String dept) {
    switch (dept) {
      case '心血管':
        return (const Color(0xFFE8F0E8), const Color(0xFFC8D8C8), const Color(0xFF6A8F6A));
      case '呼吸':
        return (const Color(0xFFF5EDE0), const Color(0xFFE3CFA0), const Color(0xFFC4A35A));
      case '消化':
        return (const Color(0xFFE8ECF5), const Color(0xFFC4CCE0), const Color(0xFF5A6FA0));
      case '内分泌':
        return (const Color(0xFFF0E8F0), const Color(0xFFD8C0D8), const Color(0xFF8A6A8A));
      default:
        return (const Color(0xFFEDE5E0), const Color(0xFFD8C8C0), const Color(0xFF8A6A5A));
    }
  }
}

/// 病例广场列表项（对齐后端 CaseMarketListVO）
class _CaseMarketItem {
  final int id;
  final String title;
  final String department;
  final int difficulty;
  final double ratingAvg;
  final int referenceCount;
  final String creatorName;
  final String knowledgeTags;
  final String createdAt;

  _CaseMarketItem({
    required this.id,
    required this.title,
    required this.department,
    required this.difficulty,
    required this.ratingAvg,
    required this.referenceCount,
    required this.creatorName,
    required this.knowledgeTags,
    required this.createdAt,
  });

  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return '简单';
      case 3:
        return '困难';
      case 2:
      default:
        return '标准';
    }
  }

  factory _CaseMarketItem.fromJson(Map<String, dynamic> json) {
    return _CaseMarketItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '未命名病例',
      department: json['department'] as String? ?? '综合',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      referenceCount: (json['referenceCount'] as num?)?.toInt() ?? 0,
      creatorName: json['creatorName'] as String? ?? '',
      knowledgeTags: json['knowledgeTags'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
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
        '搜索病例',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context)),
      ),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '标题 / 教师 / 知识点',
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
            borderSide:
                BorderSide(color: AppColors.primaryOf(context), width: 1.5),
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
