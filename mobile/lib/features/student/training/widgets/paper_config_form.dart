import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/utils/feedback.dart';
import '../../data/student_service.dart';

/// 组卷配置参数。scorePerQuestion 为每题分值（分），后端不支持时前端本地用于打分。
class PaperConfig {
  const PaperConfig({
    required this.questionTypes,
    required this.departments,
    required this.knowledgeTags,
    this.difficulty,
    required this.count,
    required this.scorePerQuestion,
  });
  final List<String> questionTypes;
  final List<String> departments;
  final List<String> knowledgeTags;
  final int? difficulty;
  final int count;

  /// 每题分值（分），本地打分用
  final double scorePerQuestion;

  /// 预估满分 = 题量 × 每题分值
  double get totalScore => count * scorePerQuestion;
}

/// 组卷配置表单 —— 「AI 组卷自测」的参数配置卡
///
/// 新版视觉（对齐全 App 设计语言 + 深色自适应）：
/// - 题型 / 难度改为「实底/轻量胶囊选择器」，选中态高对比，夜间可读
/// - 折叠区块头由调用方注入折叠态与回调，不再用标题字符串匹配（防改文案即坏）
/// - 题量 / 分值滑块用 [SliderTheme] 品牌化：圆润 thumb + 圆角轨道 + 刻度
/// - 分值显示修正：半分不再被四舍五入（2.5 显示为 3 的问题）
/// - 全部颜色走 Of(context) 语义色，夜间 / 主题预设切换不串色
class PaperConfigForm extends ConsumerStatefulWidget {
  const PaperConfigForm({super.key, required this.onSubmit});
  final ValueChanged<PaperConfig> onSubmit;
  @override
  ConsumerState<PaperConfigForm> createState() => _PaperConfigFormState();
}

class _PaperConfigFormState extends ConsumerState<PaperConfigForm> {
  static const double _scoreMin = 1;
  static const double _scoreMax = 5;

  static const List<({String value, String label, IconData icon})> _typeOptions = [
    (value: 'single_choice', label: '单选', icon: Icons.radio_button_checked),
    (value: 'judgment', label: '判断', icon: Icons.rule),
    (value: 'multiple_choice', label: '多选', icon: Icons.checklist),
    (value: 'fill_blank', label: '填空', icon: Icons.text_fields),
    (value: 'sp_case', label: 'SP 病例', icon: Icons.assignment),
  ];

  /// 难度选项：value == null 表示不限
  static const List<({int? value, String label})> _difficultyOptions = [
    (value: null, label: '不限'),
    (value: 1, label: '简单'),
    (value: 2, label: '标准'),
    (value: 3, label: '困难'),
  ];

  final Set<String> _questionTypes = {'single_choice', 'judgment'};
  final Set<String> _departments = {};
  final Set<String> _knowledgeTags = {};
  int? _difficulty;
  double _count = 10;
  double _score = 2;
  bool _foldBase = false; // 题型/难度基础项是否折叠（默认展开）
  bool _foldScope = true; // 科室/知识点长项是否折叠（默认收起）
  List<String> _deptOptions = const [];
  List<String> _tagOptions = const [];
  bool _loadingOptions = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final service = StudentService();
    final depts = await service.getQuestionDepartments();
    final tags = await service.getQuestionKnowledgeTags();
    if (!mounted) return;
    setState(() {
      _deptOptions = (depts ?? const [])
          .map((e) => '$e')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      _tagOptions = (tags ?? const [])
          .map((e) => '$e')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      _loadingOptions = false;
    });
  }

  bool get _canSubmit => _questionTypes.isNotEmpty;

  /// 分值展示文案：整分不带小数，半分保留 1 位
  String get _scoreLabel => _score % 1 == 0
      ? _score.toStringAsFixed(0)
      : _score.toStringAsFixed(1);

  int get _totalQuestions => _count.round();
  int get _totalScore => (_count.round() * _score).round();

  void _submit() {
    if (!_canSubmit) {
      AppFeedback.info(context, '请至少选择一种题型');
      return;
    }
    widget.onSubmit(PaperConfig(
      questionTypes: _questionTypes.toList(),
      departments: _departments.toList(),
      knowledgeTags: _knowledgeTags.toList(),
      difficulty: _difficulty,
      count: _count.round(),
      scorePerQuestion: _score,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _sectionDivider(),
          _buildBaseSection(),
          _sectionDivider(),
          _buildScopeSection(),
          _sectionDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sliderBlock(
                  title: '题量',
                  valueLabel: '$_totalQuestions 题',
                  value: _count,
                  min: 5,
                  max: 50,
                  divisions: 45,
                  hint: '线性步进 · 1 题一档',
                  onChanged: (v) => setState(() => _count = v),
                ),
                _sliderBlock(
                  title: '每题分值',
                  valueLabel: '$_scoreLabel 分/题',
                  value: _score,
                  min: _scoreMin,
                  max: _scoreMax,
                  divisions: ((_scoreMax - _scoreMin) * 2).round(),
                  hint: '0.5 分步进',
                  onChanged: (v) => setState(() => _score = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 满分提示条
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.mossTintOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 15, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '本卷预估满分 $_totalScore 分 · 共 $_totalQuestions 题',
                          style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppGradientButton(
                  label: '开始生成',
                  color: primary,
                  height: 48,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, thickness: 0.6, color: AppColors.ruleSoftOf(context)),
    );
  }

  /// 头部：AI 图标块 + 标题 + 当前分值徽标
  Widget _buildHeader() {
    final primary = AppColors.primaryOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, AppColors.moss3Of(context)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadow.lifted(context),
            ),
            child: Icon(Icons.auto_awesome, size: 18, color: AppColors.onPrimaryOf(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SerifText('AI 组卷配置', fontSize: 15, color: AppColors.textOf(context), weight: FontWeight.w700),
                const SizedBox(height: 2),
                MonoText('选择题型与范围，AI 按薄弱点优先组卷', fontSize: 10, color: AppColors.text4Of(context)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mossTintOf(context),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: MonoText('$_scoreLabel 分/题', fontSize: 10, color: primary, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// 区块一：题型（实底胶囊）+ 难度（轻量胶囊）—— 折叠共同控制
  Widget _buildBaseSection() {
    return _foldWrap(
      folded: _foldBase,
      onToggle: () => setState(() => _foldBase = !_foldBase),
      title: '题型与难度',
      badge: _questionTypes.isEmpty ? null : '${_questionTypes.length} 类已选',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText('题型（可多选）', fontSize: 10, color: AppColors.text4Of(context)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _typeOptions)
              _typePill(t: t, selected: _questionTypes.contains(t.value)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              MonoText('难度', fontSize: 10, color: AppColors.text4Of(context)),
              const Spacer(),
              if (_difficulty != null)
                MonoText(
                  _difficultyOptions.firstWhere((d) => d.value == _difficulty).label,
                  fontSize: 9,
                  color: AppColors.primaryOf(context),
                  weight: FontWeight.w600,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in _difficultyOptions)
              _choicePill(
                label: d.label,
                selected: _difficulty == d.value,
                emphasized: false,
                onTap: () => setState(() => _difficulty = d.value),
              ),
          ]),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  /// 区块二：学科 + 知识点（折叠）
  Widget _buildScopeSection() {
    final scopeCount = _departments.length + _knowledgeTags.length;
    return _foldWrap(
      folded: _foldScope,
      onToggle: () => setState(() => _foldScope = !_foldScope),
      title: '学科 / 知识点',
      badge: scopeCount > 0 ? '$scopeCount 项已选' : '选填',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingOptions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_deptOptions.isEmpty)
            MonoText('暂无可选科室', fontSize: 12, color: AppColors.text4Of(context))
          else ...[
            _miniTitle('科室'),
            _wrapChips(_deptOptions, _departments),
          ],
          if (!_loadingOptions && _tagOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _miniTitle('知识点'),
            _wrapChips(_tagOptions, _knowledgeTags),
          ],
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  /// 折叠包装：头部（点击展开/收起）+ 内容
  Widget _foldWrap({
    required bool folded,
    required VoidCallback onToggle,
    required String title,
    required String? badge,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _foldHeader(
            title: title,
            badge: badge,
            folded: folded,
            onToggle: onToggle,
          ),
          if (!folded) child,
        ],
      ),
    );
  }

  /// 折叠区块头。箭头语义：展开 = 向上（可收起），收起 = 向下（可展开）
  Widget _foldHeader({
    required String title,
    required String? badge,
    required bool folded,
    required VoidCallback onToggle,
  }) {
    final primary = AppColors.primaryOf(context);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SerifText(title, fontSize: 13, color: AppColors.text2Of(context), weight: FontWeight.w600),
            const SizedBox(width: 8),
            if (badge != null)
              Flexible(
                child: Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.text4Of(context),
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: kCjkMonoFallback,
                    letterSpacing: 0.04,
                  ),
                ),
              ),
            const Spacer(),
            AnimatedRotation(
              turns: folded ? 0 : 0.5,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: folded ? AppColors.ruleSoftOf(context) : primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: folded ? AppColors.text3Of(context) : primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 题型胶囊：选中实底 + 白字（主强调）
  Widget _typePill({
    required ({String value, String label, IconData icon}) t,
    required bool selected,
  }) {
    final primary = AppColors.primaryOf(context);
    return PressableScale(
      child: GestureDetector(
        onTap: () => setState(() {
          if (selected) {
            _questionTypes.remove(t.value);
          } else {
            _questionTypes.add(t.value);
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? primary : AppColors.ruleOf(context),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.18),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                t.icon,
                size: 13,
                color: selected ? AppColors.onPrimaryOf(context) : AppColors.text3Of(context),
              ),
              const SizedBox(width: 5),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.onPrimaryOf(context) : AppColors.text2Of(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 通用选择胶囊：emphasized=false 时用 tint 底（轻量多选场景）
  Widget _choicePill({
    required String label,
    required bool selected,
    required bool emphasized,
    required VoidCallback onTap,
  }) {
    final primary = AppColors.primaryOf(context);
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (emphasized ? primary : AppColors.mossTintOf(context))
                : AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? primary : AppColors.ruleOf(context),
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? (emphasized ? AppColors.onPrimaryOf(context) : primary)
                  : AppColors.text2Of(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapChips(List<String> options, Set<String> selected) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        _choicePill(
          label: o,
          selected: selected.contains(o),
          emphasized: false,
          onTap: () => setState(() {
            if (selected.contains(o)) {
              selected.remove(o);
            } else {
              selected.add(o);
            }
          }),
        ),
    ]);
  }

  Widget _miniTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MonoText(title, fontSize: 10, color: AppColors.text4Of(context)),
    );
  }

  Widget _sliderBlock({
    required String title,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String hint,
    required ValueChanged<double> onChanged,
  }) {
    final primary = AppColors.primaryOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SerifText(title, fontSize: 13, color: AppColors.text2Of(context), weight: FontWeight.w600),
            const Spacer(),
            MonoText(valueLabel, fontSize: 12, color: primary, weight: FontWeight.w800),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: primary,
            inactiveTrackColor: AppColors.paper2Of(context),
            thumbColor: primary,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 9,
              elevation: 2,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            overlayColor: primary.withValues(alpha: 0.12),
            valueIndicatorColor: primary,
            valueIndicatorTextStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimaryOf(context),
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        MonoText('$hint · 满分 $_totalScore 分', fontSize: 10, color: AppColors.text4Of(context)),
        const SizedBox(height: 14),
      ],
    );
  }
}
