import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/patient_profile.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 每日病历（每日一例升级版 · LeetCode 每日一题风格）
///
/// 数据流：GET /daily-cases/mr/today 返回今日卡（排期 + 我的记录 + 连续打卡）。
/// 学生点「开始书写」进入九段书写工坊，提交后 AI 结构化批阅出缺陷清单。
/// 历史病例在「病历题库」回看补做；打卡日历展示连续训练情况。
class DailyCaseScreen extends ConsumerStatefulWidget {
  const DailyCaseScreen({super.key});

  @override
  ConsumerState<DailyCaseScreen> createState() => _DailyCaseScreenState();
}

class _DailyCaseScreenState extends ConsumerState<DailyCaseScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _profileExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await StudentService().getTodayDailyMr();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  // ---------------- 数据解析 ----------------

  int? get _scheduleId => _data?['scheduleId'] as int?;
  String get _caseTitle => _data?['caseTitle'] as String? ?? '今日暂无排期';
  String get _department => _data?['department'] as String? ?? '';
  int get _difficulty => (_data?['difficulty'] as num?)?.toInt() ?? 2;
  int get _streak => (_data?['streak'] as num?)?.toInt() ?? 0;
  bool get _doneToday => _data?['doneToday'] as bool? ?? false;
  Map<String, dynamic>? get _myRecord => _data?['myRecord'] as Map<String, dynamic>?;

  PatientProfile get _profile =>
      parsePatientProfile(_data?['patientProfile'] as String?);

  ({String text, Color fg, Color bg}) get _difficultyInfo {
    if (_difficulty <= 1) {
      return (text: '入门', fg: AppColors.moss3Of(context), bg: AppColors.mossSoftOf(context));
    }
    if (_difficulty == 2) {
      return (text: '进阶', fg: AppColors.amberOf(context), bg: AppColors.amberSoftOf(context));
    }
    return (text: '挑战', fg: AppColors.vermilionOf(context), bg: AppColors.vermilionSoftOf(context));
  }

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.month}月${now.day}日';
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
              title: '每日病历',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildStreakBar(),
          const SizedBox(height: 12),
          if (_scheduleId == null) _buildEmpty() else ...[
            _buildTodayCard(),
            const SizedBox(height: 12),
            _buildHowTo(),
            const SizedBox(height: 12),
            _buildSegmentHint(),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  // ---------------- 打卡条 ----------------

  Widget _buildStreakBar() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _streak > 0
                  ? AppColors.amberSoftOf(context)
                  : AppColors.ruleSoftOf(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 24,
              color: _streak > 0 ? AppColors.amberOf(context) : AppColors.text4Of(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$_streak',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _streak > 0
                                ? AppColors.amberOf(context)
                                : AppColors.text3Of(context))),
                    const SizedBox(width: 4),
                    Text('天连续训练',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOf(context))),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _doneToday ? '今日已完成，明天继续保持' : '今天的病历已就绪，写完即可打卡',
                  style: TextStyle(fontSize: 11.5, color: AppColors.text3Of(context)),
                ),
              ],
            ),
          ),
          AppPressable(
            onTap: () => context.pushNamed(RouteNames.mrCalendar),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryOf(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: AppColors.primaryOf(context)),
                  const SizedBox(width: 4),
                  Text('打卡日历',
                      style: TextStyle(fontSize: 12, color: AppColors.primaryOf(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 今日病例卡 ----------------

  Widget _buildTodayCard() {
    final diff = _difficultyInfo;
    final profile = _profile;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceEdgeOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：今日任务标识 + 难度
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryOf(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('今日任务 · $_todayLabel',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOf(context))),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: diff.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(diff.text,
                    style: TextStyle(
                        fontSize: 11, color: diff.fg, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 标题 + 科室
          Text(
            _caseTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppColors.textOf(context),
            ),
          ),
          if (_department.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_department,
                style: TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
          ],
          // 患者信息 chips（性别/年龄/职业/过敏史）
          if (profile.chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in profile.chips)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bgOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
                    ),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '$label ',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.text4Of(context))),
                        TextSpan(
                            text: value,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text2Of(context))),
                      ]),
                    ),
                  ),
              ],
            ),
          ],
          // 主诉
          if (profile.complaint.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOf(context).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主诉',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryOf(context))),
                  const SizedBox(height: 3),
                  Text(profile.complaint,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOf(context))),
                ],
              ),
            ),
          ],
          // 病史摘要（可展开）
          if (profile.summary.isNotEmpty && profile.summary != profile.complaint) ...[
            const SizedBox(height: 12),
            Text(profile.summary,
                maxLines: _profileExpanded ? null : 5,
                overflow: _profileExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppColors.text2Of(context),
                )),
            if (profile.summary.length > 110) ...[
              const SizedBox(height: 4),
              AppPressable(
                onTap: () => setState(() => _profileExpanded = !_profileExpanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_profileExpanded ? '收起' : '展开全文',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryOf(context))),
                    Icon(
                      _profileExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: AppColors.primaryOf(context),
                    ),
                  ],
                ),
              ),
            ],
          ],
          // 已完成状态
          if (_doneToday) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.mossSoftOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.moss3Of(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('今天已提交，可查看批阅报告或再写一版',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.moss3Of(context))),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- 怎么用：三步引导 ----------------

  Widget _buildHowTo() {
    final steps = [
      (icon: Icons.description_rounded, title: '读病例', desc: '看患者画像与关键线索'),
      (icon: Icons.edit_note_rounded, title: '写九段', desc: '按规范逐段书写，卡住问 AI'),
      (icon: Icons.auto_awesome_rounded, title: 'AI 批阅', desc: '秒出缺陷清单，改到满意'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.paper2Of(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.text4Of(context)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(steps[i].icon, size: 15, color: AppColors.primaryOf(context)),
                      const SizedBox(width: 5),
                      Text(steps[i].title,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textOf(context))),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(steps[i].desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, height: 1.4, color: AppColors.text3Of(context))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- 九段结构 ----------------

  Widget _buildSegmentHint() {
    const segments = ['主诉', '现病史', '既往史', '查体', '辅检', '初步诊断', '诊断依据', '鉴别诊断', '诊疗计划'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('大病历九段',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context))),
              const Spacer(),
              Text('共 100 分',
                  style: TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < segments.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bgOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
                  ),
                  child: Text('${i + 1} ${segments[i]}',
                      style: TextStyle(fontSize: 11, color: AppColors.text2Of(context))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 操作区 ----------------

  Widget _buildActions() {
    if (_scheduleId == null) return const SizedBox.shrink();
    final hasRecord = _myRecord != null;
    return Column(
      children: [
        AppPrimaryButton(
          fullWidth: true,
          label: _doneToday ? '查看批阅报告' : '开始书写今日病历',
          onPressed: () async {
            if (_doneToday) {
              await context.pushNamed(RouteNames.mrReport,
                  pathParameters: {'scheduleId': '$_scheduleId'});
            } else {
              await context.pushNamed(RouteNames.mrWorkshop,
                  pathParameters: {'scheduleId': '$_scheduleId'});
            }
            _load();
          },
        ),
        const SizedBox(height: 10),
        AppGhostButton(
          fullWidth: true,
          label: hasRecord ? '再写一版（修订迭代）' : '看看往期病历题库',
          onPressed: () async {
            if (hasRecord) {
              await context.pushNamed(RouteNames.mrWorkshop,
                  pathParameters: {'scheduleId': '$_scheduleId'});
            } else {
              await context.pushNamed(RouteNames.mrBank);
            }
            _load();
          },
        ),
      ],
    );
  }

  // ---------------- 空态 ----------------

  Widget _buildEmpty() {
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.mossTintOf(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit_note_rounded,
                size: 36, color: AppColors.moss3Of(context)),
          ),
          const SizedBox(height: 16),
          Text('今天还没有排期',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context))),
          const SizedBox(height: 6),
          Text('可以先去题库看看往期病例，补写一份也行',
              style: TextStyle(fontSize: 12, color: AppColors.text3Of(context))),
        ],
      ),
    );
  }
}
