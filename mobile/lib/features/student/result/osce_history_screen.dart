import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// OSCE 考核历史记录（可点开查看详情）
class OsceHistoryScreen extends ConsumerStatefulWidget {
  const OsceHistoryScreen({super.key});

  @override
  ConsumerState<OsceHistoryScreen> createState() => _OsceHistoryScreenState();
}

class _OsceHistoryScreenState extends ConsumerState<OsceHistoryScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getOsceHistory();
    if (!mounted) return;
    setState(() {
      _list = (data ?? []).cast<Map<String, dynamic>>();
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
              title: 'AI 评估 · OSCE 历史',
              onBack: () => context.goNamed(RouteNames.studentHome),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 48, color: AppColors.text4Of(context)),
                              const SizedBox(height: 12),
                              SerifText('暂无考核记录', fontSize: 15,
                                  color: AppColors.text2Of(context)),
                              const SizedBox(height: 4),
                              Text('完成问诊训练后，这里会展示你的 OSCE 评分',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.text4Of(context))),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                          itemCount: _list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _HistoryCard(item: _list[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = item['caseTitle'] as String? ?? '未命名病例';
    final department = item['department'] as String? ?? '综合';
    final total = (item['totalScore'] as num?)?.toDouble() ?? 0;
    final endedAt = item['endedAt'] as String? ?? item['createdAt'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.osceResult,
        queryParameters: {
          'sessionId': '${item['sessionId']}',
        },
      ),
      child: Container(
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
                AppChip(label: department, type: ChipType.moss),
                const Spacer(),
                Text(
                  total.toStringAsFixed(0),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOf(context),
                  ),
                ),
                const SizedBox(width: 4),
                MonoText('/ 100', fontSize: 11, color: AppColors.text4Of(context)),
              ],
            ),
            const SizedBox(height: 10),
            SerifText(title, fontSize: 15, color: AppColors.textOf(context)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: AppColors.text4Of(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: MonoText(endedAt, fontSize: 10, color: AppColors.text4Of(context)),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}