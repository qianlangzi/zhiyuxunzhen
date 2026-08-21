import 'package:flutter/material.dart';

/// 个性化主题预设
///
/// 三套预设都严格守护「宣纸米白 + 苔藓绿 + 墨色」的东方医学品牌基调，
/// 只换色彩「韵味」与明暗适配，不改动徽标 / 圆角 / 转场 / 图标体系。
///
/// 通过 [ThemePaletteExtension] 注册进 ThemeData.extensions，
/// [AppColors] 的上下文取色函数据此拿到「当前预设 × 当前亮度」的真实色板，
/// 从而保证切换预设时全 App 统一切换、不串色、对比度不崩。
enum ThemePreset {
  /// A · 本草（默认）：现状原味，宣纸米白 + 苔藓绿
  herb(
    '本草',
    '默认 · 宣纸米白与苔藓绿',
    '东方医学的原始味道，米白宣纸衬着苔藓绿主色，温和克制。',
  ),

  /// B · 墨青·晚山：冷调素雅，青黛主色，留白更多、更具高级感
  inkSteel(
    '墨青',
    '冷调 · 青黛晚山',
    '偏青黛的墨色，背景更素净清冷，留白与秩序感更强。',
  ),

  /// C · 丹砂·印泥：暖调宣纸，印泥朱砂点缀，古籍印章气韵
  cinnabar(
    '丹砂',
    '暖调 · 印泥朱砂',
    '苔藓绿主色辅以印泥朱砂点缀，仿若古籍印章的温暖气韵。',
  );

  final String label;
  final String subtitle;
  final String desc;

  const ThemePreset(this.label, this.subtitle, this.desc);

  /// 当前预设对应的指定亮度色板
  ThemePalette palette({required bool dark}) =>
      dark ? darkPalette : lightPalette;

  /// 浅色色板
  ThemePalette get lightPalette => _lightPalettes[this]!;

  /// 深色色板（每套预设按自身基调做深色适配）
  ThemePalette get darkPalette => _darkPalettes[this]!;
}

/// 一套预设在某亮度下的完整取色语义色板
///
/// 字段与 [AppColors] 的上下文取色函数一一对应，作为「唯一取数源」。
@immutable
class ThemePalette {
  final bool dark;

  // 背景层级
  final Color bg;
  final Color paper2;
  final Color paper3;

  // 卡片 / 边框 / 分割线
  final Color surface;
  final Color surfaceEdge;
  final Color rule;
  final Color ruleSoft;

  // 文字层级
  final Color text;
  final Color text2;
  final Color text3;
  final Color text4;

  // 主色与主色上的文字
  final Color primary;
  final Color onPrimary;
  final Color onPrimarySoft;
  final Color onPrimaryLight;

  // 软色
  final Color mossTint;
  final Color mossSoft;
  final Color vermilionSoft;
  final Color amberSoft;
  final Color indigoSoft;

  // 热力图色阶（5 档）
  final List<Color> heat;

  const ThemePalette({
    required this.dark,
    required this.bg,
    required this.paper2,
    required this.paper3,
    required this.surface,
    required this.surfaceEdge,
    required this.rule,
    required this.ruleSoft,
    required this.text,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.primary,
    required this.onPrimary,
    required this.onPrimarySoft,
    required this.onPrimaryLight,
    required this.mossTint,
    required this.mossSoft,
    required this.vermilionSoft,
    required this.amberSoft,
    required this.indigoSoft,
    required this.heat,
  });
}

const Map<ThemePreset, ThemePalette> _lightPalettes = {
  // ========== A · 本草（默认）==========
  ThemePreset.herb: ThemePalette(
    dark: false,
    bg: Color(0xFFF5F1E8),
    paper2: Color(0xFFEBE5D6),
    paper3: Color(0xFFDDD5C5),
    surface: Color(0xFFFAF7F0),
    surfaceEdge: Color(0xFFE0D9C8),
    rule: Color(0xFFD8D0C0),
    ruleSoft: Color(0xFFE8E2D4),
    text: Color(0xFF1A1F1C),
    text2: Color(0xFF3A3F3C),
    text3: Color(0xFF6B7270),
    text4: Color(0xFF9AA09D),
    primary: Color(0xFF2D4A3E),
    onPrimary: Color(0xFFF5F1E8),
    onPrimarySoft: Color(0xFFB8C9B8),
    onPrimaryLight: Color(0xFFD8E0D3),
    mossTint: Color(0xFFE8F0E5),
    mossSoft: Color(0xFFC8D4C0),
    vermilionSoft: Color(0xFFF3DCD7),
    amberSoft: Color(0xFFF5E6C8),
    indigoSoft: Color(0xFFD8DCEA),
    heat: [
      Color(0xFFEBE5D6),
      Color(0xFFC8D4C0),
      Color(0xFF8FA787),
      Color(0xFF5A7A6B),
      Color(0xFF2D4A3E),
    ],
  ),

  // ========== B · 墨青·晚山 ==========
  ThemePreset.inkSteel: ThemePalette(
    dark: false,
    bg: Color(0xFFF3F5F4),
    paper2: Color(0xFFE8EDEC),
    paper3: Color(0xFFDBE3E1),
    surface: Color(0xFFFAFBFA),
    surfaceEdge: Color(0xFFDFE5E4),
    rule: Color(0xFFD4DCDB),
    ruleSoft: Color(0xFFEAF0EF),
    text: Color(0xFF18221F),
    text2: Color(0xFF3E4A47),
    text3: Color(0xFF6E7A78),
    text4: Color(0xFF9AA5A3),
    primary: Color(0xFF2E4A56),
    onPrimary: Color(0xFFF3F5F4),
    onPrimarySoft: Color(0xFFB9C9D2),
    onPrimaryLight: Color(0xFFD7E4EA),
    mossTint: Color(0xFFE7EEF0),
    mossSoft: Color(0xFFC2D3DA),
    vermilionSoft: Color(0xFFF3DCD7),
    amberSoft: Color(0xFFF3EBD8),
    indigoSoft: Color(0xFFDFE5EE),
    heat: [
      Color(0xFFE3EBEB),
      Color(0xFFC0D6DA),
      Color(0xFF86A9B2),
      Color(0xFF57828E),
      Color(0xFF2E4A56),
    ],
  ),

  // ========== C · 丹砂·印泥 ==========
  ThemePreset.cinnabar: ThemePalette(
    dark: false,
    bg: Color(0xFFF7F1E7),
    paper2: Color(0xFFF0E9DA),
    paper3: Color(0xFFE6DBC6),
    surface: Color(0xFFFCF8F2),
    surfaceEdge: Color(0xFFE6DECC),
    rule: Color(0xFFDDD2BE),
    ruleSoft: Color(0xFFEEE6D6),
    text: Color(0xFF211E1A),
    text2: Color(0xFF44403A),
    text3: Color(0xFF756F66),
    text4: Color(0xFF9E9890),
    primary: Color(0xFF2D4A3E),
    onPrimary: Color(0xFFF7F1E7),
    onPrimarySoft: Color(0xFFC0C9BC),
    onPrimaryLight: Color(0xFFDDE3D8),
    mossTint: Color(0xFFEDEFDF),
    mossSoft: Color(0xFFD5CBB0),
    vermilionSoft: Color(0xFFF2DDD3),
    amberSoft: Color(0xFFF3E7CC),
    indigoSoft: Color(0xFFEAE0D2),
    heat: [
      Color(0xFFEADFCC),
      Color(0xFFE1CDAB),
      Color(0xFFC2A67F),
      Color(0xFF9C5B3E),
      Color(0xFF8A3A2A),
    ],
  ),
};

const Map<ThemePreset, ThemePalette> _darkPalettes = {
  // ========== A · 本草（默认）深色 ==========
  ThemePreset.herb: ThemePalette(
    dark: true,
    bg: Color(0xFF12161A),
    paper2: Color(0xFF1B2126),
    paper3: Color(0xFF242B30),
    surface: Color(0xFF1B2126),
    surfaceEdge: Color(0xFF2C343A),
    rule: Color(0xFF2C343A),
    ruleSoft: Color(0xFF2C343A),
    text: Color(0xFFEDF1EF),
    text2: Color(0xFFC6CFCC),
    text3: Color(0xFF9BA6A5),
    text4: Color(0xFF737E7D),
    primary: Color(0xFF5A7A6B),
    onPrimary: Color(0xFF1A1F1C),
    onPrimarySoft: Color(0xFF1E2A24),
    onPrimaryLight: Color(0xFF12180F),
    mossTint: Color(0xFF1C2A24),
    mossSoft: Color(0xFF33423A),
    vermilionSoft: Color(0xFF2C1B18),
    amberSoft: Color(0xFF2B251A),
    indigoSoft: Color(0xFF1A1E2A),
    heat: [
      Color(0xFF181E23),
      Color(0xFF1F3A33),
      Color(0xFF2C5247),
      Color(0xFF3C6E5F),
      Color(0xFF8FC6B6),
    ],
  ),

  // ========== B · 墨青·晚山 深色 ==========
  ThemePreset.inkSteel: ThemePalette(
    dark: true,
    bg: Color(0xFF10151A),
    paper2: Color(0xFF171D23),
    paper3: Color(0xFF1F272D),
    surface: Color(0xFF171D23),
    surfaceEdge: Color(0xFF283139),
    rule: Color(0xFF283139),
    ruleSoft: Color(0xFF283139),
    text: Color(0xFFEBF0F1),
    text2: Color(0xFFC2CECD),
    text3: Color(0xFF93A2A4),
    text4: Color(0xFF6A797D),
    primary: Color(0xFF7CA4B6),
    onPrimary: Color(0xFF10151A),
    onPrimarySoft: Color(0xFF1C2A35),
    onPrimaryLight: Color(0xFF101820),
    mossTint: Color(0xFF1A2731),
    mossSoft: Color(0xFF2D4148),
    vermilionSoft: Color(0xFF2C1B18),
    amberSoft: Color(0xFF2B2A1C),
    indigoSoft: Color(0xFF1B2233),
    heat: [
      Color(0xFF141C21),
      Color(0xFF1D333C),
      Color(0xFF2A4B54),
      Color(0xFF376673),
      Color(0xFF8AC2CE),
    ],
  ),

  // ========== C · 丹砂·印泥 深色 ==========
  ThemePreset.cinnabar: ThemePalette(
    dark: true,
    bg: Color(0xFF16140F),
    paper2: Color(0xFF1F1C15),
    paper3: Color(0xFF272318),
    surface: Color(0xFF1F1C15),
    surfaceEdge: Color(0xFF312C20),
    rule: Color(0xFF312C20),
    ruleSoft: Color(0xFF312C20),
    text: Color(0xFFF1EDE4),
    text2: Color(0xFFD0CBBE),
    text3: Color(0xFFA6A092),
    text4: Color(0xFF7E786B),
    primary: Color(0xFF6B8A74),
    onPrimary: Color(0xFF16140F),
    onPrimarySoft: Color(0xFF242A20),
    onPrimaryLight: Color(0xFF151911),
    mossTint: Color(0xFF221F16),
    mossSoft: Color(0xFF3B3527),
    vermilionSoft: Color(0xFF2F1C14),
    amberSoft: Color(0xFF2D2719),
    indigoSoft: Color(0xFF262016),
    heat: [
      Color(0xFF201B13),
      Color(0xFF2C2519),
      Color(0xFF4A3A28),
      Color(0xFF6E482E),
      Color(0xFFB2563A),
    ],
  ),
};

/// 主题拓展：把当前预设色板挂到 ThemeData.extensions 上，
/// 使 [AppColors] 无需依赖 Provider 也能从 BuildContext 读到「当前预设 × 亮度」。
@immutable
class ThemePaletteExtension extends ThemeExtension<ThemePaletteExtension> {
  final ThemePalette palette;

  const ThemePaletteExtension(this.palette);

  @override
  ThemePaletteExtension copyWith({ThemePalette? palette}) =>
      ThemePaletteExtension(palette ?? this.palette);

  @override
  ThemePaletteExtension lerp(
    covariant ThemePaletteExtension? other,
    double t,
  ) {
    if (other == null) return this;
    final a = palette;
    final b = other.palette;
    Color lc(Color x, Color y) => Color.lerp(x, y, t)!;
    final aHeat = a.heat;
    final bHeat = b.heat;
    return ThemePaletteExtension(
      ThemePalette(
        dark: b.dark,
        bg: lc(a.bg, b.bg),
        paper2: lc(a.paper2, b.paper2),
        paper3: lc(a.paper3, b.paper3),
        surface: lc(a.surface, b.surface),
        surfaceEdge: lc(a.surfaceEdge, b.surfaceEdge),
        rule: lc(a.rule, b.rule),
        ruleSoft: lc(a.ruleSoft, b.ruleSoft),
        text: lc(a.text, b.text),
        text2: lc(a.text2, b.text2),
        text3: lc(a.text3, b.text3),
        text4: lc(a.text4, b.text4),
        primary: lc(a.primary, b.primary),
        onPrimary: lc(a.onPrimary, b.onPrimary),
        onPrimarySoft: lc(a.onPrimarySoft, b.onPrimarySoft),
        onPrimaryLight: lc(a.onPrimaryLight, b.onPrimaryLight),
        mossTint: lc(a.mossTint, b.mossTint),
        mossSoft: lc(a.mossSoft, b.mossSoft),
        vermilionSoft: lc(a.vermilionSoft, b.vermilionSoft),
        amberSoft: lc(a.amberSoft, b.amberSoft),
        indigoSoft: lc(a.indigoSoft, b.indigoSoft),
        heat: [
          for (var i = 0; i < 5; i++) lc(aHeat[i], bHeat[i]),
        ],
      ),
    );
  }
}