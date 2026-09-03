import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_preset.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/common/settings/settings_provider.dart';
import '../../../features/student/companion/ai_companion_prefs_provider.dart';
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

                  // ========== 主题 ==========
                  _ThemePresetSection(
                    settings: settings,
                    onSelected: (p) =>
                        notifier.update(settings.copyWith(themePreset: p)),
                  ),

                  // ========== 显示 ==========
                  _Section(
                    title: '显示',
                    children: [
                      _DarkModeRow(
                        value: settings.darkModeSetting,
                        onChanged: (v) => notifier
                            .update(settings.copyWith(darkModeSetting: v)),
                      ),
                      _TextScaleRow(
                        value: settings.textScale,
                        onChanged: (scale) =>
                            notifier.update(settings.copyWith(textScale: scale)),
                      ),
                    ],
                  ),

                  // ========== 账号与安全 ==========
                  _Section(
                    title: '账号与安全',
                    children: [
                      _ActionRow(
                        icon: Icons.lock_outline,
                        color: AppColors.primaryOf(context),
                        label: '修改密码',
                        subtitle: '修改登录密码，修改后旧密码立即失效',
                        onTap: () =>
                            context.pushNamed(RouteNames.changePasswordActive),
                      ),
                    ],
                  ),

                  // ========== AI 伴学（仅学生：语气档位 + 记忆开关，服务端持久化） ==========
                  if (isStudent) const _AiCompanionSection(),

                  // ========== 缓存 ==========
                  _Section(
                    title: '缓存',
                    children: [
                      _ActionRow(
                        icon: Icons.cleaning_services_outlined,
                        color: AppColors.text3Of(context),
                        label: '清除本地缓存',
                        subtitle: '清理临时文件与离线缓存',
                        onTap: () => _confirmClearCache(context, notifier),
                      ),
                    ],
                  ),

                  // ========== 隐私与政策 ==========
                  _Section(
                    title: '隐私与政策',
                    children: [
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mossTintOf(context),
                  border: Border.all(color: AppColors.moss3Of(context)),
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

/// 文字大小选择行（分段切换，全局生效）
class _TextScaleRow extends StatelessWidget {
  const _TextScaleRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        Icons.text_fields,
        color: AppColors.text2Of(context),
        size: 20,
      ),
      title: Text(
        '文字大小',
        style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
      ),
      subtitle: Text(
        '调整应用整体文字显示大小',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.text4Of(context),
          height: 1.4,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.ruleSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (scale, label) in TextScale.options)
              GestureDetector(
                onTap: () => onChanged(scale),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (value - scale).abs() < 0.001
                        ? AppColors.primaryOf(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (value - scale).abs() < 0.001
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: (value - scale).abs() < 0.001
                          ? AppColors.onPrimaryOf(context)
                          : AppColors.text3Of(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 深色模式选择行（三态分段：浅色 / 深色 / 自动）
///
/// 原为单个「深色模式」开关，主题与系统时间完全脱钩：关着开关时凌晨打开 App，
/// 学生端首页按时间切了夜景，二级页却仍走 lightPalette（米白底 + 深墨字），
/// 视觉严重割裂。
///
/// 改为三态后，「自动」会让 **整个 App** 在 18:00~6:00 切到 darkPalette，
/// 所有页面文字自动变成近白色（darkText #EDF1EF，对比度约 16:1），
/// 不需要逐页适配深色。
class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow({required this.value, required this.onChanged});

  final DarkModeSetting value;
  final ValueChanged<DarkModeSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        Icons.dark_mode_outlined,
        color: AppColors.indigoOf(context),
        size: 20,
      ),
      title: Text(
        '深色模式',
        style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
      ),
      subtitle: Text(
        value.desc,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.text4Of(context),
          height: 1.4,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.ruleSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in DarkModeSetting.values)
              GestureDetector(
                onTap: () => onChanged(option),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: value == option
                        ? AppColors.primaryOf(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          value == option ? FontWeight.w600 : FontWeight.w400,
                      color: value == option
                          ? AppColors.onPrimaryOf(context)
                          : AppColors.text3Of(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// AI 伴学设置分区（仅学生端展示）
///
/// 语气档位（4 选 1）+ 记忆开关 + 记忆管理入口。
/// 偏好服务端持久化（user_preference），换设备一致；仅学伴链路生效。
class _AiCompanionSection extends ConsumerStatefulWidget {
  const _AiCompanionSection();

  @override
  ConsumerState<_AiCompanionSection> createState() => _AiCompanionSectionState();
}

class _AiCompanionSectionState extends ConsumerState<_AiCompanionSection> {
  @override
  void initState() {
    super.initState();
    // 分区可见才拉取服务端偏好（教师端不挂载本组件，避免无效请求）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(aiCompanionPrefsProvider.notifier).ensureLoaded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(aiCompanionPrefsProvider);
    final notifier = ref.read(aiCompanionPrefsProvider.notifier);

    return _Section(
      title: 'AI 伴学',
      children: [
        _CompanionToneTile(
          value: prefs.tone,
          onChanged: (t) => notifier.setTone(t),
        ),
        _CompanionMemoryTile(
          value: prefs.memoryEnabled,
          onChanged: (v) => notifier.setMemoryEnabled(v),
        ),
        _ActionRow(
          icon: Icons.psychology_outlined,
          color: AppColors.primaryOf(context),
          label: '管理 AI 记忆',
          subtitle: '查看与删除 AI 记住的关于你的内容',
          onTap: () => context.pushNamed(RouteNames.memoryManage),
        ),
      ],
    );
  }
}

/// AI 语气选择行（4 档分段：温暖鼓励 / 严谨专业 / 活泼轻松 / 简洁高效）
class _CompanionToneTile extends StatelessWidget {
  const _CompanionToneTile({required this.value, required this.onChanged});

  final CompanionTone value;
  final ValueChanged<CompanionTone> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          leading: Icon(
            Icons.record_voice_over_outlined,
            color: AppColors.indigoOf(context),
            size: 20,
          ),
          title: Text(
            'AI 语气',
            style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
          ),
          subtitle: Text(
            'AI 学伴与你交流的风格（标准 SP 问诊不受影响）',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.text4Of(context),
              height: 1.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Row(
            children: [
              for (final tone in CompanionTone.values) ...[
                if (tone != CompanionTone.values.first) const SizedBox(width: 8),
                Expanded(child: _toneChip(context, tone)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _toneChip(BuildContext context, CompanionTone tone) {
    final selected = value == tone;
    return GestureDetector(
      onTap: () => onChanged(tone),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOf(context)
              : AppColors.ruleSoftOf(context),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          tone.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.onPrimaryOf(context)
                : AppColors.text3Of(context),
          ),
        ),
      ),
    );
  }
}

/// AI 记忆开关行（关闭后学伴不再记录/召回长期记忆）
class _CompanionMemoryTile extends StatelessWidget {
  const _CompanionMemoryTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        Icons.auto_awesome_outlined,
        color: AppColors.primaryOf(context),
        size: 20,
      ),
      title: Text(
        'AI 记忆',
        style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
      ),
      subtitle: Text(
        value ? '已开启：AI 学伴会记住聊天内容，跨会话用上' : '已关闭：AI 学伴不会记录你的聊天',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.text4Of(context),
          height: 1.4,
        ),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
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

/// 主题预设选择区
///
/// 三套个性化色板，点击即全局切换（通过 ThemePaletteExtension 驱动
/// AppColors.*Of 与 AppTheme 一起联动），并随设置持久化。
class _ThemePresetSection extends StatelessWidget {
  const _ThemePresetSection({required this.settings, required this.onSelected});

  final AppSettings settings;
  final ValueChanged<ThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    const presets = ThemePreset.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '主题',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06,
                color: Color(0xFF6B7270),
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: Row(
              children: [
                for (var i = 0; i < presets.length; i++) ...[
                  if (i != 0) const SizedBox(width: 12),
                  Expanded(
                    child: _ThemePresetCard(
                      preset: presets[i],
                      selected: settings.themePreset == presets[i],
                      onTap: () => onSelected(presets[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 当前预设说明
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              _descOf(context, settings.themePreset),
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.text4Of(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _descOf(BuildContext context, ThemePreset preset) =>
      preset.desc.isEmpty ? preset.subtitle : preset.desc;
}

/// 单个预设卡片：色板预览 + 选中态
class _ThemePresetCard extends StatelessWidget {
  const _ThemePresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pal = preset.palette(dark: dark);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? preset.lightPalette.primary : pal.surfaceEdge,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 色板预览条
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal.bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: pal.surfaceEdge, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  for (final c in pal.heat)
                    Container(
                      width: 8,
                      height: 18,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: preset.lightPalette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pal.surface,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: pal.text,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: preset.lightPalette.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
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
          foregroundColor: AppColors.vermilionOf(context),
          backgroundColor: AppColors.vermilionSoftOf(context).withValues(alpha: 0.35),
          side: BorderSide(color: AppColors.vermilionSoftOf(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
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
