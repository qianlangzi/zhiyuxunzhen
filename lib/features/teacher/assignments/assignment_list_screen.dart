import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  bool _showCreate = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('作业管理'),
        actions: [
          IconButton(
            icon: Icon(_showCreate ? Icons.close : Icons.add),
            onPressed: () => setState(() => _showCreate = !_showCreate),
          ),
        ],
      ),
      body: _showCreate
          ? _CreateAssignmentForm(
              onClose: () => setState(() => _showCreate = false))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 16),
                Text('进行中', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _AssignmentCard(
                  title: '胸痛鉴别诊断 · 大病历',
                  cls: '2024级临床医学1班',
                  progress: '18/32 已提交',
                  deadline: '7月18日 23:59',
                  status: 'active',
                ),
                const SizedBox(height: 8),
                _AssignmentCard(
                  title: '糖尿病初诊 · 问诊训练',
                  cls: '2024级临床医学2班',
                  progress: '30/32 已提交',
                  deadline: '7月20日 23:59',
                  status: 'active',
                ),
                const SizedBox(height: 24),
                Text('已截止', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _AssignmentCard(
                  title: '高血压管理 · 综合训练',
                  cls: '2024级临床医学1班',
                  progress: '32/32 已提交',
                  deadline: '7月5日 23:59',
                  status: 'closed',
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String title, cls, progress, deadline, status;
  const _AssignmentCard(
      {required this.title,
      required this.cls,
      required this.progress,
      required this.deadline,
      required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('$cls · $deadline'),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: status == 'closed' ? 1.0 : 0.56,
              backgroundColor: AppColors.mutedLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                  status == 'closed' ? AppColors.accent : AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(progress,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: Chip(
          label: Text(status == 'active' ? '进行中' : '已截止',
              style: TextStyle(
                  fontSize: 11,
                  color: status == 'active'
                      ? AppColors.primary
                      : AppColors.fgDimLight)),
          backgroundColor: status == 'active'
              ? AppColors.primaryLight
              : AppColors.mutedLight,
          side: BorderSide.none,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _CreateAssignmentForm extends StatelessWidget {
  final VoidCallback onClose;
  const _CreateAssignmentForm({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('创建作业', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(labelText: '作业标题 *',
              hintText: '如：胸痛鉴别诊断训练'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: '选择病例 *'),
          items: ['胸痛鉴别诊断', '糖尿病初诊', '急性腹痛', '慢性咳嗽']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: '分发班级 *'),
          items: ['2024级临床医学1班 (32人)', '2024级临床医学2班 (30人)']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: '截止日期',
            hintText: 'YYYY-MM-DD',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          readOnly: true,
          onTap: () {},
        ),
        const SizedBox(height: 20),
        // Anti-cheat
        SwitchListTile(
          title: const Text('要求提交大病历'),
          subtitle: const Text('学生需提交完整大病历'),
          value: true,
          onChanged: (_) {},
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('启用防作弊变量'),
          subtitle: const Text('同病不同症，每人独立实例'),
          value: true,
          onChanged: (_) {},
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('分发作业'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
