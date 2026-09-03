import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 题目审核状态（后端 adminAuditStatus）
enum QuestionStatus {
  draft('未提交', 0),
  pending('待审核', 1),
  approved('已通过', 2),
  rejected('已驳回', 3);

  const QuestionStatus(this.label, this.code);
  final String label;
  final int code;

  static QuestionStatus fromCode(dynamic code) {
    switch (code) {
      case 1:
        return pending;
      case 2:
        return approved;
      case 3:
        return rejected;
      case 0:
      default:
        return draft;
    }
  }
}

/// 审核状态筛选 chip（null 表示全部）
class _StatusFilter {
  const _StatusFilter(this.label, this.status);
  final String label;
  final int? status;
}

/// 教师端 · 我的基础题库：题目录入 + 提交审核 + 审核状态展示
class QuestionListScreen extends ConsumerStatefulWidget {
  const QuestionListScreen({super.key});

  @override
  ConsumerState<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends ConsumerState<QuestionListScreen> {
  static const _filters = [
    _StatusFilter('全部', null),
    _StatusFilter('未提交', 0),
    _StatusFilter('待审核', 1),
    _StatusFilter('已通过', 2),
    _StatusFilter('已驳回', 3),
  ];

  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  int? _activeStatus;
  int _scope = 0; // 0=我的题库 1=全部题库

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final Map<String, dynamic>? data = _scope == 0
        ? await TeacherService().getMyQuestions(
            pageSize: 100,
            adminAuditStatus: _activeStatus,
          )
        : await TeacherService().getAllQuestions(pageSize: 100);
    if (!mounted) return;
    setState(() {
      _list =
          (data?['records'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      _isLoading = false;
    });
  }

  void _switchScope(int scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _activeStatus = null;
      _isLoading = true;
    });
    _load();
  }

  /// 全部题库中查看他人题目（只读详情弹窗）
  Future<void> _viewPublic(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    AppFeedback.showLoading(context);
    final detail = await TeacherService().getPublicQuestion(id);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (detail == null) {
      AppFeedback.error(context, '题目加载失败');
      return;
    }
    final status = QuestionStatus.fromCode(detail['adminAuditStatus']);
    final options = (detail['options'] as List<dynamic>?)?.cast<String>() ?? [];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        scrollable: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                (item['questionNo'] as String?)?.isNotEmpty == true
                    ? '题号 ${item['questionNo']}'
                    : '题目详情',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            AppChip(label: status.label, type: ChipType.moss, fontSize: 10),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(detail['title']?.toString() ?? '（无题干）',
                style: TextStyle(fontSize: 14, color: AppColors.textOf(context), height: 1.5)),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < options.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: MonoText(
                    '${String.fromCharCode(65 + i)}. ${options[i]}',
                    fontSize: 12,
                    color: AppColors.text2Of(context),
                  ),
                ),
            ],
            if (detail['explanation'] is String && (detail['explanation'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('解析：${detail['explanation']}',
                  style: TextStyle(fontSize: 12, color: AppColors.text3Of(context), height: 1.5)),
            ],
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

  void _switchFilter(int? status) {
    if (_activeStatus == status) return;
    setState(() {
      _activeStatus = status;
      _isLoading = true;
    });
    _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    final ok = await AppFeedback.confirm(
      context,
      title: '删除题目',
      content: '确定删除该题目吗？删除后不可恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    final success = await TeacherService().deleteQuestion(id);
    if (!mounted) return;
    if (success) {
      AppFeedback.success(context, '题目已删除');
      _load();
    } else {
      AppFeedback.error(context, '删除失败，请重试');
    }
  }

  Widget _buildStatusTag(BuildContext context, Map<String, dynamic> item) {
    final status = QuestionStatus.fromCode(item['adminAuditStatus']);
    final chipType = switch (status) {
      QuestionStatus.draft => ChipType.default_,
      QuestionStatus.pending => ChipType.amber,
      QuestionStatus.approved => ChipType.moss,
      QuestionStatus.rejected => ChipType.vermilion,
    };
    return AppChip(label: status.label, type: chipType, fontSize: 10);
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
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: _scope == 0
                  ? AppIconButton(
                      icon: const Icon(Icons.add, size: 22),
                      onPressed: () async {
                        await context.pushNamed(RouteNames.teacherQuestionEdit, pathParameters: {'id': 'new'});
                        if (mounted) _load();
                      },
                    )
                  : null,
            ),
            _buildScopeBar(context),
            if (_scope == 0) _buildFilterBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? _buildEmpty(context)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                            itemCount: _list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) =>
                                _buildQuestionCard(context, _list[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: _filters.map((f) {
          final active = _activeStatus == f.status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _switchFilter(f.status),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                  border: Border.all(
                    color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: MonoText(
                  f.label,
                  fontSize: 12,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 双 Tab：全部题库 / 我的题库
  Widget _buildScopeBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: List.generate(2, (i) {
            final active = _scope == i;
            final label = i == 0 ? '我的题库' : '全部题库';
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

  Widget _buildEmpty(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Column(
              children: [
                Icon(Icons.queue_play_next_outlined,
                    size: 48, color: AppColors.text4Of(context)),
                const SizedBox(height: 12),
                SerifText(_scope == 0 ? '暂无题目' : '暂无全部题库题目',
                    fontSize: 15, color: AppColors.text2Of(context)),
                const SizedBox(height: 4),
                MonoText(_scope == 0
                    ? '点击右上角 + 录入第一道题目'
                    : '题库暂无已录入的题目',
                    fontSize: 11, color: AppColors.text4Of(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> item) {
    final id = (item['id'] as num).toInt();
    final status = QuestionStatus.fromCode(item['adminAuditStatus']);
    final title = item['title'] as String? ?? '（无题干）';
    final questionType = _questionTypeLabel(item['questionType'] as String?);
    final questionNo = item['questionNo'] as String?;
    final meta = [
      if (questionNo is String && questionNo.isNotEmpty) questionNo,
      if (item['department'] is String && (item['department'] as String).isNotEmpty)
        item['department'],
      if (item['knowledgeTag'] is String && (item['knowledgeTag'] as String).isNotEmpty)
        item['knowledgeTag'],
    ].join(' · ');
    final createdAt = _formatTime(item['createdAt']);
    // 仅"我的题库"中草稿 / 已驳回可删除
    final deletable = _scope == 0 &&
        (status == QuestionStatus.draft || status == QuestionStatus.rejected);
    final rejectReason = status == QuestionStatus.rejected
        ? (item['rejectReason'] as String?)
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (_scope == 1) {
          await _viewPublic(item);
          return;
        }
        await context.pushNamed(
          RouteNames.teacherQuestionEdit,
          pathParameters: {'id': '$id'},
        );
        if (mounted) _load();
      },
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusTag(context, item),
                const Spacer(),
                if (deletable)
                  GestureDetector(
                    onTap: () => _delete(item),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 15, color: AppColors.text4Of(context)),
                        const SizedBox(width: 2),
                        MonoText('删除', fontSize: 10, color: AppColors.text4Of(context)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SerifText(title, fontSize: 14, color: AppColors.textOf(context), weight: FontWeight.w600),
            const SizedBox(height: 8),
            MonoText(
              questionType,
              fontSize: 10,
              color: AppColors.primaryOf(context),
            ),
            const SizedBox(height: 4),
            if (meta.isNotEmpty)
              MonoText(meta, fontSize: 10, color: AppColors.text3Of(context)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: MonoText(
                    createdAt,
                    fontSize: 10,
                    color: AppColors.text4Of(context),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.text3Of(context)),
              ],
            ),
            if (rejectReason != null && rejectReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.vermilionSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 13, color: AppColors.vermilionOf(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MonoText(
                        '驳回：$rejectReason',
                        fontSize: 10,
                        color: AppColors.vermilionOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 题型中文映射
String _questionTypeLabel(String? type) {
  switch (type) {
    case 'single_choice':
      return '单选题';
    case 'multiple_choice':
      return '多选题';
    case 'judgment':
      return '判断题';
    case 'fill_blank':
      return '填空题';
    case 'essay':
    case 'short_answer':
    case 'subjective':
      return '简答/论述';
    default:
      return type ?? '题型';
  }
}

/// 时间格式化（兼容后端多种时间格式）
String _formatTime(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.isEmpty) return '';
  if (s.contains('T')) {
    return s.replaceFirst('T', ' ').split('.').first;
  }
  return s;
}