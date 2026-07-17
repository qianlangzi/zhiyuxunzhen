import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class CaseListScreen extends StatelessWidget {
  const CaseListScreen({super.key});

  static const _cases = [
    {
      'id': 1,
      'title': '胸痛鉴别诊断',
      'dept': '心血管内科',
      'diff': '困难',
      'complaint': '胸痛伴呼吸困难2小时',
      'tags': '急性冠脉综合征, 心电图判读',
    },
    {
      'id': 2,
      'title': '糖尿病初诊',
      'dept': '内分泌科',
      'diff': '简单',
      'complaint': '多饮多尿消瘦3月',
      'tags': '2型糖尿病, 糖化血红蛋白',
    },
    {
      'id': 3,
      'title': '急性腹痛',
      'dept': '消化内科',
      'diff': '标准',
      'complaint': '突发上腹痛伴恶心呕吐',
      'tags': '急性胰腺炎, 鉴别诊断',
    },
    {
      'id': 4,
      'title': '慢性咳嗽',
      'dept': '呼吸内科',
      'diff': '标准',
      'complaint': '反复咳嗽咳痰3月',
      'tags': 'COPD, 肺功能检查',
    },
    {
      'id': 5,
      'title': '头痛查因',
      'dept': '神经内科',
      'diff': '困难',
      'complaint': '反复头痛伴视力模糊',
      'tags': '偏头痛, 颅内压增高',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('病例训练')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          // Search
          TextField(
            decoration: InputDecoration(
              hintText: '搜索病例、科室、疾病…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip('全部', true),
                const SizedBox(width: 8),
                _FilterChip('心血管', false),
                const SizedBox(width: 8),
                _FilterChip('内分泌', false),
                const SizedBox(width: 8),
                _FilterChip('消化', false),
                const SizedBox(width: 8),
                _FilterChip('呼吸', false),
                const SizedBox(width: 8),
                _FilterChip('神经', false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Case list
          ..._cases.map((c) => _CaseCard(
                id: c['id'] as int,
                title: c['title'] as String,
                dept: c['dept'] as String,
                diff: c['diff'] as String,
                complaint: c['complaint'] as String,
                tags: c['tags'] as String,
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChip(this.label, this.selected);

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

class _CaseCard extends StatelessWidget {
  final int id;
  final String title, dept, diff, complaint, tags;
  const _CaseCard(
      {required this.id,
      required this.title,
      required this.dept,
      required this.diff,
      required this.complaint,
      required this.tags});

  @override
  Widget build(BuildContext context) {
    final diffColor = diff == '简单'
        ? AppColors.accent
        : diff == '困难'
            ? AppColors.destructive
            : AppColors.warning;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(complaint,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _Tag(dept, AppColors.primaryLight, AppColors.primary),
                _Tag(diff, diffColor.withValues(alpha: 0.1), diffColor),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/student/cases/$id'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Tag(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}
