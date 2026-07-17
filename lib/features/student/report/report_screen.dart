import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练报告'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 18),
            label: const Text('导出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // OSCE Radar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('OSCE 四维评估', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: RadarChart(
                      RadarChartData(
                        radarBorderData: const BorderSide(
                            color: AppColors.borderLight),
                        radarBackgroundColor: Colors.transparent,
                        dataSets: [
                          RadarDataSet(
                            fillColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            borderColor: AppColors.primary,
                            borderWidth: 2,
                            entryRadius: 4,
                            dataEntries: const [
                              RadarEntry(value: 85),
                              RadarEntry(value: 70),
                              RadarEntry(value: 90),
                              RadarEntry(value: 88),
                            ],
                          ),
                        ],
                        getTitle: (i, _) {
                          const titles = ['病史采集', '诊断逻辑', '沟通技巧', '人文关怀'];
                          return RadarChartTitle(text: titles[i]);
                        },
                        tickCount: 5,
                        ticksTextStyle:
                            const TextStyle(fontSize: 10, color: AppColors.fgDimLight),
                      ),
                      duration: const Duration(milliseconds: 400),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Strengths & Weaknesses
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('评估总结', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _BulletList(
                    color: AppColors.accent,
                    icon: Icons.star,
                    title: '3 个主要优点',
                    items: const [
                      '问诊流程完整，主诉-现病史-既往史采集到位',
                      '对患者焦虑情绪有及时的安抚和解释',
                      '检查费用控制在合理范围内',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BulletList(
                    color: AppColors.destructive,
                    icon: Icons.priority_high,
                    title: '3 个优先改进点',
                    items: const [
                      '胸痛病例需优先排除急性冠脉综合征',
                      '过敏史不能留空白，未知需写"不详"',
                      '应增加鉴别诊断的思考维度',
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recommendations
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('个性化补救路径', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _RecommendItem(
                    step: '1',
                    label: '教材复习',
                    desc: '内科学（第9版）第12章 冠状动脉粥样硬化性心脏病 p.228-256',
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _RecommendItem(
                    step: '2',
                    label: '简单病例',
                    desc: '稳定性心绞痛问诊训练',
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 8),
                  _RecommendItem(
                    step: '3',
                    label: '标准病例',
                    desc: '非ST段抬高型心肌梗死鉴别诊断',
                    color: AppColors.warning,
                  ),
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

class _BulletList extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> items;
  const _BulletList(
      {required this.color,
      required this.icon,
      required this.title,
      required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14, color: color)),
        ]),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 22, bottom: 4),
              child: Text('• $item',
                  style: Theme.of(context).textTheme.bodyMedium),
            )),
      ],
    );
  }
}

class _RecommendItem extends StatelessWidget {
  final String step, label, desc;
  final Color color;
  const _RecommendItem(
      {required this.step,
      required this.label,
      required this.desc,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child:
                Text(step, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color)),
                Text(desc, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
