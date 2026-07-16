import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/core/constants/app_colors.dart';
import 'package:zhiyu/core/constants/app_dimens.dart';
import 'package:zhiyu/core/theme/app_motion.dart';
import 'package:zhiyu/core/theme/app_theme.dart';

void main() {
  test('clinical minimal tokens stay constrained', () {
    expect(AppColors.bg, const Color(0xFFF7F9F9));
    expect(AppColors.brand, const Color(0xFF064B59));
    expect(AppDimens.radiusCard, 8);
    expect(AppDimens.radiusControl, 12);
    expect(AppDimens.radiusSheet, 20);
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
  });
}
