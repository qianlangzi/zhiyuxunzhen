import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../data/models/models.dart';
import '../providers/auth_provider.dart';
import '../data/auth_service.dart';
import '../presentation/widgets/role_segment.dart';
import '../presentation/widgets/auth_field.dart';

/// 登录方式
enum _LoginMethod { password, code }

/// 登录页
///
/// 1. 用户**自行选择身份**（学生 / 教师）。
/// 2. 选择登录方式：账号密码 或 短信验证码。
/// 3. 登录成功后校验「所选身份」与「账号身份」一致，按角色跳转到对应首页。
/// 4. 底部小字「还没有账号？立即注册」跳转独立注册页（注册必须手机号验证）。
///
/// 布局说明：标准 Scaffold + SafeArea + SingleChildScrollView，不依赖任何会导致
/// 首屏空白的整页动画 / 强制撑满居中 / 初始透明写法，确保各机型稳定可见。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _auth = const AuthService();
  final _formKey = GlobalKey<FormState>();

  UserRole _role = UserRole.student;
  _LoginMethod _method = _LoginMethod.password;

  final _accountCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();

  bool _obscure = true;
  int _countdown = 0;
  bool _sendingCode = false;
  bool _loggingIn = false;
  String? _error;
  Timer? _timer;

  Color get _roleColor =>
      _role == UserRole.student ? AppColors.moss : AppColors.vermilion;

  @override
  void dispose() {
    _timer?.cancel();
    _accountCtl.dispose();
    _passwordCtl.dispose();
    _phoneCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  void _setRole(UserRole role) => setState(() => _role = role);

  void _setMethod(_LoginMethod method) {
    if (method == _method) return;
    setState(() {
      _method = method;
      _error = null;
    });
  }

  String _roleLabel(UserRole r) => r == UserRole.student ? '学生' : '教师';

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
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    final result = _auth.requestCode(phone);
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _sendingCode = false;
        _error = result.error;
      });
      AppFeedback.error(context, result.error!);
      return;
    }
    setState(() {
      _sendingCode = false;
      _countdown = 60;
    });
    _startCountdown();
    AppFeedback.info(context, '演示验证码：${result.code}（真实环境将发送至手机）');
  }

  Future<void> _submit() async {
    if (_loggingIn) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loggingIn = true;
      _error = null;
    });

    late final ({UserModel? user, String? error}) result;
    if (_method == _LoginMethod.password) {
      result = await _auth.loginByPassword(
        account: _accountCtl.text,
        password: _passwordCtl.text,
        role: _role,
      );
    } else {
      result = await _auth.loginByCode(
        phone: _phoneCtl.text,
        code: _codeCtl.text,
        role: _role,
      );
    }
    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _loggingIn = false;
        _error = result.error;
      });
      AppFeedback.error(context, result.error!);
      return;
    }

    final user = result.user!;
    if (user.role != _role) {
      setState(() {
        _loggingIn = false;
        _error = '该账号身份为「${_roleLabel(user.role)}」，与所选「${_roleLabel(_role)}」不一致';
      });
      AppFeedback.error(context, _error!);
      return;
    }

    await ref.read(authProvider.notifier).loginWith(user);
    if (!mounted) return;
    context.goNamed(
      user.role == UserRole.student
          ? RouteNames.studentHome
          : RouteNames.teacherHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBrand(),
              const SizedBox(height: 28),
              _buildCard(),
              const SizedBox(height: 18),
              _buildRegisterLink(),
              const SizedBox(height: 18),
              const MedicalDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  /// 品牌区（朴素标题，回退到美化前状态）
  Widget _buildBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'NotoSerifSC',
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 6),
        const MonoText(
          'ZHIYU XUNZHEN · INTERNAL MEDICINE',
          fontSize: 10,
          letterSpacing: 0.18,
        ),
      ],
    );
  }

  /// 登录卡片（普通 Container，默认完全可见）
  Widget _buildCard() {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: _roleColor),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EyebrowText('SIGN IN · 内科教研协同'),
                  const SizedBox(height: 6),
                  const Text(
                    '登录',
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: -0.01,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '选择身份，以账号进入你的教研空间',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink3,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 身份选择
                  const Text(
                    '选择身份',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RoleSegment(
                    role: _role,
                    onChanged: _setRole,
                    studentIcon: Icons.school_outlined,
                    teacherIcon: Icons.menu_book_outlined,
                  ),
                  const SizedBox(height: 20),

                  // 登录方式切换（简单分段，无动画隐患）
                  _MethodToggle(
                    method: _method,
                    onChanged: _setMethod,
                  ),
                  const SizedBox(height: 20),

                  if (_method == _LoginMethod.password) ...[
                    AuthField(
                      label: '账号',
                      required: true,
                      controller: _accountCtl,
                      hint: '用户名或手机号',
                      accentColor: _roleColor,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入账号' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: '密码',
                      required: true,
                      controller: _passwordCtl,
                      hint: '请输入密码',
                      accentColor: _roleColor,
                      obscure: _obscure,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入密码' : null,
                    ),
                  ] else ...[
                    AuthField(
                      label: '手机号',
                      required: true,
                      controller: _phoneCtl,
                      hint: '用于接收验证码',
                      accentColor: _roleColor,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [LengthLimitingTextInputFormatter(11)],
                      suffix: _CodeButton(
                        countdown: _countdown,
                        sending: _sendingCode,
                        onPressed: _sendCode,
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return '请输入手机号';
                        // 测试模式：不校验手机号格式
                        // if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(s)) {
                        //   return '手机号格式不正确';
                        // }
                        return null;
                      },
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
                        // 测试模式：不校验验证码正确性
                        // if (!_auth.verifyCode(_phoneCtl.text, s)) {
                        //   return '验证码错误、已过期或未获取';
                        // }
                        return null;
                      },
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.vermilion.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.vermilion,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loggingIn ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _roleColor,
          foregroundColor: AppColors.paper,
          disabledBackgroundColor: _roleColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        child: _loggingIn
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.paper,
                ),
              )
            : const Text('登 录'),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.ink3,
          ),
          children: [
            const TextSpan(text: '还没有账号？'),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => context.pushNamed(RouteNames.register),
                child: Text(
                  '立即注册',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _roleColor,
                    decoration: TextDecoration.underline,
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

/// 登录方式分段（简单 Row 切换，无动画，确保稳定渲染）
class _MethodToggle extends StatelessWidget {
  const _MethodToggle({
    required this.method,
    required this.onChanged,
  });

  final _LoginMethod method;
  final ValueChanged<_LoginMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceEdgeOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _MethodLabel(
            label: '账号密码',
            active: method == _LoginMethod.password,
            onTap: () => onChanged(_LoginMethod.password),
          ),
          _MethodLabel(
            label: '验证码',
            active: method == _LoginMethod.code,
            onTap: () => onChanged(_LoginMethod.code),
          ),
        ],
      ),
    );
  }
}

class _MethodLabel extends StatelessWidget {
  const _MethodLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: active
                    ? AppColors.textOf(context)
                    : AppColors.text3Of(context),
              ),
            ),
          ),
        ),
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
          color: disabled ? AppColors.ink4 : AppColors.moss,
        ),
      ),
    );
  }
}
