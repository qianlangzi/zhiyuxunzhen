import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 教师·批阅申诉处理（P2-1）
///
/// 展示本人布置作业收到的批阅申诉，待处理项可「改分并回复」或「驳回」，
/// 处理结果同步给学生端。
class TeacherAppealsScreen extends ConsumerStatefulWidget {
  const TeacherAppealsScreen({super.key});

  @override
  ConsumerState<TeacherAppealsScreen> createState() =>
      _TeacherAppealsScreenState();
}

class _TeacherAppealsScreenState extends ConsumerState<TeacherAppealsScreen> {
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
    List<Map<String, dynamic>> list = [];
    try {
      list = await TeacherService().getAppealList(status: _filter);
    } catch (e) {
      debugPrint('loadAppeals error: $e');
      list = [];
    }
    if (!mounted) return;
    setState(() {
      _appeals = list;
      _loading = false;
    });
  }

  void _selectFilter(int? v) {
    setState(() => _filter = v);
    _load();
  }

  Future<void> _handle(Map<String, dynamic> m) async {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return;
    final scoreCtl = TextEditingController();
    final replyCtl = TextEditingController();
    int? choice = 1; // 1 已处理(改分) 2 已驳回
    await showModalBottomSheet<void>(
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
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Column(
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
                SerifText('处理申诉', fontSize: 17),
                const SizedBox(height: 2),
                MonoText('${m['studentName'] ?? '学生'} · ${m['assignmentTitle'] ?? '作业'}',
                    fontSize: 11, color: AppColors.text3Of(context)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amberSoftOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(m['reason'] as String? ?? '',
                      style: TextStyle(
                          fontSize: 12, height: 1.6, color: AppColors.textOf(context))),
                ),
                const SizedBox(height: 12),
                // 处理方式选择
                Row(children: [
                  Expanded(
                    child: _choiceChip(ctx, '改分并回复', 1, choice, (v) {
                      setSheet(() => choice = v);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _choiceChip(ctx, '驳回', 2, choice, (v) {
                      setSheet(() => choice = v);
                    }),
                  ),
                ]),
                if (choice == 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const EyebrowText('新分数'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: scoreCtl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceOf(context),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(color: AppColors.ruleOf(context)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(color: AppColors.ruleOf(context)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      MonoText('/ 100', fontSize: 11, color: AppColors.text3Of(context)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const EyebrowText('处理说明/回复'),
                const SizedBox(height: 4),
                TextField(
                  controller: replyCtl,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(fontSize: 12.5, height: 1.6),
                  decoration: InputDecoration(
                    hintText: '给学生的处理回复（必填）',
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
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: '确认处理',
                    onPressed: () => _submit(ctx, id, choice!, scoreCtl, replyCtl),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(BuildContext ctx, String label, int value, int? current,
      ValueChanged<int> onTap) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (value == 2 ? AppColors.vermilionSoftOf(ctx) : AppColors.mossTintOf(ctx))
              : AppColors.surfaceOf(ctx),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: active
                ? (value == 2 ? AppColors.vermilionOf(context) : AppColors.moss)
                : AppColors.ruleOf(ctx),
          ),
        ),
        child: MonoText(label,
            fontSize: 11,
            color: active
                ? (value == 2 ? AppColors.vermilionOf(context) : AppColors.moss)
                : AppColors.text3Of(ctx)),
      ),
    );
  }

  Future<void> _submit(BuildContext ctx, int id, int choice,
      TextEditingController scoreCtl, TextEditingController replyCtl) async {
    final reply = replyCtl.text.trim();
    if (reply.isEmpty) {
      AppFeedback.error(ctx, '请填写处理回复');
      return;
    }
    double? newScore;
    if (choice == 1) {
      final s = double.tryParse(scoreCtl.text.trim());
      if (s == null || s < 0 || s > 100) {
        AppFeedback.error(ctx, '请输入 0~100 的新分数');
        return;
      }
      newScore = s;
    }
    bool ok;
    try {
      ok = await TeacherService().handleAppeal(
        id,
        status: choice,
        reply: reply,
        newScore: newScore,
      );
    } catch (e) {
      debugPrint('handleAppeal error: $e');
      ok = false;
    }
    if (!ctx.mounted) return;
    if (!ok) {
      AppFeedback.error(ctx, '处理失败，请稍后重试');
      return;
    }
    AppFeedback.success(ctx, choice == 2 ? '已驳回' : '已处理并改分');
    Navigator.pop(ctx);
    _load();
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
                  : context.goNamed(RouteNames.teacherHome),
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
    final filters = const {null: '全部', 0: '待处理', 1: '已处理', 2: '已驳回'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.entries.map((e) {
          final active = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectFilter(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                child: MonoText(e.value,
                    fontSize: 11,
                    color: active
                        ? AppColors.onPrimaryOf(context)
                        : AppColors.text3Of(context)),
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
          SerifText('暂无申诉', fontSize: 15, color: AppColors.text2Of(context)),
          const SizedBox(height: 6),
          MonoText('学生提交的批阅申诉会显示在这里',
              fontSize: 11, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> m) {
    final status = (m['status'] as num?)?.toInt() ?? 0;
    final (label, chip) = _statusMeta(status);
    final title = m['assignmentTitle'] as String? ?? '作业';
    final student = m['studentName'] as String? ?? '学生';
    final clazz = m['className'] as String? ?? '';
    final reason = m['reason'] as String? ?? '';
    final reply = m['reply'] as String? ?? '';
    final createdAt = m['createdAt'] as String? ?? '';
    final pending = status == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(
          color: pending ? AppColors.amberOf(context) : AppColors.surfaceEdgeOf(context),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SerifText(title, fontSize: 13),
                    const SizedBox(height: 2),
                    MonoText('$student${clazz.isEmpty ? '' : ' · $clazz'}',
                        fontSize: 10, color: AppColors.text3Of(context)),
                  ],
                ),
              ),
              AppChip(label: label, type: chip, fontSize: 10),
            ],
          ),
          const SizedBox(height: 10),
          Text(reason,
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textOf(context))),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            MonoText('回复：$reply', fontSize: 11, color: AppColors.moss),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            MonoText('提出于 $createdAt', fontSize: 9, color: AppColors.text4Of(context)),
          ],
          if (pending) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppGhostButton(
                  label: '处理',
                  small: true,
                  onPressed: () => _handle(m),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}