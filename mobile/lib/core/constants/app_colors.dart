import 'package:flutter/material.dart';

/// 临床玻璃舱配色系统
/// 对齐 front/legacy-student-teacher 中的 CSS 变量，保留品牌识别
class AppColors {
  AppColors._();

  // 背景层
  static const Color bg = Color(0xFFF4F8F7);
  static const Color bgStrong = Color(0xFFE8F2EF);
  static const Color bgGradientTop = Color(0xFFF9FBFA);

  // 文本层
  static const Color ink = Color(0xFF10231F);
  static const Color muted = Color(0xFF536862);
  static const Color soft = Color(0xFF78908A);

  // 描边层
  static const Color line = Color(0x241B564C); // rgba(27,86,76,0.14)
  static const Color lineStrong = Color(0x3D1B564C); // rgba(27,86,76,0.24)

  // 品牌色（玉青）
  static const Color brand = Color(0xFF0F766E);
  static const Color brandStrong = Color(0xFF0B5F59);
  static const Color brandSoft = Color(0xFFDFF4F1);
  static const Color brandPressed = Color(0xFF094F49);

  // 医疗青
  static const Color aqua = Color(0xFF14B8A6);
  static const Color aquaSoft = Color(0x2414B8A6);

  // 状态色
  static const Color danger = Color(0xFFE05757);
  static const Color dangerSoft = Color(0x24E05757);
  static const Color warning = Color(0xFFC47A20);
  static const Color amberSoft = Color(0xFFFFF2D8);

  // 深色面板（问诊室）
  static const Color deep = Color(0xFF071B22);
  static const Color deepInk = Color(0xFFEFFFFB);
  static const Color deepMuted = Color(0xB0EFFFFB);

  // 卡片
  static const Color card = Colors.white;
  static const Color cardGlass = Color(0xAEFFFFFF); // rgba(255,255,255,0.68)
  static const Color cardGlassStrong = Color(0xDCFFFFFF);

  // 阴影
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A154E44),
      offset: Offset(0, 18),
      blurRadius: 44,
    ),
  ];
  static const List<BoxShadow> shadowSoft = <BoxShadow>[
    BoxShadow(
      color: Color(0x14154E44),
      offset: Offset(0, 10),
      blurRadius: 28,
    ),
  ];
  static const List<BoxShadow> shadowCard = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F154E44),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
