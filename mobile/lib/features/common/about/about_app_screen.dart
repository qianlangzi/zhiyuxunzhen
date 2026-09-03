import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';

/// 关于「智愈寻真」页面（学生 / 教师共用）
///
/// 内容均依据 PRD_V2.1 提炼：应用定位（1.2）、能力范围（2.1）、
/// 免责与合规（10.4、13.5）。
class AboutAppScreen extends StatelessWidget {
const   AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppBackAppBar(title: '关于智愈寻真'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: const _LogoHeader()),
           Divider(color: AppColors.ruleOf(context), height: 28),
                    const _FeatureIntro(),
                    const _TeamInfo(),
                    _LegalSection(
                      onOpenPolicy: (type) => _openPolicy(context, type),
                    ),
                    const SizedBox(height: 16),
                    const MedicalDisclaimer(),
                    const SizedBox(height: 16),
                    const _FeedbackFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPolicy(BuildContext context, String type) {
    context.pushNamed(
      type == 'agreement' ? RouteNames.userAgreement : RouteNames.privacyPolicy,
    );
  }
}

/// 顶部 Logo + 应用名称 + 版本
class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.mossTintOf(context),
            border: Border.all(color: AppColors.moss3Of(context), width: 1.5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '智',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryOf(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
     Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
            letterSpacing: 0.02,
          ),
        ),
        const SizedBox(height: 6),
     MonoText(
          '内科教研协同智能体平台',
          fontSize: 12,
          color: AppColors.text3Of(context),
          letterSpacing: 0.06,
        ),
     SizedBox(height: 10),
        Container(
     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.paper2Of(context),
            border: Border.all(color: AppColors.ruleOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: MonoText(
            'v${AppConstants.appVersion} · 企业级可上线版',
            fontSize: 11,
            color: AppColors.text2Of(context),
          ),
        ),
      ],
    );
  }
}

/// 功能简介
class _FeatureIntro extends StatelessWidget {
  const _FeatureIntro();

  static const _features = [
    '多模态 AI 问诊训练：沉浸式虚拟病人，支持影像判读与圈画',
    '临床思维决策树：实时呈现已问、已排除、遗漏与检查成本',
    'OSCE 四维能力雷达图：病史采集 · 诊断逻辑 · 沟通 · 人文',
    '每日一例 / 学习热力图 / 错题本：高频低压力日常训练',
    'AI 复盘报告与个性化补救路径：教材页码溯源、递进训练',
    '教师零代码病例配置、智能批阅与班级学情看板',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '功能简介'),
        const SizedBox(height: 4),
     Text(
          '智愈寻真是面向高校一流内科学建设的「教-学-管」三位一体 AI 训练平台，'
          '融合大模型、RAG 知识库与智能体编排，打通虚拟病人训练、临床思维评估、'
          '作业批阅与学情分析。',
          style: TextStyle(
            fontSize: 13,
            height: 1.7,
            color: AppColors.text2Of(context),
          ),
        ),
        const SizedBox(height: 12),
        ..._features.map((f) => _FeatureRow(text: f)),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
       style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.text2Of(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 开发团队信息
class _TeamInfo extends StatelessWidget {
  const _TeamInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '开发团队'),
        const SizedBox(height: 4),
        AppPaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Text(
                '智愈寻真由临床医学教育专家与 AI 工程团队联合研发，'
                '服务于高校一流内科学建设。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.text2Of(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  AppChip(label: '医学专家审核', type: ChipType.moss),
                  AppChip(label: 'RAG 教材知识库', type: ChipType.indigo),
                  AppChip(label: '智能体编排', type: ChipType.amber),
                  AppChip(label: '伦理安全兜底', type: ChipType.vermilion),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 用户协议 / 隐私政策 + 免责声明区块
class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.onOpenPolicy});

  final void Function(String type) onOpenPolicy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '协议与声明'),
        const SizedBox(height: 4),
        AppPaper(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _LinkRow(
                icon: Icons.description_outlined,
                label: '用户协议',
                onTap: () => onOpenPolicy('agreement'),
              ),
              Divider(
                color: AppColors.ruleSoftOf(context),
                height: 1,
                thickness: 1,
                indent: 52,
              ),
              _LinkRow(
                icon: Icons.privacy_tip_outlined,
                label: '隐私政策',
                onTap: () => onOpenPolicy('privacy'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppPaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EyebrowText('免责声明'),
              const SizedBox(height: 6),
        Text(
                '本应用提供的内容仅供医学思维训练使用，不具备真实临床诊疗效力，'
                '不能替代临床医师诊疗。真实患者信息不作为训练内容，AI 不提供'
                '真实患者诊疗建议、药物处方。训练数据仅用于教学评估。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.text3Of(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
const   _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.text3Of(context)),
      title: Text(
        label,
    style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
      ),
      trailing:
      Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      onTap: onTap,
    );
  }
}

/// 底部联系方式 / 反馈入口
class _FeedbackFooter extends StatelessWidget {
const   _FeedbackFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppPaper(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.feedback_outlined,
                size: 20, color: AppColors.primaryOf(context)),
      title: Text(
              '意见反馈',
              style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
            ),
      subtitle: MonoText(
              'support@zhiyu.edu.cn',
              fontSize: 11,
              color: AppColors.text4Of(context),
            ),
            trailing: Icon(Icons.chevron_right,
                size: 16, color: AppColors.text4Of(context)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            onTap: () {
              AppFeedback.info(
                context,
                '感谢反馈，请联系 support@zhiyu.edu.cn',
              );
            },
          ),
        ),
        const SizedBox(height: 16),
     Center(
          child: MonoText(
            '© 2026 智愈寻真 · 内科教研协同智能体平台',
            fontSize: 10,
            color: AppColors.text4Of(context),
            letterSpacing: 0.04,
          ),
        ),
      ],
    );
  }
}
