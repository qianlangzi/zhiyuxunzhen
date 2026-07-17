import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师病例配置页：分区表单 + 已配置病例登记。
class CaseConfigPage extends ConsumerStatefulWidget {
  const CaseConfigPage({super.key});

  @override
  ConsumerState<CaseConfigPage> createState() => _CaseConfigPageState();
}

class _CaseConfigPageState extends ConsumerState<CaseConfigPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _chiefCtrl = TextEditingController();
  final TextEditingController _diagnosisCtrl = TextEditingController();
  final TextEditingController _communicationCtrl = TextEditingController();
  final TextEditingController _cooperationCtrl = TextEditingController();
  final TextEditingController _tagsCtrl = TextEditingController();
  final TextEditingController _difficultyCtrl = TextEditingController();
  final TextEditingController _previewCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _ageCtrl.dispose();
    _chiefCtrl.dispose();
    _diagnosisCtrl.dispose();
    _communicationCtrl.dispose();
    _cooperationCtrl.dispose();
    _tagsCtrl.dispose();
    _difficultyCtrl.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('演示配置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CaseRepository repo = ref.watch(caseRepositoryProvider);
    final List<CaseModel> cases = repo.all();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                key: const ValueKey<String>('case-config-scroll'),
                padding: const EdgeInsets.only(bottom: AppDimens.grid8),
                children: <Widget>[
                  const ClinicalHeader(
                    productName: '智愈寻真',
                    title: '病例配置',
                    identityLabel: '教师工作台 · 训练病例',
                  ),
                  _FormSection(
                    title: '基本信息',
                    description: '定义病例身份与临床起点。',
                    children: <Widget>[
                      _LabeledField(
                        fieldKey: const ValueKey<String>('case-config-title'),
                        label: '病例标题',
                        controller: _titleCtrl,
                        hint: '例如：胸痛三联鉴别',
                        validatorMsg: '请输入病例标题',
                      ),
                      _LabeledField(
                        label: '患者年龄',
                        controller: _ageCtrl,
                        hint: '例如：55 岁',
                      ),
                      _LabeledField(
                        label: '主诉',
                        controller: _chiefCtrl,
                        hint: '一句话描述主要症状',
                      ),
                      _LabeledField(
                        label: '初步诊断',
                        controller: _diagnosisCtrl,
                        hint: '可选',
                      ),
                    ],
                  ),
                  _FormSection(
                    title: '模拟病人',
                    description: '描述沟通方式与配合程度。',
                    children: <Widget>[
                      _LabeledField(
                        label: '沟通特点',
                        controller: _communicationCtrl,
                        hint: '例如：表述含糊、需追问',
                      ),
                      _LabeledField(
                        label: '配合程度',
                        controller: _cooperationCtrl,
                        hint: '例如：配合 / 略抗拒',
                      ),
                    ],
                  ),
                  _FormSection(
                    title: '教学目标',
                    description: '标注训练难度与知识目标。',
                    children: <Widget>[
                      _LabeledField(
                        label: '知识点标签',
                        controller: _tagsCtrl,
                        hint: '多个标签用逗号分隔',
                      ),
                      _LabeledField(
                        label: '难度',
                        controller: _difficultyCtrl,
                        hint: '基础 / 标准 / 进阶 / 高阶',
                      ),
                    ],
                  ),
                  _FormSection(
                    title: '预览',
                    description: '核对学生进入训练前看到的信息。',
                    children: <Widget>[
                      _LabeledField(
                        label: '学生将看到的简短病例摘要',
                        controller: _previewCtrl,
                        hint: '学生进入训练时看到的内容',
                        maxLines: 3,
                      ),
                    ],
                  ),
                  _ConfiguredCases(cases: cases),
                ],
              ),
            ),
            ZyStickyActionBar(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存配置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 表单分组：以规则线和留白组织字段，不额外套卡片。
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding, AppDimens.grid4, AppDimens.pagePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClinicalSectionHeader(
            title: title,
            description: description,
          ),
          const SizedBox(height: AppDimens.grid3),
          ...children,
        ],
      ),
    );
  }
}

/// 字段标签始终位于输入框上方，输入后也不会消失。
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.fieldKey,
    this.validatorMsg,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final Key? fieldKey;
  final String? validatorMsg;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppDimens.grid2),
          Semantics(
            label: label,
            textField: true,
            child: TextFormField(
              key: fieldKey,
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(hintText: hint),
              validator: (String? value) {
                if (validatorMsg == null) return null;
                if (value == null || value.trim().isEmpty) return validatorMsg;
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 已配置病例登记：记录行 + 病例广场入口。
class _ConfiguredCases extends StatelessWidget {
  const _ConfiguredCases({required this.cases});

  final List<CaseModel> cases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding, AppDimens.grid6, AppDimens.pagePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClinicalSectionHeader(
            title: '已配置病例',
            description: '当前病例库中的训练条目。',
            action: TextButton(
              onPressed: () => context.push('/teacher/market'),
              child: const Text('病例广场'),
            ),
          ),
          const SizedBox(height: AppDimens.grid2),
          if (cases.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.grid5),
              child: ZyEmptyState(
                icon: Icons.description_outlined,
                title: '还没有配置病例',
                detail: '在上方填写并保存即可生成第一份病例。',
              ),
            )
          else
            ...List<Widget>.generate(cases.length, (int index) {
              return _ConfiguredRow(
                item: cases[index],
                showDivider: index != cases.length - 1,
              );
            }),
        ],
      ),
    );
  }
}

class _ConfiguredRow extends StatelessWidget {
  const _ConfiguredRow({
    required this.item,
    required this.showDivider,
  });

  final CaseModel item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return ClinicalRecordRow(
      leadingLabel: item.department,
      title: item.title,
      subtitle:
          '${item.difficulty} · ${item.duration} · ${item.referenceCount} 次引用',
      statusLabel: item.certified ? '已认证' : '草稿',
      statusTone: item.certified
          ? ClinicalEvidenceTone.success
          : ClinicalEvidenceTone.neutral,
      showDivider: showDivider,
    );
  }
}
