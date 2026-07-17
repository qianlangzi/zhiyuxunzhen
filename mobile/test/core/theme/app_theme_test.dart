import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/core/constants/app_colors.dart';
import 'package:zhiyu/core/constants/app_dimens.dart';
import 'package:zhiyu/core/constants/app_text_styles.dart';
import 'package:zhiyu/core/theme/app_motion.dart';
import 'package:zhiyu/core/theme/app_theme.dart';

void main() {
  test('clinical ledger palette uses neutral paper and semantic status colors',
      () {
    expect(AppColors.paper, const Color(0xFFF7F7F5));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.ink, const Color(0xFF171B1D));
    expect(AppColors.graphite, const Color(0xFF40484B));
    expect(AppColors.rule, const Color(0xFFCFD4D5));
    expect(AppColors.action, const Color(0xFF24508C));
    expect(AppColors.risk, const Color(0xFFB73B32));
    expect(AppColors.success, const Color(0xFF26705D));
    expect(AppColors.bg, AppColors.paper);
    expect(AppColors.brand, AppColors.action);
  });

  test('weak text meets WCAG AA contrast on neutral text surfaces', () {
    for (final Color background in <Color>[
      AppColors.paper,
      AppColors.field,
    ]) {
      expect(
        _contrastRatio(AppColors.weak, background),
        greaterThanOrEqualTo(4.5),
        reason: 'weak text must remain readable on $background',
      );
    }
  });

  test('clinical ledger uses compact 4/8/16 radius hierarchy', () {
    expect(AppDimens.radiusStatus, 4);
    expect(AppDimens.radiusCard, 6);
    expect(AppDimens.radiusControl, 8);
    expect(AppDimens.radiusSheet, 16);
  });

  test('headings use a system serif with sans fallback and body uses sans', () {
    expect(AppTextStyles.headingFontFamily, 'serif');
    expect(AppTextStyles.bodyFontFamily, 'sans-serif');
    expect(AppTextStyles.h1.fontFamily, AppTextStyles.headingFontFamily);
    expect(AppTextStyles.h1.fontFamilyFallback,
        contains(AppTextStyles.bodyFontFamily));
    expect(AppTextStyles.body.fontFamily, AppTextStyles.bodyFontFamily);
    expect(AppTextStyles.h1.letterSpacing, 0);
    expect(AppTextStyles.body.letterSpacing, 0);
  });

  testWidgets('motion is disabled when the system requests it',
      (WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (BuildContext value) {
            context = value;
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(AppMotion.standard(context), Duration.zero);
  });

  test('buttons use comfortable non-pill corners', () {
    final ButtonStyle style = AppTheme.light.filledButtonTheme.style!;
    final OutlinedBorder shape = style.shape!.resolve(<WidgetState>{})!;
    expect((shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppDimens.radiusControl));
    expect(AppTheme.light.cardTheme.elevation, 0);
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.paper);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final double foregroundLuminance = _relativeLuminance(foreground);
  final double backgroundLuminance = _relativeLuminance(background);
  final double lighter = math.max(foregroundLuminance, backgroundLuminance);
  final double darker = math.min(foregroundLuminance, backgroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double linearize(int channel) {
    final double value = channel / 255;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(color.red) +
      0.7152 * linearize(color.green) +
      0.0722 * linearize(color.blue);
}
