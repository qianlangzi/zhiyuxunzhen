import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 每日一例
class DailyCaseScreen extends StatefulWidget {
const   DailyCaseScreen({super.key});

  @override
  State<DailyCaseScreen> createState() => _DailyCaseScreenState();
}

class _DailyCaseScreenState extends State<DailyCaseScreen> {
  int _selectedQ1 = 1; // 急性下壁心肌梗死
  int _selectedQ2 = 0; // 18 导联心电图
  int _selectedQ3 = 1; // 立即冠脉造影（应避免）
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // 模拟判题请求（接入后端后替换为 /daily_case/evaluate）
  await Future.delayed( Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _submitting = false);

    final results = <String>[];
    results.add(_selectedQ1 == 1 ? '✅ Q1 正确：急性下壁心肌梗死' : '❌ Q1 错误：应选「急性下壁心肌梗死」');
    results.add(_selectedQ2 == 0 ? '✅ Q2 正确：18 导联心电图' : '❌ Q2 错误：必须做 18 导联心电图');
    results.add(_selectedQ3 == 1
        ? '✅ Q3 正确：应避免立即冠脉造影'
        : '❌ Q3 错误：无再灌注指征评估前应避免立即冠脉造影');

    final correct = (_selectedQ1 == 1 ? 1 : 0) +
        (_selectedQ2 == 0 ? 1 : 0) +
        (_selectedQ3 == 1 ? 1 : 0);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Text(
          '答对 $correct / 3',
     style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
         child: Text(r, style: TextStyle(fontSize: 13, color: AppColors.text2Of(context), height: 1.5)),
                )),
            const SizedBox(height: 8),
       Text(
              '避坑点：上腹痛伴大汗需警惕 ACS 不典型表现，勿误诊为胃病。\n教材出处：《内科学》第9版 · P247',
              style: TextStyle(fontSize: 12, color: AppColors.text3Of(context), height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppFeedback.success(context, '已完成今日一例 · No.213');
              context.goNamed(RouteNames.studentHome);
            },
            child: const Text('完成', style: TextStyle(color: AppColors.moss, fontWeight: FontWeight.w600)),
          ),
        ],
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
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCaseBrief(),
                    const SizedBox(height: 20),
                    _buildKeyExams(),
                    const SizedBox(height: 20),
                    _buildQuestion(
                      'Q1', '最可能的诊断是？',
                      ['急性胃食管反流', '急性下壁心肌梗死', '主动脉夹层', '急性心包炎'],
                      _selectedQ1,
                      (v) => setState(() => _selectedQ1 = v),
                      correctIndex: 1,
                    ),
                    const SizedBox(height: 20),
                    _buildQuestion(
                      'Q2', '必须做的一项检查是？',
                      ['18 导联心电图', '胸部 CT 平扫', 'D-二聚体'],
                      _selectedQ2,
                      (v) => setState(() => _selectedQ2 = v),
                      correctIndex: 0,
                    ),
                    const SizedBox(height: 20),
                    _buildQuestion(
                      'Q3', '应避免的一项检查是？',
                      ['心肌酶谱', '立即冠脉造影（无再灌注指征评估）'],
                      _selectedQ3,
                      (v) => setState(() => _selectedQ3 = v),
                      correctIndex: 1,
                      isAvoid: true,
                    ),
                    const SizedBox(height: 8),
                    AppPrimaryButton(
                      label: _submitting ? '判题中…' : '提交答案 · 查看反馈',
                      fullWidth: true,
                      onPressed: _submitting ? null : _submit,
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

  Widget _buildAppBar() {
    return Container(
   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
   decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border(bottom: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
          ),
      Expanded(
            child: Center(
              child: Text(
                '每日一例 · No.213',
                style: TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
            ),
          ),
      MonoText('03:24', fontSize: 11, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _buildCaseBrief() {
    return Container(
   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.moss,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowText('CASE BRIEF · 心血管', color: Color(0xFFB8C9B8)),
          const SizedBox(height: 8),
          const SerifText('58 岁男性，胸痛 2 小时', fontSize: 18, color: AppColors.paper),
          const SizedBox(height: 12),
          const Text(
            '建筑工人，搬运水泥时突发胸骨后压榨样疼痛，伴大汗、恶心，疼痛放射至左肩。既往高血压 8 年。BP 90/60，HR 102。',
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: Color(0xFFD8E0D3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyExams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
     EyebrowText('关键检查结果'),
     SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _examCard('心电图', 'II,III,aVF\nST ↑ 0.3mV', AppColors.vermilion)),
            const SizedBox(width: 8),
            Expanded(child: _examCard('肌钙蛋白', 'cTnI\n3.8 ng/mL ↑', AppColors.vermilion)),
          ],
        ),
      ],
    );
  }

  Widget _examCard(String label, String value, Color color) {
    return Container(
   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
          const SizedBox(height: 4),
          MonoText(value, fontSize: 11, color: color),
        ],
      ),
    );
  }

  Widget _buildQuestion(
    String no, String title, List<String> options,
    int selected, ValueChanged<int> onChanged,
    {int correctIndex = 0, bool isAvoid = false}
  ) {
    final accentColor = isAvoid ? AppColors.vermilion : AppColors.moss;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            MonoText(no, fontSize: 11, color: AppColors.moss, letterSpacing: 0.08),
            const SizedBox(width: 8),
            SerifText(title, fontSize: 14),
          ],
        ),
     SizedBox(height: 10),
        ...options.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          final bgColor = isSelected
              ? (isAvoid ? AppColors.vermilionSoft : AppColors.mossTint)
              : AppColors.surfaceOf(context);
          final borderColor = isSelected
              ? (isAvoid ? AppColors.vermilion : AppColors.moss)
              : AppColors.surfaceEdgeOf(context);
          final textColor = isSelected
              ? (isAvoid ? AppColors.vermilion : AppColors.moss)
              : AppColors.textOf(context);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? accentColor : AppColors.ruleOf(context),
                          width: 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (isSelected)
                      AppChip(
                        label: '已选',
                        type: isAvoid ? ChipType.vermilion : ChipType.moss,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
