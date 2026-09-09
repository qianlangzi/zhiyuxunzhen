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
            'Version ${AppConstants.appVersion}',
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
    '虚拟病人问诊训练：支持对话问诊与影像判读',
    '临床思维决策树：呈现已问、已排除与遗漏项目',
    'OSCE 四维能力评估：病史采集、诊断逻辑、沟通、人文',
    '每日一例 / 学习热力图 / 错题本：日常训练记录',
    'AI 复盘报告：训练结果分析与补充练习建议',
    '教师端：病例配置、作业批阅与班级学情查看',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '功能简介'),
        const SizedBox(height: 4),
     Text(
          '智愈寻真是一款面向内科学教学的临床思维训练应用，'
          '提供虚拟病人问诊训练、临床思维评估、作业练习与学情记录等功能，'
          '供医学生及带教教师在教学场景中使用。',
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

/// 应用说明
class _TeamInfo extends StatelessWidget {
  const _TeamInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '应用说明'),
        const SizedBox(height: 4),
        AppPaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Text(
                '本应用面向医学院校及教学医院，用于内科学教学与训练场景。'
                '应用内的病例内容均为教学模拟数据，不涉及真实患者信息。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.text2Of(context),
                ),
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
        SizedBox(
                width: double.infinity,
                child: Text(
                  '本应用提供的内容仅供医学思维训练使用，不具备真实临床诊疗效力，'
                  '不能替代临床医师诊疗。真实患者信息不作为训练内容，AI 不提供'
                  '真实患者诊疗建议、药物处方。训练数据仅用于教学评估。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: AppColors.text3Of(context),
                  ),
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
