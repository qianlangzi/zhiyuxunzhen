import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration standardDuration = Duration(milliseconds: 190);
  static const Duration routeDuration = Duration(milliseconds: 220);
  static const Curve standardCurve = Curves.easeOutCubic;

  static Duration fast(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : fastDuration;

  static Duration standard(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : standardDuration;

  static Duration route(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : routeDuration;
}
