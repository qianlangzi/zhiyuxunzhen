import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'PingFang SC';

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.6,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
    height: 1.45,
  );

  static const TextStyle kicker = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: AppColors.inkTeal,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle stat = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
    height: 1,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );

  static const TextStyle tag = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
}
