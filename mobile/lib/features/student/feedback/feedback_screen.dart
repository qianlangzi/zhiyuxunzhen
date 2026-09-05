import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_service.dart';

/// 体验反馈页（P2-3 真实用户数据）
/// 支持分类选择 + 满意度评分 + 反馈内容提交；下方展示我的历史反馈。
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const _categories = [
    ('general', '功能体验'),
    ('learning', '学习内容'),
    ('issue', '使用问题'),
    ('suggestion', '建议'),
    ('other', '其他'),
  ];

  String _category = 'general';
  int _rating = 0;
  final TextEditingController _ctl = TextEditingController();
  bool _submitting = false;

  List<dynamic> _history = const [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final data = await StudentService().myFeedback();
    if (!mounted) return;
    setState(() {
      _history = (data?['list'] as List<dynamic>?) ?? const [];
      _historyLoading = false;
    });
  }

  Future<void> _submit() async {
    final content = _ctl.text.trim();
    if (content.isEmpty && _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写反馈内容或评分')),
      );
      return;
    }
    setState(() => _submitting = true);
    final ok = await StudentService().submitFeedback(
      category: _category,
      rating: _rating,
      content: content,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
    });
    if (ok) {
      _ctl.clear();
      setState(() => _rating = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('感谢反馈，我们已收到！')),
      );
      _loadHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提交失败，请稍后重试')),
      );
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
              title: '意见反馈',
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _buildFormCard(),
                  const SizedBox(height: 16),
                  _buildHistoryCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback_outlined,
                  size: 18, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              SerifText('体验反馈', fontSize: 15, color: AppColors.textOf(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text('你的真实反馈将帮助我们持续优化产品，也会成为我们前进的动力。',
              style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 12),
          _buildRating(),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: '说说你的使用感受、遇到的问题或建议…',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
              filled: true,
              fillColor: AppColors.bgOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              label: _submitting ? '提交中…' : '提交反馈',
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) {
        final (key, label) = c;
        final selected = _category == key;
        return GestureDetector(
          onTap: () => setState(() => _category = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryOf(context).withValues(alpha: 0.12)
                  : AppColors.bgOf(context),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: selected
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceEdgeOf(context),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? AppColors.primaryOf(context)
                    : AppColors.text2Of(context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRating() {
    return Row(
      children: [
        MonoText('满意度', fontSize: 10, color: AppColors.text4Of(context)),
        const SizedBox(width: 8),
        ...List.generate(5, (i) {
          final filled = _rating >= i + 1;
          return GestureDetector(
            onTap: () => setState(() => _rating = i + 1),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              size: 28,
              color: filled ? AppColors.amberOf(context) : AppColors.text4Of(context),
            ),
          );
        }),
        const SizedBox(width: 8),
        if (_rating > 0)
          MonoText('$_rating 星', fontSize: 10, color: AppColors.amberOf(context)),
      ],
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 18, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              SerifText('我的反馈记录', fontSize: 14, color: AppColors.textOf(context)),
              const Spacer(),
              MonoText('${_history.length} 条',
                  fontSize: 10, color: AppColors.text4Of(context)),
            ],
          ),
          const SizedBox(height: 8),
          if (_historyLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('还没有反馈记录，来留下第一条吧',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.text4Of(context))),
              ),
            )
          else
            ..._history.map((f) => _buildFeedbackItem(f)),
        ],
      ),
    );
  }

  Widget _buildFeedbackItem(dynamic f) {
    final item = f is Map ? f : const <String, dynamic>{};
    final category = (item['category'] as String?) ?? 'general';
    final label = _categories.firstWhere(
      (c) => c.$1 == category,
      orElse: () => ('other', '其他'),
    ).$2;
    final rating = (item['rating'] as num?)?.toInt() ?? 0;
    final content = (item['content'] as String?) ?? '';
    final createdAt = (item['createdAt'] as String?) ?? '';
    final status = (item['status'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgOf(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppChip(label: label, type: ChipType.default_),
                const SizedBox(width: 8),
                if (rating > 0)
                  Row(
                    children: List.generate(rating, (_) => Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.amberOf(context))),
                  ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 1
                        ? AppColors.primaryOf(context).withValues(alpha: 0.12)
                        : AppColors.text4Of(context).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    status == 1 ? '已处理' : '待处理',
                    style: TextStyle(
                      fontSize: 10,
                      color: status == 1
                          ? AppColors.primaryOf(context)
                          : AppColors.text3Of(context),
                    ),
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(content,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.text2Of(context))),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(createdAt,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.text4Of(context))),
            ],
          ],
        ),
      ),
    );
  }
}
