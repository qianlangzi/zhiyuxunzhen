import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 全部题库 · 题目详情子页面
///
/// 此前「全部题库」的题目平铺在列表里且卡片不可点；现在点击卡片进入
/// 独立详情页：元信息（作者/科室/知识点/难度/题型/发布时间/出处教材）+
/// 完整题干 + 选项 + 答案 + 解析，分区展示。
class QuestionPublicDetailScreen extends StatefulWidget {
  const QuestionPublicDetailScreen({super.key, required this.questionId});

  final int questionId;

  @override
  State<QuestionPublicDetailScreen> createState() =>
      _QuestionPublicDetailScreenState();
}

class _QuestionPublicDetailScreenState extends State<QuestionPublicDetailScreen> {
  Map<String, dynamic>? _q;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final q = await TeacherService().getPublicQuestionDetail(widget.questionId);
    if (!mounted) return;
    setState(() {
      _q = q;
      _loading = false;
      _error = q == null ? '题目加载失败，请下拉重试' : null;
    });
  }

  String get _typeLabel => switch (_q?['questionType'] as String?) {
        'multiple_choice' => '多选题',
        'fill_blank' => '填空题',
        'judgment' => '判断题',
        'short_answer' => '简答题',
        'essay' => '论述题',
        _ => '单选题',
      };

  String get _difficultyLabel {
    final d = (_q?['difficulty'] as num?)?.toInt() ?? 2;
    return d == 1 ? '简单' : (d == 3 ? '困难' : '标准');
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    if (s.isEmpty) return '';
    return s.contains('T') ? s.replaceFirst('T', ' ').split('.').first : s;
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
              title: '题目详情',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.teacherHome),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            children: [
                              const SizedBox(height: 140),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 40,
                                        color: AppColors.text4Of(context)),
                                    const SizedBox(height: 12),
                                    Text(_error!,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.text3Of(context))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            children: [
                              _buildMetaCard(context),
                              const SizedBox(height: 12),
                              _buildStemCard(context),
                              if (((_q?['options'] as List?) ?? [])
                                  .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildOptionsCard(context),
                              ],
                              const SizedBox(height: 12),
                              _buildAnswerCard(context),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 元信息卡 ----------
  Widget _buildMetaCard(BuildContext context) {
    final q = _q!;
    final questionNo = q['questionNo'] as String? ?? '';
    final dept = q['department'] as String? ?? '';
    final tag = q['knowledgeTag'] as String? ?? '';
    final creator = q['creatorName'] as String? ?? '';
    final createdAt = _formatTime(q['createdAt']);
    final textbook = q['sourceTextbookTitle'] as String? ?? '';

    final rows = <(String, String)>[
      if (questionNo.isNotEmpty) ('题号', questionNo),
      if (creator.isNotEmpty) ('出题人', creator),
      if (dept.isNotEmpty) ('科室', dept),
      if (tag.isNotEmpty) ('知识点', tag),
      if (textbook.isNotEmpty) ('出处教材', textbook),
      if (createdAt.isNotEmpty) ('发布时间', createdAt),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppChip(label: _typeLabel, fontSize: 10),
              const SizedBox(width: 6),
              AppChip(label: _difficultyLabel, type: ChipType.amber, fontSize: 10),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...rows.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 64,
                        child: MonoText(e.$1,
                            fontSize: 11, color: AppColors.text4Of(context)),
                      ),
                      Expanded(
                        child: MonoText(e.$2,
                            fontSize: 11.5, color: AppColors.text2Of(context)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ---------- 题干卡 ----------
  Widget _buildStemCard(BuildContext context) {
    return _sectionCard(
      context,
      title: '题干',
      child: Text(
        _q?['title'] as String? ?? '',
        style: TextStyle(
          fontSize: 14,
          height: 1.65,
          fontWeight: FontWeight.w500,
          color: AppColors.textOf(context),
        ),
      ),
    );
  }

  // ---------- 选项卡 ----------
  Widget _buildOptionsCard(BuildContext context) {
    final options = (_q?['options'] as List?)?.cast<String>() ?? [];
    final answer = _q?['answer'] as String? ?? '';
    return _sectionCard(
      context,
      title: '选项',
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: answer.contains(String.fromCharCode(65 + i))
                    ? AppColors.mossTintOf(context)
                    : AppColors.paper2Of(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${String.fromCharCode(65 + i)}. ${options[i]}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.text2Of(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 答案 / 解析卡 ----------
  Widget _buildAnswerCard(BuildContext context) {
    final answer = _q?['answer'] as String? ?? '';
    final explanation = _q?['explanation'] as String? ?? '';
    return _sectionCard(
      context,
      title: '答案与解析',
      child: answer.isEmpty && explanation.isEmpty
          ? Text('暂无答案解析',
              style: TextStyle(fontSize: 12.5, color: AppColors.text4Of(context)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (answer.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.mossTintOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: MonoText('答案：$answer',
                        fontSize: 12.5,
                        color: AppColors.primaryOf(context),
                        weight: FontWeight.w700),
                  ),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    explanation,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.65,
                      color: AppColors.text2Of(context),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(title,
              fontSize: 11,
              color: AppColors.primaryOf(context),
              weight: FontWeight.w700),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
