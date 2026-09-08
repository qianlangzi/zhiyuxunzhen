import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/utils/media_url.dart';
import '../../../shared/utils/patient_profile.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../common/guide/guide_anchor.dart';
import '../../common/guide/guide_controller.dart';
import '../../common/guide/guide_tours.dart';
import '../../student/data/student_service.dart';

/// 病历书写工坊：九段结构化书写 + AI 段落教练（三级提示梯度）
///
/// 每段右侧「问 AI」按钮按 点击次数递增提示等级：
/// 第 1 次 → 追问（不给答案）；第 2 次 → 定向提示；第 3 次 → 示范片段（带水印警示）。
/// 提交后 AI 结构化批阅（九段评分 + 缺陷清单），跳转批阅报告页。
class MrWorkshopScreen extends ConsumerStatefulWidget {
  const MrWorkshopScreen({super.key, required this.scheduleId});

  final int scheduleId;

  @override
  ConsumerState<MrWorkshopScreen> createState() => _MrWorkshopScreenState();
}

class _MrWorkshopScreenState extends ConsumerState<MrWorkshopScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _submitting = false;

  /// 九段草稿内容
  final Map<String, TextEditingController> _ctrls = {};

  /// 每段提示等级（1追问 2定向 3示范）
  final Map<String, int> _hintLevels = {};

  /// 每段展开的 AI 教练卡
  final Map<String, Map<String, dynamic>> _hints = {};

  /// 每段教练卡加载中
  final Set<String> _hintLoading = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await StudentService().getDailyMrDetail(widget.scheduleId);
    if (!mounted) return;
    // 已有最新一版内容回填，便于修订迭代
    final records = (detail?['myRecords'] as List?) ?? const [];
    String? latestContent;
    if (records.isNotEmpty) {
      latestContent = (records.first as Map)['contentJson'] as String?;
    }
    Map<String, dynamic> segs = {};
    if (latestContent != null && latestContent.isNotEmpty) {
      try {
        segs = jsonDecode(latestContent) as Map<String, dynamic>;
      } catch (_) {}
    }
    final segmentDefs = (detail?['segments'] as List?) ?? const [];
    for (final seg in segmentDefs) {
      final key = (seg as Map)['key'] as String;
      if (!_ctrls.containsKey(key)) {
        _ctrls[key] = TextEditingController(text: segs[key]?.toString() ?? '');
      }
    }
    setState(() {
      _detail = detail;
      _loading = false;
    });
    // 数据就绪后再触发页面级引导（「问 AI」连点升级），锚点此时才渲染
    if (detail != null && mounted) {
      ref
          .read(guideControllerProvider.notifier)
          .schedulePageEnter(GuidePageIds.studentMr);
    }
  }

  // ---------------- 数据解析 ----------------

  List<Map<String, dynamic>> get _segments =>
      ((_detail?['segments'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  String get _caseTitle => _detail?['caseTitle'] as String? ?? '';
  String get _keyFindings => _detail?['keyFindings'] as String? ?? '';

  // ---------------- AI 段落教练 ----------------

  Future<void> _askHint(Map<String, dynamic> seg) async {
    final key = seg['key'] as String;
    if (_hintLoading.contains(key)) return;
    final level = ((_hintLevels[key] ?? 0) + 1).clamp(1, 3);
    setState(() => _hintLoading.add(key));
    final resp = await StudentService().dailyMrHint(
      scheduleId: widget.scheduleId,
      segmentKey: key,
      hintLevel: level,
    );
    if (!mounted) return;
    setState(() {
      _hintLoading.remove(key);
      _hintLevels[key] = level;
      if (resp != null) {
        _hints[key] = resp;
      } else {
        _hints[key] = {
          'type': 'hint',
          'text': 'AI 教练暂时离线，请对照段落规范自查一遍。',
          'degraded': true,
        };
      }
    });
  }

  String _hintTypeLabel(String? type, int level) {
    switch (type) {
      case 'question':
        return '先想想';
      case 'hint':
        return '给你个方向';
      case 'example':
        return '范例参考';
      case 'praise':
        return '写得不错';
      default:
        return level <= 1 ? '先想想' : '提示';
    }
  }

  Color _hintTypeColor(String? type) {
    switch (type) {
      case 'praise':
        return AppColors.moss3Of(context);
      case 'example':
        return AppColors.amberOf(context);
      default:
        return AppColors.primaryOf(context);
    }
  }

  // ---------------- 提交 ----------------

  Future<void> _submit() async {
    if (_submitting) return;
    final filled = <String, String>{};
    for (final e in _ctrls.entries) {
      if (e.value.text.trim().isNotEmpty) filled[e.key] = e.value.text.trim();
    }
    if (filled.length < 3) {
      AppFeedback.info(context, '至少写满 3 段再提交（主诉、现病史是基础）');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final resp = await StudentService().submitDailyMr(
      scheduleId: widget.scheduleId,
      segments: filled,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (resp == null) {
      AppFeedback.info(context, '提交失败，请稍后重试');
      return;
    }
    final degraded = resp['degraded'] as bool? ?? true;
    if (degraded) {
      AppFeedback.info(context, '已提交，AI 批阅暂不可用，待教师人工批阅');
    }
    await context.pushNamed(RouteNames.mrReport,
        pathParameters: {'scheduleId': '${widget.scheduleId}'});
    if (mounted) Navigator.of(context).pop();
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
              title: '书写工坊',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _detail == null
                      ? Center(
                          child: Text('题目加载失败',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.text3Of(context))))
                      : _buildBody(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildCaseHeader(),
        const SizedBox(height: 12),
        for (final seg in _segments) ...[
          _buildSegment(seg),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildCaseHeader() {
    final profile = parsePatientProfile(_detail?['patientProfile'] as String?);
    // 数据层统一把影像 URL 解析为绝对地址（resolveMediaUrl 幂等：http 开头原样返回）
    final examMedia = ((_detail?['exams'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((e) => {
              'name': (e['name'] as String?) ?? '',
              'imageUrls': [
                for (final u in ((e['imageUrls'] as List?) ?? const []))
                  if (resolveMediaUrl(u.toString()).isNotEmpty)
                    resolveMediaUrl(u.toString()),
              ],
            })
        .where((e) => (e['imageUrls'] as List).isNotEmpty)
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_caseTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOf(context))),
          if (profile.chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in profile.chips)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.ruleOf(context), width: 0.5),
                    ),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '$label ',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.text4Of(context))),
                        TextSpan(
                            text: value,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text2Of(context))),
                      ]),
                    ),
                  ),
              ],
            ),
          ],
          if (profile.complaint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('主诉：${profile.complaint}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                    color: AppColors.textOf(context))),
          ],
          if (profile.summary.isNotEmpty &&
              profile.summary != profile.complaint) ...[
            const SizedBox(height: 8),
            _ExpandableText(
              text: profile.summary,
              collapsedLines: 5,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppColors.text2Of(context)),
            ),
          ],
          // 患者自带影像资料（教师上传，点开可放大）
          if (examMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('患者影像资料',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.text3Of(context))),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final exam in examMedia)
                    for (var i = 0; i < ((exam['imageUrls'] as List?) ?? const []).length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _ExamImageCard(
                        url: (exam['imageUrls'] as List)[i].toString(),
                        label: i == 0 ? (exam['name'] as String? ?? '') : '',
                      ),
                      const SizedBox(width: 6),
                    ],
                ],
              ),
            ),
          ],
          if (_keyFindings.isNotEmpty &&
              _keyFindings != _detail?['patientProfile']) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science_rounded,
                          size: 13, color: AppColors.indigoOf(context)),
                      const SizedBox(width: 4),
                      Text('关键检查结果',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.indigoOf(context))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ExpandableText(
                    text: _keyFindings,
                    collapsedLines: 4,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.text2Of(context)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegment(Map<String, dynamic> seg) {
    final key = seg['key'] as String;
    final name = seg['name'] as String? ?? key;
    final spec = seg['spec'] as String? ?? '';
    final full = (seg['fullScore'] as num?)?.toInt() ?? 0;
    final ctrl = _ctrls[key];
    final hint = _hints[key];
    final hintLoading = _hintLoading.contains(key);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$name',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOf(context))),
              const SizedBox(width: 6),
              Text('$full 分',
                  style: TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
              const Spacer(),
              // 仅首段挂引导锚点：教用户「问 AI 连点升级」这条隐藏机制
              if (seg['key'] == _segments.first['key'])
                GuideTarget(
                  anchor: GuideAnchors.studentMrAskAi,
                  child: AppPressable(
                    onTap: hintLoading ? null : () => _askHint(seg),
                    child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOf(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: hintLoading
                      ? SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryOf(context)))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 13, color: AppColors.primaryOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              _hintLabel(key),
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.primaryOf(context)),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
            ],
          ),
          if (spec.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(spec,
                style: TextStyle(fontSize: 11.5, height: 1.5,
                    color: AppColors.text4Of(context))),
          ],
          const SizedBox(height: 10),
          if (ctrl != null)
            _MrField(
              controller: ctrl,
              hint: '开始书写$name…',
              minLines: key == 'chief_complaint' ? 2 : 3,
              maxLines: key == 'history_present' ? 10 : 6,
            ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            _buildHintCard(key, hint),
          ],
        ],
      ),
    );
  }

  String _hintLabel(String key) {
    final level = _hintLevels[key] ?? 0;
    if (level == 0) return '问 AI';
    if (_hints[key] != null) return '再问一次';
    return '问 AI';
  }

  Widget _buildHintCard(String key, Map<String, dynamic> hint) {
    final type = hint['type'] as String?;
    final level = _hintLevels[key] ?? 1;
    final color = _hintTypeColor(type);
    final materials = (hint['quoteMaterials'] as List?) ?? const [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.co_present_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text('AI 教练 · ${_hintTypeLabel(type, level)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint['text'] as String? ?? '',
            style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text2Of(context)),
          ),
          for (final m in materials.whereType<String>()) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 13,
                    color: AppColors.text4Of(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('问诊原话：$m',
                      style: TextStyle(fontSize: 11.5, height: 1.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.text3Of(context))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context), width: 0.5)),
      ),
      child: AppPrimaryButton(
        label: _submitting ? 'AI 批阅中…' : '提交病历 · AI 批阅',
        onPressed: _submitting ? null : _submit,
      ),
    );
  }
}

// ============================================================
// 私有组件
// ============================================================

/// 可展开文本：默认折叠 [collapsedLines] 行，超出约 100 字时显示「展开全文/收起」
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({
    required this.text,
    this.collapsedLines = 4,
    required this.style,
  });

  final String text;
  final int collapsedLines;
  final TextStyle style;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  bool get _needsToggle => widget.text.length > 100 || widget.text.contains('\n\n');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.collapsedLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: widget.style,
        ),
        if (_needsToggle) ...[
          const SizedBox(height: 4),
          AppPressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? '收起' : '展开全文',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOf(context)),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: AppColors.primaryOf(context),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 病历书写输入框：不依赖全局 InputDecorationTheme（全局是多行输入也变
/// 胶囊的 Stadium 圆角，多行场景极丑），自绘浅底圆角容器 + 聚焦主色描边
class _MrField extends StatefulWidget {
  const _MrField({
    required this.controller,
    required this.hint,
    this.minLines = 3,
    this.maxLines = 6,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  State<_MrField> createState() => _MrFieldState();
}

class _MrFieldState extends State<_MrField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused
              ? AppColors.primaryOf(context)
              : AppColors.ruleOf(context),
          width: focused ? 1.2 : 0.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        cursorColor: AppColors.primaryOf(context),
        style: TextStyle(
            fontSize: 13.5, height: 1.65, color: AppColors.textOf(context)),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: widget.hint,
          hintStyle:
              TextStyle(fontSize: 12.5, color: AppColors.text4Of(context)),
        ),
      ),
    );
  }
}

/// 患者影像卡：点击全屏放大（书写时对照阅读 X 光/CT/报告单）
/// 全屏支持双指缩放/拖动平移，加载中有占位，失败给出可读提示
class _ExamImageCard extends StatelessWidget {
  const _ExamImageCard({required this.url, this.label = ''});

  final String url;
  final String label;

  void _openFullScreen(BuildContext context) {
    final resolved = resolveMediaUrl(url);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      useSafeArea: true,
      builder: (dialogCtx) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              // 图片层：InteractiveViewer 支持双指缩放 + 拖动平移
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 48, 12, 24),
                  child: InteractiveViewer(
                    maxScale: 8,
                    minScale: 0.5,
                    boundaryMargin: const EdgeInsets.all(40),
                    child: Center(
                      child: Image.network(
                        resolved,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70),
                              const SizedBox(height: 10),
                              Text('影像加载中…',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7))),
                            ],
                          );
                        },
                        errorBuilder: (_, __, ___) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined,
                                size: 44, color: Colors.white38),
                            const SizedBox(height: 10),
                            Text('影像加载失败，请检查网络后重试',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.75))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 顶部栏：关闭按钮 + 操作提示
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    if (label.isNotEmpty)
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      )
                    else
                      const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogCtx).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              // 底部操作提示
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: Text('双指缩放 · 拖动平移 · 点右上角关闭',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.55))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 108,
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                resolveMediaUrl(url),
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) =>
                    progress == null
                        ? child
                        : Container(
                            color: AppColors.ruleSoftOf(context),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 1.6),
                              ),
                            ),
                          ),
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.ruleSoftOf(context),
                  child: Icon(Icons.broken_image_outlined,
                      size: 18, color: AppColors.text4Of(context)),
                ),
              ),
              // 右上角放大角标，暗示可点击
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.zoom_out_map_rounded,
                      size: 10, color: Colors.white),
                ),
              ),
              if (label.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white),
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
