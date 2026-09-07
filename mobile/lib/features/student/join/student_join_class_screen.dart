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
  final _focusNode = FocusNode();
  MobileScannerController? _scannerController;
  bool _scanning = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _codeCtl.addListener(_onCodeChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scannerController?.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (!mounted) return;
    var text = _codeCtl.text.toUpperCase();
    if (text.length > 6) text = text.substring(0, 6);
    if (text != _codeCtl.text) {
      _codeCtl.text = text;
      _codeCtl.selection = TextSelection.collapsed(offset: text.length);
    }
    setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _join([String? rawCode]) async {
    final code = (rawCode ?? _codeCtl.text).trim().toUpperCase();
    if (code.isEmpty) {
      AppFeedback.info(context, '请输入班级邀请码');
      return;
    }
    if (_submitting) return;
    _focusNode.unfocus();
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
    AppFeedback.success(
      context,
      '已加入${className.isNotEmpty ? '「$className」' : '班级'}',
    );
    if (context.mounted) context.pop();
  }

  void _toggleScanning() {
    if (_scanning) {
      _stopScanning();
      return;
    }
    _focusNode.unfocus();
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
    _codeCtl.text = value.trim().toUpperCase();
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
                  // 顶部说明：用浅主色 tint 替代原来沉闷的深绿渐变卡，更透气。
                  const _HeroHint(),
                  const SizedBox(height: 20),
                  // 扫码区：虚线边框卡片，扫描状态可展开相机。
                  _buildScanArea(context),
                  if (_scanning) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _stopScanning,
                        child: MonoText(
                          '关闭扫码',
                          fontSize: 12,
                          color: AppColors.text4Of(context),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  // 6 位邀请码输入格
                  _InviteCodeBoxes(
                    controller: _codeCtl,
                    focusNode: _focusNode,
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 28),
                  AppPrimaryButton(
                    label: _submitting ? '加入中…' : '加入班级',
                    fullWidth: true,
                    onPressed: _submitting ? null : () => _join(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea(BuildContext context) {
    final borderColor = AppColors.mossSoftOf(context);
    return GestureDetector(
      onTap: _toggleScanning,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: _scanning ? 220 : 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: borderColor,
            radius: AppRadius.lg,
          ),
          child: _scanning
              ? MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => Center(
                    child: Text(
                      '相机不可用：${error.errorCode.name}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: AppColors.primaryOf(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '点击扫描邀请码',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '对准老师展示的班级二维码',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.text4Of(context),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 轻量说明卡：用浅主色 tint 替代原来的深绿渐变卡，
/// 图标底仍保留主色保证品牌识别，文字层级更清晰。
class _HeroHint extends StatelessWidget {
  const _HeroHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mossTintOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 24,
              color: AppColors.onPrimaryOf(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入邀请码加入班级',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '向老师获取 6 位邀请码，扫码或手动输入即可加入',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.text3Of(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 6 位邀请码输入格：视觉上像验证码输入框，
/// 内部用一个透明 TextField 接管键盘输入与焦点。
class _InviteCodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onSubmitted;

  const _InviteCodeBoxes({
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              return Padding(
                padding: EdgeInsets.only(right: index < 5 ? 7 : 0),
                child: _CodeBox(
                  index: index,
                  controller: controller,
                  focusNode: focusNode,
                ),
              );
            }),
          ),
          // 不可见的 TextField 负责接管键盘输入与焦点；
          // IgnorePointer 避免它拦截盒子的点击，由外部 GestureDetector 统一请求焦点。
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onSubmitted: onSubmitted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;

  const _CodeBox({
    required this.index,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final hasFocus = focusNode.hasFocus;
    final isCurrent = index == text.length;
    final filled = index < text.length;
    final char = filled ? text[index].toUpperCase() : '';

    final borderColor = (hasFocus && isCurrent)
        ? AppColors.primaryOf(context)
        : AppColors.mossSoftOf(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 42,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: borderColor,
          width: (hasFocus && isCurrent) ? 1.8 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: filled
          ? Text(
              char,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textOf(context),
              ),
            )
          : (hasFocus && isCurrent)
              ? Container(
                  width: 2,
                  height: 20,
                  color: AppColors.primaryOf(context),
                )
              : null,
    );
  }
}

/// 圆角矩形虚线边框绘制器，用于扫码卡片。
class _DashedBorderPainter extends CustomPainter {
  static const double _strokeWidth = 1.5;
  static const double _dashLength = 8;
  static const double _gapLength = 6;

  final Color color;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _strokeWidth / 2,
        _strokeWidth / 2,
        size.width - _strokeWidth,
        size.height - _strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _dashPath(path);
    canvas.drawPath(dashedPath, paint);
  }

  Path _dashPath(Path source) {
    final dashed = Path();
    final metrics = source.computeMetrics().toList();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashed.addPath(
          metric.extractPath(distance, distance + _dashLength),
          Offset.zero,
        );
        distance += _dashLength + _gapLength;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
