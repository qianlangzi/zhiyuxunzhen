import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// SP 配置台
class SpConfigScreen extends StatefulWidget {
  const SpConfigScreen({super.key});

  @override
  State<SpConfigScreen> createState() => _SpConfigScreenState();
}

class _SpConfigScreenState extends State<SpConfigScreen> {
  int _difficulty = 1; // 0=简单, 1=标准, 2=困难
  final _tags = ['ACS', '心电图判读', '鉴别诊断'];

  // 下拉选择当前值（原为写死的占位，现可交互选择）
  String _grade = '大四';
  String _department = '心血管内科';
  String _gender = '男';
  final _personalityTags = ['焦虑', '表达不清'];

  // 检查项目（可用“添加检查项”新增）
  final List<({String name, String cost, String? mark, int type})> _exams = [
    (name: '18 导联心电图', cost: '¥120', mark: '关键', type: 1),
    (name: '肌钙蛋白 I', cost: '¥280', mark: '关键', type: 1),
    (name: '心肌酶谱', cost: '¥280', mark: '可过度', type: 2),
    (name: 'D-二聚体', cost: '¥180', mark: null, type: 0),
    (name: '胸主动脉 CTA', cost: '¥1,800', mark: '高价', type: 2),
  ];
  bool _saving = false;
  bool _aiLoading = false;

  // 必填字段控制器（hoist 到 state，便于校验与读取）
  final _titleCtl = TextEditingController(text: '急性下壁心肌梗死 · 不典型表现');
  final _ageCtl = TextEditingController(text: '58');
  final _complaintCtl = TextEditingController(text: '胸痛 2 小时伴大汗');

  // 报告条目: P1 #7a — 以下 5 个控制器原为 build() 内联创建，每次 rebuild 泄漏
  // 提升为 State 字段，在 dispose 中统一释放
  final _occupationCtl = TextEditingController(text: '建筑工人');
  final _historyCtl = TextEditingController(
    text: '搬运水泥时突发胸骨后压榨样疼痛 2h，放射至左肩，伴大汗、恶心。BP 90/60，HR 102。既往高血压 8 年未规律服药。',
  );
  final _pastHxCtl = TextEditingController(text: '高血压 8 年');
  final _allergyCtl = TextEditingController(text: '否认');
  final _pathCtl = TextEditingController(
    text: '''1. 询问疼痛部位、性质、放射、持续时间
2. 询问诱因（体力活动/情绪/饱餐）
3. 询问伴随症状（大汗、恶心、呼吸困难）
4. 既往史、过敏史、家族史
5. 开 18 导联心电图（关键检查）
6. 查肌钙蛋白（关键检查）
7. 鉴别 ACS / 主动脉夹层 / 肺栓塞''',
  );

  // 隐藏疾病 / 真实诊断（可编辑，保存时落库并被作业引用）
  final _hiddenCtl = TextEditingController(
    text: '''急性下壁+右室心肌梗死
阳性：胸骨后压榨痛、大汗、BP 90/60、心电图 II/III/aVF ST↑
阴性：无胸膜摩擦音、无奇脉
误导：上腹痛
鉴别：主动脉夹层、肺栓塞、急性心包炎''',
  );

  // 已保存到后端的病例 ID；为 null 表示尚未保存（首次保存走创建）
  int? _savedCaseId;

  @override
  void dispose() {
    _titleCtl.dispose();
    _ageCtl.dispose();
    _complaintCtl.dispose();
    _occupationCtl.dispose();
    _historyCtl.dispose();
    _pastHxCtl.dispose();
    _allergyCtl.dispose();
    _pathCtl.dispose();
    _hiddenCtl.dispose();
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

  /// 把表单序列化为后端 CaseCreateDTO 字段（JSON 字符串）
  Map<String, dynamic> _buildPayload() {
    return {
      'title': _titleCtl.text.trim(),
      'department': _department,
      'difficulty': _difficulty + 1, // 0/1/2 -> 1/2/3
      'patientProfile': jsonEncode({
        'age': _ageCtl.text.trim(),
        'gender': _gender,
        'grade': _grade,
        'occupation': _occupationCtl.text.trim(),
        'complaint': _complaintCtl.text.trim(),
        'presentIllness': _historyCtl.text.trim(),
        'pastHistory': _pastHxCtl.text.trim(),
        'allergy': _allergyCtl.text.trim(),
        'personality': _personalityTags,
      }),
      'hiddenDisease': _hiddenCtl.text.trim(),
      'standardPathJson': jsonEncode(
        _pathCtl.text
            .trim()
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      ),
      'presetExams': jsonEncode(
        _exams
            .map((e) => {
                  'name': e.name,
                  'cost': e.cost.replaceAll('¥', '').replaceAll(',', ''),
                  'mark': e.mark,
                  'type': e.type,
                })
            .toList(),
      ),
      'knowledgeTags': jsonEncode(_tags),
    };
  }

  /// 确保病例已保存到后端，返回病例 ID；失败返回 null
  Future<int?> _ensureSaved() async {
    final payload = _buildPayload();
    if (_savedCaseId == null) {
      final id = await TeacherService().createCaseId(payload);
      if (id != null) _savedCaseId = id;
      return id;
    }
    final ok = await TeacherService().updateCase(_savedCaseId!, payload);
    return ok ? _savedCaseId : null;
  }

  Future<void> _saveDraft() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    setState(() => _saving = true);
    final id = await _ensureSaved();
    if (!mounted) return;
    setState(() => _saving = false);
    AppFeedback.success(context, id != null ? '草稿已保存' : '保存失败，请稍后重试');
  }

  Future<void> _publish() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    setState(() => _saving = true);
    final caseId = await _ensureSaved();
    if (!mounted) return;
    setState(() => _saving = false);
    if (caseId == null) {
      AppFeedback.error(context, '病例保存失败，无法发布');
      return;
    }
    await _publishAssignmentFlow(caseId);
  }

  /// 发布作业：选择目标班级（仅限已授权班级）+ 截止时间，然后创建作业
  Future<void> _publishAssignmentFlow(int caseId) async {
    final classes = await TeacherService().getClasses();
    if (!mounted) return;
    if (classes.isEmpty) {
      AppFeedback.error(context, '暂无可授权班级，请先联系管理员完成班级授权');
      return;
    }

    final titleCtl = TextEditingController(text: _titleCtl.text.trim());
    final selected = <int>{};
    var deadline = DateTime.now().add(const Duration(days: 7));
    // 用于在 sheet 确认时把选中的截止时间带出
    var pickedDeadline = deadline;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sb) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ruleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '发布作业 · 选择班级',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: titleCtl,
                    decoration: InputDecoration(
                      labelText: '作业标题',
                      filled: true,
                      fillColor: AppColors.bgOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(color: AppColors.ruleOf(context)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: _deadlineRow(ctx, pickedDeadline, (d) {
                    pickedDeadline = d!;
                    sb(() => deadline = d);
                  }),
                ),
                Divider(height: 20, color: AppColors.ruleOf(context)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: classes.map((c) {
                      final id = (c['id'] as num).toInt();
                      final name =
                          (c['name'] as String?) ?? '班级 #$id';
                      final sub = [
                        if (c['grade'] is String && (c['grade'] as String).isNotEmpty)
                          c['grade'],
                        if (c['studentCount'] != null) '${c['studentCount']} 人',
                      ].join(' · ');
                      return CheckboxListTile(
                        value: selected.contains(id),
                        activeColor: AppColors.primaryOf(context),
                        dense: true,
                        onChanged: (v) => sb(() {
                          if (v == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                        title: Text(name,
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textOf(context))),
                        subtitle: sub.isEmpty
                            ? null
                            : Text(sub,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.text3Of(context))),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: AppPrimaryButton(
                    label: '发布到 ${selected.length} 个班级',
                    fullWidth: true,
                    onPressed: () {
                      if (selected.isEmpty) {
                        AppFeedback.error(ctx, '请至少选择一个班级');
                        return;
                      }
                      deadline = pickedDeadline;
                      Navigator.pop(ctx, true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titleCtl.dispose();
    if (!mounted) return;
    if (confirmed != true) return;

    setState(() => _saving = true);
    final deployed = await TeacherService().createAssignment({
      'caseId': caseId,
      'title': titleCtl.text.trim().isEmpty
          ? _titleCtl.text.trim()
          : titleCtl.text.trim(),
      'description': '',
      'requireMedicalRecord': true,
      'deadline': deadline.toIso8601String(),
      'classIds': selected.toList(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (deployed == null) {
      AppFeedback.error(context, '发布失败，请检查班级授权或稍后重试');
      return;
    }
    AppFeedback.success(context, '作业已发布 · 覆盖 ${selected.length} 个班级');
    context.goNamed(RouteNames.assignment);
  }

  Widget _deadlineRow(BuildContext ctx, DateTime d, ValueChanged<DateTime?> onPick) {
    return Row(
      children: [
        const Icon(Icons.schedule, size: 16, color: AppColors.amber),
        const SizedBox(width: 8),
        Text(
          '截止 ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: ctx,
              initialDate: d,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date == null) return;
            final time = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(d),
            );
            if (time == null) return;
            onPick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
          },
          child: MonoText('修改', fontSize: 12, color: AppColors.primaryOf(context)),
        ),
      ],
    );
  }

  Future<void> _preview() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    if (!mounted) return;
    _previewSheet();
  }

  /// 学生端预览（本地组装当前表单，不跳转其它路由，避免被角色守卫重定向到工作台）
  void _previewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SerifText('学生端预览 · 模拟问诊', fontSize: 17)),
                  AppGhostButton(
                    label: '关闭',
                    small: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('仅教师可见 · 基于当前表单实时预览', fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _draftBlock(
                      '主诉',
                      _complaintCtl.text.trim().isEmpty ? '（未填写）' : _complaintCtl.text.trim(),
                    ),
                    _draftBlock(
                      '患者画像',
                      '${_ageCtl.text.trim().isEmpty ? '（未填写）' : _ageCtl.text.trim()} 岁患者'
                      '，本次以「${_complaintCtl.text.trim().isEmpty ? '（未填写）' : _complaintCtl.text.trim()}」主诉进入模拟问诊。',
                    ),
                    if (_tags.isNotEmpty)
                      _draftBlock('知识点标签', _tags.join('、')),
                    _draftBlock(
                      '标准问诊路径',
                      _pathCtl.text.trim().isEmpty ? '（未填写）' : _pathCtl.text.trim(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.mossTintOf(context),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: MonoText(
                        '以上为标准病人向学生呈现的问诊起点；真实诊断与隐藏疾病仅教师可见，不会在此露出。',
                        fontSize: 11,
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI 生成 SP 病例草稿（RAG 教材锚点，防幻觉）
  Future<void> _generateDraft() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    setState(() => _aiLoading = true);
    final result = await TeacherService().getCaseDraft({
      'chiefComplaint': _complaintCtl.text.trim(),
      'department': '心血管内科',
      'difficulty': _difficulty + 1, // 0/1/2 -> 1/2/3
      'teachingGoals': _tags,
    });
    if (!mounted) return;
    setState(() => _aiLoading = false);
    if (result == null) {
      AppFeedback.error(context, 'AI 暂不可用，请稍后重试或手动填写病例');
      return;
    }
    _showDraftSheet(result);
  }

  void _showDraftSheet(Map<String, dynamic> result) {
    final patientProfile = result['patientProfile'] as String? ?? '（未生成）';
    final hiddenDisease = result['hiddenDisease'] as String? ?? '（未生成）';
    final standardPath = (result['standardPath'] as List<dynamic>?)?.cast<String>() ?? [];
    final exams = (result['presetExams'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final knowledgeTags = (result['knowledgeTags'] as List<dynamic>?)?.cast<String>() ?? [];
    final citations = (result['citations'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SerifText('AI 病例草稿 · 待审核', fontSize: 17),
                  ),
                  AppGhostButton(
                    label: '填入本表单',
                    small: true,
                    onPressed: () {
                      _pathCtl.text = standardPath.join('\n');
                      if (knowledgeTags.isNotEmpty) {
                        _tags
                          ..clear()
                          ..addAll(knowledgeTags.take(8));
                      }
                      Navigator.pop(ctx);
                      setState(() {});
                      AppFeedback.success(context, 'AI 草稿已填入，请审核后保存');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('仅教师可见 · 涉及医学事实均附教材溯源', fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _draftBlock('患者画像', patientProfile),
                    _draftBlock('隐藏疾病 / 真实诊断', hiddenDisease, vermilion: true),
                    if (standardPath.isNotEmpty)
                      _draftBlock('标准路径', standardPath.asMap().entries
                          .map((e) => '${e.key + 1}. ${e.value}')
                          .join('\n')),
                    if (exams.isNotEmpty)
                      _draftBlock('检查项目', exams
                          .map((e) => '${e['name']} · ¥${e['cost']}'
                              '${e['isKey'] == true ? " · 关键" : ""}')
                          .join('\n')),
                    if (knowledgeTags.isNotEmpty)
                      _draftBlock('知识点', knowledgeTags.join('、')),
                    if (citations.isNotEmpty)
                      _draftBlock(
                        '教材溯源',
                        citations.map((c) {
                          final book = c['book_name'] as String? ?? '';
                          final chapter = c['chapter'] as String? ?? '';
                          final page = c['page_number'];
                          return '《$book》${chapter.isNotEmpty ? '·$chapter' : ''}'
                              '${page != null ? '·P$page' : ''}';
                        }).join('\n'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draftBlock(String title, String content, {bool vermilion = false}) {
    final accent = vermilion ? AppColors.vermilion : AppColors.primaryOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(title.toUpperCase(), fontSize: 11, color: accent, letterSpacing: 0.06),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context), height: 1.6),
          ),
        ],
      ),
    );
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
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppGhostButton(
                    label: _aiLoading ? '生成中…' : 'AI 生成草稿',
                    small: true,
                    onPressed: _aiLoading || _saving ? null : _generateDraft,
                  ),
                  const SizedBox(width: 8),
                  AppGhostButton(
                    label: _saving ? '处理中…' : '预览试诊',
                    small: true,
                    onPressed: _saving ? null : _preview,
                  ),
                ],
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
                          child: AppGradientButton(
                            label: '发布作业',
                            color: AppColors.primaryOf(context),
                            height: 44,
                            loading: _saving,
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
        color: AppColors.mossTintOf(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.primaryOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: MonoText(
              'SP = 标准化病人（Standardized Patient）：模拟真实患者，供学生问诊与鉴别诊断训练。',
              fontSize: 11,
              color: AppColors.primaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 草稿保存状态（基于真实保存结果，替代原先硬编码的“自动保存于 14:14”假数据）
  Widget _buildDraftStatus() {
    // 完整度 = 已填必填项数量 / 必填项总数（用于给教师一个直观的完成参考）
    int filled = 0, total = 0;
    for (final ok in [
      _titleCtl.text.trim().isNotEmpty, // 标题
      _ageCtl.text.trim().isNotEmpty, // 年龄
      _complaintCtl.text.trim().isNotEmpty, // 主诉
      _historyCtl.text.trim().isNotEmpty, // 现病史
      _pathCtl.text.trim().isNotEmpty, // 标准路径
      _tags.isNotEmpty, // 知识点标签
    ]) {
      total++;
      if (ok) filled++;
    }
    final percent = total == 0 ? 0 : (filled * 100 / total).round();
    final saved = _savedCaseId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: saved ? AppColors.mossTintOf(context) : AppColors.amberSoftOf(context),
        border: Border.all(
          color: saved ? AppColors.mossSoftOf(context) : AppColors.amber,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            saved ? Icons.check_circle_outline : Icons.info_outline,
            size: 12,
            color: saved ? AppColors.primaryOf(context) : AppColors.amber,
          ),
          const SizedBox(width: 6),
          MonoText(
            saved
                ? '已保存草稿 · 病例 #$_savedCaseId · 完整度 $percent%'
                : '草稿 · 暂未保存 · 完整度 $percent%',
            fontSize: 11,
            color: saved ? AppColors.primaryOf(context) : AppColors.amber,
          ),
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
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MonoText(no, fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.08),
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
          Expanded(child: _field('适用年级 *', _select('适用年级', _grade, (v) => setState(() => _grade = v), ['大四', '大三', '大五/规培']))),
          const SizedBox(width: 10),
          Expanded(child: _field('科室 *', _select('科室', _department, (v) => setState(() => _department = v), ['心血管内科', '呼吸内科', '消化内科']))),
        ],
      ),
      const SizedBox(height: 10),
      _field('难度 *', _difficultySelector()),
      const SizedBox(height: 10),
      _field('知识点标签 · 最多 8 个 (${_tags.length}/8)', _tagInput(_tags)),
    ]);
  }

  Widget _buildPatientProfile() {
    return _buildFormSection('02', '患者画像', children: [
      Row(
        children: [
          Expanded(child: _field('年龄 *', TextField(decoration: _inputDec(), controller: _ageCtl, keyboardType: TextInputType.number))),
          const SizedBox(width: 10),
          Expanded(child: _field('性别 *', _select('性别', _gender, (v) => setState(() => _gender = v), ['男', '女']))),
        ],
      ),
      const SizedBox(height: 10),
      _field('职业', TextField(decoration: _inputDec(), controller: _occupationCtl)),
      const SizedBox(height: 10),
      _field('主诉 *', TextField(decoration: _inputDec(), controller: _complaintCtl)),
      const SizedBox(height: 10),
      _field('现病史摘要', TextField(
        decoration: _inputDec(),
        maxLines: 3,
        controller: _historyCtl,
      )),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _field('既往史', TextField(decoration: _inputDec(), controller: _pastHxCtl))),
          const SizedBox(width: 10),
          Expanded(child: _field('过敏史', TextField(decoration: _inputDec(), controller: _allergyCtl))),
        ],
      ),
      const SizedBox(height: 10),
      _field('性格与沟通风格', _tagInput(_personalityTags)),
    ]);
  }

  Widget _buildHiddenDisease() {
    return _buildFormSection('03', '隐藏疾病 · 标准路径',
      hintWidget: const MonoText('仅教师可见', fontSize: 11, color: AppColors.vermilion),
      children: [
        _field('隐藏疾病 / 真实诊断', TextField(
          decoration: _inputDec(),
          maxLines: 7,
          controller: _hiddenCtl,
        )),
        const SizedBox(height: 12),
        _field('标准问诊路径', TextField(
          decoration: _inputDec(),
          maxLines: 7,
          controller: _pathCtl,
        )),
      ]);
  }

  Widget _buildExamConfig() {
    return _buildFormSection('04', '检查项目配置', hint: '${_exams.length} 项', children: [
      ..._exams.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.ruleSoftOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(child: Text(e.name, style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context)))),
            MonoText(e.cost, fontSize: 11, color: AppColors.amber),
            const SizedBox(width: 8),
            if (e.mark != null)
              AppChip(label: e.mark!, type: e.type == 2 ? ChipType.amber : ChipType.moss, fontSize: 10),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _removeExam(e.name),
              child: Icon(Icons.close, size: 14, color: AppColors.text4Of(context)),
            ),
          ],
        ),
      )),
      const SizedBox(height: 8),
      AppGhostButton(
        label: '+ 添加检查项',
        fullWidth: true,
        small: true,
        dashed: true,
        onPressed: _addExam,
      ),
    ]);
  }

  /// 删除检查项
  void _removeExam(String name) {
    setState(() => _exams.removeWhere((e) => e.name == name));
  }

  /// 新增检查项（名称 + 费用）
  Future<void> _addExam() async {
    final nameCtl = TextEditingController();
    final costCtl = TextEditingController(text: '0');
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('添加检查项',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '检查名称',
                hintText: '如：超声心动图',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
              style: TextStyle(color: AppColors.textOf(context)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '费用（元）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
              style: TextStyle(color: AppColors.textOf(context)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: AppColors.text3Of(context)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('确定', style: TextStyle(color: AppColors.primaryOf(context), fontWeight: FontWeight.w600))),
        ],
      ),
    );
    final name = nameCtl.text.trim();
    final cost = costCtl.text.trim();
    if (created != true || name.isEmpty || !mounted) return;
    setState(() {
      _exams.add((
        name: name,
        cost: _formatCost(cost),
        mark: null,
        type: 0,
      ));
    });
  }

  /// 把数字字符串格式化为“¥价格”显示
  String _formatCost(String raw) {
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), ''));
    if (n == null) return '¥0';
    return '¥${n >= 1000 ? n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},') : n}';
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
      borderSide: BorderSide(color: AppColors.primaryOf(context)),
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

  /// 下拉选择：显示当前值 `current`，点击弹出底部选项面板并回调选中项
  Widget _select(
    String label,
    String current,
    ValueChanged<String> onChanged,
    List<String> options, {
    String? placeholder,
  }) {
    return GestureDetector(
      onTap: () => _pickOption(label, current, onChanged, options),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.ruleOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                current.isEmpty
                    ? (placeholder ?? '请选择')
                    : current,
                style: TextStyle(
                  fontSize: 13.5,
                  color: current.isEmpty
                      ? AppColors.text4Of(context)
                      : AppColors.textOf(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: AppColors.text3Of(context)),
          ],
        ),
      ),
    );
  }

  /// 弹出选项面板，非空即回调
  Future<void> _pickOption(
    String label,
    String current,
    ValueChanged<String> onChanged,
    List<String> options,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SerifText(label, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Divider(height: 20, color: AppColors.ruleOf(context)),
            ...options.map((o) {
              final active = o == current;
              return ListTile(
                dense: true,
                title: MonoText(o, fontSize: 13,
                    color: active ? AppColors.primaryOf(context) : AppColors.textOf(context)),
                trailing: active
                    ? Icon(Icons.check, size: 18, color: AppColors.primaryOf(context))
                    : null,
                onTap: () => Navigator.pop(ctx, o),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) onChanged(picked);
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
                color: active ? AppColors.primaryOf(context) : AppColors.surfaceOf(context),
                border: Border.all(color: active ? AppColors.primaryOf(context) : AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: MonoText(
                  labels[i],
                  fontSize: 12,
                  color: active ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _tagInput(List<String> items) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.ruleOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...items.map((t) => GestureDetector(
            onTap: () => _removeTag(items, t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mossTintOf(context),
                border: Border.all(color: AppColors.mossSoftOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonoText(t, fontSize: 11, color: AppColors.primaryOf(context)),
                  const SizedBox(width: 4),
                  Icon(Icons.close, size: 10, color: AppColors.primaryOf(context)),
                ],
              ),
            ),
          )),
          GestureDetector(
            onTap: () => _addTag(items),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.ruleOf(context), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: MonoText('+ 添加', fontSize: 11, color: AppColors.text3Of(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// 删除标签
  void _removeTag(List<String> items, String t) {
    setState(() => items.remove(t));
  }

  /// 新增标签（知识点标签最多 8 个）
  Future<void> _addTag(List<String> items) async {
    if (identical(items, _tags) && items.length >= 8) {
      AppFeedback.info(context, '知识点标签最多 8 个');
      return;
    }
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          title: Text('添加标签',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
          content: TextField(
            controller: ctl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '输入标签，如：心电图判读',
              hintStyle: TextStyle(color: AppColors.text4Of(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
              ),
            ),
            style: TextStyle(color: AppColors.textOf(context)),
            onSubmitted: (s) => Navigator.pop(ctx, s),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: AppColors.text3Of(context))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text('确定',
                  style: TextStyle(color: AppColors.primaryOf(context), fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    final trimmed = v?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      if (!items.contains(trimmed)) items.add(trimmed);
    });
  }
}
