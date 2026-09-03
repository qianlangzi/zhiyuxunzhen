import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/utils/feedback.dart';
import '../providers/auth_provider.dart';
import 'widgets/auth_field.dart';

/// 修改密码页
///
/// 支持两种场景：
/// - **强制改密**（[active] = false，默认）：后端 `mustChangePassword = true`
///   （导入学生首次登录），路由守卫强制重定向到本页，不提供返回按钮，
///   完成改密后清除标记并按角色进入学生/教师首页。
/// - **主动改密**（[active] = true）：设置页「修改密码」入口进入，可返回，
///   成功后回到上一页，不改变路由栈。
///
/// 新密码复杂度与后端保持一致（8-32 位、字母+数字混合）。
/// 改密成功后使用 `clearMustChangePassword()` 清除强制标记（非强制时无副作用）。
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.active = false,
  });

  /// 是否为主动改密（可返回、成功后回上一页）
  final bool active;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _oldPwdCtl = TextEditingController();
  final _newPwdCtl = TextEditingController();
  final _confirmPwdCtl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _oldPwdCtl.dispose();
    _newPwdCtl.dispose();
    _confirmPwdCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    // P0：由 AuthNotifier 统一执行改密（含代际 CAS + 原子 token 替换），
    // 防止迟到响应造成跨账号串号。AuthApi 不直接持久化 token。
    final result = await ref.read(authProvider.notifier).changePassword(
          oldPassword: _oldPwdCtl.text.trim(),
          newPassword: _newPwdCtl.text,
        );
    if (!mounted) return;
    if (result.ok) {
      AppFeedback.success(context, '密码修改成功');
      if (widget.active) {
        // 主动改密：返回到设置页
        context.pop();
      } else {
        // 强制改密：使用 go 清空路由栈，按角色进入对应首页
        final auth = ref.read(authProvider);
        final home = auth.isTeacher ? '/teacher' : '/student';
        context.go(home);
      }
    } else {
      AppFeedback.error(context, result.error ?? '密码修改失败');
    }
    if (mounted) setState(() => _submitting = false);
  }

  /// 退出登录：仅强制改密场景提供逃生出口，主动改密可正常返回故不需要
  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  /// 新密码复杂度校验：8-32 位、字母+数字混合（与后端规则一致）
  String? _validateNew(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return '请输入新密码';
    if (s.length < 8 || s.length > 32) return '密码长度需为 8-32 位';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    if (!hasLetter || !hasDigit) return '密码必须包含字母和数字';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').isEmpty) return '请再次输入新密码';
    if (v != _newPwdCtl.text) return '两次输入的密码不一致';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    final active = widget.active;
    // PopScope 禁止系统返回手势/返回键离开强制改密页（主动改密允许正常返回）。
    return PopScope(
      canPop: active,
      child: Scaffold(
      backgroundColor: AppColors.bgOf(context),
      // 主动改密提供返回按钮；强制改密不给返回按钮，避免绕过强制改密
      appBar: AppBar(
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 0,
        automaticallyImplyLeading: active,
        title: const Text('修改密码'),
        actions: [
          if (!active) ...[
            TextButton(
              // P0：改密提交期间禁用退出按钮，防止迟到响应造成跨账号串号
              // （代际 CAS 是主防护，禁用按钮是辅助）
              onPressed: _submitting ? null : _logout,
              child: Text(
                '退出登录',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.text2Of(context),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部提示
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amberOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 18, color: AppColors.amberOf(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          active
                              ? '请妥善保管新密码。修改后旧密码立即失效，其余设备需重新登录。'
                              : '检测到当前为首次登录或导入账号，为保障账号安全，请先修改初始密码后再继续使用。',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.text2Of(context),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                AuthField(
                  label: '原密码',
                  controller: _oldPwdCtl,
                  required: true,
                  hint: '请输入当前密码',
                  obscure: _obscureOld,
                  onToggleObscure: () =>
                      setState(() => _obscureOld = !_obscureOld),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '请输入原密码' : null,
                  accentColor: primary,
                ),
                const SizedBox(height: 16),

                AuthField(
                  label: '新密码',
                  controller: _newPwdCtl,
                  required: true,
                  hint: '8-32 位，字母与数字混合',
                  obscure: _obscureNew,
                  onToggleObscure: () =>
                      setState(() => _obscureNew = !_obscureNew),
                  validator: _validateNew,
                  accentColor: primary,
                ),
                const SizedBox(height: 16),

                AuthField(
                  label: '确认新密码',
                  controller: _confirmPwdCtl,
                  required: true,
                  hint: '请再次输入新密码',
                  obscure: _obscureConfirm,
                  onToggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: _validateConfirm,
                  accentColor: primary,
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimaryOf(context),
                            ),
                          )
                        : const Text(
                            '确认修改',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  active
                      ? '修改成功后请返回并使用新密码登录。'
                      : '修改成功后将自动进入首页。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.text3Of(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
