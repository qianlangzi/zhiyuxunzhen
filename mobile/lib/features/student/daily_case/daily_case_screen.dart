import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../../student/data/student_service.dart';

/// 每日一题（力扣式单题）
///
/// 数据流：GET /daily-cases/today 返回今日排期 VO：
///   scheduleId / caseId / caseTitle / department / difficulty
///   publishDate / question / optionsJson(JSON数组字符串) / textbookRef
/// 作答后 POST /daily-cases/submit（answer=所选选项文本），后端按
/// 标准答案规则判题或 AI 判题，返回 correct / correctAnswer / explanation。
class DailyCaseScreen extends ConsumerStatefulWidget {
  const DailyCaseScreen({super.key});

  @override
  ConsumerState<DailyCaseScreen> createState() => _DailyCaseScreenState();
}

class _DailyCaseScreenState extends ConsumerState<DailyCaseScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  int _selected = -1;
  bool _submitting = false;

  /// 判题结果（DailyCaseResultVO 反序列化）
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getTodayDailyCase();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  // ---------------- 数据解析 ----------------

  List<String> get _options {
    final raw = _data?['optionsJson'];
    if (raw is List) return raw.cast<String>();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {/* 忽略非法 JSON */}
    }
    return const [];
  }

  String get _question =>
      (_data?['question'] as String?)?.trim().isNotEmpty == true
          ? _data!['question'] as String
          : (_data?['caseTitle'] as String? ?? '今日暂无题目');

  String get _department => _data?['department'] as String? ?? '';
  String get _caseTitle => _data?['caseTitle'] as String? ?? '';
  int get _difficulty => _data?['difficulty'] as int? ?? 0;
  String get _publishDate => _data?['publishDate'] as String? ?? '';
  String get _textbookRef => _data?['textbookRef'] as String? ?? '';
  int? get _scheduleId => _data?['scheduleId'] as int?;

  // ---------------- 提交判题 ----------------

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selected < 0) {
      AppFeedback.info(context, '请先选择一个选项');
      return;
    }
    final scheduleId = _scheduleId;
    if (scheduleId == null) {
      AppFeedback.info(context, '该每日一题未配置提交排期');
      return;
    }

    setState(() => _submitting = true);
    final options = _options;
    final answer =
        _selected < options.length ? options[_selected] : '';
    final resp = await StudentService().submitDailyCase(
      scheduleId: scheduleId,
      answer: answer,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (resp != null) _result = resp;
    });

    if (resp == null) {
      AppFeedback.info(context, '提交失败：今日可能已作答过，请稍后重试');
      return;
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '每日一例',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  // 直达路由兜底：回学生端首页
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _result == null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data == null) {
      return _buildEmpty();
    }
    return _buildQuestion();
  }

  // ---------------- 空态 ----------------

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 56,
              color: AppColors.text4Of(context),
            ),
            const SizedBox(height: 16),
            Text(
              '今日题目暂未发布',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '每天 00:00 自动上新一题，\n明天再来看看新病例吧',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.text3Of(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 题目区 ----------------

  Widget _buildQuestion() {
    final options = _options;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(),
          const SizedBox(height: 14),
          _buildStemCard(),
          const SizedBox(height: 14),
          if (_result == null) _buildOptionHeader(),
          ...options.asMap().entries.map((e) {
            final idx = e.key;
            final option = e.value;
            final state = _optionState(idx);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildOptionCard(
                idx: idx,
                text: option,
                enabled: _result == null && !_submitting,
                state: state,
                onTap: () => setState(() => _selected = idx),
              ),
            );
          }),
          if (_result != null) ...[
            const SizedBox(height: 6),
            _buildResultCard(),
          ],
          if (_textbookRef.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildTextbookCard(),
          ],
        ],
      ),
    );
  }

  /// 选项状态：0 正常 / 1 选中 / 2 正确答案 / 3 我选错
  int _optionState(int idx) {
    if (_result == null) return idx == _selected ? 1 : 0;
    final options = _options;
    final correctAns = ((_result?['correctAnswer'] as String?) ?? '').trim();
    final correctIdx = correctAns.isEmpty
        ? -1
        : options.indexWhere((o) => o.trim() == correctAns);
    final correct = _result?['correct'] as bool? ?? false;
    if (idx == correctIdx) return 2;
    if (!correct && idx == _selected) return 3;
    return 0;
  }

  // ---------------- 头部 Hero ----------------

  Widget _buildHeroCard() {
    final date = _publishDate.isNotEmpty ? _fmtDate(_publishDate) : '今日一题';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryOf(context),
            AppColors.primaryOf(context).withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOf(context).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tagChip(
                text: date,
                fg: AppColors.onPrimaryOf(context),
                bg: Colors.white.withValues(alpha: 0.18),
              ),
              const Spacer(),
              if (_caseTitle.isNotEmpty)
                _tagChip(
                  text: _caseTitle,
                  fg: AppColors.onPrimaryOf(context),
                  bg: Colors.white.withValues(alpha: 0.18),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _department.isEmpty ? 'AI 每日一题' : _department,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.onPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _question.length > 46
                ? '${_question.substring(0, 46)}…'
                : _question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.onPrimaryLightOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip({
    required String text,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  // ---------------- 题干卡 ----------------

  Widget _buildStemCard() {
    return PaperCard(
      tint: AppColors.surfaceOf(context),
      tintStrength: 0.4,
      accent: AppColors.primaryOf(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '题目',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.text3Of(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _question,
            style: TextStyle(
              fontSize: 16,
              height: 1.75,
              color: AppColors.textOf(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 选项 ----------------

  Widget _buildOptionHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Text(
            '选择你的答案',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textOf(context),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _difficultyText,
            style:
                TextStyle(fontSize: 11.5, color: AppColors.amberOf(context)),
          ),
        ],
      ),
    );
  }

  String get _difficultyText {
    if (_difficulty <= 1) return '难度：入门';
    if (_difficulty == 2) return '难度：进阶';
    return '难度：挑战';
  }

  Widget _buildOptionCard({
    required int idx,
    required String text,
    required bool enabled,
    required int state,
    required VoidCallback onTap,
  }) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final letter = idx < letters.length ? letters[idx] : '${idx + 1}';

    final Color accent;
    final Color bg;
    switch (state) {
      case 1: // 选中（未判题）
        accent = AppColors.primaryOf(context);
        bg = AppColors.mossTintOf(context);
        break;
      case 2: // 正确答案
        accent = AppColors.moss3Of(context);
        bg = AppColors.mossTintOf(context);
        break;
      case 3: // 我选错
        accent = AppColors.vermilionOf(context);
        bg = AppColors.vermilionSoftOf(context);
        break;
      default:
        accent = AppColors.surfaceEdgeOf(context);
        bg = AppColors.surfaceOf(context);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: state == 0
                  ? AppColors.surfaceEdgeOf(context)
                  : accent,
              width: state == 0 ? 1 : 1.6,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 序号圆
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == 0
                      ? AppColors.surfaceOf(context)
                      : accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 1.4),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: state == 0 ? AppColors.text2Of(context) : accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: state == 3
                          ? AppColors.vermilionOf(context)
                          : AppColors.textOf(context),
                      fontWeight:
                          state == 2 || state == 3
                              ? FontWeight.w600
                              : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (state == 1)
                Icon(Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.primaryOf(context),
                ),
              if (state == 2)
                Icon(Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.moss3Of(context),
                ),
              if (state == 3)
                Icon(Icons.cancel_rounded,
                    size: 20,
                    color: AppColors.vermilionOf(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 判题结果 ----------------

  Widget _buildResultCard() {
    final correct = _result?['correct'] as bool? ?? false;
    final explanation = _result?['explanation'] as String? ?? '';
    final degraded = _result?['degraded'] as bool? ?? false;

    final accent = correct
        ? AppColors.moss3Of(context)
        : AppColors.vermilionOf(context);
    final soft = correct
        ? AppColors.mossTintOf(context)
        : AppColors.vermilionSoftOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct
                    ? Icons.emoji_events_rounded
                    : Icons.lightbulb_rounded,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? '回答正确，很棒！' : '回答错误，看看解析',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.textOf(context),
              ),
            ),
          ],
          if (degraded) ...[
            const SizedBox(height: 10),
            Text(
              '（本次由规则兜底判题，深度解析暂不可用）',
              style: TextStyle(fontSize: 12, color: AppColors.text3Of(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextbookCard() {
    return Row(
      children: [
        Icon(Icons.menu_book_rounded, size: 15, color: AppColors.text3Of(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '教材出处：$_textbookRef',
            style:
                TextStyle(fontSize: 12.5, color: AppColors.text3Of(context)),
          ),
        ),
      ],
    );
  }

  // ---------------- 底部提交栏 ----------------

  Widget? _buildBottomBar() {
    final options = _options;
    if (options.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        border: Border(
          top: BorderSide(color: AppColors.ruleOf(context), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AppPrimaryButton(
          label: _submitting ? '判题中…' : '提交答案',
          fullWidth: true,
          icon: _submitting
              ? null
              : const Icon(Icons.auto_awesome, size: 16),
          onPressed: _submitting ? null : _submit,
        ),
      ),
    );
  }

  // ---------------- 工具 ----------------

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const week = ['一', '二', '三', '四', '五', '六', '日'];
      return '${d.month}月${d.day}日 · 周${week[d.weekday - 1]}';
    } catch (_) {
      return iso;
    }
  }
}
