import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_model.dart';
import '../../shared/widgets/widgets.dart';
import 'auth_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _realNameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final TextEditingController _certificateCtrl = TextEditingController();
  final TextEditingController _departmentCtrl = TextEditingController();

  int _role = AppConfig.roleStudent;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  bool get _isTeacher => _role == AppConfig.roleTeacher;

  @override
  void dispose() {
    _realNameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _certificateCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final String phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final RegistrationResult? result =
        await ref.read(authControllerProvider.notifier).register(
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text,
              realName: _realNameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              code: _codeCtrl.text.trim(),
              role: _role,
              certificateNo: _isTeacher ? _certificateCtrl.text.trim() : null,
              department: _isTeacher ? _departmentCtrl.text.trim() : null,
            );
    if (!mounted || result == null) return;
    context.go(
      Uri(
        path: '/login',
        queryParameters: <String, String>{
          'username': result.username,
          'message': result.message,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '返回登录',
          onPressed: state.loading ? null : () => context.go('/login'),
        ),
        title: const Text('创建账号'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid4,
                AppDimens.pagePadding,
                AppDimens.grid8,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('选择你的身份', style: AppTextStyles.h2),
                    const SizedBox(height: AppDimens.grid2),
                    const Text(
                      '身份决定可使用的工作区。教师账号必须通过资质审核。',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppDimens.grid4),
                    ZySegmentedControl<int>(
                      value: _role,
                      segments: const <ZySegment<int>>[
                        ZySegment<int>(
                          value: AppConfig.roleStudent,
                          label: '学生',
                          icon: Icons.school_outlined,
                        ),
                        ZySegment<int>(
                          value: AppConfig.roleTeacher,
                          label: '教师',
                          icon: Icons.badge_outlined,
                        ),
                      ],
                      onChanged: state.loading
                          ? (_) {}
                          : (int role) {
                              setState(() => _role = role);
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearError();
                            },
                    ),
                    if (_isTeacher) ...<Widget>[
                      const SizedBox(height: AppDimens.grid3),
                      Text(
                        '教师注册后进入待审核状态，审核通过前不能使用教师业务功能。',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ],
                    const SizedBox(height: AppDimens.grid6),
                    TextFormField(
                      controller: _realNameCtrl,
                      enabled: !state.loading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.name],
                      decoration: const InputDecoration(labelText: '真实姓名'),
                      validator: (String? value) {
                        final int length = value?.trim().length ?? 0;
                        return length >= 2 && length <= 50
                            ? null
                            : '请输入 2-50 位真实姓名';
                      },
                    ),
                    const SizedBox(height: AppDimens.grid4),
                    TextFormField(
                      controller: _usernameCtrl,
                      enabled: !state.loading,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.newUsername],
                      decoration: const InputDecoration(
                        labelText: '账号',
                        helperText: '4-32 位字母、数字或下划线',
                      ),
                      validator: (String? value) =>
                          RegExp(r'^[A-Za-z0-9_]{4,32}$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : '账号格式不正确',
                    ),
                    const SizedBox(height: AppDimens.grid4),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: !state.loading,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[
                        AutofillHints.telephoneNumber
                      ],
                      decoration: const InputDecoration(labelText: '手机号'),
                      validator: (String? value) =>
                          RegExp(r'^1[3-9]\d{9}$').hasMatch(value?.trim() ?? '')
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
                            textInputAction: TextInputAction.next,
                            decoration:
                                const InputDecoration(labelText: '6 位验证码'),
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
                    const SizedBox(height: AppDimens.grid4),
                    _PasswordField(
                      controller: _passwordCtrl,
                      enabled: !state.loading,
                      obscureText: _obscurePassword,
                      label: '设置密码',
                      helperText: '至少 8 位，同时包含字母和数字',
                      tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                      onToggle: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      validator: (String? value) {
                        final String password = value ?? '';
                        return password.length >= 8 &&
                                password.length <= 64 &&
                                RegExp(r'[A-Za-z]').hasMatch(password) &&
                                RegExp(r'\d').hasMatch(password)
                            ? null
                            : '密码须为 8-64 位并包含字母和数字';
                      },
                    ),
                    const SizedBox(height: AppDimens.grid4),
                    _PasswordField(
                      controller: _confirmPasswordCtrl,
                      enabled: !state.loading,
                      obscureText: _obscureConfirmation,
                      label: '确认密码',
                      tooltip: _obscureConfirmation ? '显示确认密码' : '隐藏确认密码',
                      textInputAction: _isTeacher
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onToggle: () => setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      ),
                      validator: (String? value) =>
                          value == _passwordCtrl.text ? null : '两次输入的密码不一致',
                    ),
                    if (_isTeacher) ...<Widget>[
                      const SizedBox(height: AppDimens.grid6),
                      const Text('教师资质', style: AppTextStyles.h3),
                      const SizedBox(height: AppDimens.grid4),
                      TextFormField(
                        controller: _certificateCtrl,
                        enabled: !state.loading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '执业医师证号或教师工号',
                        ),
                        validator: (String? value) => _isTeacher &&
                                (value == null || value.trim().isEmpty)
                            ? '请填写教师资质编号'
                            : null,
                      ),
                      const SizedBox(height: AppDimens.grid4),
                      TextFormField(
                        controller: _departmentCtrl,
                        enabled: !state.loading,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: '所属科室'),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (String? value) => _isTeacher &&
                                (value == null || value.trim().isEmpty)
                            ? '请填写所属科室'
                            : null,
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
                      child: FilledButton.icon(
                        onPressed: state.loading ? null : _submit,
                        icon: state.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(_isTeacher ? '提交教师注册申请' : '注册学生账号'),
                      ),
                    ),
                    const SizedBox(height: AppDimens.grid3),
                    TextButton(
                      onPressed:
                          state.loading ? null : () => context.go('/login'),
                      child: const Text('已有账号，返回登录'),
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.enabled,
    required this.obscureText,
    required this.label,
    required this.tooltip,
    required this.onToggle,
    required this.validator,
    this.helperText,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool obscureText;
  final String label;
  final String? helperText;
  final String tooltip;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      autocorrect: false,
      textInputAction: textInputAction,
      autofillHints: const <String>[AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          tooltip: tooltip,
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
