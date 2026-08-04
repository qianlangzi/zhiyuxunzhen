import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../data/models/models.dart';
import '../data/auth_service.dart';
import '../presentation/widgets/role_segment.dart';
import '../presentation/widgets/auth_field.dart';

/// 独立注册页
///
/// 与登录页共用同一套视觉语言。收集：角色、用户名、密码、手机号，并**强制手机号验证**
/// （必须先获取验证码、且验证码校验一致才能注册）。注册成功后自动返回登录页。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _auth = const AuthService();
  final _formKey = GlobalKey<FormState>();

  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();

  UserRole _role = UserRole.student;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    _phoneCtl.dispose();
    _codeCtl.dispose();
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
      AppFeedback.error(context, '请输入有效的手机号');
      return;
    }
    setState(() => _sendingCode = true);
    final result = await _auth.requestCode(phone);
    if (!mounted) return;
    setState(() => _sendingCode = false);
    if (result.error != null) {
      AppFeedback.error(context, result.error!);
      return;
    }
    setState(() => _countdown = 60);
    _startCountdown();
    if (result.code.isNotEmpty) {
      AppFeedback.info(context, '演示验证码：${result.code}（真实环境将发送至手机）');
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final result = await _auth.register(
        phone: _phoneCtl.text,
        code: _codeCtl.text,
        username: _usernameCtl.text,
        password: _passwordCtl.text,
        role: _role,
      );
      if (!mounted) return;
      if (result.error != null) {
        AppFeedback.error(context, result.error!);
        setState(() => _submitting = false);
        return;
      }
      AppFeedback.success(context, '注册成功，请返回登录');
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, '注册失败：$e');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '创建账号',
              onBack: () {
                if (!_submitting) context.pop();
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(
                  top: 8,
                  bottom: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EyebrowText('CREATE ACCOUNT · 注册'),
                      const SizedBox(height: 6),
                      Text(
                        '填写信息以创建您的账号（注册需手机号验证）',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text3Of(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 角色选择
                      Text(
                        '注册身份',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text2Of(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RoleSegment(
                        role: _role,
                        onChanged: (r) => setState(() => _role = r),
                        studentIcon: Icons.school_outlined,
                        teacherIcon: Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 20),

                      AuthField(
                        label: '用户名',
                        required: true,
                        controller: _usernameCtl,
                        hint: '至少 3 位，登录时使用',
                        accentColor: _roleColor,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请设置用户名';
                          if (s.length < 3) return '用户名至少 3 位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AuthField(
                        label: '密码',
                        required: true,
                        controller: _passwordCtl,
                        hint: '至少 6 位',
                        accentColor: _roleColor,
                        obscure: _obscure1,
                        onToggleObscure: () =>
                            setState(() => _obscure1 = !_obscure1),
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) return '请设置密码';
                          if (s.length < 6) return '密码至少 6 位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AuthField(
                        label: '确认密码',
                        required: true,
                        controller: _confirmCtl,
                        hint: '再次输入密码',
                        accentColor: _roleColor,
                        obscure: _obscure2,
                        onToggleObscure: () =>
                            setState(() => _obscure2 = !_obscure2),
                        validator: (v) =>
                            (v != _passwordCtl.text) ? '两次输入的密码不一致' : null,
                      ),
                      const SizedBox(height: 16),

                      // 手机号 + 验证码（强制验证）
                      AuthField(
                        label: '手机号',
                        required: true,
                        controller: _phoneCtl,
                        hint: '用于接收验证码，必填',
                        accentColor: _roleColor,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请输入手机号';
                          if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(s)) {
                            return '手机号格式不正确';
                          }
                          return null;
                        },
                        suffix: _CodeButton(
                          countdown: _countdown,
                          sending: _sendingCode,
                          onPressed: _sendCode,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthField(
                        label: '验证码',
                        required: true,
                        controller: _codeCtl,
                        hint: '6 位验证码',
                        accentColor: _roleColor,
                        keyboardType: TextInputType.number,
                        inputFormatters: [LengthLimitingTextInputFormatter(6)],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请输入验证码';
                          if (!_auth.verifyCode(_phoneCtl.text, s)) {
                            return '验证码错误、已过期或未获取';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '注册必须完成手机号验证：点击「获取验证码」后，输入下发的验证码（演示环境验证码会在页面提示）。',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.text4Of(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Color get _roleColor =>
      _role == UserRole.student ? AppColors.primaryOf(context) : AppColors.vermilion;

  Widget _buildActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: AppPrimaryButton(
        label: _submitting ? '注册中…' : '注 册',
        fullWidth: true,
        onPressed: _submitting ? null : _submit,
      ),
    );
  }
}

/// 验证码「获取」按钮（含倒计时）
class _CodeButton extends StatelessWidget {
  const _CodeButton({
    required this.countdown,
    required this.sending,
    required this.onPressed,
  });

  final int countdown;
  final bool sending;
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
          color: disabled ? AppColors.text4Of(context) : AppColors.primaryOf(context),
        ),
      ),
    );
  }
}
