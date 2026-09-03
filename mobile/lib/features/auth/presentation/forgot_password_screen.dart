import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../data/models/models.dart';
import '../data/auth_service.dart';
import '../presentation/widgets/auth_field.dart';
import '../presentation/widgets/captcha_widget.dart';

/// 忘记密码页
///
/// 用户忘记密码时，通过「绑定手机号 + 短信验证码」验权后直接重置密码，
/// 无需登录、无需旧密码。补齐了「收到不到短信 / 想不起密码就被锁死」的兜底链路。
///
/// 流程：
/// 1. 输入绑定的手机号并完成图形验证码
/// 2. 获取短信验证码（后端先校验图形验证码再发短信）
/// 3. 输入验证码 + 新密码 + 确认新密码
/// 4. 提交后由后端验权并重置，跳回登录页用新密码登录
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.role = UserRole.student});

  /// 来源角色（学生/教师），用于主题强调色，保持与登录页一致
  final UserRole role;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = const AuthService();
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<CaptchaWidgetState> _captchaKey = GlobalKey();

  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _newPwdCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _obscure = true;
  bool _obscure2 = true;
  int _countdown = 0;
  bool _sendingCode = false;
  bool _submitting = false;
  String? _error;
  Timer? _timer;

  Color get _accent =>
      widget.role == UserRole.student
          ? AppColors.primaryOf(context)
          : AppColors.vermilionOf(context);

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtl.dispose();
    _codeCtl.dispose();
    _newPwdCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = _countdown - 1;
      if (left <= 0) {
        t.cancel();
        _timer = null;
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown = left);
      }
    });
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _countdown > 0) return;
    final phone = _phoneCtl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = '请输入有效的手机号');
      AppFeedback.error(context, '请输入有效的手机号');
      return;
    }
    final captcha = _captchaKey.currentState?.current();
    if (captcha == null) {
      AppFeedback.error(context, '请先完成图形验证');
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    final result = await _auth.requestCode(
      phone,
      captchaId: captcha.captchaId,
      captchaAnswer: captcha.answer,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _sendingCode = false;
        _error = result.error;
      });
      AppFeedback.error(context, result.error!);
      // 校验失败，刷新图形验证码
      _captchaKey.currentState?.refresh();
      return;
    }
    setState(() {
      _sendingCode = false;
      _countdown = 60;
    });
    _startCountdown();
    if (result.code.isNotEmpty) {
      AppFeedback.info(context, '演示验证码：${result.code}（真实环境将发送至手机）');
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await _auth.resetPassword(
      phone: _phoneCtl.text.trim(),
      code: _codeCtl.text.trim(),
      newPassword: _newPwdCtl.text,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _submitting = false;
        _error = result.error;
      });
      AppFeedback.error(context, result.error!);
      return;
    }
    AppFeedback.success(context, '密码重置成功，请用新密码登录');
    context.goNamed(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.bgOf(context),
        elevation: 0,
        leading: BackButton(color: AppColors.textOf(context)),
        title: const Text('忘记密码'),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textOf(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Text(
                    '通过绑定手机号接收验证码，验证成功后即可重置密码，无需登录。',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink3,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AuthField(
                  label: '手机号',
                  required: true,
                  controller: _phoneCtl,
                  hint: '注册时绑定的手机号',
                  accentColor: _accent,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [LengthLimitingTextInputFormatter(11)],
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return '请输入手机号';
                    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(s)) {
                      return '手机号格式不正确';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CaptchaWidget(key: _captchaKey, accentColor: _accent),
                const SizedBox(height: 16),
                AuthField(
                  label: '短信验证码',
                  required: true,
                  controller: _codeCtl,
                  hint: '6 位验证码',
                  accentColor: _accent,
                  keyboardType: TextInputType.number,
                  inputFormatters: [LengthLimitingTextInputFormatter(6)],
                  suffix: _CodeButton(
                    countdown: _countdown,
                    sending: _sendingCode,
                    accentColor: _accent,
                    onPressed: _sendCode,
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return '请输入短信验证码';
                    if (!RegExp(r'^\d{6}$').hasMatch(s)) return '验证码应为6位数字';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: '新密码',
                  required: true,
                  controller: _newPwdCtl,
                  hint: '8-32 位，须含字母和数字',
                  accentColor: _accent,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入新密码';
                    if (v.length < 8 || v.length > 32) return '密码长度需为 8-32 位';
                    if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                        !RegExp(r'\d').hasMatch(v)) {
                      return '密码必须同时包含字母和数字';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: '确认新密码',
                  required: true,
                  controller: _confirmCtl,
                  hint: '再次输入新密码',
                  accentColor: _accent,
                  obscure: _obscure2,
                  onToggleObscure: () => setState(() => _obscure2 = !_obscure2),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请再次输入新密码';
                    if (v != _newPwdCtl.text) return '两次输入的密码不一致';
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.vermilionOf(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.vermilionOf(context),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                AppGradientButton(
                  label: '重置密码',
                  color: _accent,
                  loading: _submitting,
                  onPressed: _submit,
                  height: 52,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「获取验证码」按钮（含倒计时）
class _CodeButton extends StatelessWidget {
  const _CodeButton({
    required this.countdown,
    required this.sending,
    required this.accentColor,
    required this.onPressed,
  });

  final int countdown;
  final bool sending;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = sending || countdown > 0;
    return TextButton(
      onPressed: disabled ? null : onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        sending
            ? '发送中'
            : countdown > 0
                ? '${countdown}s'
                : '获取验证码',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: disabled ? AppColors.ink4 : accentColor,
        ),
      ),
    );
  }
}