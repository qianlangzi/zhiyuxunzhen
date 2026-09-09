import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';
import '../../student/training/question_practice_screen.dart';
import 'ebook_reader_screen.dart';
import 'ebook_cache.dart';
import 'image_search_screen.dart';

/// 教材中心
///
/// 针对「教材越来越多、难检索、封面不展示、分类固定写死、刷题跳不到具体知识点」
/// 等问题做的深化：
/// 1. 科室分类改为从后端动态拉取，不再硬编码；
/// 2. 卡片展示教材封面图（coverUrl），缺失时优雅占位；
/// 3. 顶部内嵌搜索框，支持模糊搜索（书名/作者/科室/出版社，服务端 like 模糊匹配）；
/// 4. 标签只展示精简有用的前 2 个知识点，去掉无用冗余标签；
/// 5. “去刷对应基础题”直接跳转到该教材对应科室+知识点的题目，而非总入口。
class TextbookCenterScreen extends StatelessWidget {
  const TextbookCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '教材中心',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.studentHome),
              action: PopupMenuButton<String>(
                icon: Icon(Icons.cleaning_services_outlined, size: 20, color: AppColors.text2Of(context)),
                tooltip: '缓存管理',
                onSelected: (v) => TextbookCenterView.handleCacheAction(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('查看缓存', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text('清除电子书缓存', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Expanded(child: TextbookCenterView()),
          ],
        ),
      ),
    );
  }
}

/// 教材列表分页拉取器：返回 PageResult 兼容 Map（data.list / data.total）。
typedef TextbookPageFetcher = Future<Map<String, dynamic>?> Function({
  required int pageNum,
  required int pageSize,
  String? department,
  String? keyword,
});

/// 教材大厅可复用视图（搜索 + 科室筛选 + 封面卡片列表 + 详情/在线阅读/去刷题）。
///
/// 学生端「教材中心」与教师端「教材管理 · 教材库」共用此视图，保证两端
/// 浏览体验一致；宿主自行提供 Scaffold / AppBar，本组件只负责主体内容。
///
/// 数据源可注入：学生端默认走 /api/v1/student/textbooks；教师端传入
/// TeacherService 的教材库方法（/api/v1/teacher/textbooks/library，权限拦截
/// 决定了教师无法调用学生端接口）。[showPracticeAction] 控制详情页
/// 「去刷对应基础题」按钮——学生端作答链路对教师不可用，教师端关闭。
class TextbookCenterView extends ConsumerStatefulWidget {
  const TextbookCenterView({
    super.key,
    this.fetchPage,
    this.fetchDepartments,
    this.showPracticeAction = true,
  });

  /// 分页拉取教材（缺省 = 学生端教材中心接口）
  final TextbookPageFetcher? fetchPage;

  /// 拉取科室筛选项（缺省 = 学生端接口）
  final Future<List<String>> Function()? fetchDepartments;

  /// 教材详情是否展示「去刷对应基础题」（教师端无学生作答链路，传 false）
  final bool showPracticeAction;

  /// 缓存管理（查看 / 清除电子书缓存），供宿主 AppBar 菜单复用。
  static Future<void> handleCacheAction(BuildContext context, String action) async {
    if (action == 'info') {
      final size = await EbookCache.cacheSizeFormatted;
      final count = await EbookCache.cachedCount;
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(
            children: [
              Icon(Icons.storage_outlined, size: 20, color: AppColors.primaryOf(context)),
              const SizedBox(width: 8),
              const Text('电子书缓存', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cacheInfoRow(ctx, '已缓存教材', '$count 本'),
              const SizedBox(height: 8),
              _cacheInfoRow(ctx, '占用空间', size),
              const SizedBox(height: 8),
              Text('缓存文件存储在临时目录，系统或应用清理时可能被清除',
                  style: TextStyle(fontSize: 11, color: AppColors.text3Of(context))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('知道了', style: TextStyle(color: AppColors.primaryOf(context))),
            ),
          ],
        ),
      );
    } else if (action == 'clear') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('清除缓存？', style: TextStyle(fontSize: 16)),
          content: Text('将删除所有已下载的电子书离线文件，下次打开需重新下载。',
              style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('取消', style: TextStyle(color: AppColors.text2Of(context))),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('确认清除', style: TextStyle(color: AppColors.vermilionOf(context))),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      final freed = await EbookCache.clearCache();
      if (!context.mounted) return;
      if (freed >= 0) {
        final mb = (freed / (1024 * 1024)).toStringAsFixed(1);
        AppFeedback.success(context, '已释放 $mb MB 空间');
      } else {
        AppFeedback.error(context, '清除失败，请重试');
      }
    }
  }

  static Widget _cacheInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  ConsumerState<TextbookCenterView> createState() => _TextbookCenterViewState();
}

class _TextbookCenterViewState extends ConsumerState<TextbookCenterView> {
  static const _fallbackFilters = ['全部', '基础医学', '综合', '心血管内科', '呼吸内科'];
  static const int _pageSize = 20;

  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<String> _filters = ['全部'];
  String _selectedFilter = '全部';
  String _query = '';
  List<Map<String, dynamic>> _textbooks = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _pageNum = 1;
  int _total = 0;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // 科室筛选与首页教材无依赖，串行 await 会让页面加载时间翻倍，
    // 这里并行拉取（学生端教材中心与教师端教材库共同受益）
    await Future.wait([_loadDepartments(), _load(reset: true)]);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
  }

  String? get _filterKeyword {
    if (_selectedFilter == '全部') return null;
    return _selectedFilter;
  }

  Future<void> _loadDepartments() async {
    final depts = widget.fetchDepartments != null
        ? await widget.fetchDepartments!()
        : await StudentService().getTextbookDepartments();
    if (!mounted) return;
    final list = (depts ?? const []).cast<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();
    setState(() {
      _filters = ['全部', ...list.isEmpty ? _fallbackFilters.sublist(1) : list];
    });
  }

  /// 分页加载教材（首屏重置 / 上滑翻页）
  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _pageNum = 1;
      setState(() {
        _isLoading = true;
        _loadingMore = false;
        _textbooks = [];
      });
    } else {
      setState(() => _loadingMore = true);
    }
    // 数据源可注入：学生端默认走 /api/v1/student/textbooks；教师端教材库 Tab
    // 注入 TeacherService 的 /teacher/textbooks/library。此前这里写死了学生端
    // 接口，教师 token 被权限拦截导致教师端教材库恒为空——必须优先用注入源。
    final data = widget.fetchPage != null
        ? await widget.fetchPage!(
            pageNum: _pageNum,
            pageSize: _pageSize,
            department: _filterKeyword,
            keyword: _query.trim().isEmpty ? null : _query.trim(),
          )
        : await StudentService().getTextbooks(
            pageNum: _pageNum,
            pageSize: _pageSize,
            department: _filterKeyword,
            keyword: _query.trim().isEmpty ? null : _query.trim(),
          );
    if (!mounted) return;
    final list = (data?['list'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    setState(() {
      if (reset) {
        _textbooks = list;
      } else {
        _textbooks = [..._textbooks, ...list];
      }
      _total = total;
      _hasMore = _textbooks.length < _total;
      _isLoading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _isLoading || !_hasMore) return;
    _pageNum++;
    await _load(reset: false);
  }

  /// 搜索框输入去抖后触发模糊搜索
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _query = value.trim();
      _load(reset: true);
    });
  }

  void _selectFilter(String f) {
    if (_selectedFilter == f) return;
    setState(() => _selectedFilter = f);
    _load(reset: true);
  }

  void _clearSearch() {
    _searchCtl.clear();
    _debounce?.cancel();
    _query = '';
    _load(reset: true);
  }

  void _openEbook(Map<String, dynamic> tb) {
    final url = tb['fileUrl'] as String? ?? '';
    if (url.isEmpty) {
      AppFeedback.info(context, '该教材暂无电子书文件');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EbookReaderScreen(
          title: tb['title'] as String? ?? '教材',
          fileUrl: url,
        ),
      ),
    );
  }

  /// 进入该教材对应科室 + 第一个知识点的题目作答
  void _openPractice(Map<String, dynamic> tb) {
    final dept = tb['department'] as String?;
    final tags = parseTags(tb['knowledgeTags']);
    final tag = tags.isNotEmpty ? tags.first : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionPracticeScreen(
          title: '${tb['title'] ?? '教材'} · 基础题',
          department: dept,
          knowledgeTag: tag,
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> tb) {
    final tags = parseTags(tb['knowledgeTags']);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoverThumb(
                    url: tb['coverUrl'] as String?,
                    size: 56,
                    title: tb['title'] as String? ?? '',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SerifText(tb['title'] as String? ?? '教材', fontSize: 18),
                        const SizedBox(height: 6),
                        MonoText(
                          '${tb['edition'] ?? ''} · ${tb['author'] ?? ''} · ${tb['publisher'] ?? ''}',
                          fontSize: 11,
                          color: AppColors.text3Of(context),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Icon(Icons.close, size: 20, color: AppColors.text3Of(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags
                      .take(4)
                      .map((t) => AppChip(label: t, type: ChipType.moss))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                tb['description'] as String? ?? '暂无简介',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.text2Of(context),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  MonoText('共 ${tb['chapterCount'] ?? 0} 章 · ${tb['pageCount'] ?? 0} 页',
                      fontSize: 11, color: AppColors.text3Of(context)),
                  const Spacer(),
                  if (tb['fileUrl'] != null && (tb['fileUrl'] as String).isNotEmpty) ...[
                    AppGhostButton(
                      label: '在线阅读',
                      small: true,
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openEbook(tb);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.showPracticeAction)
                    AppPrimaryButton(
                      label: '去刷对应基础题',
                      small: true,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openPractice(tb);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: _textbooks.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
                ),
        ),
      ],
    );
  }

  // ---------- 顶部搜索框 ----------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: AppSearchField(
              controller: _searchCtl,
              hintText: '搜索教材 · 书名 / 作者 / 科室 / 知识点',
              onChanged: _onQueryChanged,
              onClear: _clearSearch,
            ),
          ),
          const SizedBox(width: 8),
          // 以图搜图入口：多模态影像检索（上传检查图片 → 匹配教材/知识点）
          // 功能链路（前端页 + 后端 search-image）早已就绪，此前缺的只是这个入口。
          PressableScale(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border.all(color: AppColors.ruleOf(context)),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ImageSearchScreen()),
                ),
                child: Icon(
                  Icons.image_search_rounded,
                  size: 21,
                  color: AppColors.text2Of(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 科室分类 ----------
  Widget _buildFilterBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final active = _filters[i] == _selectedFilter;
          return GestureDetector(
            onTap: () => _selectFilter(_filters[i]),
            child: PressableScale(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryOf(context)
                      : AppColors.surfaceOf(context),
                  border: Border.all(
                    color: active
                        ? AppColors.primaryOf(context)
                        : AppColors.ruleOf(context),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Center(
                  child: Text(
                    _filters[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? AppColors.onPrimaryOf(context)
                          : AppColors.text2Of(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- 列表 ----------
  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
      itemCount: _textbooks.length + 1,
      itemBuilder: (context, index) {
        if (index == _textbooks.length) return _buildFooter();
        return _textbookCard(_textbooks[index]);
      },
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (!_hasMore && _textbooks.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: MonoText('共 $_total 本教材',
              fontSize: 10, color: AppColors.text4Of(context)),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.menu_book_outlined, size: 48, color: AppColors.text4Of(context)),
        const SizedBox(height: 12),
        Center(
          child: SerifText('暂无相关教材', fontSize: 15, color: AppColors.text2Of(context)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('换个关键词或科室试试',
              style: TextStyle(fontSize: 12, color: AppColors.text4Of(context))),
        ),
      ],
    );
  }

  // ---------- 教材卡片（展示封面） ----------
  Widget _textbookCard(Map<String, dynamic> tb) {
    final tags = parseTags(tb['knowledgeTags']).where((t) => t.trim().isNotEmpty).toList();
    final dept = tb['department'] as String?;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetail(tb),
      child: PressableScale(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadow.card(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverThumb(
                    url: tb['coverUrl'] as String?,
                    size: 64,
                    title: tb['title'] as String? ?? '',
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SerifText(tb['title'] as String? ?? '教材', fontSize: 15),
                        ),
                        if (dept != null && dept.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          AppChip(
                            label: dept,
                            type: ChipType.indigo,
                            fontSize: 10,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    MonoText(
                      '${tb['author'] ?? ''} · ${tb['edition'] ?? ''}',
                      fontSize: 10,
                      color: AppColors.text3Of(context),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // 只展示精简有用的前 2 个知识点，避免无意义冗余标签
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags
                            .take(2)
                            .map((t) => AppChip(label: t, type: ChipType.default_, fontSize: 10))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      tb['description'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.text3Of(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: AppColors.text4Of(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 教材封面缩略图：coverUrl 为空或加载失败时，用「书名首字」色块占位，避免像缺失。
/// 使用 CachedNetworkImage 实现内存+磁盘缓存，滚动列表不重复请求。
class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url, required this.size, this.title = ''});

  final String? url;
  final double size;
  final String title;

  @override
  Widget build(BuildContext context) {
    final full = _resolveMediaUrl(url);
    final placeholder = _CoverPlaceholder(title: title, size: size);
    if (full == null) return placeholder;
    final resolvedUrl = full;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: size,
        height: size * 1.4,
        fit: BoxFit.cover,
        cacheKey: resolvedUrl, // 用完整 URL 作为缓存 key
        memCacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
        maxHeightDiskCache: (size * 1.4 * MediaQuery.of(context).devicePixelRatio).round(),
        errorWidget: (_, __, ___) => placeholder,
        progressIndicatorBuilder: (_, url, downloadProgress) {
          // downloadProgress.progress 是 double? (0.0~1.0)，直接给进度条用；
          // 为 null 时进度条转为不确定态（转圈）。
          return SizedBox(
            width: size,
            height: size * 1.4,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryOf(context),
                  value: downloadProgress.progress,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 相对路径拼接 API 基础地址，绝对地址原样返回。
  static String? _resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (Uri.tryParse(url)?.hasScheme ?? false) return url;
    final base = ApiConfig.apiBaseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}

/// 无封面时的占位：渐变底色 + 书名首字 + 小书本图标
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title, required this.size});

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 1.4;
    final initial = title.trim().isEmpty ? '' : title.trim().characters.first;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.mossTintOf(context), AppColors.mossSoftOf(context)],
        ),
      ),
      child: Center(
        child: initial.isEmpty
            ? Icon(Icons.menu_book_rounded, size: 24, color: AppColors.primaryOf(context))
            : SerifText(initial, fontSize: 26, color: AppColors.primaryOf(context)),
      ),
    );
  }
}

/// 解析知识点标签 JSON（兼容 List 与 String 两种存储）
List<String> parseTags(dynamic json) {
  if (json is List) {
    return json.cast<String>();
  }
  if (json is String && json.isNotEmpty) {
    try {
      final list = json.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      return list.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {}
  }
  return [];
}
