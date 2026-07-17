import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .login(_usernameCtrl.text, _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryHover],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text('寻',
                          style: GoogleFonts.figtree(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('智愈寻真',
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text('内科教研协同智能体平台',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 48),

                  // Username
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      hintText: '学生直接输入 / 教师前缀 t_',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v?.isEmpty == true ? '请输入用户名' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) < 1 ? '请输入密码' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),

                  // Error
                  if (authState.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.destructiveLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(authState.error!,
                          style: const TextStyle(
                              color: AppColors.destructive, fontSize: 14)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Login button
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _login,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('登 录'),
                  ),
                  const SizedBox(height: 32),

                  // Hint
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👨‍🎓 学生端：输入任意用户名+密码即可体验',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text('👨‍🏫 教师端：用户名以 t_ 开头 (例: t_zhang)',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
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
