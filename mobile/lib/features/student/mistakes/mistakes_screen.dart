import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';

/// 错题本
class MistakesScreen extends ConsumerStatefulWidget {
  const MistakesScreen({super.key});

  @override
  ConsumerState<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends ConsumerState<MistakesScreen> {
  String _selectedFilter = '全部';
  final List<String> _filters = ['全部', '诊断', '病史', '检查', '病历', '沟通'];
  final Set<int> _expanded = {};

List<Map<String, dynamic>> _mistakes = [];
  bool _isLoading = true;

  /// 错题类型英文 key -> 中文显示标签
  static String _displayType(String? type) {
    switch (type) {
      case 'diagnosis': return '诊断错误';
      case 'history': return '漏问病史';
      case 'exam': return '检查错误';
      case 'record': return '文书问题';
      case 'communication': return '沟通';
      default: return type ?? '未知';
    }
  }

  /// 筛选标签 -> API 错题类型 key
  String? get _filterKeyword {
    if (_selectedFilter == '全部') return null;
    switch (_selectedFilter) {
      case '诊断': return 'diagnosis';
      case '病史': return 'history';
      case '检查': return 'exam';
      case '病历': return 'record';
      case '沟通': return 'communication';
      default: return null;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final kw = _filterKeyword;
    if (kw == null) return _mistakes;
    return _mistakes.where((m) => m['mistakeType'] == kw).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMistakes());
  }

  Future<void> _loadMistakes() async {
    final data = await StudentService().getMistakes();
    if (mounted && data != null) {
      final list = data['records'] as List<dynamic>?;
      if (list != null) {
        setState(() {
          _mistakes = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
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
              title: '错题本',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
              action: AppIconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => context.pushNamed(RouteNames.reviewReport),
              ),
            ),
            _buildStats(),
            _buildFilterBar(),
            _buildRecommendEntry(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? _buildEmpty()
                      : ListView(
                          padding: const EdgeInsets.only(top: 6, bottom: 100),
                          children: [
                            ...list.map((m) => _buildMistakeCard(m)),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: AppGhostButton(
                                label: '导出 PDF 复盘报告',
                                icon: const Icon(Icons.download, size: 14),
                                fullWidth: true,
                                dashed: true,
                                onPressed: () => context.pushNamed(RouteNames.reviewReport),
                              ),
                            ),
                          ],
                        ),
            ),
            StudentTabBar(currentIndex: 2, onTap: (i) {
              if (i == 0) context.goNamed(RouteNames.studentHome);
              if (i == 1) context.goNamed(RouteNames.chat);
              if (i == 3) context.goNamed(RouteNames.studentProfile);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
    padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
       Icon(Icons.inbox_outlined, size: 40, color: AppColors.text4Of(context)),
            const SizedBox(height: 12),
       Text('该分类暂无错题', style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
            const SizedBox(height: 4),
            MonoText('已切换至：$_selectedFilter', fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final unreviewed = _mistakes.where((m) => m['resolvedStatus'] == 0).length;
    final reviewed = _mistakes.where((m) => m['resolvedStatus'] == 1).length;
    final mastered = _mistakes.where((m) => m['resolvedStatus'] == 2).length;
    final total = _mistakes.length;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statItem(unreviewed.toString(), '未复习', AppColors.vermilion),
              Container(width: 1, height: 40, color: AppColors.ruleOf(context)),
              _statItem(reviewed.toString(), '已复习', AppColors.amber),
              Container(width: 1, height: 40, color: AppColors.ruleOf(context)),
_statItem(mastered.toString(), '已掌握', AppColors.moss),
            ],
          ),
          const SizedBox(height: 8),
          MonoText('共 $total 条错题', fontSize: 10, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  Widget _statItem(String num, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            num,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 44,
   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
   decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
    separatorBuilder: (_, __) => SizedBox(width: 6),
        itemBuilder: (context, i) {
          final active = _filters[i] == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = _filters[i]),
            child: Container(
       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                border: Border.all(color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                    fontFamily: 'JetBrainsMono',
                    letterSpacing: 0.02,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 薄弱知识点推荐入口
  Widget _buildRecommendEntry() {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.recommendation),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.onPrimaryOf(context).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.auto_awesome, size: 18, color: AppColors.onPrimaryOf(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '薄弱知识点智能推荐',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '针对薄弱点推荐基础题与对应教材',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onPrimarySoftOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.onPrimaryOf(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildMistakeCard(Map<String, dynamic> m) {
    final id = m['id'] as int;
    final mistakeType = m['mistakeType'] as String?;
    final typeLabel = _displayType(mistakeType);
    final resolved = m['resolvedStatus'] == 2;
    final typeColor = resolved ? AppColors.moss : AppColors.vermilion;
    final date = m['createdAt'] as String? ?? '';
    final title = m['caseTitle'] as String? ?? '';
    final evidence = m['evidenceJson'] as String? ?? '';
    final tagsStr = m['knowledgeTag'] as String? ?? '';
    final tags = tagsStr.isEmpty
        ? <(String, ChipType)>[]
        : tagsStr.split(',').map((t) => (t.trim(), ChipType.default_)).toList();

    final expanded = _expanded.contains(id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (expanded) {
          _expanded.remove(id);
        } else {
          _expanded.add(id);
        }
      }),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Container(
     margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
     clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
child: Container(width: 3, color: resolved ? AppColors.moss : AppColors.vermilion),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Opacity(
                  opacity: resolved ? 0.7 : 1.0,
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
color: resolved ? AppColors.mossTint : AppColors.vermilionSoft,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: MonoText(
                        '● $typeLabel',
                        fontSize: 10,
                        color: typeColor,
                        letterSpacing: 0.08,
                      ),
                    ),
                    Row(
                      children: [
                        MonoText(date, fontSize: 11, color: AppColors.text4Of(context)),
             SizedBox(width: 6),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: AppColors.text3Of(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textOf(context)),
                ),
                if (expanded) ...[
                  const SizedBox(height: 6),
                  Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: AppColors.ruleOf(context)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            evidence,
                            style: TextStyle(fontSize: 12, color: AppColors.text3Of(context), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.map((t) => AppChip(label: t.$1, type: t.$2)).toList(),
                  ),
                  if (!resolved) ...[
                    const SizedBox(height: 8),
                    AppGhostButton(
                      label: '标记为已掌握',
                      small: true,
                      icon: const Icon(Icons.check, size: 12),
                      onPressed: () {
                        setState(() => m['resolvedStatus'] = 2);
                        AppFeedback.success(context, '已标记为已掌握');
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}
