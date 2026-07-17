import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_provider.dart';

class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('智愈寻真 · 教师端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Text('你好，${auth.user?.realName ?? "老师"}',
              style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('今日有 3 份作业待批阅',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_circle_outline,
                  label: '创建病例',
                  color: AppColors.primary,
                  onTap: () => context.go('/teacher/cases'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.assignment_outlined,
                  label: '分发作业',
                  color: AppColors.accent,
                  onTap: () => context.go('/teacher/assignments'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pending review
          Text('待批阅作业', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.rate_review_outlined,
                      color: AppColors.primary)),
              title: const Text('胸痛鉴别诊断 · 大病历',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('已提交 18/32 份 · AI 批阅完成 15 份'),
              trailing: const Chip(
                  label: Text('3份待复核',
                      style: TextStyle(fontSize: 12, color: AppColors.warning)),
                  backgroundColor: AppColors.warningLight),
              onTap: () => context.go('/teacher/review'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppColors.accentLight,
                  child: Icon(Icons.check_circle_outline,
                      color: AppColors.accent)),
              title: const Text('糖尿病初诊 · 问诊记录',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('已提交 30/32 份 · 全部批阅完成'),
              trailing: const Chip(
                  label: Text('已完成',
                      style: TextStyle(fontSize: 12, color: AppColors.accent)),
                  backgroundColor: AppColors.accentLight),
              onTap: () => context.go('/teacher/review'),
            ),
          ),
          const SizedBox(height: 24),

          // Class overview
          Text('班级概览', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBox('32', '学生总数', context),
              const SizedBox(width: 12),
              _StatBox('87%', '作业完成率', context),
              const SizedBox(width: 12),
              _StatBox('76', 'OSCE 均分', context),
            ],
          ),
          const SizedBox(height: 24),

          // Common weaknesses
          Text('全班共性薄弱点', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _WeaknessRow('急性冠脉综合征鉴别', '68% 学生漏诊', AppColors.destructive),
                  const Divider(height: 20),
                  _WeaknessRow('过敏史采集', '45% 学生留空', AppColors.warning),
                  const Divider(height: 20),
                  _WeaknessRow('过度检查', '32% 学生超支', AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final BuildContext ctx;
  const _StatBox(this.value, this.label, this.ctx);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Text(value, style: Theme.of(ctx).textTheme.displayMedium),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WeaknessRow extends StatelessWidget {
  final String label, detail;
  final Color color;
  const _WeaknessRow(this.label, this.detail, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: AppColors.fgDimLight),
      ],
    );
  }
}
