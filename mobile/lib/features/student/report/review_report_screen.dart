import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';
import 'report_pdf_service.dart';

/// AI 复盘报告
class ReviewReportScreen extends ConsumerStatefulWidget {
  const ReviewReportScreen({super.key});

  @override
  ConsumerState<ReviewReportScreen> createState() => _ReviewReportScreenState();
}

class _ReviewReportScreenState extends ConsumerState<ReviewReportScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    final data = await StudentService().getReportOverview();
    if (mounted) {
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    }
  }

  /// 导出真实 PDF：拉取 export 数据 → 本地生成 → 系统打印/分享
  Future<void> _exportPdf() async {
    if (!mounted) return;
    final hide = AppFeedback.showLoading(context, label: '正在生成复盘 PDF…');
    try {
      final data = await StudentService().exportReport();
      if (!mounted) return;
      hide();
      if (data == null) {
        AppFeedback.error(context, '导出失败：未获取到报告数据，请确认已完成复盘');
        return;
      }
      await ReviewReportPdf.export(data);
    } catch (e) {
      if (mounted) {
        hide();
        AppFeedback.error(context, '导出失败：$e');
      }
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
              title: 'AI 复盘报告',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.osceResult),
              action: const AppIconButton(
                icon: Icon(Icons.ios_share, size: 20),
              ),
            ),
            Expanded(
child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCover(context),
                          const SizedBox(height: 24),
                          _buildSection(context, '01', '诱因采集：被忽略的鉴别钥匙', '''
 在 6 次胸痛病例中，你4 次 未询问胸痛诱因。诱因是 ACS、肺栓塞、主动脉夹层、气胸鉴别诊断的核心钥匙——体力活动后加重指向 ACS，突发撕裂样痛指向夹层，长期卧床后指向肺栓塞。''', isMoss: true),
                          const SizedBox(height: 24),
                          _buildSection(context, '02', '过敏史：被低估的安全阀', '''
 6 次训练中3 次 未采集过敏史。在真实临床中，这可能导致严重的用药错误。养成"主诉—既往—过敏"三段式开场习惯，可显著降低遗漏率。''', isAmber: true),
                          const SizedBox(height: 24),
                          _buildSection(context, '03', '检查决策：贵的 ≠ 对的', '''
 你 2 次出现高价检查未配套低价必要检查的情况。例如：开 D-二聚体前未做 Wells 评估，开心肌酶谱同时开肌钙蛋白（重复）。卫生经济学不是抠门，而是用最少的代价获取最有效证据。''', isAmber: true, hasGrid: true),
                          const SizedBox(height: 24),
                          _buildNextSteps(context),
                          const SizedBox(height: 16),
                          AppPrimaryButton(
                            label: '导出完整 PDF',
                            icon: const Icon(Icons.download, size: 14),
                            fullWidth: true,
                            onPressed: _exportPdf,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final sessionCount = _reportData?['completedSessionCount']?.toString() ?? '6';
    final abilityScores = _reportData?['abilityScores'] as Map<String, dynamic>?;
    // 从能力评分中找出较低维度作为"关键遗漏"示意
    int lowScoreCount = 0;
    if (abilityScores != null) {
      lowScoreCount = abilityScores.values.where((v) => ((v as num?)?.toInt() ?? 100) < 70).length;
    }
    final keyMisses = lowScoreCount > 0 ? lowScoreCount.toString() : '3';
    return Container(
   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          EyebrowText('REVIEW REPORT · 2026.07.21', color: AppColors.primaryOf(context)),
          const SizedBox(height: 10),
      Text(
            '胸痛问诊中\n你漏掉的 3 个关键体征',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textOf(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          MonoText('基于 7 月共 $sessionCount 次胸痛相关病例训练', fontSize: 11),
          const SizedBox(height: 14),
          const DoubleDivider(),
      SizedBox(height: 14),
          Row(
            children: [
              _coverStat(context, sessionCount, '训练次数', AppColors.textOf(context)),
              _coverStat(context, keyMisses, '关键遗漏', AppColors.vermilion),
              _coverStat(context, '2', '过度检查', AppColors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverStat(BuildContext context, String num, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            num,
            style: TextStyle(
              fontSize: 20,
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

  Widget _buildSection(BuildContext context, String no, String title, String content,
      {bool isMoss = false, bool isAmber = false, bool hasGrid = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            MonoText(no, fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.08),
            const SizedBox(width: 8),
            Expanded(
              child: SerifText(title, fontSize: 16),
            ),
          ],
        ),
     SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
        style: TextStyle(fontSize: 13.5, color: AppColors.text2Of(context), height: 1.65),
              ),
              if (isMoss) ...[
                const SizedBox(height: 10),
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppColors.mossTintOf(context),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(AppRadius.sm),
                      bottomRight: Radius.circular(AppRadius.sm),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 3, color: AppColors.primaryOf(context)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: MonoText(
                          '建议话术："这次胸痛发作前在做什么？是活动时还是休息时？疼痛和体位有关系吗？"',
                          fontSize: 12.5,
                          color: AppColors.primaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isAmber && !hasGrid) ...[
                const SizedBox(height: 10),
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppColors.amberSoftOf(context),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(AppRadius.sm),
                      bottomRight: Radius.circular(AppRadius.sm),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 3, color: AppColors.amber),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: MonoText(
                          '参考路径：《诊断学》第9版 · 第三章 · 病史采集顺序',
                          fontSize: 12.5,
                          color: AppColors.textOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasGrid) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _costCard(context, 
                        '超支案例',
                        'D-二聚体 ¥180\n未先行 Wells 评估',
                        AppColors.vermilion,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _costCard(context, 
                        '优化方案',
                        'Wells ≤4 → 不查\nWells >4 → 查 D-二聚体',
                        AppColors.primaryOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _costCard(BuildContext context, String label, String content, Color color) {
    return Container(
   padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.ruleSoftOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(label, fontSize: 11, color: color),
          const SizedBox(height: 4),
          MonoText(content, fontSize: 12, color: AppColors.text2Of(context)),
        ],
      ),
    );
  }

  Widget _buildNextSteps(BuildContext context) {
    final steps = [
      '复习《内科学》P236-258 · ACS 章节',
      '完成"不稳定型心绞痛"简单病例',
      '完成"主动脉夹层"标准病例',
      '挑战"不典型 ACS"综合病例',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyebrowText('NEXT STEPS · 下一步训练', color: AppColors.onPrimarySoftOf(context)),
          const SizedBox(height: 6),
          SerifText('递进式补救路径', fontSize: 15, color: AppColors.onPrimaryOf(context)),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.onPrimarySoftOf(context)),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: MonoText(
                      '${e.key + 1}',
                      fontSize: 10,
                      color: AppColors.onPrimarySoftOf(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(fontSize: 13, color: AppColors.onPrimaryOf(context)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
