import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import 'practice_answer_screen.dart';
import 'reading_task_screen.dart';
import 'material_view_screen.dart';

/// 待办作业详情（组合任务包：任务项清单；存量单病例：直接问诊 + 提交大病历）
class TodoAssignmentDetailScreen extends ConsumerStatefulWidget {
  const TodoAssignmentDetailScreen({super.key, required this.instanceId});
  final int instanceId;

  @override
  ConsumerState<TodoAssignmentDetailScreen> createState() =>
      _TodoAssignmentDetailScreenState();
}

class _TodoAssignmentDetailScreenState
    extends ConsumerState<TodoAssignmentDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  final _recordCtl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _recordCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await StudentService().getAssignmentDetail(widget.instanceId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _recordCtl.text = detail?['medicalRecordText'] as String? ?? '';
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _items {
    return ((_detail?['items'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  bool get _isBundle => _items.isNotEmpty;

  int get _doneCount =>
      _items.where((it) => (it['status'] as num?)?.toInt() == 5).length;

  String _statusText(int? status) {
    switch (status) {
      case 0: return '未开始';
      case 1: return '进行中';
      case 2: return '已提交';
      case 3: return 'AI 批阅中';
      case 4: return '待复核';
      case 5: return '已完成';
      default: return '进行中';
    }
  }

  // ========= 存量：启动问诊 =========
  Future<void> _startSessionLegacy() async {
    final caseId = (_detail?['caseId'] as num?)?.toInt();
    if (caseId == null) {
      AppFeedback.info(context, '该作业未关联病例');
      return;
    }
    // 必须带 assignmentInstanceId，否则会话与作业实例无关联，
    // 问诊完成后本作业的任务项状态不会推进。
    context
        .pushNamed(
      RouteNames.chat,
      queryParameters: {
        'caseId': '$caseId',
        'assignmentInstanceId': '${widget.instanceId}',
      },
    )
        .then((_) {
      if (mounted) _load();
    });
  }

  // ========= 存量：提交大病历 =========
  Future<void> _submitRecordLegacy() async {
    if (_recordCtl.text.trim().isEmpty) {
      AppFeedback.info(context, '请先填写大病历内容');
      return;
    }
    setState(() => _submitting = true);
    final result = await StudentService().submitRecord(
      instanceId: widget.instanceId,
      medicalRecordText: _recordCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      AppFeedback.error(context, '提交失败，请稍后重试');
      return;
    }
    final passed = result['passed'] == true;
    AppFeedback.success(context, passed ? '提交成功，AI 批阅中' : '格式校验未通过，请修改后重试');
    _load();
  }

  // ========= 组合包：任务项操作 =========
  void _startCase(Map<String, dynamic> item) {
    final caseId = (item['caseId'] as num?)?.toInt();
    final itemProgressId = (item['itemId'] as num?)?.toInt();
    final progressId = (_progressIdOf(item) ?? itemProgressId);
    if (caseId == null) {
      AppFeedback.info(context, '该任务未关联病例');
      return;
    }
    context
        .pushNamed(
      RouteNames.chat,
      queryParameters: {
        'caseId': '$caseId',
        'assignmentInstanceId': '${widget.instanceId}',
        if (progressId != null) 'itemProgressId': '$progressId',
      },
    )
        .then((_) {
      if (mounted) _load();
    });
  }

  int? _progressIdOf(Map<String, dynamic> item) {
    // 组合包详情 items 由后端返回, 任务项进度ID 在 detail 接口以 item 状态对齐,
    // 这里通过服务端 items[].itemId 直接作为进度标识不可靠, 采用 detail 里额外字段
    final raw = item['progressId'] ?? item['itemProgressId'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  void _submitCaseRecord(Map<String, dynamic> item) {
    final itemProgressId = _progressIdOf(item) ?? (item['itemId'] as num?)?.toInt();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _RecordSheet(
        controller: _recordCtl,
        onSubmit: (text) => StudentService().submitRecord(
          instanceId: widget.instanceId,
          medicalRecordText: text,
          itemProgressId: itemProgressId,
        ),
      ),
    ).then((_) => _load());
  }

  void _startPractice(Map<String, dynamic> item) {
    final itemProgressId = _progressIdOf(item) ?? (item['itemId'] as num?)?.toInt();
    if (itemProgressId == null) {
      AppFeedback.info(context, '缺少任务项进度');
      return;
    }
    final questions = ((item['questions'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    if (questions.isEmpty) {
      AppFeedback.info(context, '该练习暂无题目');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeAnswerScreen(
          instanceId: widget.instanceId,
          itemProgressId: itemProgressId,
          questions: questions,
          title: item['title'] as String? ?? '基础练习',
        ),
      ),
    ).then((_) => _load());
  }

  void _openReading(Map<String, dynamic> item) {
    final itemProgressId = _progressIdOf(item) ?? (item['itemId'] as num?)?.toInt();
    if (itemProgressId == null) {
      AppFeedback.info(context, '缺少任务项进度');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingTaskScreen(
          instanceId: widget.instanceId,
          itemProgressId: itemProgressId,
          textbookTitle: item['textbookTitle'] as String? ?? '',
          textbookFileUrl: item['textbookFileUrl'] as String?,
          readingScope: item['readingScope'] as String? ?? '',
          initiallyCompleted: (item['status'] as num?)?.toInt() == 5,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '作业详情',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : d == null
                      ? const Center(child: Text('作业不存在'))
                      : _isBundle
                          ? _buildBundleDetail(d)
                          : _buildLegacyDetail(d),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 组合包详情 ----------
  Widget _buildBundleDetail(Map<String, dynamic> d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SerifText(d['assignmentTitle'] as String? ?? '未命名作业',
                        fontSize: 16, color: AppColors.textOf(context)),
                  ),
                  AppChip(
                    label: _doneCount == _items.length ? '已完成' : '${_doneCount}/${_items.length}',
                    type: _doneCount == _items.length ? ChipType.moss : ChipType.amber,
                  ),
                ],
              ),
              if (d['assignmentDescription'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  d['assignmentDescription'] as String,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.5, color: AppColors.text2Of(context)),
                ),
              ],
              if (d['deadline'] != null) ...[
                const SizedBox(height: 8),
                MonoText('截止 ${d['deadline']}', fontSize: 10.5,
                    color: AppColors.text3Of(context)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        EyebrowText('任务清单 · $_doneCount/${_items.length} 完成'),
        const SizedBox(height: 10),
        ..._items.asMap().entries.map((e) => _buildItemCard(e.key, e.value)),
      ],
    );
  }

  Widget _buildItemCard(int index, Map<String, dynamic> item) {
    final type = item['itemType'] as String? ?? 'CASE';
    final status = (item['status'] as num?)?.toInt() ?? 0;
    final done = status == 5;
    final score = item['score'] as num?;
    final (icon, color, bg) = switch (type) {
      'CASE' => (Icons.medical_services_outlined, AppColors.vermilionOf(context), AppColors.vermilionSoftOf(context)),
      'PRACTICE' => (Icons.quiz_outlined, AppColors.indigoOf(context), AppColors.indigoSoftOf(context)),
      'MATERIAL' => (Icons.attach_file_rounded, AppColors.moss3Of(context), AppColors.mossTintOf(context)),
      _ => (Icons.menu_book_outlined, AppColors.amberOf(context), AppColors.amberSoftOf(context)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String? ?? _typeLabel(type),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    MonoText(_subtitle(item), fontSize: 10,
                        color: AppColors.text3Of(context)),
                  ],
                ),
              ),
              AppChip(
                label: done && score != null
                    ? '${score.toStringAsFixed(0)}分'
                    : _statusText(status),
                type: done ? ChipType.moss : (status == 0 ? ChipType.default_ : ChipType.amber),
                fontSize: 10,
              ),
            ],
          ),
          if (!done) ...[
            const SizedBox(height: 12),
            const DottedDivider(),
            const SizedBox(height: 10),
            _buildItemActions(type, item),
          ],
        ],
      ),
    );
  }

  Widget _buildItemActions(String type, Map<String, dynamic> item) {
    switch (type) {
      case 'CASE':
        return Row(
          children: [
            Expanded(
              child: AppGhostButton(
                label: '开始问诊',
                icon: const Icon(Icons.forum_outlined, size: 13),
                small: true,
                fullWidth: true,
                onPressed: () => _startCase(item),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppPrimaryButton(
                label: '提交大病历',
                small: true,
                fullWidth: true,
                onPressed: () => _submitCaseRecord(item),
              ),
            ),
          ],
        );
      case 'PRACTICE':
        return Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                label: '开始作答',
                icon: const Icon(Icons.edit_note_rounded, size: 13),
                small: true,
                fullWidth: true,
                onPressed: () => _startPractice(item),
              ),
            ),
          ],
        );
      case 'READING':
        return Row(
          children: [
            Expanded(
              child: AppGhostButton(
                label: '查看任务',
                icon: const Icon(Icons.auto_stories_outlined, size: 13),
                small: true,
                fullWidth: true,
                onPressed: () => _openReading(item),
              ),
            ),
          ],
        );
      case 'MATERIAL':
        return Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                label: '查看资料',
                icon: const Icon(Icons.attach_file_rounded, size: 13),
                small: true,
                fullWidth: true,
                onPressed: () => _openMaterial(item),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 打开资料附件（pdf/图片进阅读器，mp4/mp3 内建播放）
  void _openMaterial(Map<String, dynamic> item) {
    final url = (item['materialFileUrl'] as String?) ?? '';
    if (url.isEmpty) {
      AppFeedback.info(context, '资料文件缺失，请联系老师');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaterialViewScreen(
          title: (item['title'] as String?)?.isNotEmpty == true
              ? item['title'] as String
              : (item['materialTitle'] as String? ?? '学习资料'),
          fileUrl: url,
          materialType: (item['materialType'] as String?) ?? '',
        ),
      ),
    ).then((_) => _load());
  }

  String _subtitle(Map<String, dynamic> item) {
    switch (item['itemType'] as String? ?? '') {
      case 'CASE':
        return '${item['caseTitle'] ?? ''}${item['department'] != null ? ' · ${item['department']}' : ''}';
      case 'PRACTICE':
        final qCount = item['questions'] == null
            ? (item['questionCount'] ?? 0)
            : (item['questions'] as List<dynamic>?)?.length ?? 0;
        return '共 $qCount 题 · 客观题自动判分';
      case 'READING':
        final scope = (item['readingScope'] as String?) ?? '';
        final book = (item['textbookTitle'] as String?) ?? '';
        return '${book}${scope.isNotEmpty ? ' · $scope' : ''}';
      case 'MATERIAL':
        final type = ((item['materialType'] as String?) ?? '').toUpperCase();
        return '${item['materialTitle'] ?? ''}${type.isNotEmpty ? ' · $type' : ''}';
      default:
        return '';
    }
  }

  String _typeLabel(String type) {
    return switch (type) {
      'CASE' => 'SP 病例问诊',
      'PRACTICE' => '基础练习',
      'MATERIAL' => '学习资料',
      _ => '阅读任务',
    };
  }

  // ---------- 存量详情 ----------
  Widget _buildLegacyDetail(Map<String, dynamic> d) {
    final status = d['status'] as int? ?? 0;
    final submitted = d['submitted'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SerifText(d['assignmentTitle'] as String? ?? '未命名作业',
                        fontSize: 16, color: AppColors.textOf(context)),
                  ),
                  AppChip(label: _statusText(status), type: ChipType.amber),
                ],
              ),
              const SizedBox(height: 8),
              if (d['assignmentDescription'] != null)
                Text(
                  d['assignmentDescription'] as String,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.5, color: AppColors.text2Of(context)),
                ),
              const SizedBox(height: 12),
              _row('病例', d['caseTitle'] ?? '未分配'),
              if (d['department'] != null) _row('科室', d['department']),
              if (d['deadline'] != null) _row('截止时间', '${d['deadline']}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('问诊训练'),
        const SizedBox(height: 8),
        AppPrimaryButton(
          label: submitted ? '重新问诊' : '开始问诊',
          fullWidth: true,
          icon: const Icon(Icons.forum_outlined, size: 16),
          onPressed: _startSessionLegacy,
        ),
        const SizedBox(height: 20),
        _sectionTitle('提交大病历'),
        const SizedBox(height: 8),
        TextField(
          controller: _recordCtl,
          maxLines: 8,
          enabled: !submitted,
          style: TextStyle(color: AppColors.textOf(context)),
          decoration: InputDecoration(
            hintText: '请填写本次问诊整理的大病历内容…',
            hintStyle: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
            filled: true,
            fillColor: AppColors.surfaceOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!submitted)
          AppGhostButton(
            label: _submitting ? '提交中…' : '提交大病历',
            fullWidth: true,
            onPressed: _submitting ? null : _submitRecordLegacy,
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return SerifText(text, fontSize: 14, color: AppColors.textOf(context));
  }

  Widget _row(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(label, fontSize: 11, color: AppColors.text4Of(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$value',
                style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context))),
          ),
        ],
      ),
    );
  }
}

/// 大病历提交底部弹层
///
/// 独立 StatefulWidget 而非直接写在 builder 闭包里：bottomSheet 是独立路由，
/// 父页面 setState 不会重建它的内容，此前导致「提交中…」永不显示、按钮永不
/// 禁用，用户可连点多次造成重复提交。同时用 SingleChildScrollView 包裹，
/// 避免键盘弹出时底部溢出。
class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final Future<Map<String, dynamic>?> Function(String text) onSubmit;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      AppFeedback.info(context, '请先填写大病历内容');
      return;
    }
    setState(() => _submitting = true);
    final result = await widget.onSubmit(text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      AppFeedback.error(context, '提交失败，请稍后重试');
      return;
    }
    Navigator.of(context).pop();
    AppFeedback.success(
      context,
      result['passed'] == true
          ? '提交成功，AI 批阅中'
          : '格式校验未通过，请修改后重试',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
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
            SerifText('提交大病历', fontSize: 16),
            const SizedBox(height: 10),
            TextField(
              controller: widget.controller,
              maxLines: 6,
              // 必须显式给 color：const TextStyle 未指定颜色时 Flutter 用默认
              // 黑色，深色模式下输入框文字完全不可见。
              style: TextStyle(fontSize: 13, color: AppColors.textOf(context)),
              decoration: InputDecoration(
                hintText: '请填写本次问诊整理的大病历内容…',
                hintStyle:
                    TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
                filled: true,
                fillColor: AppColors.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide:
                      BorderSide(color: AppColors.primaryOf(context), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: _submitting ? '提交中…' : '提交',
              fullWidth: true,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
