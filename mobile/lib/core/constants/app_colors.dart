import 'package:flutter/material.dart';

/// Mobile clinical education palette inspired by the Stitch prototypes.
///
/// 核心令牌收敛为冷白背景、深青强调和业务状态色。
class AppColors {
  AppColors._();

  // 基础表面
  static const Color bg = Color(0xFFF7F9F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = surface;

  // 文字
  static const Color ink = Color(0xFF161A1C);
  static const Color muted = Color(0xFF596367);
  static const Color soft = Color(0xFF7A8488);

  // 分隔线
  static const Color line = Color(0xFFE3E8EA);
  static const Color lineStrong = Color(0xFFC7D0D3);

  // 品牌深青
  static const Color brand = Color(0xFF064B59);
  static const Color brandStrong = Color(0xFF003441);
  static const Color brandSoft = Color(0xFFEAF1F2);
  static const Color brandPressed = Color(0xFF002B35);

  // 训练热力图四级深青色阶
  static const Color activity1 = Color(0xFFD8E7E9);
  static const Color activity2 = Color(0xFFA9CDD2);
  static const Color activity3 = Color(0xFF5F9CA5);
  static const Color activity4 = brand;

  // 业务状态色（仅用于真实状态，不参与装饰）
  static const Color success = Color(0xFF247A5A);
  static const Color successSoft = Color(0xFFE7F4ED);
  static const Color danger = Color(0xFFC2413A);
  static const Color dangerSoft = Color(0xFFFBE9E8);
  static const Color warning = Color(0xFFA7631B);

  // 业务语义色与场景别名
  static const Color bgStrong = Color(0xFFECEFEE);
  static const Color inkTeal = brand;
  static const Color lineSoft = line;
  static const Color aqua = Color(0xFF5AB7BE);
  static const Color aquaSoft = Color(0xFFE0F3F4);
  static const Color gold = Color(0xFFB7791F);
  static const Color goldSoft = Color(0xFFFFF4DF);
  static const Color amberSoft = Color(0xFFFFF4DF);
  static const Color field = Color(0xFFF3F5F6);
}
