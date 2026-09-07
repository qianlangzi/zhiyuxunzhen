import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 我的病例（草稿箱 · 抖音发布链路式管理）
///
/// 四段视图：
/// - 草稿：status=0，可继续编辑 / 发布 / 删除
/// - 审核中：已提交广场，待管理员审核
/// - 已上架：审核通过对外可见
/// - 被驳回：审核未通过，可编辑修正后重新发布
class MyCasesScreen extends ConsumerStatefulWidget {
  const MyCasesScreen({super.key});

  @override
  ConsumerState<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends ConsumerState<MyCasesScreen> {
  static const _tabs = ['草稿', '审核中', '已上架', '被驳回'];

  /// 各 tab 关键词（用于统计与筛选）
  static const _tabHints = ['新建 SP 病例创作区', '已提交，等待管理员审核', '审核通过，学生可查看', '未通过，修正后可重新发布'];

  int _tab = 0;
  int _scope = 0; // 0=我的病例 1=全部病例
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    Map<String, dynamic>? data;
    try {
      data = _scope == 0
          ? await TeacherService().getCaseList()
          : await TeacherService().getCaseListAll();
    } catch (e) {
      debugPrint('loadMyCases error: $e');
      data = null;
    }
    if (!mounted) return;
    final raw = (data?['records'] as List<dynamic>?) ??
        (data?['list'] as List<dynamic>?) ??
        const [];
    setState(() {
      _all = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
      // 若数据为空且请求异常，判定为加载失败，用错误态而非空态
      _error = data == null && _all.isEmpty;
      _loading = false;
    });
  }

  void _switchScope(int scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _tab = 0;
      _loading = true;
      _error = false;
    });
    _load();
  }

  /// 后端状态：status 0草稿 1已发布；adminAuditStatus 0未提交 1待审 2通过 3驳回 4下架
  int _statusOf(Map<String, dynamic> c) =>
      (c['status'] as num?)?.toInt() ?? 0;
  int _auditOf(Map<String, dynamic> c) =>
      (c['adminAuditStatus'] as num?)?.toInt() ?? 0;

  /// 是否属于第 i 个 tab
  bool _matches(int i, Map<String, dynamic> c) {
    final status = _statusOf(c);
    final audit = _auditOf(c);
    return switch (i) {
      0 => status == 0, // 草稿
      1 => status == 1 && audit == 1, // 审核中
      2 => status == 1 && audit == 2, // 已上架
      _ => audit == 3, // 被驳回
    };
  }

  /// 当前 tab 过滤后的列表（若切换到被驳回但没有任何被驳回项，自动归位到首个非空 tab 前的处理在 _tabVisibleList）
  List<Map<String, dynamic>> get _filtered {
    if (_scope == 1) return _all;
    return _all.where((c) => _matches(_tab, c)).toList();
  }

  /// 各 tab 计数
  List<int> get _counts =>
      _tabs.asMap().entries.map((e) => _all.where((c) => _matches(e.key, c)).length).toList();

  /// 状态角标
  (String, ChipType) _badgeOf(Map<String, dynamic> c) {
    final status = _statusOf(c);
    final audit = _auditOf(c);
    if (status == 0) return ('草稿', ChipType.amber);
    return switch (audit) {
      1 => ('待审核', ChipType.indigo),
      3 => ('已驳回', ChipType.vermilion),
      4 => ('已下架', ChipType.amber),
      _ => ('已上架', ChipType.moss),
    };
  }

  /// 状态对应顶栏底色
  Color _tintOf(Map<String, dynamic> c) {
    final status = _statusOf(c);
    final audit = _auditOf(c);
    if (status == 0) return AppColors.amberSoftOf(context);
    return switch (audit) {
      1 => AppColors.indigoSoftOf(context),
      3 => AppColors.vermilionSoftOf(context),
      4 => AppColors.paper2Of(context),
      _ => AppColors.mossTintOf(context),
    };
  }

  String _diffLabel(int? difficulty) {
    return switch (difficulty) {
      1 => '简单',
      2 => '标准',
      3 => '困难',
      _ => '未设难度',
    };
  }

  (Color, Color) _diffColor(int? difficulty) {
    return switch (difficulty) {
      1 => (AppColors.surfaceOf(context), AppColors.primaryOf(context)),
      2 => (AppColors.surfaceOf(context), AppColors.indigoOf(context)),
      3 => (AppColors.surfaceOf(context), AppColors.vermilionOf(context)),
      _ => (AppColors.ruleSoftOf(context), AppColors.text3Of(context)),
    };
  }

  String _fmtTime(Object? raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '';
    final t = DateTime.tryParse(s);
    if (t == null) return '';
    final local = t.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(local.month)}-${p(local.day)} ${p(local.hour)}:${p(local.minute)}';
  }

  /// 继续编辑（进入配置台回填）
  Future<void> _edit(Map<String, dynamic> c) async {
    final id = (c['id'] as num?)?.toInt();
    if (id == null) return;
    if (_scope == 1) {
      // 全部病例 -> 公开预览
      await _previewPublic(id);
      return;
    }
    await context.pushNamed(RouteNames.spConfig, extra: {'caseId': id});
    if (mounted) _load();
  }

  /// 公开预览他人病例
  Future<void> _previewPublic(int id) async {
    AppFeedback.showLoading(context);
    final detail = await TeacherService().getPublicCasePreview(id);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (detail == null) {
      AppFeedback.error(context, '病例加载失败');
      return;
    }
    final title = detail['title']?.toString() ?? '（未命名病例）';
    final dept = detail['department']?.toString() ?? '';
    final diff = switch (detail['difficulty'] as int?) {
      1 => '简单', 2 => '标准', 3 => '困难', _ => '未设',
    };
    final caseNo = detail['caseNo']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        scrollable: true,
        title: Text(
          caseNo.isEmpty ? '病例详情' : '病例 $caseNo',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: AppColors.textOf(context), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (dept.isNotEmpty) MonoText(dept, fontSize: 12, color: AppColors.text3Of(context)),
            const SizedBox(height: 4),
            MonoText('难度：$diff', fontSize: 12, color: AppColors.text3Of(context)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOf(context)),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 新建（空白表单，返回后刷新列表，确保新草稿立即出现在草稿箱）
  Future<void> _create() async {
    await context.pushNamed(RouteNames.spConfig);
    if (mounted) _load();
  }

  /// 发布草稿到病例中心
  Future<void> _publish(Map<String, dynamic> c) async {
    final id = (c['id'] as num?)?.toInt();
    if (id == null) return;
    final title = c['title']?.toString() ?? '该病例';
    final isReject = _auditOf(c) == 3;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text(
          isReject ? '重新提交审核' : '发布到病例中心',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          isReject
              ? '确认重新提交「$title」？\n将再次提交管理员审核，通过后学生可引用。'
              : '确认发布「$title」？\n发布后将提交管理员审核，审核通过后学生可引用。',
          style: TextStyle(fontSize: 13.5, color: AppColors.text2Of(context), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: AppColors.text3Of(context))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOf(context)),
            child: const Text('确认发布'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await TeacherService().publishCaseToMarket(id);
    if (!mounted) return;
    AppFeedback.success(context, ok ? '已提交审核' : '发布失败，请检查病例内容或稍后重试');
    if (ok) _load();
  }

  /// 删除草稿（仅草稿状态可删）
  Future<void> _delete(Map<String, dynamic> c) async {
    final id = (c['id'] as num?)?.toInt();
    if (id == null) return;
    final title = c['title']?.toString() ?? '该草稿';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('删除草稿', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          '确认删除草稿「$title」？删除后不可恢复。',
          style: TextStyle(fontSize: 13.5, color: AppColors.text2Of(context), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: AppColors.text3Of(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.vermilionOf(context))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await TeacherService().deleteCase(id);
    if (!mounted) return;
    AppFeedback.success(context, ok ? '已删除' : '删除失败，仅草稿可删除');
    if (ok) _load();
  }

  void _clearError() {
    _load();
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
              title: '病例管理',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: _scope == 0
                  ? InkWell(
                      onTap: _create,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOf(context),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: AppColors.onPrimaryOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              '新建 SP 病例',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onPrimaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
            if (_scope == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '这里管理你创建的 SP 模拟病例：人工填写或让 AI 生成草稿，完善后发布审核，通过后即可布置给学生。',
                  style: TextStyle(fontSize: 12, color: AppColors.text3Of(context), height: 1.5),
                ),
              ),
            _buildScopeBar(context),
            if (_scope == 0) _buildStats(),
            if (_scope == 0) _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error
                      ? _buildError()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(20, 4, 20,
                                    _scope == 0 ? 110 : 30),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) => _caseCard(_filtered[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  /// 双 Tab：我的病例 / 全部病例
  Widget _buildScopeBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: List.generate(2, (i) {
            final active = _scope == i;
            final label = i == 0 ? '我的病例' : '全部病例';
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchScope(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.surfaceOf(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: active ? AppShadow.lifted(context) : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? AppColors.primaryOf(context) : AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final counts = _counts;
    final items = <(IconData, Color, int, String)>[
      (Icons.edit_note_rounded, AppColors.amberOf(context), counts[0], _tabs[0]),
      (Icons.manage_search_rounded, AppColors.indigoOf(context), counts[1], _tabs[1]),
      (Icons.check_circle_outline_rounded, AppColors.moss, counts[2], _tabs[2]),
      (Icons.feedback_outlined, AppColors.vermilionOf(context), counts[3], _tabs[3]),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Row(
        children: items.map((it) {
          final (icon, color, count, label) = it;
          return Expanded(
            child: Column(
              children: [
                Icon(icon, size: 18, color: color.withValues(alpha: 0.9)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MonoText('$count', fontSize: 20, weight: FontWeight.w700, color: color, height: 1.0),
                  ],
                ),
                const SizedBox(height: 4),
                MonoText(label, fontSize: 10, color: AppColors.text3Of(context), letterSpacing: 0.08),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBar() {
    final counts = _counts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final active = i == _tab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.surfaceOf(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: active ? AppShadow.lifted(context) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? AppColors.primaryOf(context) : AppColors.text3Of(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.mossTintOf(context)
                              : AppColors.ruleSoftOf(context),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'JetBrainsMono',
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.primaryOf(context) : AppColors.text4Of(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.vermilionSoftOf(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded, size: 30, color: AppColors.vermilionOf(context)),
          ),
          const SizedBox(height: 14),
          const Text(
            '加载失败，请检查网络后重试',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _tabHints[_tab],
            style: TextStyle(fontSize: 12, color: AppColors.text3Of(context)),
          ),
          const SizedBox(height: 16),
          AppGhostButton(label: '重新加载', small: true, onPressed: _clearError),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final hint = _scope == 1
        ? '全部病例同步中，暂无数据。'
        : switch (_tab) {
      0 => '还没有草稿。点右上角「新建 SP 病例」开始创作，或先去病例广场引用一份再改造。',
      1 => '暂无审核中的病例，发布草稿后即可进入待审。',
      2 => '暂无已上架病例，审核通过的内容会展示在这里。',
      _ => '太棒了，没有被驳回的病例。',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _tab == 3
                  ? AppColors.mossTintOf(context)
                  : AppColors.paper2Of(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _tab == 3
                  ? Icons.verified_outlined
                  : _tab == 0
                      ? Icons.notes_rounded
                      : Icons.folder_open_rounded,
              size: 32,
              color: _tab == 3
                  ? AppColors.primaryOf(context)
                  : AppColors.text4Of(context),
            ),
          ),
          const SizedBox(height: 14),
          MonoText(_tabHints[_tab], fontSize: 10, letterSpacing: 0.1, color: AppColors.text4Of(context)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.text3Of(context), height: 1.6),
            ),
          ),
          if (_tab == 0) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              width: 200,
              child: AppGradientButton(
                label: '新建 SP 病例',
                color: AppColors.primaryOf(context),
                onPressed: _create,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caseCard(Map<String, dynamic> c) {
    final status = _statusOf(c);
    final audit = _auditOf(c);
    final rawTitle = c['title'];
    final title = rawTitle is String && rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : '（未命名病例）';
    final rawDept = c['department'];
    final dept = rawDept is String ? rawDept.trim() : '';
    final caseNo = c['caseNo']?.toString() ?? '';
    final diff = (c['difficulty'] as num?)?.toInt();
    final updated = _fmtTime(c['updatedAt'] ?? c['createdAt']);
    final (badgeLabel, badgeType) = _badgeOf(c);
    final tint = _tintOf(c);
    final (diffBg, diffFg) = _diffColor(diff);
    final isDraft = status == 0;
    final isReject = audit == 3;
    final referenceCount = (c['referenceCount'] as num?)?.toInt() ?? 0;
    final rating = (c['ratingAvg'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // —— 顶栏（状态色条：科室 + 状态 + 发布时间） ——
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: tint,
              border: Border(bottom: BorderSide(color: AppColors.surfaceEdgeOf(context))),
            ),
            child: Row(
              children: [
                if (caseNo.isNotEmpty) ...[
                  MonoText(caseNo, fontSize: 11, color: AppColors.text3Of(context), weight: FontWeight.w600),
                  const SizedBox(width: 8),
                ],
                if (dept.isNotEmpty) ...[
                  Icon(Icons.local_hospital_rounded, size: 14, color: AppColors.text3Of(context)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: MonoText(dept, fontSize: 11, color: AppColors.text3Of(context)),
                  ),
                ] else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 8),
                AppChip(label: badgeLabel, type: badgeType, fontSize: 10),
              ],
            ),
          ),
          // —— 主体 ——
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题（宋体）
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontFamilyFallback: const [
                      'Songti SC',
                      'STSong',
                      'Noto Serif CJK SC',
                      'Source Han Serif SC',
                      'sans-serif',
                    ],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                // 元信息：难度 / 引用 / 评分 / 更新时间
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diffBg,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.ruleSoftOf(context)),
                      ),
                      child: Text(
                        _diffLabel(diff),
                        style: TextStyle(fontSize: 10.5, fontFamily: 'JetBrainsMono', color: diffFg, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (referenceCount > 0) ...[
                      const Icon(Icons.alt_route_rounded, size: 13),
                      const SizedBox(width: 3),
                      MonoText('$referenceCount', fontSize: 11, weight: FontWeight.w600, color: AppColors.text2Of(context)),
                      const SizedBox(width: 10),
                    ],
                    if (rating > 0) ...[
                      Icon(Icons.star_rounded, size: 14, color: AppColors.amberOf(context)),
                      const SizedBox(width: 2),
                      MonoText(rating.toStringAsFixed(1), fontSize: 11, color: AppColors.amberOf(context), weight: FontWeight.w600),
                      const SizedBox(width: 10),
                    ],
                    const Spacer(),
                    if (updated.isNotEmpty)
                      MonoText(updated, fontSize: 10, color: AppColors.text4Of(context)),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.ruleSoftOf(context)),
                const SizedBox(height: 12),
                // —— 操作区 ——
                Row(
                  children: [
                    if (_scope == 1)
                      Expanded(
                        child: AppGhostButton(
                          label: '查看',
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          small: true,
                          fullWidth: true,
                          onPressed: () => _edit(c),
                        ),
                      )
                    else ...[
                      if (isReject)
                        Expanded(
                          child: AppGhostButton(
                            label: '编辑修正',
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            small: true,
                            fullWidth: true,
                            onPressed: () => _edit(c),
                          ),
                        )
                      else
                        Expanded(
                          child: AppGhostButton(
                            label: isDraft ? '继续编辑' : '二次编辑',
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            small: true,
                            fullWidth: true,
                            onPressed: () => _edit(c),
                          ),
                        ),
                      if (isDraft || isReject) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppPrimaryButton(
                            label: isReject ? '重新发布' : '发布',
                            icon: const Icon(Icons.send_rounded, size: 14),
                            small: true,
                            fullWidth: true,
                            onPressed: () => _publish(c),
                          ),
                        ),
                      ],
                      if (isDraft) ...[
                        const SizedBox(width: 8),
                        _IconAction(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.vermilionOf(context),
                          onTap: () => _delete(c),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标操作按钮（圆形）
class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.color, this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}