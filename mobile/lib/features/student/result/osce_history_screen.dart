import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../data/student_service.dart';

/// OSCE 考核记录（历史列表）
///
/// 数据源：GET /student/evaluations/history（已完成会话，后端 OsceHistoryVO）。
/// 此前接口就绪但学生端无任何入口——考完只能看当次结果，历史无处可查。
/// 点击任一条 → 按 sessionId 跳 [RouteNames.osceResult] 复用完整结果页。
class OsceHistoryScreen extends ConsumerStatefulWidget {
  const OsceHistoryScreen({super.key});

  @override
  ConsumerState<OsceHistoryScreen> createState() => _OsceHistoryScreenState();
}

class _OsceHistoryScreenState extends ConsumerState<OsceHistoryScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final data = await StudentService().getOsceHistory();
    if (!mounted) return;
    setState(() {
      _items = (data ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _isLoading = false;
      if (data == null) _error = '考核记录加载失败，请稍后重试';
    });
  }

  /// 均分（与成长页 OSCE 均分口径一致：各次总分的算术平均）
  double get _avgScore {
    final scores = _items
        .map((e) => (e['totalScore'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// 分数语义色（与 GrowthStats.colorOf 同口径：<70 朱砂 / <85 琥珀 / 主色）
  Color _scoreColor(double score) {
    if (score < 70) return AppColors.vermilionOf(context);
    if (score < 85) return AppColors.amberOf(context);
    return AppColors.primaryOf(context);
  }

  String _formatDate(dynamic raw) {
    final t = DateTime.tryParse('$raw');
    if (t == null) return '时间未记录';
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '考核记录'),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _items.isEmpty
                          ? _buildEmpty()
                          : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text(_error ?? '加载失败',
              style: TextStyle(
                  fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 16),
          AppPrimaryButton(label: '重试', small: true, onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medical_services_outlined,
              size: 44, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('还没有考核记录',
              style: TextStyle(
                  fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 6),
          Text('完成一次问诊训练后，成绩会沉淀在这里',
              style: TextStyle(
                  fontSize: 12, color: AppColors.text4Of(context))),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // 顶部小结：一次平均，不做报表
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: MonoText(
              '共 ${_items.length} 次 · 均分 ${_avgScore.toStringAsFixed(1)}',
              fontSize: 10,
              color: AppColors.text4Of(context),
              letterSpacing: 0.12,
            ),
          ),
          ..._items.map(_buildTile),
        ],
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> e) {
    final title = (e['caseTitle'] as String?)?.trim() ?? '未命名病例';
    final department = (e['department'] as String?)?.trim() ?? '';
    final score = (e['totalScore'] as num?)?.toDouble();
    final sessionId = (e['sessionId'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PaperCard(
        tint: score == null
            ? AppColors.text3Of(context)
            : _scoreColor(score),
        radius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: sessionId == null || sessionId <= 0
            ? null
            : () => context.pushNamed(
                  RouteNames.osceResult,
                  queryParameters: {'sessionId': '$sessionId'},
                ),
        child: Row(
          children: [
            GradientIconBadge(
              icon: Icons.medical_services_outlined,
              color: score == null
                  ? AppColors.text3Of(context)
                  : _scoreColor(score),
              size: 36,
              iconSize: 17,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOf(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (department.isNotEmpty) department,
                      _formatDate(e['endedAt'] ?? e['createdAt']),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.text4Of(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              score == null ? '—' : score.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: kCjkMonoFallback,
                color: score == null
                    ? AppColors.text4Of(context)
                    : _scoreColor(score),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 17, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }
}
