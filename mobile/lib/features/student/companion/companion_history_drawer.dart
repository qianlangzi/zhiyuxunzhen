import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'companion_conversation_provider.dart';

/// 学伴会话历史抽屉（底部弹层）
/// 展示按时间分组的会话列表，支持新建 / 重命名 / 删除，点击回调 [onSelect]。
class CompanionHistoryDrawer extends ConsumerWidget {
  final int? currentId;
  final void Function(int conversationId, String title) onSelect;

  const CompanionHistoryDrawer({
    super.key,
    this.currentId,
    required this.onSelect,
  });

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该会话？'),
        content: const Text('删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(companionConversationsProvider.notifier).remove(id);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('删除失败，请检查网络')));
        }
      }
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    int id,
    String currentTitle,
  ) async {
    final ctl = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(controller: ctl, maxLength: 30),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref
          .read(companionConversationsProvider.notifier)
          .rename(id, result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(companionConversationsProvider);
    final list = convs.valueOrNull ?? const <CompanionConversation>[];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Text(
                    '会话历史',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOf(context),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final c = await ref
                          .read(companionConversationsProvider.notifier)
                          .create();
                      if (context.mounted) {
                        onSelect(c.id, c.title);
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: const Text('新对话'),
                  ),
                ],
              ),
            ),
            if (convs.isLoading && list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '暂无历史会话',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _grouped(list)
                      .entries
                      .expand(
                        (entry) => [
                          _groupHeader(context, entry.key),
                          ...entry.value.map((c) => _tile(context, ref, c)),
                        ],
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, List<CompanionConversation>> _grouped(
    List<CompanionConversation> list,
  ) {
    final map = <String, List<CompanionConversation>>{};
    for (final c in list) {
      map.putIfAbsent(c.groupLabel, () => []).add(c);
    }
    return map;
  }

  Widget _groupHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.04,
          color: AppColors.text4Of(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, CompanionConversation c) {
    final selected = c.id == currentId;
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
        size: 18,
        color: AppColors.primaryOf(context),
      ),
      title: Text(
        c.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.5, color: AppColors.textOf(context)),
      ),
      selected: selected,
      selectedTileColor: AppColors.primaryOf(context).withValues(alpha: 0.08),
      onTap: () {
        Navigator.pop(context);
        onSelect(c.id, c.title);
      },
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) {
          if (v == 'rename') _rename(context, ref, c.id, c.title);
          if (v == 'delete') _confirmDelete(context, ref, c.id);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('重命名')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
