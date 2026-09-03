import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 教师端智能备课列表（Tab2 主页面）
/// 展示我的教案，支持新建；新建后进入 AI 对话式引导，生成教案后进入教案工作台。
class BprepScreen extends ConsumerStatefulWidget {
  const BprepScreen({super.key});

  @override
  ConsumerState<BprepScreen> createState() => _BprepScreenState();
}

class _BprepScreenState extends ConsumerState<BprepScreen> {
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;
  bool _multiSelect = false;
  bool _dragMode = false;
  final Set<int> _selectedIds = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final lessons = await TeacherService().getLessons();
    if (!mounted) return;
    setState(() {
      _lessons =
          (lessons ?? const []).whereType<Map<String, dynamic>>().toList();
      _isLoading = false;
    });
  }

  void _enterMultiSelect() => setState(() {
        _multiSelect = true;
        _selectedIds.clear();
      });

  void _exitMultiSelect() => setState(() {
        _multiSelect = false;
        _selectedIds.clear();
      });

  void _enterDragMode() => setState(() {
        _multiSelect = false;
        _dragMode = true;
      });

  void _toggleSelect(int id) => setState(() {
        if (!_selectedIds.add(id)) _selectedIds.remove(id);
      });

  int _lessonId(Map<String, dynamic> l) => (l['id'] as num?)?.toInt() ?? 0;

  // ========= 教案管理交互 =========

  /// 长按教案框 → 弹出管理面板（重命名/置顶/优先级/删除/多选合并）
  Future<void> _showManageSheet(Map<String, dynamic> lesson) async {
    final id = _lessonId(lesson);
    final title = (lesson['title'] as String?) ?? '未命名备课';
    final isTop = (lesson['isTop'] as num?)?.toInt() == 1;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.ruleOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOf(context)),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 16, color: AppColors.ruleOf(context)),
            _manageTile(ctx, Icons.drive_file_rename_outline, '重命名',
                () => Navigator.pop(ctx, 'rename')),
            _manageTile(
                ctx,
                isTop ? Icons.vertical_align_top : Icons.vertical_align_top,
                isTop ? '取消置顶' : '置顶',
                () => Navigator.pop(ctx, 'top')),
            _manageTile(ctx, Icons.sort_rounded, '设置优先级',
                () => Navigator.pop(ctx, 'priority')),
            _manageTile(ctx, Icons.library_add_outlined, '多选管理（批量删除 / 合并）',
                () => Navigator.pop(ctx, 'multi')),
            _manageTile(ctx, Icons.drag_handle_rounded, '排序调整（按住拖动）',
                () => Navigator.pop(ctx, 'sort')),
            _manageTile(ctx, Icons.delete_outline, '删除',
                () => Navigator.pop(ctx, 'delete'),
                danger: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'rename':
        await _renameLesson(id, title);
      case 'top':
        await _toggleTop(id, isTop);
      case 'priority':
        await _setPriority(id, (lesson['priority'] as num?)?.toInt() ?? 0);
      case 'multi':
        if (mounted) _enterMultiSelect();
      case 'sort':
        if (mounted) _enterDragMode();
      case 'delete':
        await _deleteSingle(id, title);
    }
  }

  Widget _manageTile(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(icon,
          size: 20,
          color: danger ? AppColors.vermilionOf(context) : AppColors.text2Of(context)),
      title: Text(label,
          style: TextStyle(
              fontSize: 13.5,
              color: danger ? AppColors.vermilionOf(context) : AppColors.textOf(context))),
      onTap: onTap,
    );
  }

  /// 重命名（通用标题输入对话框，合并功能也复用）
  Future<String?> _promptTitle(String text,
      {String? hint, required String buttonText}) async {
    final controller = TextEditingController(text: text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: Text(hint ?? '重命名教案'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
              hintText: '请输入教案标题', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(buttonText),
          ),
        ],
      ),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  Future<void> _renameLesson(int id, String title) async {
    final newTitle = await _promptTitle(title, hint: '重命名教案', buttonText: '保存');
    if (newTitle == null) return;
    final ok = await TeacherService().updateLesson(id, {'title': newTitle});
    if (mounted) {
      ok
          ? AppFeedback.success(context, '已重命名')
          : AppFeedback.error(context, '重命名失败');
      _load();
    }
  }

  Future<void> _toggleTop(int id, bool isTop) async {
    final plan = _lessons.where((l) => _lessonId(l) == id).firstOrNull;
    final title = (plan?['title'] as String?) ?? '未命名备课';
    final ok = await TeacherService()
        .updateLesson(id, {'title': title, 'isTop': isTop ? 0 : 1});
    if (mounted) {
      ok
          ? AppFeedback.success(context, isTop ? '已取消置顶' : '已置顶')
          : AppFeedback.error(context, '操作失败');
      _load();
    }
  }

  Future<void> _setPriority(int id, int current) async {
    int value = current;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ruleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SerifText('设置优先级', fontSize: 15),
                const SizedBox(height: 4),
                Text('数值越大越靠前，0 为默认',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.text3Of(context))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _priorityChip(value,
                        () => setSheetState(() => value = 0), 0),
                    _priorityChip(value,
                        () => setSheetState(() => value = 1), 1),
                    _priorityChip(value,
                        () => setSheetState(() => value = 2), 2),
                    _priorityChip(value,
                        () => setSheetState(() => value = 3), 3),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sort_rounded,
                                size: 16, color: AppColors.primaryOf(context)),
                            const SizedBox(width: 8),
                            Text('优先级 $value',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: '确定',
                  fullWidth: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final plan = _lessons.where((l) => _lessonId(l) == id).firstOrNull;
    final title = (plan?['title'] as String?) ?? '未命名备课';
    final saved = await TeacherService()
        .updateLesson(id, {'title': title, 'priority': value});
    if (mounted) {
      saved
          ? AppFeedback.success(context, '已设置优先级 $value')
          : AppFeedback.error(context, '设置失败');
      _load();
    }
  }

  Widget _priorityChip(int selected, VoidCallback onTap, int level) {
    final active = selected == level;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryOf(context)
                : AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active
                  ? AppColors.primaryOf(context)
                  : AppColors.ruleOf(context),
            ),
          ),
          child: Center(
            child: Text(
              'P$level',
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? AppColors.onPrimaryOf(context)
                    : AppColors.textOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSingle(int id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('删除教案'),
        content: Text('确定删除「$title」吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.vermilionOf(context)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await TeacherService().deleteLesson(id);
    if (mounted) {
      ok
          ? AppFeedback.success(context, '已删除')
          : AppFeedback.error(context, '删除失败');
      _load();
    }
  }

  /// 批量删除（多选模式）
  Future<void> _batchDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('批量删除'),
        content: Text('确定删除选中的 ${_selectedIds.length} 个教案吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.vermilionOf(context)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await TeacherService().batchDeleteLessons(_selectedIds.toList());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppFeedback.success(context, '已删除 ${_selectedIds.length} 个教案');
      _exitMultiSelect();
      _load();
    } else {
      AppFeedback.error(context, '批量删除失败');
    }
  }

  /// 智能合并（多选模式）：合并为一份，目标/重难点去重汇总，首个为基础载体
  Future<void> _mergeSelected() async {
    if (_selectedIds.length < 2) {
      AppFeedback.info(context, '合并需至少选择 2 个教案');
      return;
    }
    if (_busy) return;
    // 第一个被选中的教案作为基础载体，以其标题作为合并后的默认标题
    final ordered =
        _lessons.where((l) => _selectedIds.contains(_lessonId(l))).toList();
    final defaultTitle =
        (ordered.isNotEmpty ? (ordered.first['title'] as String?) : null) ??
            '合并教案';
    final title =
        await _promptTitle(defaultTitle, hint: '合并后的教案标题', buttonText: '合并');
    if (title == null) return;
    setState(() => _busy = true);
    final newId =
        await TeacherService().mergeLessons(_selectedIds.toList(), title);
    if (!mounted) return;
    setState(() => _busy = false);
    if (newId != null) {
      AppFeedback.success(context, '已合并为「$title」');
      _exitMultiSelect();
      _load();
      context
          .pushNamed(RouteNames.bprepDetail, pathParameters: {'id': '$newId'});
    } else {
      AppFeedback.error(context, '合并失败');
    }
  }

  /// 保存拖动排序（padding 底部已由 drag bar 覆盖）
  Future<void> _saveOrder() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await TeacherService().sortLessons(_lessons.map(_lessonId).toList());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppFeedback.success(context, '排序已保存');
      _dragMode = false;
    } else {
      AppFeedback.error(context, '排序保存失败，请重试');
    }
  }

  /// 新建备课包：弹出标题输入 → 创建 → 进入工作台
  Future<void> _createLesson() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('新建备课'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '如：心力衰竭诊疗教学',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final id = await TeacherService().createLesson({
      'title': title,
      'department': '',
      'targetGrade': '',
    });
    if (!mounted) return;
    if (id != null) {
      AppFeedback.success(context, '备课已创建，开始对话式备课');
      if (context.mounted) {
        context.pushNamed(RouteNames.bprepGuide, pathParameters: {'id': '$id'});
      }
      _load();
    } else {
      AppFeedback.error(context, '创建失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_dragMode)
              _buildDragBar()
            else if (_multiSelect)
              _buildMultiSelectBar()
            else
              AppTitleAppBar(
                tag: '智能备课',
                title: '我的教案',
                action: AppPrimaryButton(
                  label: '+ 新建备课',
                  small: true,
                  onPressed: _createLesson,
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _lessons.isEmpty
                      ? _buildEmpty()
                      : _dragMode
                          ? ReorderableListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 80),
                              itemCount: _lessons.length,
                              onReorder: (oldI, newI) => setState(() {
                                if (newI > oldI) newI--;
                                final item = _lessons.removeAt(oldI);
                                _lessons.insert(newI, item);
                              }),
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, i) => Padding(
                                key: ValueKey(_lessonId(_lessons[i])),
                                padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
                                child: _dragCard(_lessons[i]),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 8, 20, 12),
                                    itemCount: _lessons.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) =>
                                        _lessonCard(_lessons[i]),
                                  ),
                                ),
                                if (_multiSelect) _buildMultiSelectTools(),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  /// 拖动排序顶部栏：取消 / 完成
  Widget _buildDragBar() {
    return AppTitleAppBar(
      tag: '拖动排序',
      title: '按住右侧手柄调整顺序',
      onBack: () => setState(() => _dragMode = false),
      action: TextButton(
        onPressed: _busy ? null : _saveOrder,
        child: Text('完成',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _busy
                    ? AppColors.text4Of(context)
                    : AppColors.primaryOf(context))),
      ),
    );
  }

  /// 多选模式下顶部栏：取消 / 标题 / 全选
  Widget _buildMultiSelectBar() {
    final allSelected =
        _lessons.isNotEmpty && _selectedIds.length == _lessons.length;
    return AppTitleAppBar(
      tag: '管理',
      title: '已选 ${_selectedIds.length} 个',
      onBack: _exitMultiSelect,
      action: TextButton(
        onPressed: allSelected
            ? () => setState(() => _selectedIds.clear())
            : () =>
                setState(() => _selectedIds.addAll(_lessons.map(_lessonId))),
        child: Text(allSelected ? '全不选' : '全选',
            style:
                TextStyle(fontSize: 12.5, color: AppColors.primaryOf(context))),
      ),
    );
  }

  /// 多选模式下底部操作栏：合并 / 删除
  Widget _buildMultiSelectTools() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _busy
                ? AppGhostButton(
                    label: '处理中…',
                    small: true,
                    fullWidth: true,
                    onPressed: null,
                  )
                : AppGhostButton(
                    label: '智能合并',
                    icon: const Icon(Icons.merge_rounded, size: 15),
                    small: true,
                    fullWidth: true,
                    onPressed: _selectedIds.length < 2 ? null : _mergeSelected,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppPrimaryButton(
              label: _busy ? '处理中…' : '删除 (${_selectedIds.length})',
              icon: const Icon(Icons.delete_outline, size: 15),
              small: true,
              fullWidth: true,
              onPressed: _selectedIds.isEmpty ? null : _batchDeleteSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 52, color: AppColors.text4Of(context)),
          const SizedBox(height: 14),
          Text('还没有教案',
              style:
                  TextStyle(fontSize: 15, color: AppColors.text2Of(context))),
          const SizedBox(height: 6),
          Text('点击右上角「新建备课」，AI 对话确认需求后生成教案',
              style:
                  TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _createLesson,
            icon: const Icon(Icons.add),
            label: const Text('新建备课'),
          ),
        ],
      ),
    );
  }

  Widget _lessonCard(Map<String, dynamic> lesson) {
    final id = _lessonId(lesson);
    final title = (lesson['title'] as String?) ?? '未命名备课';
    final department = (lesson['department'] as String?) ?? '';
    final targetGrade = (lesson['targetGrade'] as String?) ?? '';
    final materialCount = (lesson['materialCount'] as num?)?.toInt() ?? 0;
    final caseId = lesson['caseId'];
    final status = (lesson['status'] as num?)?.toInt() ?? 0;
    final isTop = (lesson['isTop'] as num?)?.toInt() == 1;
    final priority = (lesson['priority'] as num?)?.toInt() ?? 0;
    final selected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: _multiSelect
          ? () => _toggleSelect(id)
          : () => context
              .pushNamed(RouteNames.bprepDetail, pathParameters: {'id': '$id'}),
      onLongPress: _multiSelect
          ? () => _toggleSelect(id)
          : () => _showManageSheet(lesson),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOf(context).withValues(alpha: 0.08)
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? AppColors.primaryOf(context)
                : AppColors.surfaceEdgeOf(context),
          ),
          boxShadow: selected ? null : AppShadow.card(context),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isTop
                    ? AppColors.vermilionOf(context).withValues(alpha: 0.12)
                    : AppColors.mossTintOf(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                  isTop ? Icons.push_pin_rounded : Icons.school_outlined,
                  size: 20,
                  color: isTop
                      ? AppColors.vermilionOf(context)
                      : AppColors.primaryOf(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isTop) ...[
                        Icon(Icons.push_pin_rounded,
                            size: 13, color: AppColors.vermilionOf(context)),
                        const SizedBox(width: 4),
                      ],
                      if (priority > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.amberOf(context).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text('P$priority',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amberOf(context))),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: SerifText(title,
                            fontSize: 15, color: AppColors.textOf(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (department.isNotEmpty) department,
                      if (targetGrade.isNotEmpty) targetGrade,
                      '$materialCount 份资料',
                      caseId != null ? '已关联病例' : '未关联病例',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.text3Of(context)),
                  ),
                ],
              ),
            ),
            if (_multiSelect)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.primaryOf(context)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryOf(context)
                          : AppColors.text4Of(context),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : null,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status == 1
                          ? AppColors.mossTintOf(context)
                          : AppColors.surfaceEdgeOf(context)
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(status == 1 ? '已生成教案' : '草稿',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: status == 1
                                ? AppColors.moss
                                : AppColors.text3Of(context))),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 16, color: AppColors.text4Of(context)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 拖动排序用卡片：长按/手柄拖动，内容与教案卡片一致但不可点击导航
  Widget _dragCard(Map<String, dynamic> lesson) {
    final id = _lessonId(lesson);
    final title = (lesson['title'] as String?) ?? '未命名备课';
    final department = (lesson['department'] as String?) ?? '';
    final targetGrade = (lesson['targetGrade'] as String?) ?? '';
    final materialCount = (lesson['materialCount'] as num?)?.toInt() ?? 0;
    final caseId = lesson['caseId'];
    final isTop = (lesson['isTop'] as num?)?.toInt() == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        boxShadow: AppShadow.card(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isTop
                  ? AppColors.vermilionOf(context).withValues(alpha: 0.12)
                  : AppColors.mossTintOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(isTop ? Icons.push_pin_rounded : Icons.school_outlined,
                size: 20,
                color:
                    isTop ? AppColors.vermilionOf(context) : AppColors.primaryOf(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isTop) ...[
                      Icon(Icons.push_pin_rounded,
                          size: 13, color: AppColors.vermilionOf(context)),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: SerifText(title,
                          fontSize: 15, color: AppColors.textOf(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (department.isNotEmpty) department,
                    if (targetGrade.isNotEmpty) targetGrade,
                    '$materialCount 份资料',
                    caseId != null ? '已关联病例' : '未关联病例',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: AppColors.text3Of(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ReorderableDragStartListener(
            index: _lessons.indexWhere((l) => _lessonId(l) == id),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.drag_handle_rounded,
                  size: 16, color: AppColors.primaryOf(context)),
            ),
          ),
        ],
      ),
    );
  }
}
