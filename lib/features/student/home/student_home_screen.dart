import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_provider.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('智愈寻真'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            tooltip: '退出',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Greeting
          Text('你好，${auth.user?.realName ?? "同学"}',
              style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('今天继续提升临床思维吧',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),

          // Quick actions grid
          Row(
            children: [
              Expanded(
                child: _QuickCard(
                  icon: Icons.chat_bubble_outline,
                  label: 'AI 问诊训练',
                  color: AppColors.primary,
                  onTap: () => context.go('/student/cases'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickCard(
                  icon: Icons.today,
                  label: '每日一例',
                  color: AppColors.accent,
                  onTap: () => context.go('/student/daily'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _StatCard(label: '完成病例', value: '12', ctx: context),
              const SizedBox(width: 12),
              _StatCard(label: '错题待复习', value: '8', ctx: context),
              const SizedBox(width: 12),
              _StatCard(label: '连续打卡', value: '5天', ctx: context),
            ],
          ),
          const SizedBox(height: 24),

          // Pending assignments
          Text('待完成作业', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _AssignmentCard(
            title: '胸痛鉴别诊断训练',
            teacher: '张教授',
            deadline: '7月18日 23:59',
            status: '未开始',
            onTap: () => context.go('/student/cases/1'),
          ),
          const SizedBox(height: 8),
          _AssignmentCard(
            title: '糖尿病病例问诊',
            teacher: '王老师',
            deadline: '7月20日 23:59',
            status: '问诊中',
            onTap: () => context.go('/student/cases/2'),
          ),
          const SizedBox(height: 24),

          // Recommended cases
          Text('推荐训练', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RecommendCard(
                  title: '急性心梗',
                  dept: '心血管内科',
                  difficulty: '标准',
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _RecommendCard(
                  title: '肺栓塞',
                  dept: '呼吸内科',
                  difficulty: '困难',
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _RecommendCard(
                  title: '甲亢',
                  dept: '内分泌科',
                  difficulty: '简单',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard(
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

class _StatCard extends StatelessWidget {
  final String label, value;
  final BuildContext ctx;
  const _StatCard(
      {required this.label, required this.value, required this.ctx});

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

class _AssignmentCard extends StatelessWidget {
  final String title, teacher, deadline, status;
  final VoidCallback onTap;
  const _AssignmentCard(
      {required this.title,
      required this.teacher,
      required this.deadline,
      required this.status,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('$teacher · 截止 $deadline'),
        trailing: Chip(
          label: Text(status,
              style: const TextStyle(fontSize: 12, color: AppColors.primary)),
          backgroundColor: AppColors.primaryLight,
          side: BorderSide.none,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _RecommendCard extends StatelessWidget {
  final String title, dept, difficulty;
  final VoidCallback onTap;
  const _RecommendCard(
      {required this.title,
      required this.dept,
      required this.difficulty,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diffColor = difficulty == '简单'
        ? AppColors.accent
        : difficulty == '困难'
            ? AppColors.destructive
            : AppColors.warning;
    return SizedBox(
      width: 160,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(dept, style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Chip(
                  label: Text(difficulty,
                      style: TextStyle(fontSize: 11, color: diffColor)),
                  backgroundColor: diffColor.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
