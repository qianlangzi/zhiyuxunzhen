import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/page_parser.dart';
import '../../student/textbook/textbook_center_screen.dart';
import '../data/teacher_service.dart';

/// 教师端 · 教材管理（上传电子书 + 我的教材 + 教材库）
///
/// 「教材库」Tab 与学生端教材中心共用 [TextbookCenterView]（封面 / 搜索 /
/// 科室筛选 / 在线阅读完全一致），数据源注入教师自己的
/// /api/v1/teacher/textbooks/library 接口（权限拦截决定教师不能调学生端接口）。
class TeacherTextbookScreen extends ConsumerStatefulWidget {
  const TeacherTextbookScreen({super.key});

  @override
  ConsumerState<TeacherTextbookScreen> createState() => _TeacherTextbookScreenState();
}

class _TeacherTextbookScreenState extends ConsumerState<TeacherTextbookScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  /// 0=我的教材（自己上传，可下架） 1=教材库（平台全部已上架教材，与学生端一致）
  int _scope = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await TeacherService().getMyTextbooks(pageSize: 50);
    if (!mounted) return;
    setState(() {
      // 后端 PageResult 字段是 list，统一走 PageParser 兼容解析
      _list = PageParser.mapListOf(data);
      _isLoading = false;
    });
  }

  void _switchScope(int scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
  }

  Future<void> _delete(int id) async {
    final ok = await TeacherService().deleteTextbook(id);
    if (!mounted) return;
    if (ok) {
      AppFeedback.success(context, '教材已下架');
      _load();
    } else {
      AppFeedback.error(context, '下架失败，请重试');
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
              title: '教材管理',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.teacherHome),
              action: _scope == 0
                  ? AppIconButton(
                      icon: const Icon(Icons.add, size: 22),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TextbookUploadScreen()),
                        );
                        _load();
                      },
                    )
                  : null,
            ),
            _buildScopeBar(context),
            // IndexedStack 保持两个 Tab 的状态：教材库浏览位置 / 我的教材列表不因切换丢失
            Expanded(
              child: IndexedStack(
                index: _scope,
                children: [
                  _buildMineList(),
                  TextbookCenterView(
                    fetchPage: ({required int pageNum, required int pageSize,
                        String? department, String? keyword}) =>
                        TeacherService().getTextbookLibrary(
                      pageNum: pageNum,
                      pageSize: pageSize,
                      department: department,
                      keyword: keyword,
                    ),
                    fetchDepartments: () =>
                        TeacherService().getTextbookLibraryDepartments(),
                    // 学生端作答链路对教师不可用，教师端详情不展示「去刷对应基础题」
                    showPracticeAction: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 我的教材列表（Tab 0）
  Widget _buildMineList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _list.isEmpty
            ? _buildEmpty(context)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _TextbookRow(
                    item: _list[i],
                    onDelete: () {
                      final id = (_list[i]['id'] as num?)?.toInt();
                      if (id != null) _delete(id);
                    },
                  ),
                ),
              );
  }

  /// 双 Tab：我的教材 / 教材库
  Widget _buildScopeBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.paper2Of(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: List.generate(2, (i) {
            final active = _scope == i;
            final label = i == 0 ? '我的教材' : '教材库';
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchScope(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.surfaceOf(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: active ? AppShadow.lifted(context) : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active
                            ? AppColors.primaryOf(context)
                            : AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final mine = _scope == 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Column(
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 48, color: AppColors.text4Of(context)),
                const SizedBox(height: 12),
                SerifText(mine ? '暂无教材' : '教材库暂无内容', fontSize: 15,
                    color: AppColors.text2Of(context)),
                const SizedBox(height: 4),
                Text(
                  mine ? '点击右上角 + 上传医学电子书' : '平台上还没有已上架的教材',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.text4Of(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextbookRow extends StatelessWidget {
  const _TextbookRow({
    required this.item,
    this.onDelete,
  });
  final Map<String, dynamic> item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.mossTintOf(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_rounded, size: 20, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SerifText(item['title'] as String? ?? '未命名',
                          fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                MonoText(
                  '${item['department'] ?? '综合'} · ${item['chapterCount'] ?? 0} 章',
                  fontSize: 10,
                  color: AppColors.text3Of(context),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.remove_circle_outline,
                    size: 18, color: AppColors.text4Of(context)),
              ),
            )
          else
            Icon(Icons.check_circle, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// 教材上传页
class TextbookUploadScreen extends ConsumerStatefulWidget {
  const TextbookUploadScreen({super.key});

  @override
  ConsumerState<TextbookUploadScreen> createState() => _TextbookUploadScreenState();
}

class _TextbookUploadScreenState extends ConsumerState<TextbookUploadScreen> {
  final _titleCtl = TextEditingController();
  final _departmentCtl = TextEditingController();
  final _authorCtl = TextEditingController();
  final _publisherCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _tagsCtl = TextEditingController();
  String? _fileUrl;
  String? _fileName;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _departmentCtl.dispose();
    _authorCtl.dispose();
    _publisherCtl.dispose();
    _descCtl.dispose();
    _tagsCtl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final file = await picker.pickMedia();
    if (file == null) return;
    if (!mounted) return;
    setState(() => _fileName = file.name);
    AppFeedback.info(context, '正在上传文件…');
    final result = await TeacherService().uploadTextbookFile(file.path);
    if (!mounted) return;
    if (result == null) {
      AppFeedback.error(context, '上传失败，请重试');
      return;
    }
    setState(() {
      _fileUrl = result['url'] as String?;
      _fileName = result['filename'] as String? ?? file.name;
    });
    AppFeedback.success(context, '文件上传成功');
  }

  Future<void> _submit() async {
    if (_titleCtl.text.trim().isEmpty) {
      AppFeedback.info(context, '请填写书名');
      return;
    }
    if (_fileUrl == null) {
      AppFeedback.info(context, '请先上传电子书文件');
      return;
    }
    setState(() => _submitting = true);
    final tags = _tagsCtl.text
        .split(RegExp(r'[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final result = await TeacherService().createTextbook({
      'title': _titleCtl.text.trim(),
      'department': _departmentCtl.text.trim().isEmpty ? '综合' : _departmentCtl.text.trim(),
      'author': _authorCtl.text.trim(),
      'publisher': _publisherCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'fileUrl': _fileUrl,
      'knowledgeTags': tags,
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      AppFeedback.error(context, '发布失败，请稍后重试');
      return;
    }
    AppFeedback.success(context, '教材已上架');
    if (context.mounted) context.pop();
  }

  Widget _field(String label, TextEditingController ctl, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          maxLines: maxLines,
          style: TextStyle(color: AppColors.textOf(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
            filled: true,
            fillColor: AppColors.surfaceOf(context),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
            ),
          ),
        ),
      ],
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
            AppBackAppBar(title: '上传教材', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                children: [
                  // 上传文件区域
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        border: Border.all(
                          color: _fileUrl != null
                              ? AppColors.primaryOf(context)
                              : AppColors.surfaceEdgeOf(context),
                          width: _fileUrl != null ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _fileUrl != null
                                ? Icons.description
                                : Icons.cloud_upload_outlined,
                            size: 34,
                            color: _fileUrl != null
                                ? AppColors.primaryOf(context)
                                : AppColors.text4Of(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fileName ?? '点击上传电子书（pdf / epub）',
                            style: TextStyle(
                              fontSize: 12,
                              color: _fileUrl != null
                                  ? AppColors.primaryOf(context)
                                  : AppColors.text3Of(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field('书名 *', _titleCtl, hint: '如：内科学（第 9 版）'),
                  const SizedBox(height: 14),
                  _field('科室分类', _departmentCtl, hint: '如：心血管内科'),
                  const SizedBox(height: 14),
                  _field('作者', _authorCtl),
                  const SizedBox(height: 14),
                  _field('出版社', _publisherCtl),
                  const SizedBox(height: 14),
                  _field('知识点标签（逗号分隔）', _tagsCtl, hint: '如：冠心病,心力衰竭'),
                  const SizedBox(height: 14),
                  _field('简介', _descCtl, maxLines: 3),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: _submitting ? '发布中…' : '发布教材',
                    fullWidth: true,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}