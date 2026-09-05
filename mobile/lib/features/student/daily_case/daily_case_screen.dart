import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 每日一例（开放诊断作答）
///
/// 数据流：GET /daily-cases/today 返回今日排期 VO：
///   scheduleId / caseId / caseTitle / department / difficulty
///   publishDate / patientProfile(患者画像) / keyFindings(关键检查)
/// 学生开放书写「诊断 + 依据 + 初步诊疗方案」，POST /daily-cases/submit
/// 由 AI（DeepSeek）对照标准诊断要点评审，返回 correct / correctAnswer(标准诊断要点)
/// / explanation(AI点评) / textbookRef / degraded。
class DailyCaseScreen extends ConsumerStatefulWidget {
  const DailyCaseScreen({super.key});

  @override
  ConsumerState<DailyCaseScreen> createState() => _DailyCaseScreenState();
}

class _DailyCaseScreenState extends ConsumerState<DailyCaseScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;

  final TextEditingController _answerCtrl = TextEditingController();

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
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

  String get _caseTitle => _data?['caseTitle'] as String? ?? '';
  String get _department => _data?['department'] as String? ?? '';
  int get _difficulty => _data?['difficulty'] as int? ?? 0;
  String get _publishDate => _data?['publishDate'] as String? ?? '';
  String get _patientProfile => _data?['patientProfile'] as String? ?? '';
  String get _keyFindings => _data?['keyFindings'] as String? ?? '';
  int? get _scheduleId => _data?['scheduleId'] as int?;

  /// 当前学生对今日病例的问诊状态：null未做过 / 0进行中 / 1已完成 / 2评估异常
  int? get _lastSessionStatus => _data?['lastSessionStatus'] as int?;

  String get _difficultyText {
    if (_difficulty <= 1) return '入门';
    if (_difficulty == 2) return '进阶';
    return '挑战';
  }

  ({String text, Color fg, Color bg}) _sessionInfo() {
    switch (_lastSessionStatus) {
      case 0:
        return (
          text: '进行中',
          fg: AppColors.amberOf(context),
          bg: AppColors.amberSoftOf(context),
        );
      case 1:
        return (
          text: '已做过',
          fg: AppColors.moss3Of(context),
          bg: AppColors.mossTintOf(context),
        );
      case 2:
        return (
          text: '待重试',
          fg: AppColors.vermilionOf(context),
          bg: AppColors.vermilionSoftOf(context),
        );
      default:
        return (
          text: '未做过',
          fg: AppColors.text3Of(context),
          bg: AppColors.ruleSoftOf(context),
        );
    }
  }

  // ---------------- 提交判题 ----------------

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _answerCtrl.text.trim();
    if (text.length < 8) {
      AppFeedback.info(context, '再补充一些诊断思路吧，至少 8 个字');
      return;
    }
    final scheduleId = _scheduleId;
    if (scheduleId == null) {
      AppFeedback.info(context, '该每日一例未配置提交排期');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final resp = await StudentService().submitDailyCase(
      scheduleId: scheduleId,
      answer: text,
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
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data == null) {
      return _buildEmpty();
    }
    return _buildContent();
  }

  // ---------------- 空态 ----------------

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_hospital_rounded,
                size: 44,
                color: AppColors.moss3Of(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '今日病例还未上新',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textOf(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '每天 00:00 自动更新一个临床病例',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.text3Of(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 主内容 ----------------

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (_patientProfile.isNotEmpty) ...[
            _sectionCard(
              icon: Icons.face_rounded,
              iconColor: AppColors.primaryOf(context),
              title: '患者画像',
              child: _buildPatientProfile(),
            ),
            const SizedBox(height: 12),
          ],
          if (_keyFindings.isNotEmpty) ...[
            _sectionCard(
              icon: Icons.monitor_heart_rounded,
              iconColor: AppColors.indigoOf(context),
              title: '关键检查',
              child: _buildKeyFindings(),
            ),
            const SizedBox(height: 12),
          ],
          if (_result == null)
            _buildAnswerCard()
          else ...[
            _buildResultCard(),
            const SizedBox(height: 12),
            _buildAnswerReview(),
          ],
        ],
      ),
    );
  }

  // ---------------- 头部（轻量，无深绿大块） ----------------

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.mossTintOf(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_hospital_rounded,
            size: 24,
            color: AppColors.primaryOf(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _caseTitle.isNotEmpty ? _caseTitle : '今日临床病例',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.textOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (_department.isNotEmpty) ...[
                    Text(
                      _department,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _caseStatusChip(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _lightChip(
              AppColors.indigoOf(context),
              AppColors.indigoSoftOf(context),
              '难度·$_difficultyText',
            ),
            const SizedBox(height: 6),
            if (_publishDate.isNotEmpty)
              _lightChip(
                AppColors.text3Of(context),
                AppColors.ruleSoftOf(context),
                _fmtDate(_publishDate),
              ),
          ],
        ),
      ],
    );
  }

  Widget _lightChip(Color fg, Color bg, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  /// 当前学生对今日病例的「已做/进行中/未做」状态小签
  Widget _caseStatusChip() {
    final info = _sessionInfo();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: info.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: info.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            info.text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: info.fg,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 分区卡片 ----------------

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.surfaceEdgeOf(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPatientProfile() {
    final profile = _patientProfile.trim();
    final decoded = _tryDecodeMap(profile);
    if (decoded != null && decoded.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: decoded.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    '${_patientFieldLabel(e.key)}  ',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.text3Of(context),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '${e.value}',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
    return Text(
      profile,
      style: TextStyle(
        fontSize: 14,
        height: 1.7,
        color: AppColors.textOf(context),
      ),
    );
  }

  Widget _buildKeyFindings() {
    final lines = _keyFindings
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return Text(
        _keyFindings,
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          color: AppColors.textOf(context),
        ),
      );
    }
    return Column(
      children: lines.asMap().entries.map((entry) {
        final idx = entry.key;
        final line = entry.value;
        final bullet = idx < 26 ? String.fromCharCode(0x2460 + idx) : '${idx + 1}.';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.indigoOf(context).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  bullet,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigoOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: AppColors.textOf(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------- 作答区（更大） ----------------

  Widget _buildAnswerCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Row(
            children: [
              Text(
                '你的诊断',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOf(context),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI 将对照标准诊断要点评审',
                style: TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.surfaceEdgeOf(context),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _answerCtrl,
            enabled: !_submitting,
            maxLines: 9,
            minLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textOf(context),
            ),
            decoration: InputDecoration(
              hintText: '初步诊断：\n诊断依据（结合画像与检查）：\n初步诊疗方案：',
              hintStyle: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: AppColors.text4Of(context),
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- 判题结果 ----------------

  Widget _buildResultCard() {
    final correct = _result?['correct'] as bool? ?? false;
    final degraded = _result?['degraded'] as bool? ?? false;

    final Color accent;
    final Color soft;
    IconData icon;
    String title;
    String sub;
    if (degraded) {
      accent = AppColors.amberOf(context);
      soft = AppColors.amberSoftOf(context);
      icon = Icons.schedule_rounded;
      title = '已保存';
      sub = '评审服务暂不可用，答案已记录';
    } else if (correct) {
      accent = AppColors.moss3Of(context);
      soft = AppColors.mossTintOf(context);
      icon = Icons.check_circle_rounded;
      title = '诊断基本命中';
      sub = 'AI 已对照标准诊断要点完成评审';
    } else {
      accent = AppColors.vermilionOf(context);
      soft = AppColors.vermilionSoftOf(context);
      icon = Icons.lightbulb_rounded;
      title = '思路略有偏差';
      sub = 'AI 已对照标准诊断要点完成评审';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(sub, style: TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerReview() {
    final correctAnswer = _result?['correctAnswer'] as String? ?? '';
    final explanation = _result?['explanation'] as String? ?? '';
    final textbookRef = _result?['textbookRef'] as String? ?? '';
    final degraded = _result?['degraded'] as bool? ?? false;

    if (degraded && explanation.isEmpty) {
      return _sectionCard(
        icon: Icons.auto_awesome_rounded,
        iconColor: AppColors.indigoOf(context),
        title: '评审要点',
        child: Text(
          '当前评审服务暂不可用，你的答案已保存。',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.7,
            color: AppColors.text2Of(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (correctAnswer.isNotEmpty) ...[
          _sectionCard(
            icon: Icons.local_hospital_rounded,
            iconColor: AppColors.primaryOf(context),
            title: '标准诊断要点',
            child: Text(
              correctAnswer,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.primaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (explanation.isNotEmpty)
          _sectionCard(
            icon: Icons.rate_review_rounded,
            iconColor: AppColors.indigoOf(context),
            title: 'AI 点评',
            child: Text(
              explanation,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.textOf(context),
              ),
            ),
          ),
        if (textbookRef.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 15,
                  color: AppColors.text3Of(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '教材出处：$textbookRef',
                    style: TextStyle(fontSize: 12.5, color: AppColors.text3Of(context)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------- 底部提交栏 ----------------

  Widget? _buildBottomBar() {
    if (_result != null) return null;
    if (_data == null) return null;
    final hasText = _answerCtrl.text.trim().length >= 8;
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
          label: _submitting ? 'AI 评审中…' : '提交，让 AI 评审',
          fullWidth: true,
          icon: _submitting
              ? null
              : const Icon(Icons.auto_awesome_rounded, size: 17),
          onPressed: (_submitting || !hasText) ? null : _submit,
        ),
      ),
    );
  }

  // ---------------- 工具 ----------------

  Map<String, dynamic>? _tryDecodeMap(String text) {
    final t = text.trim();
    if (!t.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
        return decoded;
      }
    } catch (_) {/* 非法 JSON 则原文展示 */}
    return null;
  }

  String _patientFieldLabel(String key) {
    const map = {
      'age': '年龄',
      'gender': '性别',
      'occupation': '职业',
      'chiefComplaint': '主诉',
      'presentIllness': '现病史',
      'pastHistory': '既往史',
      'allergy': '过敏史',
      'personality': '性格',
      'name': '姓名',
    };
    return map[key] ?? key;
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.month}月${d.day}日';
    } catch (_) {
      return iso;
    }
  }
}