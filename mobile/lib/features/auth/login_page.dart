import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'auth_controller.dart';

/// 登录页：角色切换 + 表单 + mock 登录
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// teacher / student
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

    final AuthController controller =
        ref.read(authControllerProvider.notifier);
    await controller.login(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    final AuthState s = ref.read(authControllerProvider);
    if (s.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.error!)),
      );
    } else if (s.isLoggedIn) {
      // 路由守卫会自动重定向到对应首页
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.pagePaddingLarge,
            vertical: AppDimens.grid8,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  AppDimens.grid8 * 2,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildBrand(),
                  const SizedBox(height: AppDimens.grid8),
                  _buildHero(),
                  const SizedBox(height: AppDimens.grid6),
                  _buildRoleCard(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: AppColors.line, width: 1),
          ),
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/images/brand-logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: AppDimens.grid3),
        const Text(
          '智愈寻真',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.brandStrong,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '内科学',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: AppDimens.grid4),
        Text(
          '选择身份后进入对应页面。\n教师可以配置病例、批阅作业；学生可以完成问诊、提交大病历并查看 OSCE 反馈。',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(AuthState state) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.grid5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.aqua,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x2414B8A6),
                      blurRadius: 8,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.grid2),
              const Text(
                '选择身份',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandStrong,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Text(
            _role == 'teacher' ? '教师工作区' : '学生训练区',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppDimens.grid2),
          Text(
            _role == 'teacher'
                ? '配置模拟病人，分发作业，查看批阅与班级薄弱点。'
                : '选择病例，完成问诊、影像判读和大病历提交。',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimens.grid5),
          _buildRoleSwitch(),
          const SizedBox(height: AppDimens.grid5),
          _buildForm(state),
        ],
      ),
    );
  }

  Widget _buildRoleSwitch() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.grid2 - 2),
      decoration: BoxDecoration(
        color: const Color(0x140F766E),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _roleButton('teacher', '教师端', Icons.school_rounded)),
          Expanded(child: _roleButton('student', '学生端', Icons.menu_book_rounded)),
        ],
      ),
    );
  }

  Widget _roleButton(String role, String label, IconData icon) {
    final bool active = _role == role;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Material(
        key: ValueKey<String>('$role-$active'),
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _role = role;
              _applyRoleDefaults();
              ref.read(authControllerProvider.notifier).clearError();
            });
          },
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.grid4,
              vertical: AppDimens.grid3,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              boxShadow: active
                  ? <BoxShadow>[
                      const BoxShadow(
                        color: Color(0x330F766E),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: active ? Colors.white : AppColors.muted),
                const SizedBox(width: AppDimens.grid2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: _usernameCtrl,
          autocorrect: false,
          autofillHints: const <String>['username'],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '请输入用户名',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
          validator: (String? v) {
            if (v == null || v.trim().isEmpty) return '请输入用户名';
            return null;
          },
        ),
        const SizedBox(height: AppDimens.grid4),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          autofillHints: const <String>['password'],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: (String? v) {
            if (v == null || v.isEmpty) return '请输入密码';
            return null;
          },
        ),
        const SizedBox(height: AppDimens.grid5),
        SizedBox(
          height: AppDimens.buttonHeightLg,
          child: FilledButton(
            onPressed: state.loading ? null : _submit,
            child: state.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('登录 ${_role == 'teacher' ? '教师端' : '学生端'}'),
          ),
        ),
        const SizedBox(height: AppDimens.grid4),
        Container(
          padding: const EdgeInsets.all(AppDimens.grid3),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.brandStrong),
              const SizedBox(width: AppDimens.grid2),
              Expanded(
                child: Text(
                  '演示账号：teacher01 / student01，密码 123456',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandStrong,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
