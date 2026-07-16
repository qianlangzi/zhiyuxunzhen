import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!)),
      );
    } else if (state.isLoggedIn) {
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
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Image.asset(
                            'assets/images/brand-logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                            semanticLabel: '知语寻真 Logo',
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '知语寻真',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h1,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '内科临床训练平台',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 32),
                          ZySegmentedControl<String>(
                            value: _role,
                            segments: const <ZySegment<String>>[
                              ZySegment<String>(value: 'student', label: '学生'),
                              ZySegment<String>(value: 'teacher', label: '教师'),
                            ],
                            onChanged: (String value) {
                              setState(() {
                                _role = value;
                                _applyRoleDefaults();
                                ref
                                    .read(authControllerProvider.notifier)
                                    .clearError();
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _usernameCtrl,
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
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
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            validator: (String? value) =>
                                value == null || value.isEmpty ? '请输入密码' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
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
                          const SizedBox(height: 20),
                          Text(
                            '演示账号：${_role == 'teacher' ? 'teacher01' : 'student01'} / 123456',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '账号问题请联系所在教研组管理员',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption,
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
