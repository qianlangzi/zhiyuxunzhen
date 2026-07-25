import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 错题本
class MistakesScreen extends StatefulWidget {
const   MistakesScreen({super.key});

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  int _currentFilter = 0;
  final _filters = ['全部 48', '诊断错误 12', '漏问病史 9', '检查错误 7', '文书问题 11', '沟通 9'];
  final Set<int> _expanded = {};

  final _mistakes = <_Mistake>[
    _Mistake(
      id: 1,
      type: '诊断错误',
      typeColor: AppColors.vermilion,
      date: '07.20 · 心血管',
      title: '将急性下壁心梗误诊为胃食管反流',
      evidence: '学生诊断：胃食管反流\n标准诊断：急性下壁+右室心肌梗死\n脱轨节点：未识别上腹痛伴大汗的 ACS 不典型表现',
      tags: [('ACS', ChipType.vermilion), ('不典型表现', ChipType.default_), ('高危遗漏', ChipType.default_)],
      resolved: false,
    ),
    _Mistake(
      id: 2,
      type: '漏问病史',
      typeColor: AppColors.vermilion,
      date: '07.20 · 心血管',
      title: '未询问胸痛诱因（体力活动/情绪）',
      evidence: '为什么重要：诱因是 ACS 与肺栓塞、主动脉夹层鉴别关键\n对应风险：可能延误再灌注治疗时机',
      tags: [('诱因', ChipType.vermilion), ('鉴别诊断', ChipType.default_)],
      resolved: false,
    ),
    _Mistake(
      id: 3,
      type: '检查错误',
      typeColor: AppColors.vermilion,
      date: '07.19 · 呼吸',
      title: '慢阻肺急性加重病例过度开立 D-二聚体',
      evidence: '学生行为：无 Wells 评估即开 D-二聚体\n建议路径：先评估临床概率，再决定是否查 D-二聚体\n成本超支：¥180 / 单次',
      tags: [('过度检查', ChipType.amber), ('卫生经济学', ChipType.default_), ('慢阻肺', ChipType.default_)],
      resolved: false,
    ),
    _Mistake(
      id: 4,
      type: '已掌握',
      typeColor: AppColors.moss,
      date: '07.15 · 消化',
      title: '消化道出血未评估出血严重程度',
      evidence: '曾经错误：仅凭主诉判断出血量\n已掌握：已能正确使用 Rockall / Glasgow-Blatchford 评分',
      tags: [('消化道出血', ChipType.moss), ('严重程度评估', ChipType.default_)],
      resolved: true,
    ),
  ];

  /// 筛选标签 -> 错题类型关键词
  String? get _filterKeyword {
    if (_currentFilter == 0) return null;
    // 去掉尾部数量，如「诊断错误 12」->「诊断错误」
    final label = _filters[_currentFilter].split(' ').first;
    return label;
  }

  List<_Mistake> get _filtered {
    final kw = _filterKeyword;
    if (kw == null) return _mistakes;
    return _mistakes.where((m) => m.type == kw).toList();
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
            Expanded(
              child: list.isEmpty
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
            MonoText('已切换至：${_filters[_currentFilter]}', fontSize: 11, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
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
              _statItem('17', '未复习', AppColors.vermilion),
              Container(width: 1, height: 40, color: AppColors.ruleOf(context)),
              _statItem('8', '已复习', AppColors.amber),
              Container(width: 1, height: 40, color: AppColors.ruleOf(context)),
              _statItem('23', '已掌握', AppColors.moss),
            ],
          ),
          const SizedBox(height: 8),
          MonoText('示例数据 · 仅展示部分错题', fontSize: 10, color: AppColors.text4Of(context)),
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
              fontFamily: 'NotoSerifSC',
              fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
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
          final active = i == _currentFilter;
          return GestureDetector(
            onTap: () => setState(() => _currentFilter = i),
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
                    color: active ? AppColors.paper : AppColors.text2Of(context),
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

  Widget _buildMistakeCard(_Mistake m) {
    final expanded = _expanded.contains(m.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (expanded) {
          _expanded.remove(m.id);
        } else {
          _expanded.add(m.id);
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
                child: Container(width: 3, color: m.resolved ? AppColors.moss : AppColors.vermilion),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Opacity(
                  opacity: m.resolved ? 0.7 : 1.0,
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: m.resolved ? AppColors.mossTint : AppColors.vermilionSoft,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: MonoText(
                        '● ${m.type}',
                        fontSize: 10,
                        color: m.typeColor,
                        letterSpacing: 0.08,
                      ),
                    ),
                    Row(
                      children: [
                        MonoText(m.date, fontSize: 11, color: AppColors.text4Of(context)),
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
                  m.title,
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
                            m.evidence,
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
                    children: m.tags.map((t) => AppChip(label: t.$1, type: t.$2)).toList(),
                  ),
                  if (!m.resolved) ...[
                    const SizedBox(height: 8),
                    AppGhostButton(
                      label: '标记为已掌握',
                      small: true,
                      icon: const Icon(Icons.check, size: 12),
                      onPressed: () {
                        setState(() => m.resolved = true);
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

class _Mistake {
  final int id;
  String type;
  Color typeColor;
  String date;
  String title;
  String evidence;
  List<(String, ChipType)> tags;
  bool resolved;

_Mistake({
    required this.id,
    required this.type,
    required this.typeColor,
    required this.date,
    required this.title,
    required this.evidence,
    required this.tags,
    required this.resolved,
  });
}
