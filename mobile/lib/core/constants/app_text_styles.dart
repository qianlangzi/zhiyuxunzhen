import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String headingFontFamily = 'serif';
  static const String bodyFontFamily = 'sans-serif';
  static const List<String> headingFallback = <String>[bodyFontFamily];

  static const TextStyle h1 = TextStyle(
    fontFamily: headingFontFamily,
    fontFamilyFallback: headingFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.18,
    letterSpacing: 0,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: headingFontFamily,
    fontFamilyFallback: headingFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.22,
    letterSpacing: 0,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle title = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.55,
    letterSpacing: 0,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.45,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.graphite,
    height: 1.45,
    letterSpacing: 0,
  );

  static const TextStyle kicker = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.action,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle stat = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle button = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle tag = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle data = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.graphite,
    height: 1.3,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}
