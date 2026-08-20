import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/student_service.dart';

/// 临床思维树（独立全屏页面）
///
/// 数据来源：GET /api/v1/student/evaluations/{sessionId}/thinking-tree
/// 返回 ThinkingTreeVO：sessionId / totalExamCost / nodes / edges / socraticPrompt / currentStage
class ThinkingTreeScreen extends ConsumerStatefulWidget {
  const ThinkingTreeScreen({super.key});

  @override
  ConsumerState<ThinkingTreeScreen> createState() => _ThinkingTreeScreenState();
}

class _ThinkingTreeScreenState extends ConsumerState<ThinkingTreeScreen> {
  Map<String, dynamic>? _treeData;
  bool _isLoading = true;
  String? _errorMsg;

  /// 检查费用阈值（元）。超过即视为"超支"。
  static const double _costThreshold = 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTree());
  }

  Future<void> _loadTree() async {
    final state = GoRouterState.of(context);
    final qs = state.uri.queryParameters['sessionId'];
    final parsed = qs == null ? null : int.tryParse(qs);
    if (parsed == null || parsed <= 0) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = '缺少会话 ID，无法加载思维树';
      });
      return;
    }
    final data = await StudentService().getThinkingTree(parsed);
    if (!mounted) return;
    setState(() {
      _treeData = data;
      _isLoading = false;
    });
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
              title: 'AI 临床思维树',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.studentHome),
              action: AppIconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => AppFeedback.info(context, '思维树导出功能即将开放'),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return _buildEmpty(_errorMsg!, Icons.link_off);
    }
    final nodes = (_treeData?['nodes'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final socraticPrompt = _treeData?['socraticPrompt'] as String?;
    final totalCost = ((_treeData?['totalExamCost'] as num?)?.toDouble()) ?? 0.0;
    if (nodes.isEmpty && (socraticPrompt == null || socraticPrompt.isEmpty)) {
      return _buildEmpty('该会话暂无思维树数据', Icons.account_tree_outlined);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCostCard(context, totalCost),
          if (nodes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNodesSection(context, nodes),
          ],
          if (socraticPrompt != null && socraticPrompt.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSocraticPrompt(context, socraticPrompt),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 16),
          AppGhostButton(
            label: '返回首页',
            onPressed: () => context.goNamed(RouteNames.studentHome),
          ),
        ],
      ),
    );
  }

  Widget _buildCostCard(BuildContext context, double totalCost) {
    final progress = (totalCost / _costThreshold).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final overBudget = totalCost > _costThreshold;
    final remain = (totalCost - _costThreshold).abs();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText('检查累计费用',
                      fontSize: 11, color: AppColors.amber, letterSpacing: 0.06),
                  const SizedBox(height: 4),
                  Text(
                    '¥ ${totalCost.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MonoText('阈值 ¥${_costThreshold.toStringAsFixed(0)}',
                      fontSize: 11, color: AppColors.text3Of(context)),
                  const SizedBox(height: 2),
                  MonoText('$percent% 已用', fontSize: 11, color: AppColors.amber),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            value: progress,
            height: 4,
            backgroundColor: AppColors.amber.withValues(alpha: 0.2),
            foregroundColor: AppColors.amber,
            radius: 2,
          ),
          const SizedBox(height: 6),
          MonoText(
            overBudget
                ? '已超支 ¥${remain.toStringAsFixed(0)} · 模拟不扣费'
                : '距超支 ¥${remain.toStringAsFixed(0)} · 模拟不扣费',
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  Widget _buildNodesSection(BuildContext context, List<Map<String, dynamic>> nodes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MonoText('思维树节点 / Nodes', fontSize: 10, letterSpacing: 0.12),
              MonoText('${nodes.length} 节点',
                  fontSize: 10, color: AppColors.text3Of(context)),
            ],
          ),
        ),
        ...nodes.map((n) => _treeNodeFromMap(context, n)),
      ],
    );
  }

  Widget _treeNodeFromMap(BuildContext context, Map<String, dynamic> node) {
    final type = (node['type'] as String?) ?? 'node';
    final label = (node['label'] as String?) ?? type;
    final status = (node['status'] as String?) ?? '';
    final evidence = (node['evidence'] as String?) ?? '';
    final cost = (node['cost'] as num?)?.toDouble();
    final meta = (cost != null && cost > 0)
        ? '产生费用 ¥${cost.toStringAsFixed(0)}'
        : null;
    final statusBadge = _mapStatus(status);
    final text = evidence.isNotEmpty ? evidence : label;
    return _treeNode(
      context,
      _typeLabel(type),
      _statusLabel(status),
      text,
      statusBadge,
      meta: meta,
      miss: statusBadge == StatusBadgeType.miss,
      warn: statusBadge == StatusBadgeType.warn,
      neutral: statusBadge == StatusBadgeType.neutral,
    );
  }

  /// 兼容英文代码与中文文案两种状态格式（Python agent 可能输出其中任一种）
  String _normalizeStatus(String raw) {
    switch (raw.trim()) {
      case '已询问':
      case '已采集':
      case '已开':
      case '建议':
      case '高度怀疑':
      case '已确诊':
      case '已做':
        return 'ok';
      case '未询问':
      case '未查':
      case '关键遗漏':
      case '遗漏':
      case '未采集':
        return 'miss';
      case '待跟进':
      case '待排除':
      case '过度检查':
      case '已排除':
      case '错误排除':
      case '需复查':
        return 'warn';
      case '可能性低':
      case '低概率':
      case '排除':
        return 'neutral';
      default:
        return raw;
    }
  }

  StatusBadgeType _mapStatus(String status) {
    switch (_normalizeStatus(status)) {
      case 'ok':
        return StatusBadgeType.ok;
      case 'miss':
        return StatusBadgeType.miss;
      case 'warn':
        return StatusBadgeType.warn;
      case 'neutral':
        return StatusBadgeType.neutral;
      default:
        switch (status) {
          case 'asked':
          case 'collected':
          case 'opened':
          case 'suggested':
          case 'suspected':
          case 'queried':
            return StatusBadgeType.ok;
          case 'notAsked':
          case 'keyMiss':
            return StatusBadgeType.miss;
          case 'needFollowUp':
          case 'overExam':
          case 'excluded':
            return StatusBadgeType.warn;
          case 'lowProbability':
            return StatusBadgeType.neutral;
          default:
            return StatusBadgeType.info;
        }
    }
  }

  String _statusLabel(String status) {
    switch (_normalizeStatus(status)) {
      case 'ok':
        return '已询问';
      case 'miss':
        return '关键遗漏';
      case 'warn':
        return '待跟进';
      case 'neutral':
        return '可能性低';
      default:
        switch (status) {
          case 'asked':
          case 'queried':
            return '已询问';
          case 'collected':
            return '已采集';
          case 'opened':
            return '已开';
          case 'suggested':
            return '建议';
          case 'suspected':
            return '高度怀疑';
          case 'notAsked':
            return '未询问';
          case 'keyMiss':
            return '关键遗漏';
          case 'needFollowUp':
            return '待跟进';
          case 'overExam':
            return '过度检查';
          case 'excluded':
            return '已排除';
          case 'lowProbability':
            return '可能性低';
          default:
            return status.isEmpty ? '节点' : status;
        }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'symptom':
        return '症状';
      case 'history':
        return '病史';
      case 'exam':
        return '检查';
      case 'diagnosis':
        return '诊断';
      case 'cost':
        return '费用';
      default:
        return type;
    }
  }

  Widget _treeNode(
    BuildContext context,
    String type,
    String status,
    String text,
    StatusBadgeType statusType, {
    String? meta,
    bool miss = false,
    bool warn = false,
    bool neutral = false,
  }) {
    Color leftColor = AppColors.primaryOf(context);
    Color bgColor = AppColors.surfaceOf(context);
    if (miss) {
      leftColor = AppColors.vermilion;
      bgColor = AppColors.vermilionSoftOf(context);
    } else if (warn) {
      leftColor = AppColors.amber;
      bgColor = AppColors.amberSoftOf(context);
    } else if (neutral) {
      leftColor = AppColors.text4Of(context);
      bgColor = AppColors.surfaceOf(context);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: leftColor),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MonoText(type,
                        fontSize: 10,
                        color: AppColors.text3Of(context),
                        letterSpacing: 0.06),
                    AppStatusBadge(label: status, type: statusType),
                  ],
                ),
                const SizedBox(height: 3),
                Text(text,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.text2Of(context),
                        height: 1.4)),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  MonoText(meta, fontSize: 10, color: AppColors.text3Of(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocraticPrompt(BuildContext context, String prompt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amberSoftOf(context),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, size: 12, color: AppColors.amber),
              const SizedBox(width: 6),
              const MonoText(
                '苏格拉底式提示',
                fontSize: 11,
                color: AppColors.amber,
                letterSpacing: 0.1,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$prompt"',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textOf(context),
              height: 1.55,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
