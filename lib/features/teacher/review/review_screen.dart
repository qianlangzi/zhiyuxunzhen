import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('批阅复核')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          Text('待教师复核', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...List.generate(3, (i) {
            final names = ['李同学', '王同学', '赵同学'];
            final scores = ['82', '75', '91'];
            final statuses = ['AI批阅完成', 'AI批阅完成', '格式打回'];
            final statusColors = [AppColors.primary, AppColors.primary, AppColors.destructive];

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(names[i][0],
                      style: const TextStyle(color: AppColors.primary)),
                ),
                title: Text(names[i],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('胸痛鉴别诊断 · 大病历'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('AI评分: ${scores[i]}分',
                            style: TextStyle(
                                color: AppColors.fgDimLight, fontSize: 13)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColors[i].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(statuses[i],
                              style: TextStyle(
                                  color: statusColors[i],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showReviewDetail(context, names[i]),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(72, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: Text(statuses[i] == '格式打回' ? '查看' : '复核'),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text('已复核', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final names = ['陈同学', '刘同学', '黄同学', '周同学', '吴同学'];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                    backgroundColor: AppColors.accentLight,
                    child: Icon(Icons.check, color: AppColors.accent, size: 18)),
                title: Text(names[i],
                    style: const TextStyle(fontSize: 15)),
                subtitle: const Text('87分 · 教师已确认'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showReviewDetail(BuildContext ctx, String name) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text('$name · 大病历批阅',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),

            // AI批阅结果
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI 批阅报告',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 12),
                    _ReviewItem(
                        icon: Icons.close,
                        color: AppColors.destructive,
                        title: '诊断逻辑',
                        detail: '现病史与体格检查之间缺少逻辑关联'),
                    const SizedBox(height: 8),
                    _ReviewItem(
                        icon: Icons.warning_amber,
                        color: AppColors.warning,
                        title: '文书规范',
                        detail: '主诉应包含症状持续时间'),
                    const SizedBox(height: 8),
                    _ReviewItem(
                        icon: Icons.check_circle,
                        color: AppColors.accent,
                        title: '鉴别诊断',
                        detail: '鉴别诊断覆盖完整，高危疾病未遗漏'),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('AI 综合评分',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('82分',
                            style: Theme.of(ctx)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 教师操作
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('确认通过'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('修正评分'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, detail;
  const _ReviewItem(
      {required this.icon,
      required this.color,
      required this.title,
      required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: color)),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
