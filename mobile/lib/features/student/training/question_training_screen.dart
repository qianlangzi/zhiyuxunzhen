import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import 'question_practice_screen.dart';

/// 基础题库（大型题库 · 入口收敛页）
///
/// 反复刷统计（正确率 / 模块正确率）在成长页已有统一展示，这里不再重复——
/// 本页聚焦「入口」：顶部浏览题库入口 + 按科室直接刷题。
class QuestionTrainingScreen extends ConsumerStatefulWidget {
  const QuestionTrainingScreen({super.key});

  @override
  ConsumerState<QuestionTrainingScreen> createState() => _QuestionTrainingScreenState();
}

class _QuestionTrainingScreenState extends ConsumerState<QuestionTrainingScreen> {
  static const _fallbackDepartments = ['心血管内科', '呼吸内科', '诊断学', '综合'];
  List<String> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final depts = await StudentService().getQuestionDepartments();
    if (!mounted) return;
    setState(() {
      final list = (depts ?? <String>[]).cast<String>();
      _departments = list.isEmpty ? [..._fallbackDepartments] : list;
      _isLoading = false;
    });
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
              title: '基础题库',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                        children: [
                          _buildBankEntry(),
                          const SizedBox(height: 20),
                          _buildDeptSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 浏览题库入口（顶部醒目位） ----------
  Widget _buildBankEntry() {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.questionBank),
      child: PressableScale(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.indigoOf(context),
                AppColors.indigoOf(context).withValues(alpha: 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card(context),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.grid_view_rounded,
                    size: 24,
                    color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('浏览题库',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    SizedBox(height: 4),
                    Text('按科室 / 知识点 / 难度 / 题型筛选，逐题练习',
                        style: TextStyle(fontSize: 12.5, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 按科室刷题 ----------
  Widget _buildDeptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SerifText('按科室刷题', fontSize: 15, color: AppColors.textOf(context)),
            MonoText('${_departments.length} 个科室',
                fontSize: 10, color: AppColors.text4Of(context)),
          ],
        ),
        const SizedBox(height: 4),
        Text('直接进入某科室练习，进度会在本地自动续接',
            style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
        const SizedBox(height: 12),
        ..._departments.map((dept) => _deptTile(dept)),
      ],
    );
  }

  Widget _deptTile(String department) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuestionPracticeScreen(title: department, department: department),
        ),
      ),
      child: PressableScale(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card(context),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.indigoSoftOf(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medical_services_outlined,
                    size: 17, color: AppColors.indigoOf(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SerifText(department,
                    fontSize: 15, color: AppColors.textOf(context)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.text3Of(context)),
            ],
          ),
        ),
      ),
    );
  }
}