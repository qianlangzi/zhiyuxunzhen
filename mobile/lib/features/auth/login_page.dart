import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/widgets/widgets.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// 默认教师，保留演示行为
  String _role = 'teacher';
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _applyRoleDefaults();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _applyRoleDefaults() {
    _usernameCtrl.text = _role == 'teacher' ? 'teacher01' : 'student01';
    _passwordCtrl.text = '123456';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final AuthController controller = ref.read(authControllerProvider.notifier);
    await controller.login(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    final AuthState state = ref.read(authControllerProvider);
    if (state.isLoggedIn) {
      // 路由守卫会按角色重定向到对应工作区
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    AppDimens.grid8,
                    AppDimens.pagePadding,
                    AppDimens.grid6,
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Image.asset(
                                'assets/images/brand-logo.png',
                                width: 58,
                                height: 58,
                                fit: BoxFit.contain,
                                semanticLabel: '智愈寻真 Logo',
                              ),
                              const SizedBox(width: AppDimens.grid4),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '智愈寻真',
                                      style: AppTextStyles.h1,
                                    ),
                                    SizedBox(height: AppDimens.grid),
                                    Text(
                                      '内科临床教学与训练',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.grid6),
                          const Divider(
                            height: 1,
                            color: AppColors.ruleStrong,
                          ),
                          const SizedBox(height: AppDimens.grid8),
                          const Text(
                            '登录工作区',
                            style: AppTextStyles.h2,
                          ),
                          const SizedBox(height: AppDimens.grid2),
                          const Text(
                            '选择演示身份并使用对应账号进入。',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: AppDimens.grid6),
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  '演示身份',
                                  style: AppTextStyles.bodyStrong,
                                ),
                              ),
                              SizedBox(
                                width: 176,
                                child: ZySegmentedControl<String>(
                                  value: _role,
                                  segments: const <ZySegment<String>>[
                                    ZySegment<String>(
                                      value: 'student',
                                      label: '学生',
                                    ),
                                    ZySegment<String>(
                                      value: 'teacher',
                                      label: '教师',
                                    ),
                                  ],
                                  onChanged: (String value) {
                                    if (state.loading) return;
                                    setState(() {
                                      _role = value;
                                      _formKey.currentState?.reset();
                                      _applyRoleDefaults();
                                      ref
                                          .read(
                                            authControllerProvider.notifier,
                                          )
                                          .clearError();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.grid6),
                          TextFormField(
                            controller: _usernameCtrl,
                            enabled: !state.loading,
                            autocorrect: false,
                            autofillHints: const <String>[
                              AutofillHints.username
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '账号',
                            ),
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
                            autofillHints: const <String>[
                              AutofillHints.password
                            ],
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
                          if (state.error != null) ...<Widget>[
                            const SizedBox(height: AppDimens.grid4),
                            Semantics(
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: AppColors.risk,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.grid2),
                                  Expanded(
                                    child: Text(
                                      state.error!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.risk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDimens.grid6),
                          SizedBox(
                            height: AppDimens.buttonHeight,
                            child: FilledButton(
                              onPressed: state.loading ? null : _submit,
                              child: state.loading
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('正在登录'),
                                      ],
                                    )
                                  : const Text('登录'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
