import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 病例广场 · 病例详情子页面
///
/// 修复点：此前详情是底部弹层直接吐患者画像原始 JSON（英文 key 裸奔）。
/// 现在独立子页面 + 结构化解析 patientProfile：
///   基本信息（年龄/性别/职业/年级/过敏史）→ 主诉 → 现病史 → 既往史 → 人格特质，
///   全部中文标签；JSON 解析失败时回退展示原文，兼容旧数据。
class CaseMarketDetailScreen extends StatefulWidget {
  const CaseMarketDetailScreen({
    super.key,
    required this.caseId,
    required this.title,
    required this.department,
    required this.difficulty,
    required this.author,
    required this.refs,
    required this.rating,
    required this.tags,
  });

  final int caseId;
  final String title;
  final String department;
  final String difficulty;
  final String author;
  final int refs;
  final double rating;
  final List<String> tags;

  @override
  State<CaseMarketDetailScreen> createState() => _CaseMarketDetailScreenState();
}

class _CaseMarketDetailScreenState extends State<CaseMarketDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _quoting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final detail = await TeacherService().getMarketDetail(widget.caseId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  /// 解析 patientProfile：JSON 对象 → 结构化字段；失败返回 null（回退原文）
  Map<String, dynamic>? _parseProfile(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  String _text(dynamic v) {
    if (v == null) return '';
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('、');
    }
    return v.toString().trim();
  }

  Future<void> _quote() async {
    if (_quoting) return;
    final ok = await AppFeedback.confirm(
      context,
      title: '引用病例',
      content: '引用后将生成独立副本到你的病例库，可基于副本设置班级变量。原病例后续修改不影响本副本。',
      confirmText: '引用',
    );
    if (!ok || !mounted) return;
    setState(() => _quoting = true);
    final newId = await TeacherService().quoteCase(widget.caseId);
    if (!mounted) return;
    setState(() => _quoting = false);
    if (newId == null) {
      AppFeedback.error(context, '引用失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '已引用到我的病例库 · 病例 #$newId');
    // 引用后直接进入编辑模式：配置台按副本 ID 回填，可改可保存可发布
    context.pushNamed(RouteNames.spConfig, extra: {'caseId': newId});
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final profileRaw = detail?['patientProfile'] as String? ?? '';
    final profile = _parseProfile(profileRaw);

    final tagsRaw = detail?['knowledgeTags'];
    final tags = tagsRaw is List && tagsRaw.isNotEmpty
        ? tagsRaw.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList()
        : widget.tags;
    final refs = (detail?['referenceCount'] as num?)?.toInt() ?? widget.refs;
    final rating = (detail?['ratingAvg'] as num?)?.toDouble() ?? widget.rating;
    final author = detail?['creatorName'] as String? ?? widget.author;

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '病例详情',
              onBack: () => context.canPop() ? context.pop() : null,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        children: [
                          _buildHeader(context, refs, rating, author),
                          const SizedBox(height: 14),
                          if (tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .map((t) => AppChip(label: t, type: ChipType.moss, fontSize: 10))
                                  .toList(),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (profile != null)
                            _buildStructuredProfile(context, profile)
                          else
                            _buildSectionCard(
                              context,
                              title: '患者画像 / 病例内容',
                              child: Text(
                                profileRaw.isEmpty ? '暂无患者画像内容' : profileRaw,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.7,
                                  color: profileRaw.isEmpty
                                      ? AppColors.text4Of(context)
                                      : AppColors.textOf(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      // 底部悬浮引用按钮
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
        ),
        child: AppPrimaryButton(
          label: _quoting ? '引用中…' : '引用到我的病例库',
          fullWidth: true,
          onPressed: _quoting ? null : _quote,
        ),
      ),
    );
  }

  // ---------- 头部：标题 + 元信息 ----------
  Widget _buildHeader(BuildContext context, int refs, double rating, String author) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _detail?['title'] as String? ?? widget.title,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC'],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppChip(label: widget.department, type: ChipType.indigo, fontSize: 10),
            ],
          ),
          const SizedBox(height: 8),
          MonoText(
            '${widget.difficulty} · $author · 引用 $refs · ★ ${rating.toStringAsFixed(1)}',
            fontSize: 11,
            color: AppColors.text3Of(context),
          ),
        ],
      ),
    );
  }

  // ---------- 结构化患者画像 ----------
  Widget _buildStructuredProfile(BuildContext context, Map<String, dynamic> p) {
    // 基本信息（基本信息缺失的字段自动不展示）
    final basics = <(String, String)>[
      ('年龄', _text(p['age']).isEmpty ? '' : '${_text(p['age'])} 岁'),
      ('性别', _genderLabel(_text(p['gender']))),
      ('职业', _text(p['occupation'])),
      ('年级', _text(p['grade'])),
      ('过敏史', _text(p['allergy'])),
    ].where((e) => e.$2.isNotEmpty).toList();

    final personality = p['personality'];
    final personalityTags = personality is List
        ? personality.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (basics.isNotEmpty)
          _buildSectionCard(
            context,
            title: '基本信息',
            child: basics.isNotEmpty
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: basics
                        .map((e) => _infoPill(context, e.$1, e.$2))
                        .toList(),
                  )
                : const SizedBox.shrink(),
          ),
        _sectionGap(),
        _buildSectionCard(
          context,
          title: '主诉',
          child: _bodyText(context, _text(p['complaint'])),
        ),
        if (_text(p['presentIllness']).isNotEmpty) ...[
          _sectionGap(),
          _buildSectionCard(
            context,
            title: '现病史',
            child: _bodyText(context, _text(p['presentIllness'])),
          ),
        ],
        if (_text(p['pastHistory']).isNotEmpty) ...[
          _sectionGap(),
          _buildSectionCard(
            context,
            title: '既往史',
            child: _bodyText(context, _text(p['pastHistory'])),
          ),
        ],
        if (personalityTags.isNotEmpty) ...[
          _sectionGap(),
          _buildSectionCard(
            context,
            title: '人格特质（SP 扮演要点）',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: personalityTags
                  .map((t) => AppChip(label: t, type: ChipType.indigo, fontSize: 10))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  String _genderLabel(String raw) {
    if (raw.isEmpty) return '';
    if (raw.contains('女')) return '女';
    if (raw.contains('男')) return '男';
    return raw;
  }

  Widget _sectionGap() => const SizedBox(height: 10);

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
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

  Widget _infoPill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoText(label,
              fontSize: 11, color: AppColors.text3Of(context)),
          const SizedBox(width: 6),
          MonoText(value,
              fontSize: 11.5,
              color: AppColors.textOf(context),
              weight: FontWeight.w600),
        ],
      ),
    );
  }

  Widget _bodyText(BuildContext context, String text) {
    if (text.isEmpty) {
      return Text('（未填写）',
          style: TextStyle(fontSize: 13, color: AppColors.text4Of(context)));
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.7,
        color: AppColors.textOf(context),
      ),
    );
  }
}
