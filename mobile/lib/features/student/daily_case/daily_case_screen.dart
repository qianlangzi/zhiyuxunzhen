import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 每日一例
class DailyCaseScreen extends ConsumerStatefulWidget {
const   DailyCaseScreen({super.key});

  @override
  ConsumerState<DailyCaseScreen> createState() => _DailyCaseScreenState();
}

class _DailyCaseScreenState extends ConsumerState<DailyCaseScreen> {
  Map<String, dynamic>? _dailyCaseData;
  bool _isLoading = true;
  int _selectedQ1 = -1;
  int _selectedQ2 = -1;
  int _selectedQ3 = -1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDailyCase());
  }

  Future<void> _loadDailyCase() async {
    final data = await StudentService().getTodayDailyCase();
    if (mounted) {
      setState(() {
        _dailyCaseData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selectedQ1 < 0 || _selectedQ2 < 0 || _selectedQ3 < 0) {
      AppFeedback.info(context, '请完成所有题目');
      return;
    }
    setState(() => _submitting = true);

    final scheduleId = _dailyCaseData?['scheduleId'] as int?;
    if (scheduleId != null) {
      await StudentService().submitDailyCase(
        scheduleId: scheduleId,
        answer: '$_selectedQ1,$_selectedQ2,$_selectedQ3',
      );
    } else {
      // Mock 模式：模拟延迟
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    // 获取题目数据用于判题反馈
    final questions = _dailyCaseData?['questions'] as List<dynamic>?;
    final results = <String>[];

    if (questions != null && questions.length >= 3) {
      for (int i = 0; i < 3; i++) {
        final q = questions[i] as Map<String, dynamic>;
        final correctIdx = q['correctIndex'] as int? ?? 0;
        final selected = [_selectedQ1, _selectedQ2, _selectedQ3][i];
        final options = q['options'] as List<dynamic>? ?? [];
        final correctAnswer = options.length > correctIdx ? options[correctIdx] : '';
        final isCorrect = selected == correctIdx;
        results.add(isCorrect
            ? '✅ Q${i + 1} 正确：$correctAnswer'
            : '❌ Q${i + 1} 错误：应选「$correctAnswer」');
      }
    } else {
      // 默认判题逻辑
      results.add(_selectedQ1 == 1 ? '✅ Q1 正确：急性下壁心肌梗死' : '❌ Q1 错误：应选「急性下壁心肌梗死」');
      results.add(_selectedQ2 == 0 ? '✅ Q2 正确：18 导联心电图' : '❌ Q2 错误：必须做 18 导联心电图');
      results.add(_selectedQ3 == 1
          ? '✅ Q3 正确：应避免立即冠脉造影'
          : '❌ Q3 错误：无再灌注指征评估前应避免立即冠脉造影');
    }

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
            child: Text('完成', style: TextStyle(color: AppColors.primaryOf(context), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgOf(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 从 API 数据读取题目信息，未加载时使用默认值
    final questions = _dailyCaseData?['questions'] as List<dynamic>?;
    final caseNo = _dailyCaseData?['caseNo'] as int? ?? 213;
    final department = _dailyCaseData?['department'] as String? ?? '心血管';
    final estimatedTime = _dailyCaseData?['estimatedTime'] as String? ?? '03:24';

    // 题目数据
    final q1 = questions != null && questions.length > 0
        ? questions[0] as Map<String, dynamic>
        : null;
    final q2 = questions != null && questions.length > 1
        ? questions[1] as Map<String, dynamic>
        : null;
    final q3 = questions != null && questions.length > 2
        ? questions[2] as Map<String, dynamic>
        : null;

    final q1Title = q1?['title'] as String? ?? '最可能的诊断是？';
    final q1Options = (q1?['options'] as List<dynamic>?)?.cast<String>() ?? ['急性胃食管反流', '急性下壁心肌梗死', '主动脉夹层', '急性心包炎'];
    final q1CorrectIdx = q1?['correctIndex'] as int? ?? 1;

    final q2Title = q2?['title'] as String? ?? '必须做的一项检查是？';
    final q2Options = (q2?['options'] as List<dynamic>?)?.cast<String>() ?? ['18 导联心电图', '胸部 CT 平扫', 'D-二聚体'];
    final q2CorrectIdx = q2?['correctIndex'] as int? ?? 0;

    final q3Title = q3?['title'] as String? ?? '应避免的一项检查是？';
    final q3Options = (q3?['options'] as List<dynamic>?)?.cast<String>() ?? ['心肌酶谱', '立即冠脉造影（无再灌注指征评估）'];
    final q3CorrectIdx = q3?['correctIndex'] as int? ?? 1;

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(caseNo: caseNo, estimatedTime: estimatedTime),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCaseBrief(department: department),
                    const SizedBox(height: 20),
                    _buildKeyExams(),
                    const SizedBox(height: 20),
                    _buildQuestion(
                      'Q1', q1Title, q1Options,
                      _selectedQ1,
                      (v) => setState(() => _selectedQ1 = v),
                      correctIndex: q1CorrectIdx,
                    ),
                    const SizedBox(height: 20),
                    _buildQuestion(
                      'Q2', q2Title, q2Options,
                      _selectedQ2,
                      (v) => setState(() => _selectedQ2 = v),
                      correctIndex: q2CorrectIdx,
                    ),
                    const SizedBox(height: 20),
                    _buildQuestion(
                      'Q3', q3Title, q3Options,
                      _selectedQ3,
                      (v) => setState(() => _selectedQ3 = v),
                      correctIndex: q3CorrectIdx,
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

  Widget _buildAppBar({int caseNo = 213, String estimatedTime = '03:24'}) {
    return Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                'AI 每日一例 · No.$caseNo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
            ),
          ),
      MonoText(estimatedTime, fontSize: 11, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _buildCaseBrief({String department = '心血管'}) {
    final caseBrief = _dailyCaseData?['caseBrief'] as String? ?? '58 岁男性，胸痛 2 小时';
    final caseDescription = _dailyCaseData?['caseDescription'] as String? ??
        '建筑工人，搬运水泥时突发胸骨后压榨样疼痛，伴大汗、恶心，疼痛放射至左肩。既往高血压 8 年。BP 90/60，HR 102。';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
EyebrowText('CASE BRIEF · $department', color: AppColors.onPrimarySoftOf(context)),
          const SizedBox(height: 8),
          SerifText(caseBrief, fontSize: 18, color: AppColors.onPrimaryOf(context)),
          const SizedBox(height: 12),
          Text(
            caseDescription,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: AppColors.onPrimaryLightOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyExams() {
    final exams = _dailyCaseData?['exams'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
     EyebrowText('关键检查结果'),
     SizedBox(height: 8),
        Row(
          children: [
            if (exams != null && exams.length > 0)
              ...exams.take(2).map((e) {
                final exam = e as Map<String, dynamic>;
                final name = exam['name'] as String? ?? '';
                final result = exam['result'] as String? ?? '';
                final highlight = exam['highlight'] as bool? ?? false;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: exams.indexOf(e) < exams.length - 1 ? 8 : 0),
                    child: _examCard(name, result, highlight ? AppColors.vermilion : AppColors.text2Of(context)),
                  ),
                );
              })
            else ...[
              Expanded(child: _examCard('心电图', 'II,III,aVF\nST ↑ 0.3mV', AppColors.vermilion)),
              const SizedBox(width: 8),
              Expanded(child: _examCard('肌钙蛋白', 'cTnI\n3.8 ng/mL ↑', AppColors.vermilion)),
            ],
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
    final accentColor = isAvoid ? AppColors.vermilion : AppColors.primaryOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            MonoText(no, fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.08),
            const SizedBox(width: 8),
            SerifText(title, fontSize: 14),
          ],
        ),
     SizedBox(height: 10),
        ...options.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          final bgColor = isSelected
              ? (isAvoid ? AppColors.vermilionSoftOf(context) : AppColors.mossTintOf(context))
              : AppColors.surfaceOf(context);
          final borderColor = isSelected
              ? (isAvoid ? AppColors.vermilion : AppColors.primaryOf(context))
              : AppColors.surfaceEdgeOf(context);
          final textColor = isSelected
              ? (isAvoid ? AppColors.vermilion : AppColors.primaryOf(context))
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
