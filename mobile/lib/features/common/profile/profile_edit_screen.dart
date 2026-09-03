import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/models.dart';

/// 个人信息编辑页（学生/教师通用）
///
/// 学生端展示「学号」必填字段；教师端无学号，故隐藏该字段。
class ProfileEditScreen extends ConsumerStatefulWidget {
const   ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameCtl = TextEditingController();
  final _studentNumberCtl = TextEditingController();
  final _contactCtl = TextEditingController();
  final _majorCtl = TextEditingController();
  final _gradeCtl = TextEditingController();

  String? _avatarPath;
  late final bool _isStudent;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _isStudent = user?.role == UserRole.student;
    _nicknameCtl.text = user?.nickname ?? user?.realName ?? '';
    _studentNumberCtl.text = user?.studentNumber ?? '';
    _contactCtl.text = user?.contact ?? '';
    _majorCtl.text = user?.major ?? '';
    _gradeCtl.text = user?.grade ?? '';
    _avatarPath = user?.avatarPath;
  }

  @override
  void dispose() {
    _nicknameCtl.dispose();
    _studentNumberCtl.dispose();
    _contactCtl.dispose();
    _majorCtl.dispose();
    _gradeCtl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '请填写$field';
    }
    return null;
  }

  String? _contactValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // 选填
    final phone = RegExp(r'^1[3-9]\d{9}$');
    final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (phone.hasMatch(v) || email.hasMatch(v)) return null;
    return '联系方式格式不正确（手机或邮箱）';
  }

  Future<void> _pickAvatar() async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _AvatarSourceSheet(hasAvatar: _avatarPath != null),
    );
    if (action == null) return;

    if (action == _AvatarAction.remove) {
      setState(() => _avatarPath = null);
      return;
    }

    final source =
        action == _AvatarAction.camera ? ImageSource.camera : ImageSource.gallery;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null && mounted) {
        setState(() => _avatarPath = picked.path);
      }
    } catch (e) {
      log('头像选择失败: $e', name: 'profile_edit');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像选择失败：$e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return; // 校验失败：错误信息已由 TextFormField 就地展示
    }
    final user = ref.read(authProvider).user;
    if (user == null) {
      context.pop();
      return;
    }
    final updated = user.copyWith(
      nickname: _nicknameCtl.text.trim(),
      avatarPath: _avatarPath,
      contact: _contactCtl.text.trim().isEmpty ? null : _contactCtl.text.trim(),
      // 教师无学号：保持为 null
      studentNumber: _isStudent ? _studentNumberCtl.text.trim() : null,
      major: _majorCtl.text.trim().isEmpty ? null : _majorCtl.text.trim(),
      grade: _gradeCtl.text.trim().isEmpty ? null : _gradeCtl.text.trim(),
    );
    await ref.read(authProvider.notifier).updateProfile(updated);
    if (mounted) context.pop(); // 取消/返回均不在此写入，保存已写入 authProvider
  }

  @override
  Widget build(BuildContext context) {
    final nameForInitial = _nicknameCtl.text.trim().isNotEmpty
        ? _nicknameCtl.text.trim()
        : (ref.read(authProvider).user?.realName ?? '?');
    final initial = nameForInitial.isNotEmpty ? nameForInitial[0] : '?';

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '编辑资料',
              onBack: () => context.pop(),
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
                      _buildAvatar(initial),
                      const SizedBox(height: 24),
                      _Field(
                        label: '昵称',
                        required: true,
                        controller: _nicknameCtl,
                        hint: '展示名称',
                        validator: (v) => _requiredValidator(v, '昵称'),
                      ),
                      const SizedBox(height: 16),
                      if (_isStudent) ...[
                        _Field(
                          label: '学号',
                          required: true,
                          controller: _studentNumberCtl,
                          hint: '如 2021302014',
                          keyboardType: TextInputType.number,
                          validator: (v) => _requiredValidator(v, '学号'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _Field(
                        label: '联系方式',
                        required: false,
                        controller: _contactCtl,
                        hint: '手机号或邮箱（选填）',
                        keyboardType: TextInputType.emailAddress,
                        validator: _contactValidator,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: '专业',
                        required: false,
                        controller: _majorCtl,
                        hint: '如 临床医学（选填）',
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: '年级',
                        required: false,
                        controller: _gradeCtl,
                        hint: '如 大四（选填）',
                      ),
                      const SizedBox(height: 8),
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

  Widget _buildAvatar(String initial) {
    return Center(
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                border: Border.all(color: AppColors.mossSoftOf(context)),
                shape: BoxShape.circle,
                image: (_avatarPath != null && File(_avatarPath!).existsSync())
                    ? DecorationImage(
                        image: FileImage(File(_avatarPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: (_avatarPath == null || !File(_avatarPath!).existsSync())
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOf(context),
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.onPrimaryOf(context), width: 2),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 15,
                  color: AppColors.onPrimaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
   decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: AppGhostButton(
              label: '取消',
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AppPrimaryButton(
              label: '保存',
              fullWidth: true,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// 表单字段（标签 + 必填星号 + 输入框）
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: [
              Text(
                label,
        style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2Of(context),
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(fontSize: 13, color: AppColors.vermilionOf(context)),
                ),
              ],
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
     style: TextStyle(fontSize: 14, color: AppColors.textOf(context)),
          decoration: InputDecoration(
            hintText: hint,
      hintStyle: TextStyle(color: AppColors.text4Of(context), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ),
      ],
    );
  }
}

/// 头像来源选择底部弹窗
enum _AvatarAction { camera, gallery, remove }

class _AvatarSourceSheet extends StatelessWidget {
  const _AvatarSourceSheet({this.hasAvatar = false});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: AppColors.primaryOf(context)),
      title: Text(
              '拍照',
              style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
            ),
            onTap: () => Navigator.of(context).pop(_AvatarAction.camera),
          ),
          ListTile(
            leading:
                Icon(Icons.photo_library_outlined, color: AppColors.primaryOf(context)),
      title: Text(
              '从相册选择',
              style: TextStyle(fontSize: 14, color: AppColors.text2Of(context)),
            ),
            onTap: () => Navigator.of(context).pop(_AvatarAction.gallery),
          ),
          if (hasAvatar)
            ListTile(
              leading:
                  Icon(Icons.delete_outline, color: AppColors.vermilionOf(context)),
              title: Text(
                '移除头像',
                style: TextStyle(fontSize: 14, color: AppColors.vermilionOf(context)),
              ),
              onTap: () => Navigator.of(context).pop(_AvatarAction.remove),
            ),
          ListTile(
      leading: Icon(Icons.close, color: AppColors.text3Of(context)),
      title: Text(
              '取消',
              style: TextStyle(fontSize: 14, color: AppColors.text3Of(context)),
            ),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
