import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 病例广场
class CaseMarketScreen extends ConsumerStatefulWidget {
  const CaseMarketScreen({super.key});

  @override
  ConsumerState<CaseMarketScreen> createState() => _CaseMarketScreenState();
}

class _CaseMarketScreenState extends ConsumerState<CaseMarketScreen> {
  /// 筛选标签：首位「全部」，其余科室由后端 /case-market/departments 动态下发。
  /// 科室由教师创建病例时填写，无法预知全集，硬编码会导致新增科室永远筛不到。
  List<String> _filters = const ['全部'];
  int _currentFilter = 0;
  String _query = '';
  List<_CaseData> _cases = [];
  bool _isLoading = true;
  int? _qcLoadingId; // AI 质检进行中的 caseId
  int? _pqLoadingId; // AI 生成练习题进行中的 caseId

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDepartments();
      _loadCases();
    });
  }

  /// 拉取动态科室列表（失败静默，仅剩「全部」也不影响主流程）
  Future<void> _loadDepartments() async {
    final depts = await TeacherService().getMarketDepartments();
    if (!mounted || depts.isEmpty) return;
    setState(() {
      _filters = ['全部', ...depts];
      if (_currentFilter >= _filters.length) _currentFilter = 0;
    });
  }

  /// 加载列表：关键字 + 科室筛选均走服务端，不做客户端过滤
  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? data;
    try {
      data = await TeacherService().getMarketList(
        department: _currentFilter == 0 ? null : _filters[_currentFilter],
        keyword: _query.trim().isEmpty ? null : _query.trim(),
      );
    } catch (e) {
      // 兜底：加载异常也退出 loading，回退到默认展示，避免页面永久转圈
      debugPrint('loadCaseMarket error: $e');
      data = null;
    }
    if (mounted) {
      setState(() {
        List<dynamic>? raw;
        if (data != null) {
          // 后端分页结构 records；兼容旧字段 cases
          raw = (data['records'] as List<dynamic>?) ??
              (data['cases'] as List<dynamic>?);
        }
        // 仅当后端返回了非空列表才用真实数据，否则保留默认展示（供离线/无数据时预览）
        if (raw != null && raw.isNotEmpty) {
          _cases = raw
              .map((c) => _CaseData.fromJson(c as Map<String, dynamic>))
              .toList();
        } else {
          _cases.clear();
        }
        _isLoading = false;
      });
    }
  }

  /// 筛选切换（科室走服务端过滤）
  void _onFilterTap(int i) {
    if (i == _currentFilter) return;
    setState(() => _currentFilter = i);
    _loadCases();
  }

  /// AI 病例质检（RAG 教材锚点）
  Future<void> _qualityCheck(_CaseData c) async {
    if (c.caseId == null || _qcLoadingId != null) return;
    setState(() => _qcLoadingId = c.caseId);
    final result = await TeacherService().getQualityCheck(c.caseId!);
    if (!mounted) return;
    setState(() => _qcLoadingId = null);
    if (result == null) {
      AppFeedback.error(context, 'AI 暂不可用，无法质检病例');
      return;
    }
    _showQualitySheet(result);
  }

  /// AI 自动生成练习题（RAG 教材锚点）
  Future<void> _practiceQuestions(_CaseData c) async {
    if (c.caseId == null || _pqLoadingId != null) return;
    setState(() => _pqLoadingId = c.caseId);
    final result = await TeacherService().getPracticeQuestions(c.caseId!);
    if (!mounted) return;
    setState(() => _pqLoadingId = null);
    if (result == null) {
      AppFeedback.error(context, 'AI 暂不可用，无法生成练习题');
      return;
    }
    final questions =
        (result['questions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    _showQuestionsSheet(questions);
  }

  void _showQualitySheet(Map<String, dynamic> result) {
    final overallPass = result['overallPass'] as bool? ?? false;
    final checklist =
        (result['checklist'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: SerifText('AI 病例质检', fontSize: 17)),
                  AppChip(
                    label: overallPass ? '通过' : '需整改',
                    type: overallPass ? ChipType.moss : ChipType.vermilion,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('依据教材逐项校验病例，附出处',
                  fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: checklist.isEmpty
                    ? const Center(
                        child:
                            MonoText('无可质检项', fontSize: 12, color: Colors.grey))
                    : ListView(
                        controller: scrollController,
                        children: checklist.asMap().entries.map((e) {
                          final item = e.value;
                          final passed = item['passed'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceOf(context),
                              border: Border.all(
                                  color: AppColors.surfaceEdgeOf(context)),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                        passed
                                            ? Icons.check_circle
                                            : Icons.error_outline,
                                        size: 16,
                                        color: passed
                                            ? AppColors.primaryOf(context)
                                            : AppColors.vermilionOf(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: MonoText(
                                          '${item['item'] ?? '质检项'}',
                                          fontSize: 11,
                                          color: AppColors.textOf(context)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${item['reason'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textOf(context),
                                        height: 1.6)),
                                if ((item['textbookRef'] as String?)
                                        ?.isNotEmpty ??
                                    false)
                                  MonoText('教材：${item['textbookRef']}',
                                      fontSize: 11,
                                      color: AppColors.text3Of(context)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuestionsSheet(List<Map<String, dynamic>> questions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: SerifText('AI 配套练习题', fontSize: 17)),
                  const AppChip(label: 'AI', type: ChipType.moss),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('依据本病例知识点生成，均附教材出处',
                  fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: questions.isEmpty
                    ? const Center(
                        child: MonoText('暂未生成题目',
                            fontSize: 12, color: Colors.grey))
                    : ListView(
                        controller: scrollController,
                        children: questions.asMap().entries.map((e) {
                          final q = e.value;
                          final options = (q['options'] as List<dynamic>?)
                                  ?.cast<String>() ??
                              [];
                          final typeLabel = switch (q['type']) {
                            'single' => '单选',
                            'multi' => '多选',
                            'short' => '简答',
                            _ => '${q['type'] ?? '题'}',
                          };
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceOf(context),
                              border: Border.all(
                                  color: AppColors.surfaceEdgeOf(context)),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOf(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: MonoText('${e.key + 1}',
                                          fontSize: 10,
                                          color:
                                              AppColors.onPrimaryOf(context)),
                                    ),
                                    const SizedBox(width: 8),
                                    AppChip(label: typeLabel, fontSize: 10),
                                    if ((q['knowledgeTag'] as String?)
                                            ?.isNotEmpty ??
                                        false)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: MonoText('${q['knowledgeTag']}',
                                            fontSize: 10,
                                            color: AppColors.text3Of(context)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${q['stem'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textOf(context),
                                        height: 1.6)),
                                if (options.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ...options.map((o) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Text(o,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.text2Of(context),
                                                height: 1.5)),
                                      )),
                                ],
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.mossTintOf(context),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MonoText('答案：${q['answer'] ?? ''}',
                                          fontSize: 11,
                                          color: AppColors.primaryOf(context)),
                                      const SizedBox(height: 4),
                                      Text('解析：${q['explanation'] ?? ''}',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.text2Of(context),
                                              height: 1.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchDialog(initialQuery: _query),
    );
    if (result != null) {
      setState(() => _query = result);
      if (_query.trim().isNotEmpty) _loadCases();
    }
  }

  /// 清除搜索条件后回列表全量
  void _clearSearch() {
    setState(() => _query = '');
    _loadCases();
  }

  @override
  Widget build(BuildContext context) {
    final list = _cases;
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
                  : context.goNamed(RouteNames.teacherHome),
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.add_rounded, size: 20),
                    color: AppColors.primaryOf(context),
                    onPressed: () => context.pushNamed(RouteNames.spConfig),
                  ),
                  AppIconButton(
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: _openSearch,
                  ),
                ],
              ),
            ),
            _buildFilterBar(),
            if (_query.trim().isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    MonoText('搜索「$_query」· ${list.length} 条',
                        fontSize: 11, color: AppColors.text3Of(context)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearSearch,
                      child: MonoText('清除',
                          fontSize: 11, color: AppColors.vermilionOf(context)),
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
                              Text('没有匹配的病例',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.text3Of(context))),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(top: 6, bottom: 100),
                          children: list
                              .map((c) => _caseCard(
                                    data: c,
                                    dept: '${c.dept} · ${c.difficulty}',
                                    title: c.title,
                                    coverColor: c.coverColor,
                                    coverBorderColor: c.coverBorderColor,
                                    deptColor: c.deptColor,
                                    official: c.official,
                                    author: c.author,
                                    hospital: c.hospital,
                                    grade: c.grade,
                                    summary: c.summary,
                                    refs: c.refs,
                                    rating: c.rating.toStringAsFixed(1),
                                    version: c.versionStr,
                                  ))
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
            onTap: () => _onFilterTap(i),
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

  Widget _caseCard({
    required _CaseData data,
    required String dept,
    required String title,
    required Color coverColor,
    required Color coverBorderColor,
    required Color deptColor,
    bool official = false,
    required String author,
    required String hospital,
    required String grade,
    required String summary,
    required int refs,
    required String rating,
    required String version,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        boxShadow: AppShadow.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // —— 封面区域 ——
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: coverColor,
              border: Border(bottom: BorderSide(color: coverBorderColor)),
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
                      MonoText(dept,
                          fontSize: 10, color: deptColor, letterSpacing: 0.12),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'NotoSerifSC',
                          fontFamilyFallback: [
                            'Songti SC',
                            'STSong',
                            'Noto Serif CJK SC',
                            'Source Han Serif SC'
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
                if (official)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: MonoText(
                      '✓ 官方',
                      fontSize: 10,
                      color: AppColors.onPrimaryOf(context),
                      letterSpacing: 0.04,
                    ),
                  ),
              ],
            ),
          ),
          // —— 详情区域 ——
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MonoText(author,
                        fontSize: 11, color: AppColors.text3Of(context)),
                    MonoText(' · $hospital',
                        fontSize: 11, color: AppColors.text3Of(context)),
                    MonoText(' · $grade',
                        fontSize: 11, color: AppColors.text3Of(context)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(summary,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.text2Of(context),
                        height: 1.55)),
                const SizedBox(height: 10),
                const DottedDivider(),
                const SizedBox(height: 8),
                // —— AI 辅助入口（质检 / 生成练习题）——
                Row(
                  children: [
                    Expanded(
                      child: AppGhostButton(
                        label: _qcLoadingId == data.caseId ? '质检中…' : 'AI 质检',
                        icon: const Icon(Icons.fact_check_outlined, size: 14),
                        small: true,
                        fullWidth: true,
                        onPressed: data.caseId == null
                            ? null
                            : (() => _qualityCheck(data)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppGhostButton(
                        label: _pqLoadingId == data.caseId ? '生成中…' : 'AI 练习题',
                        icon: const Icon(Icons.quiz_outlined, size: 14),
                        small: true,
                        fullWidth: true,
                        onPressed: data.caseId == null
                            ? null
                            : (() => _practiceQuestions(data)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        MonoText('引用 ',
                            fontSize: 11, color: AppColors.text3Of(context)),
                        MonoText('$refs',
                            fontSize: 11,
                            color: AppColors.textOf(context),
                            weight: FontWeight.w600),
                        const SizedBox(width: 12),
                        MonoText('★ $rating',
                            fontSize: 11, color: AppColors.amberOf(context)),
                        const SizedBox(width: 12),
                        MonoText(version,
                            fontSize: 11, color: AppColors.text3Of(context)),
                      ],
                    ),
                    Builder(
                      builder: (btnCtx) => AppPrimaryButton(
                        label: '引用',
                        small: true,
                        onPressed: () async {
                          final ok = await AppFeedback.confirm(
                            btnCtx,
                            title: '引用病例',
                            content:
                                '引用后将生成独立副本到你的病例库，可基于副本设置班级变量。原病例后续修改不影响本副本。',
                            confirmText: '引用',
                          );
                          if (!ok || !btnCtx.mounted) return;
                          if (data.caseId == null) {
                            AppFeedback.error(btnCtx, '该病例暂不可引用');
                            return;
                          }
                          final newId =
                              await TeacherService().quoteCase(data.caseId!);
                          if (!btnCtx.mounted) return;
                          if (newId == null) {
                            AppFeedback.error(btnCtx, '引用失败，请稍后重试');
                            return;
                          }
                          AppFeedback.success(btnCtx, '已引用到我的病例库 · 病例 #$newId');
                          // 引用后直接进入编辑模式：配置台按副本 ID 回填，可改可保存可发布
                          btnCtx.pushNamed(RouteNames.spConfig,
                              extra: {'caseId': newId});
                        },
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
}

/// 病例广场数据
class _CaseData {
  final int? caseId;
  final String dept;
  final String difficulty;
  final String title;
  final Color coverColor;
  final Color coverBorderColor;
  final Color deptColor;
  final bool official;
  final String author;
  final String hospital;
  final String grade;
  final String summary;
  final int refs;
  final double rating;
  final String versionStr;

  _CaseData({
    this.caseId,
    required this.dept,
    required this.difficulty,
    required this.title,
    required this.coverColor,
    required this.coverBorderColor,
    required this.deptColor,
    this.official = false,
    required this.author,
    required this.hospital,
    required this.grade,
    required this.summary,
    required this.refs,
    required this.rating,
    required this.versionStr,
  });

  factory _CaseData.fromJson(Map<String, dynamic> json) {
    // 后端 CaseMarketListVO 字段：id/title/department/difficulty(1-3)/
    // ratingAvg/referenceCount/creatorName/knowledgeTags/createdAt
    // 注意：difficulty 后端为 Integer，不能直接 as String，否则运行时抛异常
    final diffRaw = json['difficulty'];
    final difficulty = switch (diffRaw) {
      final num n => n.toInt() <= 1 ? '简单' : (n.toInt() >= 3 ? '困难' : '标准'),
      final String s => s,
      _ => '标准',
    };
    return _CaseData(
      caseId: (json['id'] as num?)?.toInt(),
      dept: (json['department'] as String?) ?? (json['dept'] as String?) ?? '',
      difficulty: difficulty,
      title: json['title'] as String? ?? '',
      coverColor: Color(json['coverColor'] as int? ?? 0xFFF0F0F0),
      coverBorderColor: Color(json['coverBorderColor'] as int? ?? 0xFFE0E0E0),
      deptColor: Color(json['deptColor'] as int? ?? 0xFF6A8F6A),
      official: json['official'] as bool? ?? false,
      author:
          (json['creatorName'] as String?) ?? (json['author'] as String?) ?? '',
      hospital: json['hospital'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      refs: ((json['referenceCount'] as num?) ?? (json['refs'] as num?))
              ?.toInt() ??
          0,
      rating: ((json['ratingAvg'] as num?) ?? (json['rating'] as num?))
              ?.toDouble() ??
          0.0,
      versionStr: json['versionStr'] as String? ?? 'v1',
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
          hintText: '标题 / 作者 / 摘要',
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
          child:
              Text('清除', style: TextStyle(color: AppColors.text3Of(context))),
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
