import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 病例广场
class CaseMarketScreen extends StatefulWidget {
  const CaseMarketScreen({super.key});

  @override
  State<CaseMarketScreen> createState() => _CaseMarketScreenState();
}

class _CaseMarketScreenState extends State<CaseMarketScreen> {
  int _currentFilter = 0;
  final _filters = ['全部', '心血管', '呼吸', '消化', '内分泌', '官方认证', '高评分'];
  String _query = '';

  final _cases = <_CaseData>[
    _CaseData(
      dept: '心血管', difficulty: '标准',
      title: '急性下壁心梗的\n不典型表现',
      coverTheme: CoverTheme.moss,
      official: true, author: '王老师', hospital: '附属第一医院', grade: '大四',
      summary: '58 岁建筑工人，搬运水泥时突发胸痛伴上腹痛，需要学生识别 ACS 不典型表现并完成鉴别诊断。',
      refs: 23, rating: 4.8, versionStr: 'v3',
    ),
    _CaseData(
      dept: '呼吸', difficulty: '困难',
      title: '慢阻肺急性加重\n伴 II 型呼衰',
      coverTheme: CoverTheme.amber,
      official: false, author: '李老师', hospital: '附属第二医院', grade: '大五/规培',
      summary: '68 岁慢阻肺患者，急性加重伴意识障碍，考察呼吸支持决策和血气分析判读。',
      refs: 15, rating: 4.6, versionStr: 'v2',
    ),
    _CaseData(
      dept: '消化', difficulty: '标准',
      title: '肝硬化食管胃底\n静脉曲张出血',
      coverTheme: CoverTheme.indigo,
      official: true, author: '张老师', hospital: '附属第一医院', grade: '大四',
      summary: '52 岁乙肝肝硬化患者呕血 200ml，考察出血量评估、Rockall 评分和急诊处理决策。',
      refs: 31, rating: 4.9, versionStr: 'v4',
    ),
  ];

  List<_CaseData> get _filtered {
    final kw = _filters[_currentFilter];
    final q = _query.trim();
    return _cases.where((c) {
      bool match = true;
      switch (kw) {
        case '官方认证':
          match = c.official;
        case '高评分':
          match = c.rating >= 4.8;
        case '全部':
          match = true;
        default:
          match = c.dept == kw;
      }
      if (match && q.isNotEmpty) {
        match = c.title.replaceAll('\n', '').toLowerCase().contains(q.toLowerCase()) ||
            c.summary.toLowerCase().contains(q.toLowerCase()) ||
            c.author.toLowerCase().contains(q.toLowerCase());
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

  // ---- 封面配色解析：根据 CoverTheme + 主题亮度返回 context-aware 颜色组 ----
  ({Color bg, Color border, Color dept}) _coverColorsOf(
    BuildContext context,
    CoverTheme theme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (theme) {
      case CoverTheme.moss:
        return (
          bg: AppColors.mossTintOf(context),
          border: AppColors.mossSoftOf(context),
          dept: AppColors.primaryOf(context),
        );
      case CoverTheme.amber:
        return (
          bg: AppColors.amberSoftOf(context),
          // 琥珀色边框：用 amber 适度提亮，深浅模式均可读
          border: isDark
              ? const Color(0xFF4A3E2A)
              : const Color(0xFFE3CFA0),
          dept: AppColors.amber,
        );
      case CoverTheme.indigo:
        return (
          bg: AppColors.indigoSoftOf(context),
          border: isDark
              ? const Color(0xFF2A2E3A)
              : const Color(0xFFC4CCE0),
          dept: AppColors.indigo,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '病例广场',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
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
                    MonoText('搜索「$_query」· ${list.length} 条', fontSize: 11, color: AppColors.text3Of(context)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _query = ''),
                      child: const MonoText('清除', fontSize: 11, color: AppColors.vermilion),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: AppColors.text4Of(context)),
                          const SizedBox(height: 12),
                          Text('没有匹配的病例', style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.only(
                        top: 6,
                        bottom: MediaQuery.paddingOf(context).bottom + 90,
                      ),
                      children: list.map((c) {
                        final colors = _coverColorsOf(context, c.coverTheme);
                        return _caseCard(
                          dept: '${c.dept} · ${c.difficulty}',
                          title: c.title,
                          coverColor: colors.bg,
                          coverBorderColor: colors.border,
                          deptColor: colors.dept,
                          official: c.official,
                          author: c.author,
                          hospital: c.hospital,
                          grade: c.grade,
                          summary: c.summary,
                          refs: c.refs,
                          rating: c.rating.toStringAsFixed(1),
                          version: c.versionStr,
                          isDark: isDark,
                        );
                      }).toList(),
                    ),
            ),
            TeacherTabBar(
              currentIndex: 2,
              onTap: (i) {
                if (i == 0) context.goNamed(RouteNames.teacherHome);
                if (i == 1) context.goNamed(RouteNames.spConfig);
                if (i == 3) context.goNamed(RouteNames.teacherProfile);
              },
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                border: Border.all(
                  color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
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
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        // 深色模式下用更明显的阴影；浅色模式用极淡阴影保持纸感
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF1A1F1C).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // —— 封面区域 ——
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: coverColor,
              border: Border(bottom: BorderSide(color: coverBorderColor, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoText(dept, fontSize: 10, color: deptColor, letterSpacing: 0.12),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                    MonoText(author, fontSize: 11, color: AppColors.text3Of(context)),
                    MonoText(' · $hospital', fontSize: 11, color: AppColors.text3Of(context)),
                    MonoText(' · $grade', fontSize: 11, color: AppColors.text3Of(context)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(summary, style: TextStyle(fontSize: 12.5, color: AppColors.text2Of(context), height: 1.55)),
                const SizedBox(height: 10),
                DottedDivider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        MonoText('引用 ', fontSize: 11, color: AppColors.text3Of(context)),
                        MonoText('$refs', fontSize: 11, color: AppColors.textOf(context), weight: FontWeight.w600),
                        const SizedBox(width: 12),
                        MonoText('★ $rating', fontSize: 11, color: AppColors.amber),
                        const SizedBox(width: 12),
                        MonoText(version, fontSize: 11, color: AppColors.text3Of(context)),
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
                            content: '引用后将生成独立副本到你的病例库，可基于副本设置班级变量。原病例后续修改不影响本副本。',
                            confirmText: '引用',
                          );
                          if (!ok || !btnCtx.mounted) return;
                          AppFeedback.success(btnCtx, '已引用到我的病例库');
                          btnCtx.pushNamed(RouteNames.spConfig);
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

/// 封面主题色系
enum CoverTheme { moss, amber, indigo }

/// 病例广场数据
class _CaseData {
  final String dept;
  final String difficulty;
  final String title;
  final CoverTheme coverTheme;
  final bool official;
  final String author;
  final String hospital;
  final String grade;
  final String summary;
  final int refs;
  final double rating;
  final String versionStr;

  const _CaseData({
    required this.dept,
    required this.difficulty,
    required this.title,
    required this.coverTheme,
    this.official = false,
    required this.author,
    required this.hospital,
    required this.grade,
    required this.summary,
    required this.refs,
    required this.rating,
    required this.versionStr,
  });
}

/// 搜索对话框，TextEditingController 随 widget 销毁被 dispose
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      title: Text(
        '搜索病例',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textOf(context)),
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
            borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
          ),
        ),
        style: TextStyle(color: AppColors.textOf(context)),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text('清除', style: TextStyle(color: AppColors.text3Of(context))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctl.text),
          child: Text(
            '搜索',
            style: TextStyle(color: AppColors.primaryOf(context), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
