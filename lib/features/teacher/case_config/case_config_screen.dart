import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CaseConfigScreen extends StatefulWidget {
  const CaseConfigScreen({super.key});

  @override
  State<CaseConfigScreen> createState() => _CaseConfigScreenState();
}

class _CaseConfigScreenState extends State<CaseConfigScreen> {
  bool _showCreateForm = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('病例配置'),
        actions: [
          IconButton(
            icon: Icon(_showCreateForm ? Icons.close : Icons.add),
            onPressed: () => setState(() => _showCreateForm = !_showCreateForm),
          ),
        ],
      ),
      body: _showCreateForm
          ? _CreateCaseForm(onClose: () => setState(() => _showCreateForm = false))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterBtn('全部', true),
                      const SizedBox(width: 8),
                      _FilterBtn('已发布', false),
                      const SizedBox(width: 8),
                      _FilterBtn('草稿', false),
                      const SizedBox(width: 8),
                      _FilterBtn('广场', false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(6, (i) {
                  final titles = [
                    '胸痛鉴别诊断', '糖尿病初诊', '急性腹痛',
                    '慢性咳嗽', '头痛查因', '高血压管理',
                  ];
                  final depts = [
                    '心血管内科', '内分泌科', '消化内科',
                    '呼吸内科', '神经内科', '心血管内科',
                  ];
                  final statuses = ['已发布', '草稿', '广场', '已发布', '草稿', '已发布'];
                  final refs = [12, 0, 8, 6, 0, 4];

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(titles[i],
                          style: theme.textTheme.titleMedium),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(depts[i],
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _Tag(statuses[i],
                                  statuses[i] == '广场'
                                      ? AppColors.accent
                                      : AppColors.primary),
                              if (refs[i] > 0) ...[
                                const SizedBox(width: 8),
                                Text('被引用 ${refs[i]} 次',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ],
                          ),
                        ],
                      ),
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
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool active;
  const _FilterBtn(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {},
      showCheckmark: false,
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _CreateCaseForm extends StatelessWidget {
  final VoidCallback onClose;
  const _CreateCaseForm({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('创建标准化病人 (SP)',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),

        // Basic info
        Text('基础信息', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            labelText: '病例标题 *',
            hintText: '如：胸痛鉴别诊断',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '科室 *'),
                items: ['心血管内科', '内分泌科', '呼吸内科', '消化内科', '神经内科']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '难度 *'),
                items: ['简单', '标准', '困难']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Patient profile
        Text('患者画像', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '主诉 *',
              hintText: '如：胸痛伴呼吸困难2小时'),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '现病史摘要',
              hintText: '描述症状发生、发展经过'),
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        // Hidden disease
        Text('隐藏配置 (仅教师/管理员可见)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '真实诊断 *',
              hintText: '如：急性ST段抬高型心肌梗死'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '知识点标签',
              hintText: '用逗号分隔：急性冠脉综合征, 心电图判读'),
        ),
        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('保存草稿'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('发布病例'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.accent),
            foregroundColor: AppColors.accent,
          ),
          child: const Text('预览试诊'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
