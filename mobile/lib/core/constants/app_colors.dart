import 'package:flutter/material.dart';

/// Semantic palette for the clinical ledger interface.
class AppColors {
  AppColors._();

  static const Color paper = Color(0xFFF7F7F5);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF171B1D);
  static const Color graphite = Color(0xFF40484B);
  static const Color weak = Color(0xFF687073);

  static const Color rule = Color(0xFFCFD4D5);
  static const Color ruleStrong = Color(0xFF8D9598);

  static const Color action = Color(0xFF24508C);
  static const Color actionPressed = Color(0xFF193E70);
  static const Color actionSoft = Color(0xFFE8EEF6);

  static const Color risk = Color(0xFFB73B32);
  static const Color riskSoft = Color(0xFFF7E8E6);
  static const Color success = Color(0xFF26705D);
  static const Color successSoft = Color(0xFFE6F0EC);
  static const Color warning = Color(0xFF8A5A22);
  static const Color warningSoft = Color(0xFFF5EDE3);

  static const Color field = Color(0xFFF1F2F0);
  static const Color paperStrong = Color(0xFFECEDE9);

  // Compatibility aliases retained while feature pages migrate to semantic names.
  static const Color bg = paper;
  static const Color bgStrong = paperStrong;
  static const Color card = surface;
  static const Color muted = graphite;
  static const Color soft = weak;
  static const Color line = rule;
  static const Color lineSoft = rule;
  static const Color lineStrong = ruleStrong;
  static const Color brand = action;
  static const Color brandStrong = actionPressed;
  static const Color brandSoft = actionSoft;
  static const Color brandPressed = actionPressed;
  static const Color danger = risk;
  static const Color dangerSoft = riskSoft;
  static const Color amberSoft = warningSoft;
  static const Color gold = warning;
  static const Color goldSoft = warningSoft;
  static const Color inkTeal = action;
  static const Color aqua = action;
  static const Color aquaSoft = actionSoft;

  static const Color activity1 = Color(0xFFDDE5EF);
  static const Color activity2 = Color(0xFFAFC1D8);
  static const Color activity3 = Color(0xFF6D8FB8);
  static const Color activity4 = action;
}
