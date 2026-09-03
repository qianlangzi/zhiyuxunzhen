import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/student_service.dart';

/// 学生·批阅申诉（P2-1）
///
/// 学生查看「我发起的申诉」列表，可对已出批阅结果的作业发起申诉；
/// 教师处理后回填回复与状态，学生在列表内查看进展。
class StudentAppealsScreen extends ConsumerStatefulWidget {
  const StudentAppealsScreen({super.key});

  @override
  ConsumerState<StudentAppealsScreen> createState() =>
      _StudentAppealsScreenState();
}

class _StudentAppealsScreenState extends ConsumerState<StudentAppealsScreen> {
  List<Map<String, dynamic>> _appeals = [];
  bool _loading = true;
  int? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<dynamic>? list;
    try {
      list = await StudentService().myAppeals();
    } catch (e) {
      debugPrint('loadAppeals error: $e');
      list = null;
    }
    if (!mounted) return;
    final items = (list ?? [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    setState(() {
      _appeals = items;
      _loading = false;
    });
  }

  Future<void> _openCreateSheet() async {
    final selected = await _pickReviewedAssignment();
    if (!mounted || selected == null) return;
    final reason = await _reasonSheet(selected);
    if (!mounted || reason == null) return;
    final instanceId = selected['instanceId'] as num?;

    // 收集待申诉的目标实例，仅含已出批阅结果的作业
    if (instanceId == null) {
      return;
    }
    int? newId;
    try {
      newId = await StudentService().createAppeal(
        instanceId: instanceId.toInt(),
        reason: reason,
      );
    } catch (e) {
      debugPrint('createAppeal error: $e');
      newId = null;
    }
    if (!mounted) return;
    if (newId == null) {
      AppFeedback.error(context, '发起申诉失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '申诉已提交，等待教师处理');
    _load();
  }

  /// 从「我的作业」中挑选已出批阅结果的作业作为申诉目标
  Future<Map<String, dynamic>?> _pickReviewedAssignment() async {
    List<dynamic>? candidates = [];
    try {
      final page = await StudentService().getMyAssignments(pageNum: 1, pageSize: 50);
      final records = page?['records'];
      if (records is List) candidates = records;
    } catch (e) {
      debugPrint('loadAssignments error: $e');
    }
    final reviewed = (candidates ?? <dynamic>[])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((m) {
          final status = (m['status'] as num?)?.toInt() ?? 0;
          return status >= 3 || m['score'] != null;
        })
        .toList();
    if (reviewed.isEmpty) {
      if (!mounted) return null;
      AppFeedback.error(context, '暂无可申诉的已批阅作业');
      return null;
    }
    if (!mounted) return null;
    int? picked;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.ruleOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SerifText('选择要申诉的作业', fontSize: 17),
                  ),
                  AppChip(label: '已批阅', type: ChipType.moss, fontSize: 10),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: reviewed.asMap().entries.map((e) {
                  final m = e.value;
                  final id = (m['instanceId'] as num?)?.toInt();
                  final title = m['assignmentTitle'] as String? ?? '作业';
                  final score = m['score'];
                  return ListTile(
                    leading: Icon(Icons.assignment_outlined,
                        color: AppColors.primaryOf(context)),
                    title: Text(title, style: const TextStyle(fontSize: 13)),
                    subtitle: MonoText(
                      '实例 #$id' +
                          (score != null ? ' · 得分 $score' : ''),
                      fontSize: 10,
                      color: AppColors.text3Of(context),
                    ),
                    onTap: () {
                      picked = id;
                      Navigator.pop(ctx, picked);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return null;
    return {'instanceId': picked};
  }

  Future<String?> _reasonSheet(Map<String, dynamic> selected) async {
    final ctl = TextEditingController();
    String? reason;
    final instanceId = (selected['instanceId'] as num?)?.toInt();
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SerifText('发起批阅申诉', fontSize: 17),
              const SizedBox(height: 4),
              MonoText('实例 #$instanceId — 请简述你认为批阅有误的理由',
                  fontSize: 11, color: AppColors.text3Of(context)),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                maxLines: 5,
                minLines: 4,
                style: const TextStyle(fontSize: 13, height: 1.6),
                decoration: InputDecoration(
                  hintText: '例如：此处判定与教材/实际作答不符，请复核……',
                  filled: true,
                  fillColor: AppColors.surfaceOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.ruleOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.ruleOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.indigoOf(context), width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: '提交申诉',
                  onPressed: () {
                    final v = ctl.text.trim();
                    if (v.isEmpty) {
                      AppFeedback.error(ctx, '请填写申诉理由');
                      return;
                    }
                    reason = v;
                    Navigator.pop(ctx, v);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return reason;
  }

  (String, ChipType) _statusMeta(int s) {
    return switch (s) {
      1 => ('已处理', ChipType.moss),
      2 => ('已驳回', ChipType.vermilion),
      _ => ('待处理', ChipType.amber),
    };
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
              title: '批阅申诉',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.studentHome),
              action: AppGhostButton(
                label: '发起申诉',
                small: true,
                onPressed: _openCreateSheet,
              ),
            ),
            _buildFilterBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _appeals.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _appeals.length,
                          itemBuilder: (_, i) => _buildCard(_appeals[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = const {
      null: '全部',
      0: '待处理',
      1: '已处理',
      2: '已驳回',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.entries.map((e) {
          final active = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryOf(context)
                      : AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? AppColors.primaryOf(context)
                        : AppColors.ruleOf(context),
                  ),
                ),
                child: MonoText(
                  e.value,
                  fontSize: 11,
                  color: active
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text3Of(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.ruleSoftOf(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined,
                size: 30, color: AppColors.text3Of(context)),
          ),
          const SizedBox(height: 16),
          SerifText('暂无申诉记录', fontSize: 15, color: AppColors.text2Of(context)),
          const SizedBox(height: 6),
          MonoText('对批阅结果有异议时，可发起申诉等待教师复核',
              fontSize: 11, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> m) {
    final status = (m['status'] as num?)?.toInt() ?? 0;
    final (label, chip) = _statusMeta(status);
    final title = m['assignmentTitle'] as String? ?? '作业';
    final reason = m['reason'] as String? ?? '';
    final reply = m['reply'] as String? ?? '';
    final score = m['totalScore'];
    final createdAt = m['createdAt'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            children: [
              Expanded(
                child: SerifText(title, fontSize: 13),
              ),
              AppChip(label: label, type: chip, fontSize: 10),
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 4),
            MonoText('当前得分 · $score / 100',
                fontSize: 10, color: AppColors.text3Of(context)),
          ],
          const SizedBox(height: 10),
          Text(reason,
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textOf(context))),
          if (_filter != null && _filter != m['status'])
            const SizedBox.shrink()
          else ...[
            if (reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mossTintOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text('教师回复：$reply',
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppColors.moss)),
              ),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              MonoText('发起于 $createdAt',
                  fontSize: 9, color: AppColors.text4Of(context)),
            ],
          ],
        ],
      ),
    );
  }
}