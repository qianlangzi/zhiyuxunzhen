import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../common/data/drug_api.dart';

/// 药品详情页（训练中心 · 药房 · 说明书式速查）
///
/// 说明书式分段展示教学摘要：适应症 / 用法用量 / 不良反应 / 禁忌 / 注意事项，
/// 底部常驻医学免责声明。字段为后端 V37 种子里整理的摘要文案，用药一律以
/// 最新版说明书与医嘱为准。
class DrugDetailScreen extends ConsumerStatefulWidget {
  const DrugDetailScreen({super.key, required this.drugId});

  final int drugId;

  @override
  ConsumerState<DrugDetailScreen> createState() => _DrugDetailScreenState();
}

class _DrugDetailScreenState extends ConsumerState<DrugDetailScreen> {
  Map<String, dynamic>? _drug;
  bool _isLoading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _notFound = false;
    });
    final resp = await DrugApi().getDrugDetail(widget.drugId);
    if (!mounted) return;
    setState(() {
      if (resp.isSuccess && resp.data != null) {
        _drug = resp.data;
      } else {
        _notFound = true;
      }
      _isLoading = false;
    });
  }

  String _s(Map<String, dynamic> d, String k) => d[k] as String? ?? '';
  bool _b(Map<String, dynamic> d, String k) => (d[k] as num?)?.toInt() == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '药品详情', action: _buildRefresh()),
            Expanded(
              child: _isLoading
                  ? _buildSkeleton()
                  : (_notFound || _drug == null)
                      ? _buildNotFound()
                      : _buildBody(_drug!),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildRefresh() {
    return IconButton(
      icon: const Icon(Icons.refresh_rounded, size: 20),
      onPressed: _load,
    );
  }

  // ---------- 主体 ----------
  Widget _buildBody(Map<String, dynamic> d) {
    final isOtc = _b(d, 'isOtc');
    final sections = <(String, String)>[
      if (_s(d, 'indications').isNotEmpty) ('适应症', _s(d, 'indications')),
      if (_s(d, 'usageDosage').isNotEmpty) ('用法用量', _s(d, 'usageDosage')),
      if (_s(d, 'adverseReactions').isNotEmpty)
        ('不良反应', _s(d, 'adverseReactions')),
      if (_s(d, 'contraindications').isNotEmpty)
        ('禁忌', _s(d, 'contraindications')),
      if (_s(d, 'precautions').isNotEmpty) ('注意事项', _s(d, 'precautions')),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _buildHeaderCard(d, isOtc),
        const SizedBox(height: 14),
        for (final (title, body) in sections) _buildSection(title, body),
        const MedicalDisclaimer(),
      ],
    );
  }

  /// 顶部药名卡：通用名大标题 + 商品名 / 英文名 / 维度标签
  Widget _buildHeaderCard(Map<String, dynamic> d, bool isOtc) {
    final generic = _s(d, 'genericName');
    final trade = _s(d, 'tradeName');
    final english = _s(d, 'englishName');
    final category = _s(d, 'category');
    final department = _s(d, 'department');
    final dosageForm = _s(d, 'dosageForm');
    final depts = department
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final accent = isOtc ? AppColors.amberOf(context) : AppColors.primaryOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.8)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isOtc ? Icons.storefront_outlined : Icons.medication_outlined,
                  size: 24,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            generic,
                            style: TextStyle(
                              fontFamily: 'NotoSerifSC',
                              fontFamilyFallback: const [
                                'Songti SC',
                                'STSong',
                                'Noto Serif CJK SC',
                                'Source Han Serif SC',
                                'sans-serif',
                              ],
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOf(context),
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            isOtc ? '非处方药 OTC' : '处方药',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: kCjkMonoFallback,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (trade.isNotEmpty || english.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        [
                          if (trade.isNotEmpty) '商品名：$trade',
                          if (english.isNotEmpty) english,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.text3Of(context)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.ruleOf(context), height: 1),
          const SizedBox(height: 12),
          if (category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 14, color: AppColors.text4Of(context)),
                  const SizedBox(width: 6),
                  Text('药理分类',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text4Of(context))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(category,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2Of(context))),
                  ),
                ],
              ),
            ),
          if (depts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.local_hospital_outlined,
                        size: 14, color: AppColors.text4Of(context)),
                  ),
                  const SizedBox(width: 6),
                  Text('适用科室',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.text4Of(context))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final dept in depts)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.ruleSoftOf(context),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              dept,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.text3Of(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (dosageForm.isNotEmpty)
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.text4Of(context)),
                const SizedBox(width: 6),
                Text('剂型规格',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.text4Of(context))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(dosageForm,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text2Of(context))),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 说明书分段卡：等宽眉标 + 正文
  Widget _buildSection(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.6)),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primaryOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              MonoText(title,
                  fontSize: 11.5,
                  color: AppColors.primaryOf(context),
                  weight: FontWeight.w600,
                  letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textOf(context),
              height: 1.62,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 骨架 / 空态 ----------
  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: const [
        AppSkeleton(height: 150, radius: AppRadius.xl),
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: AppSkeleton(height: 120, radius: AppRadius.lg),
        ),
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: AppSkeleton(height: 160, radius: AppRadius.lg),
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined,
              size: 44, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text('药品不存在或已下架',
              style:
                  TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }
}
