import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/auth_api.dart';

/// 图形验证码组件（数学题防盗刷）
///
/// 自动从后端拉取一道数学题，用户输入答案，供短信验证码接口防刷校验。
///
/// 通过 [GlobalKey<CaptchaWidgetState>] 持有引用，调用 [CaptchaWidgetState.current]
/// 取当前验证码信息，调用 [CaptchaWidgetState.refresh] 重新获取题目。
class CaptchaWidget extends StatefulWidget {
  const CaptchaWidget({
    super.key,
    required this.accentColor,
    this.label = '图形验证',
  });

  /// 角色强调色（学生=苔藓绿，教师=朱砂红）
  final Color accentColor;

  /// 字段标签文案
  final String label;

  @override
  State<CaptchaWidget> createState() => CaptchaWidgetState();
}

/// 公开 State，便于父页面用 `GlobalKey<CaptchaWidgetState>` 访问
/// [current] / [refresh]。
class CaptchaWidgetState extends State<CaptchaWidget> {
  final TextEditingController _answerCtl = TextEditingController();
  final AuthApi _api = AuthApi();

  String? _captchaId;
  String? _question;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final data = await _api.getCaptcha();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _failed = true;
        _captchaId = null;
        _question = null;
      });
      _answerCtl.clear();
      return;
    }
    setState(() {
      _loading = false;
      _captchaId = data.captchaId;
      _question = data.question;
    });
    _answerCtl.clear();
  }

  /// 重新获取验证题
  Future<void> refresh() => _load();

  /// 当前验证码信息（captchaId 与 answer 均非空才返回）
  ({String captchaId, String answer})? current() {
    final id = _captchaId;
    final ans = _answerCtl.text.trim();
    if (id == null || id.isEmpty || ans.isEmpty) return null;
    return (captchaId: id, answer: ans);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2Of(context),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(fontSize: 13, color: AppColors.vermilion),
              ),
            ],
          ),
        ),
        _buildBody(context),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return _frame(
        context,
        Row(
          children: [
            const SizedBox(width: 12),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '加载中…',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text3Of(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_failed || _question == null || _captchaId == null) {
      return _frame(
        context,
        GestureDetector(
          onTap: _load,
          behavior: HitTestBehavior.opaque,
          child: const Row(
            children: [
              SizedBox(width: 12),
              Icon(
                Icons.error_outline,
                size: 16,
                color: AppColors.vermilion,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '验证码加载失败，点击重试',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.vermilion,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.surfaceEdgeOf(context),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _question!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _answerCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(4),
                FilteringTextInputFormatter.digitsOnly,
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context),
              ),
              decoration: InputDecoration(
                hintText: '?',
                hintStyle: TextStyle(
                  color: AppColors.text4Of(context),
                  fontSize: 13,
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                filled: true,
                fillColor: AppColors.surfaceOf(context),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.surfaceEdgeOf(context),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: widget.accentColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: AppColors.text3Of(context),
            ),
            onPressed: _load,
            tooltip: '刷新验证码',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  /// 加载/失败态的外框，与正常态边框一致
  Widget _frame(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.surfaceEdgeOf(context),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      child: child,
    );
  }
}
