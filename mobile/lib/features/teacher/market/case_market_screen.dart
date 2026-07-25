import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 病例广场
class CaseMarketScreen extends StatefulWidget {
const   CaseMarketScreen({super.key});

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
      coverColor: AppColors.mossTint, coverBorderColor: AppColors.mossSoft, deptColor: AppColors.moss,
      official: true, author: '王老师', hospital: '附属第一医院', grade: '大四',
      summary: '58 岁建筑工人，搬运水泥时突发胸痛伴上腹痛，需要学生识别 ACS 不典型表现并完成鉴别诊断。',
      refs: 23, rating: 4.8, versionStr: 'v3',
    ),
    _CaseData(
      dept: '呼吸', difficulty: '困难',
      title: '慢阻肺急性加重\n伴 II 型呼衰',
   coverColor: AppColors.amberSoft, coverBorderColor: Color(0xFFE3CFA0), deptColor: AppColors.amber,
      official: false, author: '李老师', hospital: '附属第二医院', grade: '大五/规培',
      summary: '68 岁慢阻肺患者，急性加重伴意识障碍，考察呼吸支持决策和血气分析判读。',
      refs: 15, rating: 4.6, versionStr: 'v2',
    ),
    _CaseData(
      dept: '消化', difficulty: '标准',
      title: '肝硬化食管胃底\n静脉曲张出血',
   coverColor: AppColors.indigoSoft, coverBorderColor: Color(0xFFC4CCE0), deptColor: AppColors.indigo,
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
      builder: (ctx) {
        final ctl = TextEditingController(text: _query);
        return AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
     title: Text('搜索病例', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
          content: TextField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '标题 / 作者 / 摘要'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(''), child: Text('清除', style: TextStyle(color: AppColors.text3Of(context)))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('搜索', style: TextStyle(color: AppColors.moss, fontWeight: FontWeight.w600))),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => _query = result);
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                      padding: const EdgeInsets.only(top: 6, bottom: 100),
                      children: list.map((c) => _caseCard(
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
                      )).toList(),
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
          final active = i == _currentFilter;
          return GestureDetector(
            onTap: () => setState(() => _currentFilter = i),
            child: Container(
       padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                border: Border.all(color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? AppColors.paper : AppColors.text2Of(context),
                    fontFamily: 'JetBrainsMono',
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
    required String dept, required String title,
    required Color coverColor, required Color coverBorderColor, required Color deptColor,
    bool official = false,
    required String author, required String hospital, required String grade,
    required String summary,
    required int refs, required String rating, required String version,
  }) {
    return Container(
   margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: coverColor,
              border: Border(bottom: BorderSide(color: coverBorderColor)),
       borderRadius: BorderRadius.only(
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
                      MonoText(dept, fontSize: 10, color: deptColor, letterSpacing: 0.12),
                      const SizedBox(height: 4),
                      Text(
                        title,
            style: TextStyle(
                          fontFamily: 'NotoSerifSC',
                          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
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
                      color: AppColors.moss,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const MonoText('✓ 官方', fontSize: 10, color: AppColors.paper, letterSpacing: 0.04),
                  ),
              ],
            ),
          ),
          Padding(
      padding: EdgeInsets.all(16),
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
         SizedBox(height: 10),
         DottedDivider(),
         SizedBox(height: 8),
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

/// 病例广场数据
class _CaseData {
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

  const _CaseData({
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
}
