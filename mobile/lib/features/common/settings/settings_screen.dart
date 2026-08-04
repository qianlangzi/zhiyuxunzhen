import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/common/settings/settings_provider.dart';
import '../../../routes/route_names.dart';
import '../../../data/models/models.dart';

/// 设置页（学生/教师通用）
///
/// 包含：账户概览、通知、训练与缓存、隐私与安全、通用，以及「退出登录」。
/// 开关项通过 [settingsProvider] 本地持久化；退出登录调用 [AuthNotifier.logout]。
class SettingsScreen extends ConsumerWidget {
const   SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authProvider).user;
    final isStudent = user?.role == UserRole.student;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
       AppBackAppBar(title: '设置'),
            Expanded(
              child: ListView(
        padding: EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  _AccountCard(
                    user: user,
                    onTap: () => context.pushNamed(
                      isStudent
                          ? RouteNames.profileEdit
                          : RouteNames.profileEditTeacher,
                    ),
                  ),

                  // ========== 通知 ==========
                  _Section(
                    title: '通知',
                    children: [
                      _SwitchRow(
                        icon: Icons.notifications_outlined,
                        color: AppColors.indigo,
                        label: '消息推送',
                        subtitle: '接收问诊、批阅与系统通知',
                        value: settings.pushNotifications,
                        onChanged: (v) =>
                            notifier.update(settings.copyWith(pushNotifications: v)),
                      ),
                      _SwitchRow(
                        icon: Icons.event_repeat_outlined,
                        color: AppColors.primaryOf(context),
                        label: '训练提醒',
                        subtitle: '每日一例与复习计划提醒',
                        value: settings.trainingReminder,
                        onChanged: (v) =>
                            notifier.update(settings.copyWith(trainingReminder: v)),
                      ),
                      _SwitchRow(
                        icon: Icons.volume_up_outlined,
                        color: AppColors.amber,
                        label: '提示音',
                        subtitle: '操作与消息提示音效',
                        value: settings.soundEnabled,
                        onChanged: (v) =>
                            notifier.update(settings.copyWith(soundEnabled: v)),
                      ),
                    ],
                  ),

                  // ========== 训练与缓存 ==========
                  _Section(
                    title: '训练与缓存',
                    children: [
                      _SwitchRow(
                        icon: Icons.cloud_download_outlined,
                        color: AppColors.primaryOf(context),
                        label: '离线缓存病例',
                        subtitle: '缓存病例数据，弱网环境可用',
                        value: settings.offlineCache,
                        onChanged: (v) =>
                            notifier.update(settings.copyWith(offlineCache: v)),
                      ),
                      _SwitchRow(
                        icon: Icons.wifi_outlined,
                        color: AppColors.indigo,
                        label: '仅 Wi-Fi 自动下载',
                        subtitle: '避免消耗移动流量',
                        value: settings.wifiAutoDownload,
                        onChanged: (v) => notifier
                            .update(settings.copyWith(wifiAutoDownload: v)),
                      ),
                      _ActionRow(
                        icon: Icons.cleaning_services_outlined,
                        color: AppColors.text3Of(context),
                        label: '清除本地缓存',
                        subtitle: '清理临时文件与离线缓存',
                        onTap: () => _confirmClearCache(context, notifier),
                      ),
                    ],
                  ),

                  // ========== 隐私与安全 ==========
                  _Section(
                    title: '隐私与安全',
                    children: [
                      _SwitchRow(
                        icon: Icons.fingerprint,
                        color: AppColors.primaryOf(context),
                        label: '生物识别登录',
                        subtitle: '使用指纹 / Face ID 快速登录',
                        value: settings.biometricLogin,
                        onChanged: (v) async {
                          if (v) {
                            final ok = await notifier.setBiometricLogin(
                              true,
                              user?.role,
                            );
                            if (!ok && context.mounted) {
                              AppFeedback.info(
                                context,
                                '设备暂不支持生物识别，或验证未通过',
                              );
                            }
                          } else {
                            await notifier.setBiometricLogin(false, null);
                          }
                        },
                      ),
                      _ActionRow(
                        icon: Icons.policy_outlined,
                        color: AppColors.text3Of(context),
                        label: '隐私政策',
                        onTap: () => context.pushNamed(RouteNames.privacyPolicy),
                      ),
                      _ActionRow(
                        icon: Icons.description_outlined,
                        color: AppColors.text3Of(context),
                        label: '用户协议',
                        onTap: () => context.pushNamed(RouteNames.userAgreement),
                      ),
                    ],
                  ),

                  // ========== 通用 ==========
                  _Section(
                    title: '通用',
                    children: [
                      _SwitchRow(
                        icon: Icons.dark_mode_outlined,
                        color: AppColors.indigo,
                        label: '深色模式',
                        subtitle: '夜间护眼主题',
                        value: settings.darkMode,
                        onChanged: (v) =>
                            notifier.update(settings.copyWith(darkMode: v)),
                      ),
                      _ActionRow(
                        icon: Icons.info_outline,
                        color: AppColors.text3Of(context),
                        label: '关于智愈寻真',
                        onTap: () => context.pushNamed(RouteNames.about),
                      ),
                    ],
                  ),

                  // ========== 退出登录 ==========
                  Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: _LogoutButton(
                      onTap: () => _confirmLogout(context, ref),
                    ),
                  ),
                  Center(
                    child: MonoText(
                      '${AppConstants.appName} v${AppConstants.appVersion}',
                      fontSize: 11,
                      color: AppColors.text4Of(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 退出登录：二次确认后清空本地用户态并返回登录页
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: '退出登录',
      content: '退出后需要重新登录才能使用完整功能，确定要退出吗？',
      confirmText: '退出登录',
      cancelText: '取消',
      danger: true,
    );
    if (!confirmed) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.goNamed(RouteNames.login);
  }

  /// 清除本地缓存：二次确认后真实清理临时/离线文件，并展示释放大小
  Future<void> _confirmClearCache(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: '清除本地缓存',
      content: '将删除应用临时文件与已离线缓存的数据，操作不可恢复。',
      confirmText: '清除',
      danger: true,
    );
    if (!confirmed) return;

    final bytes = await notifier.clearCache();
    if (!context.mounted) return;

    if (bytes > 0) {
      final mb = bytes / 1024 / 1024;
      AppFeedback.success(
        context,
        mb >= 0.1
            ? '已释放 ${mb.toStringAsFixed(1)} MB 缓存'
            : '已释放 ${(bytes / 1024).toStringAsFixed(0)} KB 缓存',
      );
    } else {
      AppFeedback.success(context, '本地缓存已清理');
    }
  }
}

/// 顶部账户概览卡片
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.onTap});

  final UserModel? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.nickname ?? user?.realName ?? '未登录';
    final initial = name.isNotEmpty ? name[0] : '?';
    final isStudent = user?.role == UserRole.student;
    final roleLabel = isStudent ? '学生' : '教师';
    final sub =
        user?.studentNumber ?? user?.contact ?? (isStudent ? '学号未填写' : '联系方式未填写');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: AppPaper(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mossTintOf(context),
                  border: Border.all(color: AppColors.moss3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
           style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    MonoText('$roleLabel · $sub', fontSize: 11),
                  ],
                ),
              ),
        Icon(Icons.chevron_right, size: 18, color: AppColors.text4Of(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置分区容器（标题 + 卡片列表，行间分割线）
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
       style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06,
                color: AppColors.text3Of(context),
              ),
            ),
          ),
          AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      color: AppColors.ruleSoftOf(context),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 带开关的设置行
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
    style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
       style: TextStyle(
                fontSize: 11,
                color: AppColors.text4Of(context),
                height: 1.4,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primaryOf(context),
        activeThumbColor: AppColors.onPrimaryOf(context),
      ),
    );
  }
}

/// 可点击跳转的设置行
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
    style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
       style: TextStyle(
                fontSize: 11,
                color: AppColors.text4Of(context),
                height: 1.4,
              ),
            )
          : null,
   trailing: Icon(Icons.chevron_right, size: 16, color: AppColors.text4Of(context)),
      onTap: onTap,
    );
  }
}

/// 退出登录按钮
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.vermilion,
          backgroundColor: AppColors.vermilionSoftOf(context).withValues(alpha: 0.35),
          side: BorderSide(color: AppColors.vermilionSoftOf(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_outlined, size: 18),
            SizedBox(width: 8),
            Text(
              '退出登录',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
