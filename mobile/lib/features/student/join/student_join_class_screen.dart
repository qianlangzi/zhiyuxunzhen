import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 学生端 · 加入班级 —— 输入邀请码或扫码加入教师创建的班级。
class StudentJoinClassScreen extends ConsumerStatefulWidget {
  const StudentJoinClassScreen({super.key});

  @override
  ConsumerState<StudentJoinClassScreen> createState() =>
      _StudentJoinClassScreenState();
}

class _StudentJoinClassScreenState extends ConsumerState<StudentJoinClassScreen> {
  final _codeCtl = TextEditingController();
  MobileScannerController? _scannerController;
  bool _scanning = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _codeCtl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _join(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      AppFeedback.info(context, '请输入班级邀请码');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await StudentService().joinClass(code);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.data == null) {
      AppFeedback.error(context, result.message);
      _stopScanning();
      return;
    }
    final className = result.data?['name'] as String? ?? '';
    AppFeedback.success(context, '已加入${className.isNotEmpty ? '「$className」' : '班级'}');
    if (context.mounted) context.pop();
  }

  void _toggleScanning() {
    if (_scanning) {
      _stopScanning();
      return;
    }
    setState(() {
      _scanning = true;
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    });
  }

  void _stopScanning() {
    _scannerController?.dispose();
    _scannerController = null;
    if (mounted) setState(() => _scanning = false);
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes
        .map((e) => e.rawValue)
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!)
        .firstOrNull;
    if (value == null) return;
    _codeCtl.text = value.trim();
    // 扫码命中后自动提交
    _join(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: '加入班级', onBack: context.pop),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  // 说明
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryOf(context), AppColors.moss2],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadow.lifted(context),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.onPrimaryOf(context)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(Icons.group_add_rounded,
                              size: 22, color: AppColors.onPrimaryOf(context)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('扫描或输入邀请码加入班级',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimaryOf(context),
                                  )),
                              const SizedBox(height: 4),
                              Text('请输入老师课堂展示的 6 位邀请码，进入后即可接收作业与学习资料',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onPrimaryLightOf(context),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 扫码区
                  GestureDetector(
                    onTap: _toggleScanning,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: _scanning ? 220 : 96,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.surfaceEdgeOf(context)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _scanning
                          ? MobileScanner(
                              controller: _scannerController,
                              onDetect: _onDetect,
                              errorBuilder: (context, error, child) =>
                                  Center(
                                child: Text(
                                  '相机不可用：${error.errorCode.name}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.text3Of(context)),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner,
                                    size: 28,
                                    color: AppColors.primaryOf(context)),
                                const SizedBox(width: 12),
                                Text('点击开启摄像头扫码',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.text2Of(context))),
                              ],
                            ),
                    ),
                  ),
                  if (_scanning) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: _stopScanning,
                        child: MonoText('关闭扫码',
                            fontSize: 11, color: AppColors.text4Of(context)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // 手动输入
                  TextField(
                    controller: _codeCtl,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.textOf(context),
                    ),
                    decoration: InputDecoration(
                      hintText: '请输入邀请码',
                      hintStyle: TextStyle(
                          fontSize: 15, color: AppColors.text4Of(context)),
                      filled: true,
                      fillColor: AppColors.surfaceOf(context),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide:
                            BorderSide(color: AppColors.surfaceEdgeOf(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide:
                            BorderSide(color: AppColors.surfaceEdgeOf(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                            color: AppColors.primaryOf(context), width: 1.5),
                      ),
                    ),
                    onSubmitted: _join,
                  ),
                  const SizedBox(height: 16),
                  AppPrimaryButton(
                    label: _submitting ? '加入中…' : '加入班级',
                    fullWidth: true,
                    onPressed: _submitting
                        ? null
                        : () => _join(_codeCtl.text),
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