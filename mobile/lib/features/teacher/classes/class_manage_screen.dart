import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 班级管理 · 我的教学班
///
/// 班级管理 tab 下的首页：列出当前教师可见的所有班级（自建 + 授权）。
/// - 「新建班级」生成邀请码，学生扫码/输码加入；
/// - 每个班级点击进入 ClassDetailScreen；
/// - 长按弹出管理面板（对齐备课交互）：重命名 / 扫码加入 / 成员 / 多选管理 / 排序调整 / 解散；
/// - 「多选管理」批量解散；「排序调整」按住拖动调整上下位置并持久化。
class ClassManageScreen extends ConsumerStatefulWidget {
  const ClassManageScreen({super.key});

  @override
  ConsumerState<ClassManageScreen> createState() => _ClassManageScreenState();
}

class _ClassManageScreenState extends ConsumerState<ClassManageScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  bool _multiSelect = false;
  bool _dragMode = false;
  bool _busy = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> data = [];
    try {
      data = await TeacherService().getMyClasses();
    } catch (e) {
      debugPrint('loadClasses error: $e');
    }
    if (!mounted) return;
    setState(() {
      _classes = data;
      _isLoading = false;
    });
  }

  int _clsId(Map<String, dynamic> c) => (c['id'] as num?)?.toInt() ?? 0;
  bool _owned(Map<String, dynamic> c) =>
      (c['teacherId'] as num?)?.toInt() != null;
  String _inviteCode(Map<String, dynamic> c) =>
      (c['inviteCode'] as String?)?.trim() ?? '';
  String _clsName(Map<String, dynamic> c) =>
      (c['name'] as String?)?.trim() ?? '未命名班级';

  void _enterMultiSelect() => setState(() {
        _dragMode = false;
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

  // ========= 新建班级 =========
  Future<void> _createClass() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('新建班级'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '请输入班级名称，如：2024 级内科 3 班',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    final loading = AppFeedback.showLoading(context, label: '创建中…');
    final result = await TeacherService().createClass({'name': name});
    loading();
    if (!mounted) return;
    if (result == null) {
      AppFeedback.error(context, '创建失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '班级已创建，可长按班级邀请学生加入');
    _load();
    await _showManageSheet(result);
  }

  // ========= 长按管理面板（对齐备课交互） =========
  Future<void> _showManageSheet(Map<String, dynamic> cls) async {
    final id = _clsId(cls);
    if (id == 0) return;
    final name = _clsName(cls);
    final owned = _owned(cls);
    final inviteCode = _inviteCode(cls);

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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context),
                      ),
                    ),
                  ),
                  if (inviteCode.isNotEmpty)
                    Text('邀请码 · $inviteCode',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.text3Of(context))),
                ],
              ),
            ),
            Divider(height: 16, color: AppColors.ruleOf(context)),
            _manageTile(ctx, Icons.qr_code_2_rounded, '扫码/邀请码加入',
                () => Navigator.pop(ctx, 'invite')),
            _manageTile(ctx, Icons.people_alt_outlined, '成员管理',
                () => Navigator.pop(ctx, 'members')),
            if (owned) ...[
              _manageTile(ctx, Icons.drive_file_rename_outline, '重命名',
                  () => Navigator.pop(ctx, 'rename')),
            ],
            _manageTile(ctx, Icons.library_add_outlined, '多选管理（批量解散）',
                () => Navigator.pop(ctx, 'multi')),
            _manageTile(ctx, Icons.drag_handle_rounded, '排序调整（按住拖动）',
                () => Navigator.pop(ctx, 'sort')),
            if (owned)
              _manageTile(ctx, Icons.delete_outline, '解散班级',
                  () => Navigator.pop(ctx, 'dissolve'),
                  danger: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'invite':
        await _invite(cls);
        break;
      case 'members':
        await _members(cls);
        break;
      case 'rename':
        await _renameClass(cls);
        break;
      case 'multi':
        if (mounted) _enterMultiSelect();
        break;
      case 'sort':
        if (mounted) _enterDragMode();
        break;
      case 'dissolve':
        await _dissolveClass(cls);
        break;
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

  // ========= 具体操作 =========
  Future<void> _invite(Map<String, dynamic> cls) async {
    final id = _clsId(cls);
    if (id == 0) return;
    context.pushNamed(
      RouteNames.classInvite,
      extra: {'className': _clsName(cls), 'inviteCode': _inviteCode(cls)},
      pathParameters: {'id': '$id'},
    );
  }

  Future<void> _members(Map<String, dynamic> cls) async {
    final id = _clsId(cls);
    if (id == 0) return;
    context.pushNamed(
      RouteNames.classMembers,
      extra: {'className': _clsName(cls)},
      pathParameters: {'id': '$id'},
    );
  }

  Future<void> _renameClass(Map<String, dynamic> cls) async {
    final id = _clsId(cls);
    if (id == 0) return;
    final controller =
        TextEditingController(text: (cls['name'] as String?)?.trim() ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('重命名班级'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '请输入新的班级名称',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == _clsName(cls)) return;
    final loading = AppFeedback.showLoading(context, label: '保存中…');
    final done = await TeacherService().renameClass(id, {'name': newName});
    loading();
    if (!mounted) return;
    if (!done) {
      AppFeedback.error(context, '重命名失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '班级名称已更新');
    _load();
  }

  Future<void> _dissolveClass(Map<String, dynamic> cls) async {
    final id = _clsId(cls);
    if (id == 0) return;
    final name = _clsName(cls);
    final ok = await AppFeedback.confirm(
      context,
      title: '解散班级',
      content: '解散后学生将退出该班级，不可恢复。确定解散「$name」吗？',
      confirmText: '解散',
      danger: true,
    );
    if (!ok || !mounted) return;
    final loading = AppFeedback.showLoading(context, label: '解散中…');
    final done = await TeacherService().dissolveClass(id);
    loading();
    if (!mounted) return;
    if (!done) {
      AppFeedback.error(context, '解散失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '班级已解散');
    _load();
  }

  // ========= 批量（多选）解散 =========
  Future<void> _batchDissolveSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('批量解散'),
        content: Text(
            '确定解散选中的 ${_selectedIds.length} 个班级吗？解散后学生将退出，不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.vermilionOf(context)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('解散'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    var failed = 0;
    for (final id in _selectedIds.toList()) {
      final ok = await TeacherService().dissolveClass(id);
      if (!ok) failed++;
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failed == 0) {
      AppFeedback.success(context, '已解散 ${_selectedIds.length} 个班级');
      _exitMultiSelect();
    } else {
      AppFeedback.error(context, '$failed 个班级解散失败');
    }
    _load();
  }

  // ========= 拖动排序 =========
  Future<void> _saveOrder() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await TeacherService().sortClasses(_classes.map(_clsId).toList());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppFeedback.success(context, '排序已保存');
      _dragMode = false;
    } else {
      AppFeedback.error(context, '排序保存失败，请重试');
    }
  }

  // ========= UI =========
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
                tag: '教师端 · 班级管理',
                title: '我的教学班',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppPrimaryButton(
                      label: '新建班级',
                      small: true,
                      onPressed: _createClass,
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      label: '发放作业',
                      small: true,
                      onPressed: () =>
                          context.pushNamed(RouteNames.assignmentCreate),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? _emptyState()
                      : _dragMode
                          ? ReorderableListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 6, 20, 80),
                              itemCount: _classes.length,
                              onReorder: (oldI, newI) => setState(() {
                                if (newI > oldI) newI--;
                                final item = _classes.removeAt(oldI);
                                _classes.insert(newI, item);
                              }),
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, i) => Padding(
                                key: ValueKey(_clsId(_classes[i])),
                                padding:
                                    EdgeInsets.only(top: i > 0 ? 12 : 0),
                                child: _dragCard(_classes[i]),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 6, 20, 80),
                              itemCount: _classes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  _classCard(_classes[i]),
                            ),
            ),
            if (_multiSelect) _buildMultiSelectTools(),
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

  Widget _buildMultiSelectBar() {
    final allSelected =
        _classes.isNotEmpty && _selectedIds.length == _classes.length;
    return AppTitleAppBar(
      tag: '管理',
      title: '已选 ${_selectedIds.length} 个',
      onBack: _exitMultiSelect,
      action: TextButton(
        onPressed: allSelected
            ? () => setState(() => _selectedIds.clear())
            : () => setState(() =>
                _selectedIds.addAll(_classes.map(_clsId))),
        child: Text(allSelected ? '全不选' : '全选',
            style:
                TextStyle(fontSize: 12.5, color: AppColors.primaryOf(context))),
      ),
    );
  }

  Widget _buildMultiSelectTools() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20,
          MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppGhostButton(
              label: '排序调整',
              icon: const Icon(Icons.drag_handle_rounded, size: 15),
              small: true,
              fullWidth: true,
              onPressed: _selectedIds.isEmpty ? null : () {
                _exitMultiSelect();
                if (mounted) _enterDragMode();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppPrimaryButton(
              label: _busy ? '处理中…' : '解散 (${_selectedIds.length})',
              icon: const Icon(Icons.delete_outline, size: 15),
              small: true,
              fullWidth: true,
              onPressed: _selectedIds.isEmpty ? null : _batchDissolveSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('暂无教学班级',
              style:
                  TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 4),
          Text('点击「新建班级」创建，学生凭邀请码即可加入',
              style:
                  TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: '新建班级',
            onPressed: _createClass,
          ),
        ],
      ),
    );
  }

  Widget _classCard(Map<String, dynamic> cls) {
    final id = _clsId(cls);
    final name = _clsName(cls);
    final studentCount = (cls['studentCount'] as num?)?.toInt();
    final inviteCode = _inviteCode(cls);
    final owned = _owned(cls);
    final selected = _selectedIds.contains(id);
    final sub = studentCount != null
        ? '$studentCount 名学生'
        : '作业 · 学情 · 资料';

    return GestureDetector(
      onTap: _multiSelect
          ? id == 0
              ? null
              : () => _toggleSelect(id)
          : id == 0
              ? null
              : () => context.pushNamed(
                    RouteNames.classDetail,
                    extra: {'className': name},
                    pathParameters: {'id': '$id'},
                  ),
      onLongPress: _multiSelect
          ? id == 0
              ? null
              : () => _toggleSelect(id)
          : id == 0
              ? null
              : () => _showManageSheet(cls),
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
                color: AppColors.indigoSoftOf(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.school_outlined,
                  size: 20, color: AppColors.indigoOf(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: SerifText(name,
                            fontSize: 15, color: AppColors.textOf(context)),
                      ),
                      if (owned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.mossTintOf(context),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text('我创建',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primaryOf(context))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text3Of(context))),
                  if (inviteCode.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('邀请码 · $inviteCode',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.text4Of(context))),
                  ],
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
                      ? Icon(Icons.check_rounded,
                          size: 15, color: AppColors.onPrimaryOf(context))
                      : null,
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  /// 拖动排序用卡片：点击无动作，长按/手柄拖动
  Widget _dragCard(Map<String, dynamic> cls) {
    final name = _clsName(cls);
    final studentCount = (cls['studentCount'] as num?)?.toInt();
    final inviteCode = _inviteCode(cls);
    final owned = _owned(cls);
    final sub = studentCount != null
        ? '$studentCount 名学生'
        : '作业 · 学情 · 资料';
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
              color: AppColors.indigoSoftOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.school_outlined,
                size: 20, color: AppColors.indigoOf(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: SerifText(name,
                          fontSize: 15, color: AppColors.textOf(context)),
                    ),
                    if (owned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.mossTintOf(context),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text('我创建',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.primaryOf(context))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.text3Of(context))),
                if (inviteCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('邀请码 · $inviteCode',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.text4Of(context))),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ReorderableDragStartListener(
            index: _classes.indexWhere((c) => _clsId(c) == _clsId(cls)),
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