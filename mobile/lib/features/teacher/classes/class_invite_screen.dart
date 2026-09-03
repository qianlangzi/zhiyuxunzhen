import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 班级邀请 —— 展示邀请码 + 二维码，供课堂展示 / 学生扫码或输入加入。
class ClassInviteScreen extends ConsumerStatefulWidget {
  const ClassInviteScreen({
    super.key,
    required this.classId,
    this.className,
    this.inviteCode,
  });

  final int classId;
  final String? className;
  final String? inviteCode;

  @override
  ConsumerState<ClassInviteScreen> createState() => _ClassInviteScreenState();
}

class _ClassInviteScreenState extends ConsumerState<ClassInviteScreen> {
  String? _code;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _code = widget.inviteCode;
    // 始终拉取一次最新邀请码，确保二维码可靠显示且与后端一致
    _loadCode();
  }

  Future<void> _loadCode() async {
    setState(() => _loading = true);
    // 以后端为准：即便入参带了邀请码也拉取一次，保证二维码与最新邀请码一致
    final data = await TeacherService().getClassDetail(widget.classId);
    if (!mounted) return;
    setState(() {
      _code = (data?['inviteCode'] as String?)?.trim().isNotEmpty == true
          ? (data?['inviteCode'] as String).trim()
          : null;
      _loading = false;
    });
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppFeedback.success(context, '邀请码已复制');
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.className?.trim().isNotEmpty == true
        ? widget.className!.trim()
        : '班级邀请';
    final code = _code ?? '';
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: name,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.classManage),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      children: [
                        // 二维码
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                  color: AppColors.surfaceEdgeOf(context)),
                              boxShadow: AppShadow.card(context),
                            ),
                            child: code.isEmpty
                                ? Container(
                                    width: 180,
                                    height: 180,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code_2_rounded,
                                            size: 40,
                                            color: AppColors.text4Of(context)),
                                        const SizedBox(height: 8),
                                        MonoText('该班级暂无邀请码',
                                            fontSize: 12,
                                            color: AppColors.text4Of(context)),
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: () => _loadCode(),
                                          icon: const Icon(Icons.refresh,
                                              size: 16),
                                          label: const Text('刷新'),
                                        ),
                                      ],
                                    ),
                                  )
                                : QrImageView(
                                    data: code,
                                    version: QrVersions.auto,
                                    size: 180,
                                    eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square),
                                    dataModuleStyle:
                                        const QrDataModuleStyle(
                                      dataModuleShape:
                                          QrDataModuleShape.square,
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 邀请码
                        Center(
                          child: Text('课堂扫码即加入', style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textOf(context))),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.primaryOf(context), AppColors.moss2],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              boxShadow: AppShadow.lifted(context),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < code.length; i++) ...[
                                  Text(
                                    code[i],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      fontFamily: 'JetBrainsMono',
                                      color: AppColors.onPrimaryOf(context),
                                    ),
                                  ),
                                  if (i < code.length - 1)
                                    const SizedBox(width: 4),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: MonoText(
                            '打开学生端「加入班级」→ 输入上方邀请码或扫码即可入班',
                            fontSize: 11,
                            color: AppColors.text3Of(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppPrimaryButton(
                          label: '复制邀请码',
                          fullWidth: true,
                          onPressed: code.isEmpty
                              ? (() => AppFeedback.info(context, '该班级暂未生成邀请码'))
                              : () => _copy(code),
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