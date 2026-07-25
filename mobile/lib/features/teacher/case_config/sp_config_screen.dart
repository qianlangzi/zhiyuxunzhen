import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/app_router.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';

/// SP 配置台
class SpConfigScreen extends StatefulWidget {
  const SpConfigScreen({super.key});

  @override
  State<SpConfigScreen> createState() => _SpConfigScreenState();
}

class _SpConfigScreenState extends State<SpConfigScreen> {
  int _difficulty = 1; // 0=简单, 1=标准, 2=困难
  final _tags = ['ACS', '心电图判读', '鉴别诊断'];
  bool _saving = false;

  // 必填字段控制器（hoist 到 state，便于校验与读取）
  final _titleCtl = TextEditingController(text: '急性下壁心肌梗死 · 不典型表现');
  final _ageCtl = TextEditingController(text: '58');
  final _complaintCtl = TextEditingController(text: '胸痛 2 小时伴大汗');

  @override
  void dispose() {
    _titleCtl.dispose();
    _ageCtl.dispose();
    _complaintCtl.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_titleCtl.text.trim().isEmpty) return '请填写病例标题';
    if (_ageCtl.text.trim().isEmpty) return '请填写患者年龄';
    if (int.tryParse(_ageCtl.text.trim()) == null) return '年龄必须为数字';
    if (_complaintCtl.text.trim().isEmpty) return '请填写主诉';
    if (_tags.isEmpty) return '请至少添加 1 个知识点标签';
    return null;
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
  await Future.delayed( Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _saving = false);
    AppFeedback.success(context, '草稿已保存 · ${DateTime.now().toIso8601String().substring(11, 16)}');
  }

  Future<void> _publish() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: '发布作业',
      content: '将基于该病例创建作业并分发到班级，学生即可开始训练。确认发布？',
      confirmText: '发布',
    );
    if (!ok) return;
    setState(() => _saving = true);
    // 模拟发布（接入后端后替换为 POST /api/v1/teacher/assignments）
  await Future.delayed( Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _saving = false);
    AppFeedback.success(context, '作业已发布，已分发至心血管 03 班');
    context.goNamed(RouteNames.assignment);
  }

  Future<void> _preview() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    AppFeedback.info(context, '进入教师预览试诊（演示版）');
  await Future.delayed( Duration(milliseconds: 400));
    if (!mounted) return;
    context.pushNamed(RouteNames.chat);
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
              title: 'SP 配置台',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: AppGhostButton(
                label: _saving ? '处理中…' : '预览试诊',
                small: true,
                onPressed: _saving ? null : _preview,
              ),
            ),
            _buildSpHint(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDraftStatus(),
                    _buildBasicInfo(),
                    _buildPatientProfile(),
                    _buildHiddenDisease(),
                    _buildExamConfig(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppGhostButton(
                            label: _saving ? '保存中…' : '保存草稿',
                            fullWidth: true,
                            onPressed: _saving ? null : _saveDraft,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppPrimaryButton(
                            label: _saving ? '发布中…' : '发布作业',
                            fullWidth: true,
                            onPressed: _saving ? null : _publish,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpHint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mossTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.moss),
          const SizedBox(width: 8),
          Expanded(
            child: MonoText(
              'SP = 标准化病人（Standardized Patient）：模拟真实患者，供学生问诊与鉴别诊断训练。',
              fontSize: 11,
              color: AppColors.moss,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        border: Border.all(color: AppColors.amber, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
    children: [
          Icon(Icons.warning_amber, size: 12, color: AppColors.amber),
          SizedBox(width: 6),
          MonoText('草稿 · 自动保存于 14:14 · 完整度 72%', fontSize: 11, color: AppColors.amber),
        ],
      ),
    );
  }

  Widget _buildFormSection(String no, String title, {String? hint, Widget? hintWidget, required List<Widget> children}) {
    return Container(
   margin: EdgeInsets.only(bottom: 12),
   padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MonoText(no, fontSize: 11, color: AppColors.moss, letterSpacing: 0.08),
              const SizedBox(width: 8),
              SerifText(title, fontSize: 15),
              const Spacer(),
              if (hint != null) MonoText(hint, fontSize: 11, color: AppColors.text3Of(context)),
              if (hintWidget != null) hintWidget,
            ],
          ),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return _buildFormSection('01', '基础信息', hint: '必填 4 项', children: [
      _field('病例标题 *', TextField(decoration: _inputDec(), controller: _titleCtl)),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _field('适用年级 *', _select(['大四', '大三', '大五/规培']))),
          const SizedBox(width: 10),
          Expanded(child: _field('科室 *', _select(['心血管内科', '呼吸内科', '消化内科']))),
        ],
      ),
      const SizedBox(height: 10),
      _field('难度 *', _difficultySelector()),
      const SizedBox(height: 10),
      _field('知识点标签 · 最多 8 个 (3/8)', _tagInput()),
    ]);
  }

  Widget _buildPatientProfile() {
    return _buildFormSection('02', '患者画像', children: [
      Row(
        children: [
          Expanded(child: _field('年龄 *', TextField(decoration: _inputDec(), controller: _ageCtl, keyboardType: TextInputType.number))),
          const SizedBox(width: 10),
          Expanded(child: _field('性别 *', _select(['男', '女']))),
        ],
      ),
      const SizedBox(height: 10),
      _field('职业', TextField(decoration: _inputDec(), controller: TextEditingController(text: '建筑工人'))),
      const SizedBox(height: 10),
      _field('主诉 *', TextField(decoration: _inputDec(), controller: _complaintCtl)),
      const SizedBox(height: 10),
      _field('现病史摘要', TextField(
        decoration: _inputDec(),
        maxLines: 3,
        controller: TextEditingController(text: '搬运水泥时突发胸骨后压榨样疼痛 2h，放射至左肩，伴大汗、恶心。BP 90/60，HR 102。既往高血压 8 年未规律服药。'),
      )),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _field('既往史', TextField(decoration: _inputDec(), controller: TextEditingController(text: '高血压 8 年')))),
          const SizedBox(width: 10),
          Expanded(child: _field('过敏史', TextField(decoration: _inputDec(), controller: TextEditingController(text: '否认')))),
        ],
      ),
      const SizedBox(height: 10),
      _field('性格与沟通风格', _tagInput(tags: ['焦虑', '表达不清'])),
    ]);
  }

  Widget _buildHiddenDisease() {
    return _buildFormSection('03', '隐藏疾病 · 标准路径',
      hintWidget: const MonoText('仅教师可见', fontSize: 11, color: AppColors.vermilion),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.vermilionSoft,
            border: Border.all(color: AppColors.vermilion, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock, size: 16, color: AppColors.vermilion),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
         text: TextSpan(
                    style: TextStyle(fontSize: 12, color: AppColors.text2Of(context), height: 1.5),
                    children: [
                      TextSpan(text: '真实诊断：', style: TextStyle(color: AppColors.vermilion, fontWeight: FontWeight.bold)),
                      TextSpan(text: '急性下壁+右室心肌梗死\n'),
                      TextSpan(text: '关键阳性体征：', style: TextStyle(color: AppColors.vermilion, fontWeight: FontWeight.bold)),
                      TextSpan(text: '胸骨后压榨痛、大汗、BP 90/60、心电图 II/III/aVF ST↑\n'),
                      TextSpan(text: '关键阴性体征：', style: TextStyle(color: AppColors.vermilion, fontWeight: FontWeight.bold)),
                      TextSpan(text: '无胸膜摩擦音、无奇脉\n'),
                      TextSpan(text: '误导信息：', style: TextStyle(color: AppColors.vermilion, fontWeight: FontWeight.bold)),
                      TextSpan(text: '上腹痛（可能误诊为胃病）\n'),
                      TextSpan(text: '鉴别诊断：', style: TextStyle(color: AppColors.vermilion, fontWeight: FontWeight.bold)),
                      TextSpan(text: '主动脉夹层、肺栓塞、急性心包炎'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _field('标准问诊路径', TextField(
          decoration: _inputDec(),
          maxLines: 7,
          controller: TextEditingController(text: '''1. 询问疼痛部位、性质、放射、持续时间
2. 询问诱因（体力活动/情绪/饱餐）
3. 询问伴随症状（大汗、恶心、呼吸困难）
4. 既往史、过敏史、家族史
5. 开 18 导联心电图（关键检查）
6. 查肌钙蛋白（关键检查）
7. 鉴别 ACS / 主动脉夹层 / 肺栓塞'''),
        )),
      ]);
  }

  Widget _buildExamConfig() {
    final exams = [
      ('18 导联心电图', '¥120', '关键', ChipType.moss),
      ('肌钙蛋白 I', '¥280', '关键', ChipType.moss),
      ('心肌酶谱', '¥280', '可过度', ChipType.amber),
      ('D-二聚体', '¥180', null, null),
      ('胸主动脉 CTA', '¥1,800', '高价', ChipType.amber),
    ];
    return _buildFormSection('04', '检查项目配置', hint: '5 项', children: [
      ...exams.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.ruleSoft),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
      Expanded(child: Text(e.$1, style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context)))),
            MonoText(e.$2, fontSize: 11, color: AppColors.amber),
            const SizedBox(width: 8),
            if (e.$3 != null)
              AppChip(label: e.$3!, type: e.$4 ?? ChipType.default_, fontSize: 10),
          ],
        ),
      )),
      const SizedBox(height: 8),
      AppGhostButton(label: '+ 添加检查项', fullWidth: true, small: true, dashed: true),
    ]);
  }

  // ====== 表单辅助 ======

  InputDecoration _inputDec() => InputDecoration(
    filled: true,
    fillColor: AppColors.bgOf(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
   borderSide: BorderSide(color: AppColors.ruleOf(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
   borderSide: BorderSide(color: AppColors.ruleOf(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.moss),
    ),
  );

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText(label.toUpperCase(), fontSize: 11, color: AppColors.text2Of(context), letterSpacing: 0.04),
     SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _select(List<String> options) {
    return Container(
   padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.ruleOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
     Text(options.first, style: TextStyle(fontSize: 13.5, color: AppColors.textOf(context))),
      Icon(Icons.expand_more, size: 18, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _difficultySelector() {
    final labels = ['简单', '标准', '困难'];
    return Row(
      children: List.generate(3, (i) {
        final active = i == _difficulty;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _difficulty = i),
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
       padding: EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? AppColors.moss : AppColors.surfaceOf(context),
                border: Border.all(color: active ? AppColors.moss : AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: MonoText(
                  labels[i],
                  fontSize: 12,
                  color: active ? AppColors.paper : AppColors.text2Of(context),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _tagInput({List<String>? tags}) {
    final items = tags ?? _tags;
    return Container(
   padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.ruleOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...items.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.mossTint,
              border: Border.all(color: AppColors.mossSoft),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MonoText(t, fontSize: 11, color: AppColors.moss),
                const SizedBox(width: 4),
                const Icon(Icons.close, size: 10, color: AppColors.moss),
              ],
            ),
          )),
          Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.ruleOf(context), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
      child: MonoText('+ 添加', fontSize: 11, color: AppColors.text3Of(context)),
          ),
        ],
      ),
    );
  }
}
