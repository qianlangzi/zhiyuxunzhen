import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../features/common/settings/settings_provider.dart';
import 'legal_content.dart';

/// 隐私政策 / 用户协议说明页（学生 / 教师共用）
///
/// 通过 [type] 区分展示内容：'privacy' 为隐私政策，'agreement' 为用户协议。
/// 内容来自 [LegalContent]，均为本地文本，无后端依赖即可阅读。
///
/// 交互：需滚动至底部后才能勾选「已阅读并同意」，确认后把同意状态写入
/// [settingsProvider]（agreedToTerms），供登录页作为准入门禁。
class LegalDocumentScreen extends ConsumerStatefulWidget {
const   LegalDocumentScreen({super.key, required this.type});

  final String type;

  @override
  ConsumerState<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  final _scrollController = ScrollController();
  bool _reachedBottom = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    // 已同意过的用户回到页面时默认勾选（仍可重新阅读后确认）
    _agreed = ref.read(settingsProvider).agreedToTerms;
    _scrollController.addListener(_onScroll);
    // 内容不足一屏时视为已读到底
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0 && !_reachedBottom) {
        setState(() => _reachedBottom = true);
      }
    });
  }

  void _onScroll() {
    if (_reachedBottom) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 24) {
      setState(() => _reachedBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    ref.read(settingsProvider.notifier).setAgreedToTerms(true);
    if (!mounted) return;
    AppFeedback.success(context, '感谢阅读，已记录您的同意');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacy = widget.type == 'privacy';
    final title =
        isPrivacy ? LegalContent.privacyTitle : LegalContent.agreementTitle;
    final updated =
        isPrivacy ? LegalContent.privacyUpdated : LegalContent.agreementUpdated;
    final sections =
        isPrivacy ? LegalContent.privacySections : LegalContent.agreementSections;

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: title),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: MonoText(
                        updated,
                        fontSize: 11,
                        color: AppColors.text4Of(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...sections.expand(
                      (s) => [
                        AppSectionHeader(title: s.title),
                        const SizedBox(height: 4),
                        ...s.paragraphs.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              p,
               style: TextStyle(
                                fontSize: 13,
                                height: 1.7,
                                color: AppColors.text2Of(context),
                              ),
                            ),
                          ),
                        ),
                        if (s.bullets != null)
                          ...s.bullets!.map((b) => _Bullet(text: b)),
                        const SizedBox(height: 10),
                      ],
                    ),
                    const MedicalDisclaimer(),
                  ],
                ),
              ),
            ),
            _AgreeBar(
              reachedBottom: _reachedBottom,
              agreed: _agreed,
              onToggle: (v) => setState(() => _agreed = v ?? false),
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部「已阅读并同意」同意栏：未滚动到底时禁用勾选，确认按钮随勾选启用
class _AgreeBar extends StatelessWidget {
const   _AgreeBar({
    required this.reachedBottom,
    required this.agreed,
    required this.onToggle,
    required this.onConfirm,
  });

  final bool reachedBottom;
  final bool agreed;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: reachedBottom && !agreed
                    ? () => onToggle(true)
                    : (reachedBottom && agreed ? () => onToggle(false) : null),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: agreed,
                        onChanged: reachedBottom ? onToggle : null,
                        activeColor: AppColors.moss,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
           SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reachedBottom ? '我已阅读并同意以上条款' : '请滑动阅读至底部后勾选',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: reachedBottom ? AppColors.text2Of(context) : AppColors.text4Of(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            AppPrimaryButton(
              label: '确认',
              onPressed: agreed ? onConfirm : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 章节内要点（圆点列表）
class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.moss,
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
