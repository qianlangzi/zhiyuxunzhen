import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 评分要点（标准答案的可评判依据）
class _Sp {
  _Sp(String label, String mark, String criteria, String deduct)
      : label = TextEditingController(text: label),
        mark = TextEditingController(text: mark),
        criteria = TextEditingController(text: criteria),
        deduct = TextEditingController(text: deduct);

  final TextEditingController label; // 要点名
  final TextEditingController mark; // 满分
  final TextEditingController criteria; // 给分标准
  final TextEditingController deduct; // 扣分说明
}

/// SP 配置台
///
/// 支持两种进入方式：
/// - 新建：不传 caseId，表单为空白（去写死示例数据），可手动填写或 AI 生成
/// - 继续编辑：传 caseId，进入时调 preview 接口回填全表，保存走 update
class SpConfigScreen extends StatefulWidget {
  const SpConfigScreen({super.key, this.caseId});

  /// 已保存病例 ID；null 表示新建草稿
  final int? caseId;

  @override
  State<SpConfigScreen> createState() => _SpConfigScreenState();
}

class _SpConfigScreenState extends State<SpConfigScreen> {
  int _difficulty = 1; // 0=简单, 1=标准, 2=困难
  final _tags = <String>[];

  // 下拉选择当前值（新建时为空，显示"请选择"）
  String _grade = '';
  String _department = '';
  String _gender = '';
  final _personalityTags = <String>[];

  // 检查项目（可用"添加检查项"新增）
  final List<({String name, String cost, String? mark, int type})> _exams = [];
  bool _saving = false;
  bool _aiLoading = false;

  // AI 生成阶段推进（驱动加载动画 + 分阶段状态文案）
  int _aiStage = 0;
  Timer? _aiTimer;

  // 评分依据：标准答案 + 评分要点（PRD 新增，供评判与广场管理）
  final _referenceCtl = TextEditingController();
  final List<_Sp> _points = [];

  // 必填字段控制器（hoist 到 state，便于校验与读取）
  final _titleCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _complaintCtl = TextEditingController();

  // 报告条目: P1 #7a — 以下 5 个控制器原为 build() 内联创建，每次 rebuild 泄漏
  // 提升为 State 字段，在 dispose 中统一释放
  final _occupationCtl = TextEditingController();
  final _historyCtl = TextEditingController();
  final _pastHxCtl = TextEditingController();
  final _allergyCtl = TextEditingController();
  final _pathCtl = TextEditingController();

  // 隐藏疾病 / 真实诊断（可编辑，保存时落库并被作业引用）
  final _hiddenCtl = TextEditingController();

  // 已保存到后端的病例 ID；为 null 表示尚未保存（首次保存走创建）
  int? _savedCaseId;

  // 防丢失：进入时表单快照，用于检测是否有未保存改动
  String _initialSnapshot = '';
  bool _allowPop = false;
  bool _confirmingExit = false;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    _savedCaseId = widget.caseId;
    _initialSnapshot = jsonEncode(_buildPayload());
    if (widget.caseId != null) {
      // 继续编辑：拉取后端完整配置回填表单
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
    }
  }

  /// 继续编辑：拉取病例完整配置（preview）并回填表单
  Future<void> _loadPreview() async {
    final id = widget.caseId;
    if (id == null) return;
    setState(() => _loadingPreview = true);
    Map<String, dynamic>? vo;
    try {
      vo = await TeacherService().getCasePreview(id);
    } catch (e) {
      // 加载失败不阻塞页面，表单保持空白
      debugPrint('loadCasePreview error: $e');
    }
    if (!mounted) return;
    setState(() {
      _loadingPreview = false;
      if (vo != null) _fillFormFromPreview(vo);
      _initialSnapshot = jsonEncode(_buildPayload());
    });
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _aiTimer = null;
    _titleCtl.dispose();
    _ageCtl.dispose();
    _complaintCtl.dispose();
    _occupationCtl.dispose();
    _historyCtl.dispose();
    _pastHxCtl.dispose();
    _allergyCtl.dispose();
    _pathCtl.dispose();
    _hiddenCtl.dispose();
    _referenceCtl.dispose();
    for (final p in _points) {
      p.label.dispose();
      p.mark.dispose();
      p.criteria.dispose();
      p.deduct.dispose();
    }
    super.dispose();
  }

  /// 草稿校验：仅要求标题非空（抖音式：任意进度都能存草稿）
  String? _validateDraft() {
    if (_titleCtl.text.trim().isEmpty) return '请填写病例标题，才能保存草稿';
    return null;
  }

  /// 发布校验：发布到病例中心要求内容完整（与后端 publishToMarket 校验对齐）
  String? _validatePublish() {
    if (_titleCtl.text.trim().isEmpty) return '请填写病例标题';
    if (_ageCtl.text.trim().isEmpty) return '请填写患者年龄';
    if (int.tryParse(_ageCtl.text.trim()) == null) return '年龄必须为数字';
    if (_complaintCtl.text.trim().isEmpty) return '请填写主诉';
    if (_tags.isEmpty) return '请至少添加 1 个知识点标签';
    if (_pathCtl.text.trim().isEmpty) return '请填写标准问诊路径';
    if (_hiddenCtl.text.trim().isEmpty) return '请填写隐藏疾病/真实诊断';
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
      'referenceAnswer': _referenceCtl.text.trim(),
      'scoringPointsJson': jsonEncode(
        _points
            .map((p) => {
                  'label': p.label.text.trim(),
                  'fullMark': int.tryParse(p.mark.text.trim()) ?? 0,
                  'criteria': p.criteria.text.trim(),
                  'deduct': p.deduct.text.trim(),
                })
            .where((e) => '${e['label']}${e['criteria']}'.trim().isNotEmpty)
            .toList(),
      ),
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

  /// 保存草稿（仅标题必填）。成功返回 true
  Future<bool> _saveDraft() async {
    final err = _validateDraft();
    if (err != null) {
      AppFeedback.error(context, err);
      return false;
    }
    setState(() => _saving = true);
    // try/catch + finally 兜底：任何保存路径的意外异常（序列化/网络/DTO）都必须
    // 复位 _saving 并给出提示，否则按钮停留在"保存中…"，界面表现为此无响应的卡死。
    int? id;
    String? failMsg;
    try {
      id = await _ensureSaved();
    } catch (e) {
      failMsg = '保存时发生异常：$e';
    }
    if (!mounted) return false;
    setState(() => _saving = false);
    if (failMsg != null) {
      AppFeedback.error(context, failMsg);
      return false;
    }
    if (id == null) {
      AppFeedback.error(context, '保存失败，请稍后重试');
      return false;
    }
    // 保存成功即标记为已保存，返回时不再误弹「草稿未保存」二次提示
    _markClean();
    AppFeedback.success(context, '草稿已保存');
    return true;
  }

  Future<void> _publish() async {
    final err = _validatePublish();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }
    setState(() => _saving = true);
    int? caseId;
    String? saveFailMsg;
    try {
      caseId = await _ensureSaved();
    } catch (e) {
      saveFailMsg = '保存时发生异常：$e';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saveFailMsg != null) {
      AppFeedback.error(context, saveFailMsg);
      return;
    }
    if (caseId == null) {
      AppFeedback.error(context, '病例保存失败，无法发布');
      return;
    }

    // 发布到病例中心（病例广场）：后端将病例置为"待管理员审核"，
    // 直接投递，不需要选择班级 / 向管理员申请班级授权。
    final bool ok;
    try {
      ok = await TeacherService().publishCaseToMarket(caseId);
    } catch (e) {
      AppFeedback.error(context, '发布时发生异常：$e');
      return;
    }
    if (!mounted) return;
    AppFeedback.success(context,
        ok ? '已发布到病例中心，等待管理员审核' : '发布失败，请检查病例内容或稍后重试');
    if (!ok) return;
    // 发布成功：标记无未保存改动，解除返回拦截，回到列表页（列表刷新后草稿消失）
    _markClean();
    _doExit();
  }

  Future<void> _preview() async {
    final err = _validatePublish();
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
  ///
  /// 流程：① 校验人工必需项（标题/主诉）→ ② 弹窗确认并补充可选备注 →
  /// ③ 分阶段动画加载 → ④ AI 返回后自动填充整表（或先预览）。
  Future<void> _generateDraft() async {
    final err = _validateAIGate();
    if (err != null) {
      AppFeedback.error(context, err);
      return;
    }

    // 弹窗内的一次性输入直接保存字符串，避免弹窗退出动画期间
    // TextField 仍参与构建而控制器已被提前 dispose 的生命周期竞态。
    var remark = '';
    var directFill = true;

    final result = await showModalBottomSheet<({String remark, bool directFill})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: SerifText('AI 生成 SP 草稿', fontSize: 17),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MonoText(
                    'AI 基于教材检索生成，医学事实均附溯源；确认后自动填充本表单。',
                    fontSize: 11,
                    color: AppColors.text3Of(context),
                  ),
                ),
                Divider(height: 20, color: AppColors.ruleOf(context)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    children: [
                      _aiRackLabel('① 已确认 · AI 生成依据', AppColors.primaryOf(context)),
                      _aiSummaryChips([
                        ('标题', _titleCtl.text.trim()),
                        ('科室', _department),
                        ('难度', const ['简单', '标准', '困难'][_difficulty]),
                        ('主诉', _complaintCtl.text.trim()),
                        if (_tags.isNotEmpty)
                          ('知识点标签', _tags.take(8).join('、')),
                      ]),
                      const SizedBox(height: 14),
                      _aiRackLabel('② 待完善 · AI 将生成并自动填充（可选）', AppColors.text2Of(context)),
                      _aiOptionalList(),
                      const SizedBox(height: 14),
                      _field(
                        '给 AI 的补充说明（可选）',
                        TextField(
                          maxLines: 2,
                          onChanged: (value) => remark = value,
                          decoration: _inputDec(
                            hintText: '如：重点突出胸痛鉴别诊断、学生易错点',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: directFill,
                        activeColor: AppColors.primaryOf(context),
                        onChanged: (v) => sb(() => directFill = v),
                        title: MonoText('生成后自动填入本表单', fontSize: 13,
                            color: AppColors.textOf(context)),
                        subtitle: MonoText(
                          directFill ? 'AI 将直接把各字段写回表单，可在下方逐项审核' : '先生成草稿预览，由你确认后再填入',
                          fontSize: 11,
                          color: AppColors.text3Of(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppGhostButton(
                          label: '取消',
                          fullWidth: true,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppGradientButton(
                          label: '生成并自动填充',
                          color: AppColors.primaryOf(context),
                          height: 44,
                          onPressed: () => Navigator.pop(
                            ctx,
                            (remark: remark.trim(), directFill: directFill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _runAIGenerate(remark: result.remark, directFill: result.directFill);
  }

  /// AI 生成前的必要内容校验：仅要求"人工确定"的输入项（标题/主诉）
  String? _validateAIGate() {
    if (_titleCtl.text.trim().isEmpty) return '请先填写病例标题（AI 将以它作为草稿主题）';
    if (_complaintCtl.text.trim().isEmpty) return '请先填写主诉（AI 以它为核心生成病例）';
    return null;
  }

  /// 汇总当前表单中"待 AI 生成填充"的可选字段（供弹窗透明提示）
  List<({String label, bool filled})> _aiOptionalFields() => [
        (label: '年龄', filled: _ageCtl.text.trim().isNotEmpty),
        (label: '职业', filled: _occupationCtl.text.trim().isNotEmpty),
        (label: '现病史摘要', filled: _historyCtl.text.trim().isNotEmpty),
        (label: '既往史', filled: _pastHxCtl.text.trim().isNotEmpty),
        (label: '过敏史', filled: _allergyCtl.text.trim().isNotEmpty),
        (label: '性格标签', filled: _personalityTags.isNotEmpty),
        (label: '隐藏疾病/诊断', filled: _hiddenCtl.text.trim().isNotEmpty),
        (label: '标准问诊路径', filled: _pathCtl.text.trim().isNotEmpty),
        (label: '标准答案/要点', filled: _referenceCtl.text.trim().isNotEmpty),
        (label: '评分要点', filled: _points.isNotEmpty),
      ];

  /// 执行 AI 生成：分阶段动画加载 → 成功自动填充整表 / 或预览草稿
  Future<void> _runAIGenerate({
    required String remark,
    required bool directFill,
  }) async {
    setState(() {
      _aiLoading = true;
      _aiStage = 0;
    });
    _startAiStageAdvance();

    final payload = <String, dynamic>{
      'chiefComplaint': _complaintCtl.text.trim(),
      'department': _department,
      'difficulty': _difficulty + 1,
      'teachingGoals': _tags,
      if (remark.isNotEmpty) 'remark': remark,
    };
    // try-catch 兜住任何非 Dio 异常（解析/cast 等）：确保 _aiLoading/_aiTimer
    // 一定复位，避免遮罩永久停留，形成"卡死/疑似超时"假象。
    // ignore: always_specify_types
    ({Map<String, dynamic>? data, String message}) res;
    try {
      res = await TeacherService().getCaseDraft(payload);
    } catch (e) {
      res = (data: null, message: 'AI 生成异常，请稍后重试：$e');
    }

    _stopAiStageAdvance();
    if (!mounted) return;

    // 关键：在整表填充前先收起键盘，再先仅移除遮罩。
    // 否则"弹窗退场动画 + IME 收起动画 + 移除遮罩 + 整表重填"会在同一帧内
    // 落到 layout 阶段，触发 _debugDoingThisLayout / _dependents.isEmpty 渲染异常。
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _aiLoading = false;
      _aiStage = 0;
    });

    final draft = res.data;
    if (draft == null) {
      final msg = res.message.trim();
      AppFeedback.error(context,
          msg.isEmpty ? 'AI 生成失败，请稍后重试或手动填写病例' : msg);
      return;
    }
    if (directFill) {
      // 填充拆到下一帧（postFrame，非 layout 相位）执行，错开遮罩移除、
      // 弹窗退场与键盘收起，从根上消除同帧重排导致的渲染断言。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fillFormFromDraft(draft);
        AppFeedback.success(context, 'AI 已生成并自动填充表单，请审核后保存');
      });
    } else {
      _showDraftSheet(draft);
    }
  }

  /// 驱动加载弹层的分阶段状态推进
  void _startAiStageAdvance() {
    _aiTimer?.cancel();
    _aiTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_aiStage < 4) _aiStage++;
      });
      if (_aiStage >= 4) t.cancel();
    });
  }

  void _stopAiStageAdvance() {
    _aiTimer?.cancel();
    _aiTimer = null;
  }

  /// 把 AI 返回的草稿逐字段写回表单（整表填充，仅覆盖非空字段，保留人工已填内容）
  void _fillFormFromDraft(Map<String, dynamic> result) {
    String? _text(Object? v) {
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    List<String> _stringList(Object? v) => (v is List)
        ? v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
        : const [];

    final age = _text(result['age']);
    if (age != null) _ageCtl.text = age;

    final gender = _text(result['gender']);
    if (gender == '男' || gender == '女') _gender = gender ?? '男';

    final occ = _text(result['occupation']);
    if (occ != null) _occupationCtl.text = occ;

    final comp = _text(result['chiefComplaint']);
    if (comp != null) _complaintCtl.text = comp;

    final present = _text(result['presentIllness']);
    if (present != null) _historyCtl.text = present;

    final pastHx = _text(result['pastHistory']);
    if (pastHx != null) _pastHxCtl.text = pastHx;

    final allergy = _text(result['allergy']);
    if (allergy != null) _allergyCtl.text = allergy;

    final hidden = _text(result['hiddenDisease']);
    if (hidden != null) _hiddenCtl.text = hidden;

    final path = _stringList(result['standardPath']);
    if (path.isNotEmpty) _pathCtl.text = path.join('\n');

    final tags = _stringList(result['knowledgeTags']);
    if (tags.isNotEmpty) {
      _tags
        ..clear()
        ..addAll(tags.take(8));
    }

    final personality = _stringList(result['personality']);
    if (personality.isNotEmpty) {
      _personalityTags
        ..clear()
        ..addAll(personality.take(8));
    }

    // 检查项目：isKey -> 关键
    final exams = result['presetExams'];
    if (exams is List && exams.isNotEmpty) {
      _exams.clear();
      for (final e in exams) {
        final name = (e is Map ? e['name'] : null)?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final isKey = e is Map && e['isKey'] == true;
        final costRaw = (e is Map ? e['cost'] : 0).toString();
        _exams.add((
          name: name,
          cost: _formatCost(costRaw),
          mark: isKey ? '关键' : null,
          type: isKey ? 1 : 0,
        ));
      }
    }

    final reference = _text(result['referenceAnswer']);
    if (reference != null) _referenceCtl.text = reference;

    // 评分要点
    final pts = result['scoringPoints'];
    if (pts is List && pts.isNotEmpty) {
      // 先构建新的评分要点并替换到 _points，再把旧要点中已挂到 TextField 的
      // 控制器放到回帧后统一 dispose，避免在重建帧内释放仍被旧 TextField 引用的
      // 控制器导致 "used after being disposed" 的构建期渲染异常。
      // 必须复制列表快照；直接引用 _points 会在 clear/addAll 后指向新要点，
      // 回帧释放时误把新 TextField 正在使用的控制器 dispose 掉。
      final oldPoints = List<_Sp>.of(_points);
      final next = <_Sp>[];
      for (final s in pts) {
        if (s is! Map) continue;
        final label = (s['label']?.toString() ?? '').trim();
        if (label.isEmpty) continue;
        next.add(_Sp(
          label,
          s['fullMark']?.toString() ?? '',
          (s['criteria']?.toString() ?? '').trim(),
          (s['deduct']?.toString() ?? '').trim(),
        ));
      }
      _points
        ..clear()
        ..addAll(next);

      if (oldPoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final p in oldPoints) {
            p.label.dispose();
            p.mark.dispose();
            p.criteria.dispose();
            p.deduct.dispose();
          }
        });
      }
    }

    setState(() {});
  }

  /// 把后端 preview 返回的完整病例配置回填到表单（继续编辑）
  ///
  /// preview 各字段为后端存储的原始形态：patientProfile / standardPathJson /
  /// presetExams / knowledgeTags / scoringPointsJson 均为 JSON 字符串。
  void _fillFormFromPreview(Map<String, dynamic> vo) {
    String? _text(Object? v) {
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    final title = _text(vo['title']);
    if (title != null) _titleCtl.text = title;

    final dept = _text(vo['department']);
    if (dept != null) _department = dept;

    final diff = vo['difficulty'];
    if (diff is num && diff >= 1 && diff <= 3) _difficulty = diff.toInt() - 1;

    // 患者画像 JSON
    final profileRaw = vo['patientProfile'];
    if (profileRaw is String && profileRaw.trim().isNotEmpty) {
      try {
        final p = jsonDecode(profileRaw) as Map<String, dynamic>;
        final age = _text(p['age']);
        if (age != null) _ageCtl.text = age;
        final gender = _text(p['gender']);
        if (gender != null && (gender == '男' || gender == '女')) _gender = gender;
        final grade = _text(p['grade']);
        if (grade != null) _grade = grade;
        final occ = _text(p['occupation']);
        if (occ != null) _occupationCtl.text = occ;
        final comp = _text(p['complaint']);
        if (comp != null) _complaintCtl.text = comp;
        final present = _text(p['presentIllness']);
        if (present != null) _historyCtl.text = present;
        final past = _text(p['pastHistory']);
        if (past != null) _pastHxCtl.text = past;
        final allergy = _text(p['allergy']);
        if (allergy != null) _allergyCtl.text = allergy;
        final personality = p['personality'];
        if (personality is List && personality.isNotEmpty) {
          _personalityTags
            ..clear()
            ..addAll(personality
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .take(8));
        }
      } catch (_) {
        // 患者画像 JSON 解析失败不阻塞，其余字段继续回填
      }
    }

    final hidden = _text(vo['hiddenDisease']);
    if (hidden != null) _hiddenCtl.text = hidden;

    // 标准问诊路径 JSON 数组
    final pathRaw = vo['standardPathJson'];
    if (pathRaw is String && pathRaw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(pathRaw) as List<dynamic>;
        if (list.isNotEmpty) {
          _pathCtl.text = list
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .join('\n');
        }
      } catch (_) {}
    }

    // 检查项目 JSON 数组
    final examsRaw = vo['presetExams'];
    if (examsRaw is String && examsRaw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(examsRaw) as List<dynamic>;
        _exams.clear();
        for (final e in list) {
          if (e is! Map) continue;
          final name = e['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final markRaw = e['mark'];
          final typeRaw = e['type'];
          _exams.add((
            name: name,
            cost: _formatCost((e['cost'] ?? '').toString()),
            mark: markRaw is String && markRaw.isNotEmpty ? markRaw : null,
            type: typeRaw is num ? typeRaw.toInt() : 0,
          ));
        }
      } catch (_) {}
    }

    // 知识点标签 JSON 数组
    final tagsRaw = vo['knowledgeTags'];
    if (tagsRaw is String && tagsRaw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(tagsRaw) as List<dynamic>;
        _tags
          ..clear()
          ..addAll(list
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .take(8));
      } catch (_) {}
    }

    final reference = _text(vo['referenceAnswer']);
    if (reference != null) _referenceCtl.text = reference;

    // 评分要点 JSON 数组 [{label,fullMark,criteria,deduct}]
    final pointsRaw = vo['scoringPointsJson'];
    if (pointsRaw is String && pointsRaw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(pointsRaw) as List<dynamic>;
        for (final s in list) {
          if (s is! Map) continue;
          final label = s['label']?.toString().trim() ?? '';
          if (label.isEmpty) continue;
          _points.add(_Sp(
            label,
            (s['fullMark'] ?? '').toString(),
            (s['criteria']?.toString() ?? '').trim(),
            (s['deduct']?.toString() ?? '').trim(),
          ));
        }
      } catch (_) {}
    }
  }

  // ====== 防丢失（抖音式：退出未保存内容时弹窗确认） ======

  /// 是否有未保存改动（当前表单与进入时快照不一致）
  bool get _hasUnsavedChanges => jsonEncode(_buildPayload()) != _initialSnapshot;

  /// 标记当前内容已保存（刷新快照，解除返回拦截）
  void _markClean() {
    _initialSnapshot = jsonEncode(_buildPayload());
    setState(() {});
  }

  /// 确认退出：无改动直接退出；有改动弹窗（保存草稿 / 不保存 / 取消）
  Future<void> _handleExit() async {
    if (!_hasUnsavedChanges) {
      _doExit();
      return;
    }
    if (_confirmingExit) return; // 防重复弹窗
    _confirmingExit = true;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('草稿未保存',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textOf(context))),
        content: Text('当前内容有修改且尚未保存，是否保存草稿？',
            style: TextStyle(fontSize: 13.5, color: AppColors.text2Of(context), height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('不保存', style: TextStyle(color: AppColors.vermilionOf(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text('取消', style: TextStyle(color: AppColors.text3Of(context))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryOf(context),
            ),
            child: const Text('保存草稿'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (!mounted) return;
    switch (action) {
      case 'save':
        final ok = await _saveDraft();
        if (ok && mounted) {
          _markClean();
          _doExit();
        }
      case 'discard':
        _markClean();
        _doExit();
    }
  }

  /// 执行返回（可 pop 则 pop，否则回教师工作台）
  void _doExit() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(RouteNames.teacherHome);
      }
    });
  }

  /// 弹窗内分组小标题
  Widget _aiRackLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MonoText(text, fontSize: 12, color: color, letterSpacing: 0.04),
    );
  }

  /// 弹窗内"已确认项"标签（chip 形式展示 key: value）
  Widget _aiSummaryChips(List<(String, String)> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((e) {
        final over = e.$2.length > 14;
        return Container(
          width: e.$2.isNotEmpty ? 150 : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.ruleSoftOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoText('${e.$1}：', fontSize: 11, color: AppColors.text3Of(context)),
              const SizedBox(width: 3),
              Flexible(
                child: MonoText(
                  over ? '${e.$2.substring(0, 12)}…' : e.$2,
                  fontSize: 11,
                  color: AppColors.primaryOf(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 弹窗内"待完善"可选字段列表（未填高亮为待生成，已填置灰提示 AI 将覆盖/保留）
  Widget _aiOptionalList() {
    final fields = _aiOptionalFields();
    final pending = fields.where((f) => !f.filled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: fields.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: f.filled
                    ? AppColors.mossTintOf(context)
                    : AppColors.surfaceOf(context),
                border: Border.all(
                  color: f.filled
                      ? AppColors.mossSoftOf(context)
                      : AppColors.amberOf(context).withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.filled
                        ? Icons.check_circle_outline
                        : Icons.auto_awesome_outlined,
                    size: 12,
                    color: f.filled
                        ? AppColors.primaryOf(context)
                        : AppColors.amberOf(context),
                  ),
                  const SizedBox(width: 4),
                  MonoText(
                    f.label,
                    fontSize: 11,
                    color: f.filled
                        ? AppColors.text3Of(context)
                        : AppColors.text2Of(context),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        MonoText(
          pending == 0
              ? '表单已较完整，AI 将补充并优化生成结果。'
              : '共 $pending 项待 AI 生成，生成后可直接覆盖，也可自动保留已填内容。',
          fontSize: 11,
          color: AppColors.text3Of(context),
        ),
      ],
    );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                      Navigator.pop(ctx);
                      _fillFormFromDraft(result);
                      AppFeedback.success(context, 'AI 草稿已填入本表单，请审核后保存');
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
    final accent = vermilion ? AppColors.vermilionOf(context) : AppColors.primaryOf(context);
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
    final editing = widget.caseId != null;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                AppBackAppBar(
              title: editing ? '编辑 SP 病例' : '新建 SP 病例',
              onBack: _handleExit,
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    icon: Icon(Icons.folder_outlined, size: 20, color: AppColors.text2Of(context)),
                    onPressed: () => context.pushNamed(RouteNames.myCases),
                  ),
                  const SizedBox(width: 4),
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
                    _buildReferenceAndScoring(),
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
                            label: '发布到病例中心',
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
          if (_aiLoading) _buildAiLoadingOverlay(),
          if (_loadingPreview) _buildPreviewLoading(),
        ],
      ),
      ),
    );
  }

  /// 继续编辑时加载病例配置的轻量遮罩
  Widget _buildPreviewLoading() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // 拦截点击，避免误触表单
        child: Container(
          color: AppColors.bgOf(context).withValues(alpha: 0.25),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgOf(context).withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                MonoText('正在加载病例配置…', fontSize: 13, color: AppColors.textOf(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// AI 生成时全屏分阶段动画遮罩（随 _aiStage 推进，实时可见生成进度）
  Widget _buildAiLoadingOverlay() {
    const steps = [
      ('检索教材锚点', 'RAG 定位相关章节，防幻觉'),
      ('生成患者画像', '主诉 · 现病史 · 隐藏诊断'),
      ('构建问诊与检查', '标准路径 · 预设检查'),
      ('校验与溯源', '评分要点 · 教材引用'),
    ];
    final idx = _aiStage.clamp(0, steps.length);
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // 拦截点击，避免误触表单
        child: Container(
          color: AppColors.bgOf(context).withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (ctx, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              decoration: BoxDecoration(
                color: AppColors.bgOf(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bgOf(context).withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SerifText('AI 正在生成 SP 病例…', fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  MonoText(
                    '基于教材检索生成，医学事实均附溯源',
                    fontSize: 11,
                    color: AppColors.text3Of(context),
                  ),
                  const SizedBox(height: 14),
                  ...steps.asMap().entries.map((e) {
                    final i = e.key;
                    final done = idx > i;
                    final active = idx == i;
                    final icon = done
                        ? Icons.check_circle
                        : active
                            ? Icons.radar
                            : Icons.radio_button_unchecked;
                    final color = done
                        ? AppColors.primaryOf(context)
                        : active
                            ? AppColors.vermilionOf(context)
                            : AppColors.text3Of(context);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MonoText(
                                  e.value.$1,
                                  fontSize: 13,
                                  color: done || active
                                      ? AppColors.textOf(context)
                                      : AppColors.text3Of(context),
                                ),
                                if (active)
                                  MonoText(
                                    e.value.$2,
                                    fontSize: 11,
                                    color: AppColors.text3Of(context),
                                  ),
                              ],
                            ),
                          ),
                          if (active)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: steps.isEmpty
                          ? 0
                          : idx / steps.length,
                      minHeight: 4,
                      backgroundColor: AppColors.ruleOf(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: MonoText(
                      '请稍候 · 通常约 10~30 秒，完成后自动填入表单',
                      fontSize: 11,
                      color: AppColors.text3Of(context),
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
          color: saved ? AppColors.mossSoftOf(context) : AppColors.amberOf(context),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            saved ? Icons.check_circle_outline : Icons.info_outline,
            size: 12,
            color: saved ? AppColors.primaryOf(context) : AppColors.amberOf(context),
          ),
          const SizedBox(width: 6),
          MonoText(
            saved
                ? '已保存草稿 · 病例 #$_savedCaseId · 完整度 $percent%'
                : '草稿 · 暂未保存 · 完整度 $percent%',
            fontSize: 11,
            color: saved ? AppColors.primaryOf(context) : AppColors.amberOf(context),
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
      hintWidget: MonoText('仅教师可见', fontSize: 11, color: AppColors.vermilionOf(context)),
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

  /// 评分依据：标准答案 + 评分要点（PRD 新增，供 AI 评判与广场管理）
  Widget _buildReferenceAndScoring() {
    return _buildFormSection('04', '评分依据 · 标准答案', children: [
      _field('标准答案 / 诊断要点', TextField(
        decoration: _inputDec(hintText: '填写诊断依据、鉴别要点，或在下方拆分为可评判的评分要点'),
        maxLines: 7,
        controller: _referenceCtl,
      )),
      const SizedBox(height: 14),
      Row(
        children: [
          MonoText('评分要点 (${_points.length})', fontSize: 11, color: AppColors.text2Of(context)),
          const Spacer(),
          AppGhostButton(
            label: '+ 添加评分要点',
            small: true,
            onPressed: () => setState(() {
              _points.add(_Sp('', '', '', ''));
            }),
          ),
        ],
      ),
      if (_points.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: MonoText(
            '尚未添加评分要点。发布到病例广场前，请至少填写标准答案或评分要点，以支持 AI 评判。',
            fontSize: 11,
            color: AppColors.text3Of(context),
          ),
        )
      else
        ..._points.asMap().entries.map((e) => _scorePointCard(e.key, e.value)),
    ]);
  }

  /// 单条评分要点卡片（label/mark/criteria/deduct）
  ///
  /// 必须给最外层加 ObjectKey(p)：AI 填充/删除会就地替换 _points 列表，
  /// 若无 key，Flutter 会按 index 复用 Element，导致旧 TextField 的
  /// TextEditingController 与新 controller 绑定错位，触发 "used after being disposed"。
  /// ObjectKey 让 Element 随 _Sp 对象精确匹配/重建，彻底消灭该竞态。
  Widget _scorePointCard(int index, _Sp p) {
    return Container(
      key: ObjectKey(p),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        border: Border.all(color: AppColors.ruleSoftOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MonoText('要点 ${index + 1}',
                  fontSize: 11, color: AppColors.primaryOf(context)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  // 先从 _points 移除该要点，再在回帧后释放其控制器，
                  // 避免在本帧内释放仍被卡片内 TextField 引用的控制器。
                  final gone = _points.removeAt(index);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    gone.label.dispose();
                    gone.mark.dispose();
                    gone.criteria.dispose();
                    gone.deduct.dispose();
                  });
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 13, color: AppColors.vermilionOf(context)),
                    const SizedBox(width: 2),
                    MonoText('删除', fontSize: 11, color: AppColors.vermilionOf(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: _field('要点名', TextField(
                  decoration: _inputDec(hintText: '如：心电图判读'),
                  controller: p.label,
                )),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _field('满分', TextField(
                  decoration: _inputDec(hintText: '10'),
                  controller: p.mark,
                  keyboardType: TextInputType.number,
                )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _field('给分标准', TextField(
            decoration: _inputDec(hintText: '满足哪些条件给分'),
            maxLines: 2,
            controller: p.criteria,
          )),
          const SizedBox(height: 10),
          _field('扣分说明', TextField(
            decoration: _inputDec(hintText: '在何种情况下扣分（可选）'),
            maxLines: 2,
            controller: p.deduct,
          )),
        ],
      ),
    );
  }

  Widget _buildExamConfig() {
    return _buildFormSection('05', '检查项目配置', hint: '${_exams.length} 项', children: [
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
            MonoText(e.cost, fontSize: 11, color: AppColors.amberOf(context)),
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

  InputDecoration _inputDec({String? hintText}) => InputDecoration(
    filled: true,
    fillColor: AppColors.bgOf(context),
    hintText: hintText,
    hintStyle: hintText == null
        ? null
        : TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
