import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../data/models/models.dart';
import '../providers/auth_provider.dart';
import '../data/auth_service.dart';
import '../presentation/widgets/role_segment.dart';
import '../presentation/widgets/auth_field.dart';
import '../presentation/widgets/captcha_widget.dart';

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
  final GlobalKey<CaptchaWidgetState> _captchaKey = GlobalKey();

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
      _role == UserRole.student ? AppColors.primaryOf(context) : AppColors.vermilionOf(context);

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
    // 切换登录方式时刷新图形验证码，避免使用过期/无效题目
    _captchaKey.currentState?.refresh();
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
      // 验证码校验失败或发送失败，刷新图形验证码
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
    if (_loggingIn) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loggingIn = true;
      _error = null;
    });

    late final ({UserModel? user, String? token, String? refreshToken, String? error}) result;
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
      // P1：角色不匹配时 token 尚未持久化（AuthApi 不再自动持久化），
      // 无需清理。仅提示用户身份不一致。
      setState(() {
        _loggingIn = false;
        _error = '该账号身份为「${_roleLabel(user.role)}」，与所选「${_roleLabel(_role)}」不一致';
      });
      AppFeedback.error(context, _error!);
      return;
    }

    // P0：角色校验通过后原子提交会话（setSession 在互斥锁内一次性写 access+refresh + user）
    // loginWith 在 token 持久化失败时抛异常（不吞），此处必须 try/catch，
    // 否则 _loggingIn 卡在 true 且可能残留半会话（token 已部分写入但 user 未保存）。
    try {
      await ref.read(authProvider.notifier).loginWith(
            user,
            token: result.token,
            refreshToken: result.refreshToken,
          );
    } catch (e) {
      if (!mounted) return;
      // 持久化失败：重置 loading、提示用户、确保无残留半会话
      // loginWith 内部 setSession 失败时不会保存 user，但可能已部分写入 token——
      // 调用 clearSession 确保清理（幂等操作，无副作用）
      await ApiClient.clearSession();
      setState(() {
        _loggingIn = false;
        _error = '登录凭证保存失败，请重试';
      });
      AppFeedback.error(context, _error!);
      return;
    }
    if (!mounted) return;
    context.goNamed(
      user.role == UserRole.student
          ? RouteNames.studentHome
          : RouteNames.teacherHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = _roleColor;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: Stack(
        children: [
          // 精致克制的背景氛围：右上/左下两团柔光，不喧宾夺主
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    brandColor.withValues(alpha: 0.10),
                    brandColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    brandColor.withValues(alpha: 0.06),
                    brandColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrand(),
                  const SizedBox(height: 32),
                  _buildCard(),
                  const SizedBox(height: 18),
                  _buildRegisterLink(),
                  const SizedBox(height: 18),
                  const MedicalDisclaimer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 品牌区：展示真实产品 logo（assets/images/brand-logo.png）
  Widget _buildBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // logo 容器：圆润白底 + 细边 + 淡影，整体克制精致
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.55),
            ),
            boxShadow: AppShadow.leveled(level: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.asset(
              'assets/images/brand-logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_hospital_outlined,
                size: 28,
                color: AppColors.primaryOf(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 7),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  const EyebrowText('SIGN IN · 内科教研协同'),
                  const SizedBox(height: 6),
                  Text(
                    '登录',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
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
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.pushNamed(
                          RouteNames.forgotPassword,
                          extra: _role,
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            '忘记密码？',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _roleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    CaptchaWidget(
                      key: _captchaKey,
                      accentColor: _roleColor,
                    ),
                    const SizedBox(height: 16),
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

                  const SizedBox(height: 22),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildLoginButton() {
    return AppGradientButton(
      label: '登  录',
      color: _roleColor,
      loading: _loggingIn,
      onPressed: _submit,
      height: 52,
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
        borderRadius: BorderRadius.circular(AppRadius.full),
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
            borderRadius: BorderRadius.circular(AppRadius.full),
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
          color: disabled ? AppColors.ink4 : AppColors.primaryOf(context),
        ),
      ),
    );
  }
}
