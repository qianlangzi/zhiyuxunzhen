import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// 临床思维树（独立全屏页面）
class ThinkingTreeScreen extends StatelessWidget {
const   ThinkingTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '临床思维树',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.chat),
              action: AppIconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => AppFeedback.info(context, '思维树导出功能即将开放（演示版）'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCostCard(context, ),
                    const SizedBox(height: 16),
                    _buildSymptomSection(context),
                    const SizedBox(height: 16),
                    _buildReasoningSection(context, ),
                    const SizedBox(height: 20),
                    _buildSocraticPrompt(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
    border: Border.all(color: Color(0xFFE3CFA0)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  MonoText('检查累计费用', fontSize: 11, color: AppColors.amber, letterSpacing: 0.06),
                  SizedBox(height: 4),
                  Text(
                    '¥ 680',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MonoText('阈值 ¥1,000', fontSize: 11, color: AppColors.text3Of(context)),
                  SizedBox(height: 2),
                  MonoText('68% 已用', fontSize: 11, color: AppColors.amber),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            value: 0.68,
            height: 4,
            backgroundColor: const Color(0x33B8821E),
            foregroundColor: AppColors.amber,
            radius: 2,
          ),
          const SizedBox(height: 6),
          const MonoText('已开 3 项 · 距超支 ¥320 · 模拟不扣费', fontSize: 11),
        ],
      ),
    );
  }

  Widget _buildSymptomSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              MonoText('症状 / Symptom', fontSize: 10, letterSpacing: 0.12),
              MonoText('1 关键遗漏', fontSize: 10, color: AppColors.vermilion),
            ],
          ),
        ),
        _treeNode(context, '胸部', '已询问', '胸骨后压榨样疼痛 2h，放射至左肩', StatusBadgeType.ok),
        _treeNode(context, '伴随', '已询问', '大汗、恶心、左手麻木', StatusBadgeType.ok),
        _treeNode(context, 
          '诱因', '关键遗漏',
          '未询问体力活动、情绪、饱餐等诱因',
          StatusBadgeType.miss,
          meta: '⚠ 高危遗漏 · 影响鉴别诊断',
          miss: true,
        ),
      ],
    );
  }

  Widget _buildReasoningSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
     padding: EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MonoText('诊断推理 / Reasoning', fontSize: 10, letterSpacing: 0.12),
              MonoText('3 节点', fontSize: 10, color: AppColors.text3Of(context)),
            ],
          ),
        ),
        _treeNode(context, 'ACS', '高度怀疑', '急性下壁+右室心梗可能', StatusBadgeType.ok),
        _treeNode(context, '主动脉夹层', '待排除', '需 D-二聚体 / 胸主动脉 CTA 排除', StatusBadgeType.warn, warn: true),
        _treeNode(context, '肺栓塞', '可能性低', '无危险因素，待 Wells 评估', StatusBadgeType.neutral, neutral: true),
      ],
    );
  }

  Widget _treeNode(BuildContext context, 
    String type, String status, String text, StatusBadgeType statusType,
    {String? meta, bool miss = false, bool warn = false, bool neutral = false}
  ) {
    Color leftColor = AppColors.moss;
    Color bgColor = AppColors.surfaceOf(context);
    if (miss) {
      leftColor = AppColors.vermilion;
      bgColor = AppColors.vermilionSoft;
    } else if (warn) {
      leftColor = AppColors.amber;
      bgColor = AppColors.amberSoft;
    } else if (neutral) {
      leftColor = AppColors.text4Of(context);
      bgColor = AppColors.surfaceOf(context);
    }
    return Container(
   margin: EdgeInsets.only(bottom: 6),
   clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: leftColor),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MonoText(type, fontSize: 10, color: AppColors.text3Of(context), letterSpacing: 0.06),
              AppStatusBadge(label: status, type: statusType),
            ],
          ),
          const SizedBox(height: 3),
     Text(text, style: TextStyle(fontSize: 12.5, color: AppColors.text2Of(context), height: 1.4)),
          if (meta != null) ...[
            const SizedBox(height: 4),
            MonoText(meta, fontSize: 10, color: AppColors.text3Of(context)),
          ],
        ],
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocraticPrompt(BuildContext context) {
    return Container(
   padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        border: Border.all(color: const Color(0xFFE3CFA0)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, size: 12, color: AppColors.amber),
              const SizedBox(width: 6),
              const MonoText(
                '苏格拉底式提示（轻度）',
                fontSize: 11,
                color: AppColors.amber,
                letterSpacing: 0.1,
              ),
            ],
          ),
      SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
         TextSpan(
                  text: '"你已经识别出 ST 段抬高和肌钙蛋白升高——但患者胸痛的',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textOf(context), height: 1.55, fontStyle: FontStyle.italic),
                ),
                TextSpan(
                  text: '诱因',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textOf(context), fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                ),
         TextSpan(
                  text: '你还没问。是否需要确认疼痛与体力活动的关系，再来判断这是 ACS 还是其他疾病？"',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textOf(context), height: 1.55, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _showStandardPath(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border.all(color: const Color(0xFFE3CFA0)),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 12, color: AppColors.amber),
                    SizedBox(width: 4),
                    MonoText('标准路径（完整答案）', fontSize: 11, color: AppColors.amber, letterSpacing: 0.04),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStandardPath(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    title: Text('标准问诊路径', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
    content: Text(
          '1. 询问疼痛部位、性质、放射、持续时间\n'
          '2. 询问诱因（体力活动/情绪/饱餐）\n'
          '3. 询问伴随症状（大汗、恶心、呼吸困难）\n'
          '4. 既往史、过敏史、家族史\n'
          '5. 开 18 导联心电图（关键检查）\n'
          '6. 查肌钙蛋白（关键检查）\n'
          '7. 鉴别 ACS / 主动脉夹层 / 肺栓塞\n\n'
          '脱轨节点：第 2 步未询问诱因，影响 ACS 鉴别。\n'
          '教材：《内科学》第9版 · P247',
          style: TextStyle(fontSize: 13, color: AppColors.text2Of(context), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了', style: TextStyle(color: AppColors.moss, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
