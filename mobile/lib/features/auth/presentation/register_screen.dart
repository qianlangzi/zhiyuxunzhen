import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../data/models/models.dart';
import '../data/auth_service.dart';
import '../data/auth_api.dart';
import '../presentation/widgets/role_segment.dart';
import '../presentation/widgets/auth_field.dart';
import '../presentation/widgets/captcha_widget.dart';

/// 独立注册页
///
/// 与登录页共用同一套视觉语言。按角色动态展示字段：
/// - 公共：角色、姓名、账号、密码、确认密码、学校、手机号、图形验证码、短信验证码
/// - 学生：年级（下拉）、班级
/// - 教师：资质编号、所属科室、资质证书上传
///
/// 注册强制手机号验证：必须先完成图形验证码 → 获取短信验证码 → 输入验证码。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _auth = const AuthService();
  final _formKey = GlobalKey<FormState>();
  final _captchaKey = GlobalKey<CaptchaWidgetState>();
  final ImagePicker _picker = ImagePicker();

  // 文本控制器
  final _realNameCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _schoolCtl = TextEditingController();
  final _classCtl = TextEditingController();
  final _certNoCtl = TextEditingController();
  final _deptCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();

  UserRole _role = UserRole.student;
  String? _grade; // 学生年级下拉值
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _timer;

  // 资质证书上传状态
  String? _certImageUrl;
  String? _certFileName;
  bool _uploadingCert = false;

  /// 年级选项
  static const List<String> _gradeOptions = [
    '大一',
    '大二',
    '大三',
    '大四',
    '大五',
    '研一',
    '研二',
    '研三',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _realNameCtl.dispose();
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    _schoolCtl.dispose();
    _classCtl.dispose();
    _certNoCtl.dispose();
    _deptCtl.dispose();
    _phoneCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  Color get _roleColor =>
      _role == UserRole.student
          ? AppColors.primaryOf(context)
          : AppColors.vermilion;

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

  void _setRole(UserRole r) {
    if (r == _role) return;
    setState(() {
      _role = r;
      // 切换角色时清空角色专属字段，避免脏数据被提交
      _grade = null;
      _classCtl.clear();
      _certNoCtl.clear();
      _deptCtl.clear();
      _certImageUrl = null;
      _certFileName = null;
    });
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _countdown > 0) return;
    final phone = _phoneCtl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      AppFeedback.error(context, '请输入有效的手机号');
      return;
    }
    final captcha = _captchaKey.currentState?.current();
    if (captcha == null) {
      AppFeedback.error(context, '请先完成图形验证');
      return;
    }
    setState(() => _sendingCode = true);
    final result = await _auth.requestCode(
      phone,
      captchaId: captcha.captchaId,
      captchaAnswer: captcha.answer,
    );
    if (!mounted) return;
    setState(() => _sendingCode = false);
    if (result.error != null) {
      AppFeedback.error(context, result.error!);
      // 验证码校验失败或发送失败，刷新图形验证码
      _captchaKey.currentState?.refresh();
      return;
    }
    setState(() => _countdown = 60);
    _startCountdown();
    if (result.code.isNotEmpty) {
      AppFeedback.info(context, '演示验证码：${result.code}（真实环境将发送至手机）');
    }
  }

  Future<void> _pickAndUploadCert() async {
    if (_uploadingCert) return;
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
    );
    if (x == null) return;
    final file = File(x.path);
    setState(() => _uploadingCert = true);
    try {
      final result = await AuthApi().uploadCertificate(file);
      if (!mounted) return;
      if (result.error != null || result.url == null) {
        AppFeedback.error(context, result.error ?? '上传失败');
      } else {
        setState(() {
          _certImageUrl = result.url;
          _certFileName = x.name;
        });
        AppFeedback.success(context, '证书上传成功');
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, '上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingCert = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    // 校验图形验证码
    final captcha = _captchaKey.currentState?.current();
    if (captcha == null) {
      AppFeedback.error(context, '请先完成图形验证');
      return;
    }
    // 教师必须上传资质证书
    if (_role == UserRole.teacher &&
        (_certImageUrl == null || _certImageUrl!.isEmpty)) {
      AppFeedback.error(context, '请上传资质证书');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _auth.register(
        phone: _phoneCtl.text.trim(),
        code: _codeCtl.text.trim(),
        username: _usernameCtl.text.trim(),
        password: _passwordCtl.text,
        role: _role,
        realName: _realNameCtl.text.trim(),
        schoolName: _schoolCtl.text.trim(),
        grade: _role == UserRole.student ? _grade : null,
        className: _role == UserRole.student ? _classCtl.text.trim() : null,
        certificateNo:
            _role == UserRole.teacher ? _certNoCtl.text.trim() : null,
        department: _role == UserRole.teacher ? _deptCtl.text.trim() : null,
        teacherCertificateImage:
            _role == UserRole.teacher ? _certImageUrl : null,
      );
      if (!mounted) return;
      if (result.error != null) {
        AppFeedback.error(context, result.error!);
        setState(() => _submitting = false);
        return;
      }
      if (_role == UserRole.teacher) {
        AppFeedback.success(context, '注册申请已提交，请等待审核');
      } else {
        AppFeedback.success(context, '注册成功，请返回登录');
      }
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

                      // 1. 角色选择
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
                        onChanged: _setRole,
                        studentIcon: Icons.school_outlined,
                        teacherIcon: Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 20),

                      // 2. 姓名
                      AuthField(
                        label: '姓名',
                        required: true,
                        controller: _realNameCtl,
                        hint: '真实姓名，2-50位',
                        accentColor: _roleColor,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                        ],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请输入姓名';
                          if (s.length < 2 || s.length > 50) {
                            return '姓名为2-50位';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. 账号
                      AuthField(
                        label: '账号',
                        required: true,
                        controller: _usernameCtl,
                        hint: '4-32位字母数字下划线',
                        accentColor: _roleColor,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(32),
                        ],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请设置账号';
                          if (!RegExp(r'^[A-Za-z0-9_]{4,32}$').hasMatch(s)) {
                            return '4-32位字母数字下划线';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 4. 密码
                      AuthField(
                        label: '密码',
                        required: true,
                        controller: _passwordCtl,
                        hint: '8位以上，需含字母和数字',
                        accentColor: _roleColor,
                        obscure: _obscure1,
                        onToggleObscure: () =>
                            setState(() => _obscure1 = !_obscure1),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(64),
                        ],
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) return '请设置密码';
                          if (s.length < 8) return '密码至少 8 位';
                          if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$')
                              .hasMatch(s)) {
                            return '密码需同时包含字母和数字';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 5. 确认密码
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

                      // 6. 学校
                      AuthField(
                        label: '学校',
                        required: true,
                        controller: _schoolCtl,
                        hint: '所在学校',
                        accentColor: _roleColor,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请输入学校';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 7. 学生专属：年级 + 班级
                      if (_role == UserRole.student) ...[
                        _buildGradeField(context),
                        const SizedBox(height: 16),
                        AuthField(
                          label: '班级',
                          required: true,
                          controller: _classCtl,
                          hint: '如 临床2101班',
                          accentColor: _roleColor,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(50),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return '请输入班级';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 8. 教师专属：资质编号 + 科室 + 证书上传
                      if (_role == UserRole.teacher) ...[
                        AuthField(
                          label: '资质编号',
                          required: true,
                          controller: _certNoCtl,
                          hint: '教师资质编号',
                          accentColor: _roleColor,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return '请输入资质编号';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          label: '所属科室',
                          required: true,
                          controller: _deptCtl,
                          hint: '如 心血管内科',
                          accentColor: _roleColor,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return '请输入所属科室';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildCertUploadField(context),
                        const SizedBox(height: 16),
                      ],

                      // 9. 手机号
                      AuthField(
                        label: '手机号',
                        required: true,
                        controller: _phoneCtl,
                        hint: '用于接收验证码',
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
                          accentColor: _roleColor,
                          onPressed: _sendCode,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 10. 图形验证码
                      CaptchaWidget(
                        key: _captchaKey,
                        accentColor: _roleColor,
                      ),
                      const SizedBox(height: 16),

                      // 11. 短信验证码
                      AuthField(
                        label: '短信验证码',
                        required: true,
                        controller: _codeCtl,
                        hint: '6 位验证码',
                        accentColor: _roleColor,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(6),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请输入验证码';
                          if (!RegExp(r'^\d{6}$').hasMatch(s)) {
                            return '验证码为6位数字';
                          }
                          if (!_auth.verifyCode(_phoneCtl.text, s)) {
                            return '验证码错误、已过期或未获取';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '注册必须完成手机号验证：先作答图形验证码，点击「获取验证码」后输入下发短信验证码（演示环境验证码会在页面提示）。',
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

  /// 学生年级下拉（样式对齐 AuthField）
  Widget _buildGradeField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: [
              Text(
                '年级',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2Of(context),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(fontSize: 13, color: AppColors.vermilion),
              ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _grade,
          decoration: InputDecoration(
            hintText: '请选择年级',
            hintStyle: TextStyle(
              color: AppColors.text4Of(context),
              fontSize: 13,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.surfaceOf(context),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.surfaceEdgeOf(context),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _roleColor, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.vermilion, width: 1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: AppColors.vermilion, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textOf(context),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.text3Of(context),
          ),
          items: _gradeOptions
              .map(
                (g) => DropdownMenuItem<String>(
                  value: g,
                  child: Text(g),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _grade = v),
          validator: (v) =>
              (v == null || v.isEmpty) ? '请选择年级' : null,
        ),
      ],
    );
  }

  /// 教师资质证书上传区域
  Widget _buildCertUploadField(BuildContext context) {
    final uploaded = _certImageUrl != null && _certImageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: [
              Text(
                '资质证书',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2Of(context),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(fontSize: 13, color: AppColors.vermilion),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _uploadingCert ? null : _pickAndUploadCert,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: uploaded ? _roleColor : AppColors.surfaceEdgeOf(context),
                width: uploaded ? 1.5 : 1,
              ),
            ),
            child: _buildCertContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCertContent(BuildContext context) {
    if (_uploadingCert) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _roleColor,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '上传中…',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text3Of(context),
            ),
          ),
        ],
      );
    }
    if (_certFileName != null && _certImageUrl != null) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: _roleColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _certFileName!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textOf(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '重新上传',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text3Of(context),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(
          Icons.upload_file_outlined,
          size: 18,
          color: AppColors.text3Of(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '点击上传资质证书（jpg/png/pdf，≤5MB）',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text3Of(context),
            ),
          ),
        ),
      ],
    );
  }

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
    required this.accentColor,
  });

  final int countdown;
  final bool sending;
  final VoidCallback onPressed;
  final Color accentColor;

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
          color: disabled ? AppColors.text4Of(context) : accentColor,
        ),
      ),
    );
  }
}
