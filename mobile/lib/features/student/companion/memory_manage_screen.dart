import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../data/student_api.dart';
import '../../../core/network/page_parser.dart';

/// AI 学伴记忆管理页（P1-2）
/// 查看 AI 从对话中抽取的长期记忆，支持单条删除 / 一键清空。
/// 仅学伴链路生效：AI 学伴会依据这些记忆跨会话个性化，学生可随时掌控与删除。
class MemoryManageScreen extends ConsumerStatefulWidget {
  const MemoryManageScreen({super.key});

  @override
  ConsumerState<MemoryManageScreen> createState() => _MemoryManageScreenState();
}

class _MemoryManageScreenState extends ConsumerState<MemoryManageScreen> {
  static const int _pageSize = 100;

  final StudentApi _api = StudentApi();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadFailed = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final resp = await _api.getCompanionMemories(pageNum: 1, pageSize: _pageSize);
    if (!mounted) return;
    final data = resp.data;
    if (resp.code == 0 && data != null) {
      setState(() {
        _items
          ..clear()
          ..addAll(PageParser.mapListOf(data));
        _total = PageParser.totalOf(data) > 0
            ? PageParser.totalOf(data)
            : _items.length;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _removeOne(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await AppFeedback.confirm(
      context,
      title: '删除这条记忆',
      content: '删除后 AI 学伴将不再记得这条内容。',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final resp = await _api.deleteCompanionMemory(id);
    if (!mounted) return;
    if (resp.code == 0) {
      setState(() {
        _items.removeWhere((e) => e['id'] == id);
        _total = _total > 0 ? _total - 1 : 0;
      });
      _toast('已删除');
    } else {
      _toast(resp.message);
    }
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) return;
    final confirmed = await AppFeedback.confirm(
      context,
      title: '清空全部记忆',
      content: '将删除 AI 学伴记住的关于你的全部 ${_items.length} 条内容，'
          '清空后 AI 将不再记得之前的聊天。此操作不可恢复。',
      confirmText: '全部清空',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final resp = await _api.clearCompanionMemories();
    if (!mounted) return;
    if (resp.code == 0) {
      setState(() {
        _items.clear();
        _total = 0;
      });
      _toast('已清空全部记忆');
    } else {
      _toast(resp.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
      ));
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
              title: 'AI 记忆管理',
              action: _items.isNotEmpty
                  ? TextButton(
                      onPressed: _clearAll,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.vermilionOf(context),
                      ),
                      child: const Text('清空', style: TextStyle(fontSize: 13)),
                    )
                  : null,
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('记忆加载失败，请稍后重试'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 56,
                color: AppColors.text4Of(context),
              ),
              const SizedBox(height: 16),
              Text(
                'AI 还没有记住关于你的内容\n去和 AI 学伴聊聊你的学习目标、困扰或习惯\n它会把这些沉淀为长期记忆，并在之后主动用上',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.text3Of(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
          child: Text(
            '共 $_total 条记忆 · 删除后 AI 学伴将不再记得',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.text4Of(context),
            ),
          ),
        ),
        for (final item in _items) _MemoryCard(item: item, onDelete: () => _removeOne(item)),
        if (_total > _items.length)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                '仅展示最近 ${_items.length} 条',
                style: TextStyle(fontSize: 11, color: AppColors.text4Of(context)),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.item, required this.onDelete});

  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  static const Map<String, String> _typeLabels = {
    'fact': '一般记忆',
    'profile': '个人信息',
    'goal': '学习目标',
    'preference': '偏好习惯',
    'learning': '学习情况',
  };

  String _fmtTime(String? raw) {
    if (raw == null || raw.length < 16) return '';
    final t = raw.replaceFirst('T', ' ');
    return t.substring(0, 16);
  }

  @override
  Widget build(BuildContext context) {
    final type = (item['factType'] as String?) ?? 'fact';
    final content = (item['content'] as String?) ?? '';
    final time = _fmtTime(item['createdAt'] as String?);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppPaper(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.mossTintOf(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _typeLabels[type] ?? '一般记忆',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.text4Of(context),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.text2Of(context),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.text4Of(context),
              ),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}
