import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';
import '../textbook/ebook_reader_screen.dart';

/// 阅读任务页（组合任务包）
///
/// 展示指定教材与阅读范围，支持在线阅读电子书、标记已完成。
class ReadingTaskScreen extends ConsumerStatefulWidget {
  const ReadingTaskScreen({
    super.key,
    required this.instanceId,
    required this.itemProgressId,
    this.textbookTitle = '',
    this.textbookFileUrl,
    this.readingScope = '',
    this.author = '',
    this.initiallyCompleted = false,
  });

  final int instanceId;
  final int itemProgressId;
  final String textbookTitle;
  final String? textbookFileUrl;
  final String readingScope;
  final String author;
  /// 服务端任务项完成状态（status == 5 为已完成）。
  /// 不传会导致已完成的阅读任务再次打开时仍显示「标记已完成」，可无限重复提交。
  final bool initiallyCompleted;

  @override
  ConsumerState<ReadingTaskScreen> createState() => _ReadingTaskScreenState();
}

class _ReadingTaskScreenState extends ConsumerState<ReadingTaskScreen> {
  bool _completed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _completed = widget.initiallyCompleted;
  }

  Future<void> _complete() async {
    setState(() => _submitting = true);
    final result = await StudentService().completeReading(
      instanceId: widget.instanceId,
      itemProgressId: widget.itemProgressId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      AppFeedback.error(context, '操作失败，请重试');
      return;
    }
    setState(() => _completed = true);
    AppFeedback.success(context, '已标记完成');
  }

  void _openBook() {
    final url = widget.textbookFileUrl;
    if (url == null || url.isEmpty) {
      AppFeedback.info(context, '该教材暂无电子书文件');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EbookReaderScreen(
          title: widget.textbookTitle.isEmpty ? '阅读教材' : widget.textbookTitle,
          fileUrl: url,
        ),
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
              title: '阅读任务',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.amberSoftOf(context),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Icon(Icons.menu_book_rounded,
                                  size: 20, color: AppColors.amberOf(context)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SerifText(
                                    widget.textbookTitle.isEmpty
                                        ? '未命名教材'
                                        : widget.textbookTitle,
                                    fontSize: 15,
                                  ),
                                  if (widget.author.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    MonoText(widget.author, fontSize: 10,
                                        color: AppColors.text3Of(context)),
                                  ],
                                ],
                              ),
                            ),
                            if (_completed)
                              AppChip(label: '已完成', type: ChipType.moss, fontSize: 10),
                          ],
                        ),
                        if (widget.readingScope.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const DottedDivider(),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.pin_drop_outlined,
                                  size: 15, color: AppColors.amberOf(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '阅读范围：${widget.readingScope}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.text2Of(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(top: BorderSide(color: AppColors.ruleSoftOf(context))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.textbookFileUrl != null &&
                  widget.textbookFileUrl!.isNotEmpty) ...[
                AppGhostButton(
                  label: '阅读电子书',
                  icon: const Icon(Icons.auto_stories_outlined, size: 15),
                  fullWidth: true,
                  onPressed: _openBook,
                ),
                const SizedBox(height: 8),
              ],
              AppPrimaryButton(
                label: _completed
                    ? '已完成'
                    : (_submitting ? '提交中…' : '标记已完成'),
                fullWidth: true,
                icon: const Icon(Icons.check_rounded, size: 15),
                onPressed: _completed || _submitting ? null : _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
