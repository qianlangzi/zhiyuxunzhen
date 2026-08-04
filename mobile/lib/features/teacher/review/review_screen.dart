import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 智能批阅
class ReviewScreen extends StatefulWidget {
const   ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _currentTab = 0;
  final _scoreController = TextEditingController(text: '85');

  // 报告条目: P1 #7b — 补充评语控制器原为 build() 内联创建，每次 rebuild 泄漏
  final _commentController = TextEditingController(
    text: '诱因遗漏扣分偏重，调整为 -3。整体诊断思路清晰，鉴别诊断虽未列夹层但已识别肺栓塞，给 85 分。',
  );

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final raw = _scoreController.text.trim();
    final score = int.tryParse(raw);
    if (raw.isEmpty || score == null) {
      AppFeedback.error(context, '请输入有效的数字分数');
      return;
    }
    if (score < 0 || score > 100) {
      AppFeedback.error(context, '分数应在 0 ~ 100 之间');
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: '提交复核',
      content: '最终成绩以教师复核为准（$score 分），提交后写入审计日志并同步给学生。确认提交？',
      confirmText: '提交',
    );
    if (!ok) return;
    // 模拟提交（接入后端后替换为覆盖 AI 批阅的接口）
  await Future.delayed( Duration(milliseconds: 800));
    if (!mounted) return;
    AppFeedback.success(context, '复核已提交 · $score 分');
    context.goNamed(RouteNames.dashboard);
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
              title: '陈思远 · 大病历',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: const AppIconButton(icon: Icon(Icons.download_outlined, size: 20)),
            ),
            _buildReviewTabs(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  _buildFormatShieldResult(),
                  _buildRecordBlock('主诉 · 必填', '胸骨后疼痛 2 小时伴大汗。', highlights: [
                    ('伴大汗', 'ok'),
                  ]),
                  _buildRecordBlock('现病史 · 必填', '''
患者 2 小时前搬运水泥时突发胸骨后压榨样疼痛，未询问放射部位具体描述，伴大汗、恶心，无呕吐。未记录诱因与体力活动关系。来诊时 BP 90/60，HR 102。''', highlights: [
                    ('搬运水泥时', 'ok'),
                    ('未询问', 'err'),
                    ('未记录', 'warn'),
                  ]),
                  _buildRecordBlock('既往史 · 必填', '''
高血压 8 年，未规律服用降压药。未询问过敏史。未询问家族史。''', highlights: [
                    ('高血压 8 年', 'ok'),
                    ('未询问过敏史', 'err'),
                    ('未询问家族史', 'warn'),
                  ]),
                  _buildRecordBlock('辅助检查', '''
心电图：II、III、aVF 导联 ST 段抬高 0.3mV ✓
肌钙蛋白 I：3.8 ng/mL ↑ ✓
心肌酶谱：CK-MB 25 U/L（与肌钙蛋白重复开立）''', highlights: [
                    ('✓', 'ok'),
                    ('心肌酶谱：CK-MB 25 U/L（与肌钙蛋白重复开立）', 'warn'),
                  ]),
                  _buildRecordBlock('初步诊断 · 必填', '''
急性下壁心肌梗死
鉴别诊断：未列出主动脉夹层、肺栓塞''', highlights: [
                    ('急性下壁心肌梗死', 'ok'),
                    ('未列出主动脉夹层', 'err'),
                  ]),
                  _buildAiScoreCard(),
                  _buildOverrideSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTabs() {
    final tabs = ['大病历', 'AI 批阅', '教师复核', '思维树'];
    return Container(
   decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == _currentTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = i),
              child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.primaryOf(context) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? AppColors.primaryOf(context) : AppColors.text3Of(context),
                      fontFamily: 'JetBrainsMono',
                      letterSpacing: 0.04,
                      fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFormatShieldResult() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        border: Border.all(color: AppColors.mossSoftOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, size: 16, color: AppColors.primaryOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('格式盾牌 · 通过', style: TextStyle(fontSize: 12, color: AppColors.primaryOf(context), fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                const MonoText('7 项必填段落齐全 · 主诉 18 字 · 过敏史已注明', fontSize: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordBlock(String title, String content, {List<(String, String)>? highlights}) {
    return Container(
   margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
   padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SerifText(title, fontSize: 13, color: AppColors.primaryOf(context)),
          const SizedBox(height: 8),
          _buildHighlightedText(content, highlights ?? []),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, List<(String, String)> highlights) {
    if (highlights.isEmpty) {
   return Text(text, style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context), height: 1.7));
    }
    final spans = <InlineSpan>[];
    int start = 0;
    for (final (word, type) in highlights) {
      final idx = text.indexOf(word, start);
      if (idx == -1) continue;
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      Color bg, fg;
      switch (type) {
        case 'err':
          bg = AppColors.vermilionSoftOf(context);
          fg = AppColors.vermilion;
          break;
        case 'warn':
          bg = AppColors.amberSoftOf(context);
          fg = AppColors.amber;
          break;
        default:
          bg = AppColors.mossTintOf(context);
          fg = AppColors.primaryOf(context);
      }
      spans.add(TextSpan(
        text: word,
        style: TextStyle(backgroundColor: bg, color: fg),
      ));
      start = idx + word.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return Text.rich(
      TextSpan(
    style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context), height: 1.7),
        children: spans,
      ),
    );
  }

  Widget _buildAiScoreCard() {
    final deductions = [
      ('诱因未询问', '现病史缺失体力活动/情绪诱因，影响 ACS 鉴别', '-6'),
      ('过敏史遗漏', '必填项缺失，存在用药安全风险', '-5'),
      ('鉴别诊断不全', '未列出主动脉夹层这一高危鉴别', '-4'),
      ('检查重复', '心肌酶谱与肌钙蛋白重复，违反卫生经济学', '-3'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryOf(context), AppColors.moss2],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: MonoText('AI REVIEW', fontSize: 10, color: AppColors.onPrimaryOf(context).withValues(alpha: 0.4), letterSpacing: 0.14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '82',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimaryOf(context),
                      height: 1,
                      letterSpacing: -0.03,
                    ),
                  ),
                  Text(' / 100', style: TextStyle(fontSize: 14, color: AppColors.onPrimarySoftOf(context))),
                  const SizedBox(width: 8),
                  Text('良好 · 接近优秀', style: TextStyle(fontSize: 12, color: AppColors.onPrimaryLightOf(context), fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 12),
              ...deductions.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: AppColors.onPrimaryOf(context).withValues(alpha: 0.08),
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
                      child: Container(width: 2, color: AppColors.onPrimarySoftOf(context)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 12, color: AppColors.onPrimaryLightOf(context), height: 1.5),
                                children: [
                                  TextSpan(text: '${d.$1} · ', style: TextStyle(color: AppColors.onPrimaryOf(context), fontWeight: FontWeight.bold)),
                                  TextSpan(text: d.$2),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            d.$3,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              color: AppColors.vermilionSoftOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(color: AppColors.amber, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit, size: 12, color: AppColors.amber),
              SizedBox(width: 6),
              MonoText('教师复核 · 可覆盖', fontSize: 11, color: AppColors.amber, letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 8),
      Text(
            '最终成绩以教师复核为准。所有覆盖操作写入审计日志。',
            style: TextStyle(fontSize: 12, color: AppColors.text2Of(context)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const EyebrowText('调整分数'),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _scoreController,
                  textAlign: TextAlign.center,
         style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.amber),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.amber),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
        MonoText('/ 100', fontSize: 11, color: AppColors.text3Of(context)),
              const Spacer(),
              AppPrimaryButton(label: '提交复核', small: true, onPressed: _submitReview),
            ],
          ),
          const SizedBox(height: 10),
          const EyebrowText('补充评语'),
          const SizedBox(height: 4),
          TextField(
            maxLines: 3,
      style: TextStyle(fontSize: 12.5, height: 1.55),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.ruleOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.ruleOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.amber),
              ),
            ),
            controller: _commentController,
          ),
        ],
      ),
    );
  }
}
