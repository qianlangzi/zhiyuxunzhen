import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MistakeListScreen extends StatelessWidget {
  const MistakeListScreen({super.key});

  static const _mistakes = [
    {
      'type': 'diagnosis',
      'label': '诊断错误',
      'question': '胸痛病例',
      'student': '不稳定型心绞痛',
      'correct': '急性ST段抬高型心肌梗死',
      'date': '7月12日',
      'key': 'ST段抬高+硝酸甘油不缓解 → STEMI',
    },
    {
      'type': 'history',
      'label': '漏问病史',
      'question': '糖尿病病例',
      'student': '未询问过敏史',
      'correct': '需确认药物过敏史',
      'date': '7月10日',
      'key': '开药前必须确认过敏史',
    },
    {
      'type': 'exam',
      'label': '检查遗漏',
      'question': '胸痛病例',
      'student': '未开立心电图',
      'correct': '胸痛首查心电图',
      'date': '7月8日',
      'key': '胸痛三大检查：心电图+肌钙蛋白+胸片',
    },
    {
      'type': 'record',
      'label': '文书问题',
      'question': '大病历',
      'student': '主诉未注明持续时间',
      'correct': '主诉需包含症状+持续时间',
      'date': '7月5日',
      'key': '主诉格式：主要症状+持续时间',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('导出PDF'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip('全部', true),
                const SizedBox(width: 8),
                _TypeChip('诊断错误', false),
                const SizedBox(width: 8),
                _TypeChip('漏问病史', false),
                const SizedBox(width: 8),
                _TypeChip('检查遗漏', false),
                const SizedBox(width: 8),
                _TypeChip('文书问题', false),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('共 ${_mistakes.length} 条待复习',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          // Mistake cards
          ..._mistakes.map((m) {
            final typeColor = {
              'diagnosis': AppColors.destructive,
              'history': AppColors.warning,
              'exam': AppColors.primary,
              'record': AppColors.fgDimLight,
            }[m['type']]!;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(m['label']!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const Spacer(),
                        Text(m['date']!,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(m['question']!,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.close, size: 14, color: AppColors.destructive),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('你的答案: ${m['student']}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.destructive)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('标准答案: ${m['correct']}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('💡 ${m['key']}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _TypeChip(this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {},
      showCheckmark: false,
    );
  }
}
