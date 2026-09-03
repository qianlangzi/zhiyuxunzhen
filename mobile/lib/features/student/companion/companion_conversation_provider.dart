import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/student_service.dart';

/// 学伴会话（历史列表项）
class CompanionConversation {
  final int id;
  final String title;
  final DateTime createdAt;

  const CompanionConversation({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  /// 按时间分组的文案：今天 / 昨天 / 7 天内 / 这个月 / x 月 / x 年
  String get groupLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '7 天内';
    if (createdAt.year == now.year && createdAt.month == now.month) {
      return '这个月';
    }
    if (createdAt.year == now.year) return '${createdAt.month} 月';
    return '${createdAt.year} 年';
  }
}

/// 学伴会话列表状态管理（异步加载 + shared_preferences 本地缓存兜底）
/// 优先走后端真实会话 CRUD；后端不可用时退回本地缓存数据（离线浏览场景）。
class CompanionConversationNotifier
    extends StateNotifier<AsyncValue<List<CompanionConversation>>> {
  CompanionConversationNotifier() : super(const AsyncValue.loading());

  static const _cacheKey = 'companion_conversations_v1';

  final StudentService _svc = StudentService();
  int _nextId = 1000; // 本地临时会话 id 起点，避免与服务端 id 冲突

  Future<void> load() async {
    state = const AsyncValue.loading();
    List<CompanionConversation>? local;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        local = (jsonDecode(cached) as List)
            .cast<Map<String, dynamic>>()
            .map(_parse)
            .toList();
        state = AsyncValue.data(local);
      }
    } catch (_) {
      // 缓存损坏时忽略，直接走后端
    }
    try {
      final data = await _svc.getCompanionConversations();
      final list = _parseList(data);
      if (list.isNotEmpty) {
        state = AsyncValue.data(list);
        await _cache(list);
      } else if (local == null) {
        state = const AsyncValue.data([]);
      }
    } catch (_) {
      // 后端失败时保留缓存态；无缓存则置空
      if (local == null) state = const AsyncValue.data([]);
    }
  }

  /// 新建会话：优先走后端，后端无返回时生成本地临时会话
  Future<CompanionConversation> create() async {
    CompanionConversation conv;
    try {
      final data = await _svc.createCompanionConversation(title: '新对话');
      conv = data != null ? _parse(data) : _localTemp();
    } catch (_) {
      conv = _localTemp();
    }
    final updated = [
      conv,
      ...(state.valueOrNull ?? const <CompanionConversation>[]),
    ];
    state = AsyncValue.data(updated);
    await _cache(updated);
    return conv;
  }

  /// 重命名会话：乐观更新本地与缓存，后端失败时回滚
  Future<void> rename(int id, String title) async {
    final before = state.valueOrNull ?? const <CompanionConversation>[];
    final updated = before.map((c) {
      if (c.id != id) return c;
      return CompanionConversation(
        id: c.id,
        title: title,
        createdAt: c.createdAt,
      );
    }).toList();
    state = AsyncValue.data(updated);
    await _cache(updated);
    try {
      await _svc.renameCompanionConversation(id, title);
    } catch (_) {
      state = AsyncValue.data(before);
      await _cache(before);
      rethrow;
    }
  }

  /// 删除会话：乐观移除，后端失败时恢复并抛错（交由 UI 提示）
  Future<void> remove(int id) async {
    final before = state.valueOrNull ?? const <CompanionConversation>[];
    final updated = before.where((c) => c.id != id).toList();
    state = AsyncValue.data(updated);
    await _cache(updated);
    try {
      await _svc.deleteCompanionConversation(id);
    } catch (_) {
      state = AsyncValue.data(before);
      await _cache(before);
      rethrow;
    }
  }

  CompanionConversation _localTemp() => CompanionConversation(
        id: _nextId++,
        title: '新对话',
        createdAt: DateTime.now(),
      );

  CompanionConversation _parse(Map<String, dynamic> e) => CompanionConversation(
        id: (e['id'] as num).toInt(),
        title: (e['title'] as String?)?.trim().isNotEmpty == true
            ? e['title'] as String
            : '新对话',
        createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  List<CompanionConversation> _parseList(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final list =
        (data['list'] as List?) ?? (data['records'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .cast<Map<String, dynamic>>()
        .map(_parse)
        .toList();
  }

  Future<void> _cache(List<CompanionConversation> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = [
        for (final c in list)
          {
            'id': c.id,
            'title': c.title,
            'createdAt': c.createdAt.toIso8601String(),
          },
      ];
      await prefs.setString(_cacheKey, jsonEncode(items));
    } catch (_) {
      // 本地缓存失败不影响内存状态
    }
  }
}

final companionConversationsProvider = StateNotifierProvider.autoDispose<
    CompanionConversationNotifier, AsyncValue<List<CompanionConversation>>>(
  (ref) => CompanionConversationNotifier()..load(),
);
