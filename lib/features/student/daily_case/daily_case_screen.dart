import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DailyCaseScreen extends StatefulWidget {
  const DailyCaseScreen({super.key});

  @override
  State<DailyCaseScreen> createState() => _DailyCaseScreenState();
}

class _DailyCaseScreenState extends State<DailyCaseScreen> {
  int? _selectedAnswer;
  bool _submitted = false;

  void _submit() {
    if (_selectedAnswer == null) return;
    setState(() => _submitted = true);
  }

  void _next() {
    setState(() {
      _selectedAnswer = null;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const correct = 2; // Option C

    return Scaffold(
      appBar: AppBar(title: const Text('每日一例')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Heatmap stub
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Text('本月打卡', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(
                    31,
                    (i) => Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: i < 15
                            ? AppColors.accent.withValues(alpha: 0.3 + (i / 50))
                            : AppColors.mutedLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: i < 15
                          ? const Icon(Icons.check, size: 16, color: AppColors.accent)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Today's case
          Text('今日病例', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('患者，男性，56岁。突发胸骨后压榨性疼痛2小时，含服硝酸甘油不缓解。',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('心电图：V1-V4导联 ST段弓背向上抬高',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                  const SizedBox(height: 16),
                  Text('最可能的诊断是？', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ...List.generate(4, (i) {
                    final options = [
                      'A. 稳定型心绞痛',
                      'B. 主动脉夹层',
                      'C. 急性ST段抬高型心肌梗死',
                      'D. 急性心包炎',
                    ];
                    final isCorrect = i == correct;
                    Color? bg;
                    if (_submitted) {
                      if (i == _selectedAnswer && !isCorrect) {
                        bg = AppColors.destructiveLight;
                      } else if (isCorrect) {
                        bg = AppColors.accentLight;
                      }
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: _submitted
                            ? null
                            : () => setState(() => _selectedAnswer = i),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: bg ??
                              (_selectedAnswer == i
                                  ? AppColors.primaryLight
                                  : null),
                          foregroundColor: isCorrect && _submitted
                              ? AppColors.accent
                              : AppColors.fgLight,
                          side: BorderSide(
                            color: isCorrect && _submitted
                                ? AppColors.accent
                                : (_selectedAnswer == i
                                    ? AppColors.primary
                                    : AppColors.borderLight),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: Row(
                          children: [
                            if (_submitted && isCorrect)
                              const Icon(Icons.check_circle,
                                  color: AppColors.accent, size: 20),
                            if (_submitted &&
                                i == _selectedAnswer &&
                                !isCorrect)
                              const Icon(Icons.cancel,
                                  color: AppColors.destructive, size: 20),
                            const SizedBox(width: 8),
                            Text(options[i],
                                style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  if (!_submitted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('提交答案'),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✅ 避坑要点',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent)),
                          SizedBox(height: 4),
                          Text('硝酸甘油不缓解提示急性心梗而非心绞痛。'
                              'ST段弓背向上抬高是STEMI的特征性心电图表现。'
                              '\n出处：内科学（第9版）第12章 p.234'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _next,
                        child: const Text('下一题'),
                      ),
                    ),
                  ],
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
