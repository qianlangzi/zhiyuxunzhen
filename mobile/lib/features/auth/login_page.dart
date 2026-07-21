import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/widgets/widgets.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    this.initialUsername,
    this.registrationMessage,
  });

  final String? initialUsername;
  final String? registrationMessage;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  final TextEditingController _passwordCtrl =
      TextEditingController(text: '123456');
  final TextEditingController _phoneCtrl =
      TextEditingController(text: '18500000002');
  final TextEditingController _codeCtrl = TextEditingController();

  String _mode = 'password';
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(
      text: widget.initialUsername?.isNotEmpty == true
          ? widget.initialUsername
          : 'student01',
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthController controller = ref.read(authControllerProvider.notifier);
    if (_mode == 'password') {
      await controller.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      await controller.loginWithSms(
        phone: _phoneCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
      );
    }
    if (!mounted) return;
    if (ref.read(authControllerProvider).isLoggedIn) {
      context.go('/');
    }
  }

  Future<void> _requestCode() async {
    final String phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ref.read(authControllerProvider.notifier).clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的 11 位手机号')),
      );
      return;
    }
    final String? devCode =
        await ref.read(authControllerProvider.notifier).requestSmsCode(phone);
    if (!mounted || devCode == null) return;
    _codeCtrl.text = devCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('开发验证码：$devCode，已自动填入')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Image.asset(
                          'assets/images/brand-logo.png',
                          width: 58,
                          height: 58,
                          semanticLabel: '智愈寻真 Logo',
                        ),
                        const SizedBox(width: AppDimens.grid4),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('智愈寻真', style: AppTextStyles.h1),
                              SizedBox(height: AppDimens.grid),
                              Text('内科临床教学与训练', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.grid8),
                    const Text('登录工作区', style: AppTextStyles.h2),
                    const SizedBox(height: AppDimens.grid2),
                    const Text(
                      '系统会根据账号的真实身份进入学生端或教师端。',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppDimens.grid6),
                    if (widget.registrationMessage != null) ...<Widget>[
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(AppDimens.grid3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            border: Border.all(color: AppColors.success),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusControl),
                          ),
                          child: Text(
                            widget.registrationMessage!,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.success),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.grid4),
                    ],
                    ZySegmentedControl<String>(
                      value: _mode,
                      segments: const <ZySegment<String>>[
                        ZySegment<String>(value: 'password', label: '账号密码'),
                        ZySegment<String>(value: 'sms', label: '手机验证码'),
                      ],
                      onChanged: state.loading
                          ? (_) {}
                          : (String value) {
                              setState(() => _mode = value);
                              _formKey.currentState?.reset();
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearError();
                            },
                    ),
                    const SizedBox(height: AppDimens.grid6),
                    if (_mode == 'password') ...<Widget>[
                      TextFormField(
                        controller: _usernameCtrl,
                        enabled: !state.loading,
                        autocorrect: false,
                        autofillHints: const <String>[AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '账号'),
                        validator: (String? value) =>
                            value == null || value.trim().isEmpty
                                ? '请输入账号'
                                : null,
                      ),
                      const SizedBox(height: AppDimens.grid4),
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !state.loading,
                        obscureText: _obscure,
                        autofillHints: const <String>[AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: '密码',
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            tooltip: _obscure ? '显示密码' : '隐藏密码',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (String? value) =>
                            value == null || value.isEmpty ? '请输入密码' : null,
                      ),
                    ] else ...<Widget>[
                      TextFormField(
                        controller: _phoneCtrl,
                        enabled: !state.loading,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '手机号'),
                        validator: (String? value) => RegExp(r'^1[3-9]\d{9}$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : '请输入正确的 11 位手机号',
                      ),
                      const SizedBox(height: AppDimens.grid4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _codeCtrl,
                              enabled: !state.loading,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              decoration:
                                  const InputDecoration(labelText: '6 位验证码'),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (String? value) =>
                                  RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                      ? null
                                      : '请输入 6 位验证码',
                            ),
                          ),
                          const SizedBox(width: AppDimens.grid3),
                          SizedBox(
                            width: 112,
                            height: AppDimens.buttonHeight,
                            child: OutlinedButton(
                              onPressed: state.loading ? null : _requestCode,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('获取验证码', maxLines: 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (state.error != null) ...<Widget>[
                      const SizedBox(height: AppDimens.grid4),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.error!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.risk),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimens.grid6),
                    SizedBox(
                      height: AppDimens.buttonHeight,
                      child: FilledButton(
                        onPressed: state.loading ? null : _submit,
                        child: state.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('登录'),
                      ),
                    ),
                    const SizedBox(height: AppDimens.grid4),
                    TextButton.icon(
                      onPressed: state.loading
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearError();
                              context.go('/register');
                            },
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('没有账号？注册'),
                    ),
                    const SizedBox(height: AppDimens.grid2),
                    const Text(
                      '演示账号：student01 / teacher01，密码 123456',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
