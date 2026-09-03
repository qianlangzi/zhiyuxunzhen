import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 教师端学情预警中心
/// 总览（风险等级分布）+ 预警学生列表 + 学生详情（规则明细 + AI 干预建议）
class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({super.key});

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// 立即触发学情预警全量扫描，随后刷新页面
  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    final ok = await TeacherService().scanAlert();
    if (!mounted) return;
    setState(() => _scanning = false);
    if (ok) {
      AppFeedback.success(context, '已触发扫描，数据刷新中，请稍候…');
      _load();
    } else {
      AppFeedback.error(context, '扫描失败，请稍后重试');
    }
  }

  Future<void> _load() async {
    final overview = await TeacherService().getAlertOverview();
    final alerts = await TeacherService().getAlertList();
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _alerts = (alerts ?? const []).whereType<Map<String, dynamic>>().toList();
      _isLoading = false;
    });
  }

  Future<void> _generateIntervention(int studentId) async {
    final data = await TeacherService().generateIntervention(studentId);
    if (!mounted) return;
    if (data != null) {
      AppFeedback.success(context, 'AI 干预建议已生成');
      _load();
    } else {
      AppFeedback.error(context, '生成失败，请重试');
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
            AppBackAppBar(
              title: '学情预警中心',
              onBack: () =>
                  context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      children: [
                        _buildOverview(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _sectionTitle('风险学生（${_alerts.length}）'),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _scanning ? null : _scan,
                              icon: _scanning
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 15),
                              label: Text(_scanning ? '扫描中…' : '立即扫描'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_alerts.isEmpty)
                          _emptyState()
                        else
                          ..._alerts.map((a) => _alertCard(a)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final o = _overview ?? const {};
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
          _overviewItem('高风险', (o['highCount'] as num?)?.toInt() ?? 0, AppColors.vermilionOf(context)),
          _divider(),
          _overviewItem('中风险', (o['mediumCount'] as num?)?.toInt() ?? 0, AppColors.amberOf(context)),
          _divider(),
          _overviewItem('低风险', (o['lowCount'] as num?)?.toInt() ?? 0, AppColors.text3Of(context)),
          _divider(),
          _overviewItem('待处理', (o['pendingCount'] as num?)?.toInt() ?? 0, AppColors.primaryOf(context)),
        ],
      ),
    );
  }

  Widget _overviewItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 4),
          MonoText(label, fontSize: 10, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 32, color: AppColors.surfaceEdgeOf(context));
  }

  Widget _sectionTitle(String title) {
    return SerifText(title, fontSize: 15, color: AppColors.textOf(context));
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 44, color: AppColors.moss),
          const SizedBox(height: 10),
          Text('暂无风险预警', style: TextStyle(fontSize: 14, color: AppColors.text2Of(context))),
          const SizedBox(height: 4),
          Text('预警需学生先产生学习行为（OSCE 问诊 / 完成作业）后，由系统扫描生成，',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
          const SizedBox(height: 4),
          Text('每日 8:00 自动扫描，也可点右上「立即扫描」手动触发',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 16),
            label: Text(_scanning ? '扫描中…' : '立即扫描'),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> a) {
    final level = (a['riskLevel'] as num?)?.toInt() ?? 2;
    final (Color color, String levelText) = switch (level) {
      3 => (AppColors.vermilionOf(context), '高风险'),
      2 => (AppColors.amberOf(context), '中风险'),
      _ => (AppColors.text3Of(context), '低风险'),
    };
    final type = _typeName((a['alertType'] as String?) ?? '');
    final name = (a['studentName'] as String?) ?? '学生';
    final time = (a['createdAt'] as String?) ?? '';
    final intervention = a['intervention'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(levelText,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$name · $type',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
              ),
              if (time.isNotEmpty)
                Text(time.length >= 10 ? time.substring(0, 10) : time,
                    style: TextStyle(fontSize: 10, color: AppColors.text4Of(context))),
            ],
          ),
          if (a['ruleDetail'] != null && '${a['ruleDetail']}' != '{}' && '${a['ruleDetail']}' != 'null') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgOf(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(_ruleSummary(a['ruleDetail'] as String?),
                  style: TextStyle(fontSize: 11, color: AppColors.text3Of(context), height: 1.5)),
            ),
          ],
          if (intervention != null && intervention.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('💡 AI 干预建议已生成，点击查看详情',
                  style: TextStyle(fontSize: 11, color: AppColors.moss)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _generateIntervention((a['studentId'] as num?)?.toInt() ?? 0),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('生成 AI 干预建议'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showDetail(a),
                child: const Text('查看详情'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 预警详情弹窗（规则明细 + 干预建议）
  void _showDetail(Map<String, dynamic> a) {
    final intervention = a['intervention'] as String?;
    Map<String, dynamic>? interventionMap;
    if (intervention != null && intervention.isNotEmpty) {
      try {
        interventionMap = jsonDecode(intervention) as Map<String, dynamic>;
      } catch (_) {}
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SerifText('${a['studentName'] ?? '学生'} · 预警详情',
                    fontSize: 16, color: AppColors.textOf(context)),
                const SizedBox(height: 12),
                Text('触发规则：${_typeName((a['alertType'] as String?) ?? '')}',
                    style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
                const SizedBox(height: 6),
                Text(_ruleSummary(a['ruleDetail'] as String?),
                    style: TextStyle(fontSize: 12, color: AppColors.text3Of(context), height: 1.5)),
                if (interventionMap != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  SerifText('AI 干预建议', fontSize: 15, color: AppColors.primaryOf(context)),
                  const SizedBox(height: 8),
                  if (interventionMap['riskSummary'] != null)
                    Text('${interventionMap['riskSummary']}',
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.text2Of(context), height: 1.5)),
                  const SizedBox(height: 8),
                  ...((interventionMap['interventions'] as List<dynamic>?) ?? const [])
                      .map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('· ${(i as Map)['action'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.text2Of(context), height: 1.4)),
                          )),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _typeName(String type) {
    return switch (type) {
      'osce_low' => 'OSCE 连续低分',
      'assignment_overdue' => '作业逾期',
      'daily_break' => '每日一例断档',
      'weakness_worsening' => '薄弱知识点持续',
      'behavior_abnormal' => '问诊行为异常',
      _ => type,
    };
  }

  String _ruleSummary(String? ruleJson) {
    if (ruleJson == null || ruleJson.isEmpty || ruleJson == '{}' || ruleJson == 'null') {
      return '规则明细：—';
    }
    try {
      final map = jsonDecode(ruleJson) as Map<String, dynamic>;
      final parts = <String>[];
      map.forEach((k, v) {
        if (v is List && v.isNotEmpty) {
          parts.add('$k: ${v.length} 项');
        } else if (v is num || v is String) {
          parts.add('$k: $v');
        }
      });
      return '规则明细：${parts.join('，')}';
    } catch (_) {
      return '规则明细：${ruleJson.substring(0, ruleJson.length > 100 ? 100 : ruleJson.length)}';
    }
  }
}
