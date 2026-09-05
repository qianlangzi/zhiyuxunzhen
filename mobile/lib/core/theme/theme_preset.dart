import 'package:flutter/material.dart';

/// 个性化主题预设
///
/// 三套预设各自扛一个明确的色调身份，围绕同一套「宣纸或素底 + 墨色文字
/// + 品牌主色」的东方医学基础气质，只在主色与背景冷暖上拉开差异，
/// 不改动徽标 / 圆角 / 转场 / 图标体系。
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

  /// C · 丹砂·印泥：暖调宣纸，印泥朱砂主色，古籍印章气韵
  cinnabar(
    '丹砂',
    '暖调 · 印泥朱砂',
    '印泥朱砂作主色，暖赭宣纸作底，仿若古籍印章的温暖气韵。',
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
    surfaceEdge: Color(0xFFE1DBCA),
    rule: Color(0xFFD6CFBE),
    ruleSoft: Color(0xFFE8E2D4),
    text: Color(0xFF1A1F1C),
    text2: Color(0xFF343A37),
    text3: Color(0xFF5F6764),
    text4: Color(0xFF8E9492),
    primary: Color(0xFF2D4A3E),
    onPrimary: Color(0xFFF5F1E8),
    onPrimarySoft: Color(0xFFB9CAB9),
    onPrimaryLight: Color(0xFFD9E1D4),
    mossTint: Color(0xFFE7EFE4),
    mossSoft: Color(0xFFC6D3BF),
    vermilionSoft: Color(0xFFF3DCD7),
    amberSoft: Color(0xFFF5E6C8),
    indigoSoft: Color(0xFFDDE2EF),
    heat: [
      Color(0xFFECE6D8),
      Color(0xFFC6D3BF),
      Color(0xFF8EA485),
      Color(0xFF58786C),
      Color(0xFF2D4A3E),
    ],
  ),

  // ========== B · 墨青·晚山 ==========
  ThemePreset.inkSteel: ThemePalette(
    dark: false,
    bg: Color(0xFFF1F5F6),
    paper2: Color(0xFFE6ECED),
    paper3: Color(0xFFD8E1E2),
    surface: Color(0xFFFAFCFC),
    surfaceEdge: Color(0xFFDDE5E6),
    rule: Color(0xFFD0DCDD),
    ruleSoft: Color(0xFFE8EFEF),
    text: Color(0xFF182320),
    text2: Color(0xFF3C4C4A),
    text3: Color(0xFF647674),
    text4: Color(0xFF8EA09E),
    primary: Color(0xFF2E4A56),
    onPrimary: Color(0xFFF1F5F6),
    onPrimarySoft: Color(0xFFB7C9D3),
    onPrimaryLight: Color(0xFFD5E3EA),
    mossTint: Color(0xFFE5EEF1),
    mossSoft: Color(0xFFC0D2DA),
    vermilionSoft: Color(0xFFF6DAD3),
    amberSoft: Color(0xFFF4EBD7),
    indigoSoft: Color(0xFFDDE4F0),
    heat: [
      Color(0xFFE3EBEC),
      Color(0xFFBFD5DC),
      Color(0xFF84A9B4),
      Color(0xFF56818F),
      Color(0xFF2E4A56),
    ],
  ),

  // ========== C · 丹砂·印泥 ==========
  ThemePreset.cinnabar: ThemePalette(
    dark: false,
    bg: Color(0xFFF6EFE7),
    paper2: Color(0xFFEEE4D7),
    paper3: Color(0xFFE1D4C2),
    surface: Color(0xFFFBF6EF),
    surfaceEdge: Color(0xFFE8DCCA),
    rule: Color(0xFFDCD0BD),
    ruleSoft: Color(0xFFF0E8D9),
    text: Color(0xFF211D19),
    text2: Color(0xFF483F37),
    text3: Color(0xFF776B60),
    text4: Color(0xFF9D9387),
    primary: Color(0xFF9C4530),
    onPrimary: Color(0xFFFBF2E9),
    onPrimarySoft: Color(0xFFE0B9A6),
    onPrimaryLight: Color(0xFFEACDC1),
    mossTint: Color(0xFFF6E4D6),
    mossSoft: Color(0xFFDCC0A8),
    vermilionSoft: Color(0xFFF5D6C9),
    amberSoft: Color(0xFFF3E4C4),
    indigoSoft: Color(0xFFDCD7E2),
    heat: [
      Color(0xFFEADFCC),
      Color(0xFFE1CDB2),
      Color(0xFFC89F7A),
      Color(0xFF9C5B3E),
      Color(0xFF8A3A28),
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
    bg: Color(0xFF15120E),
    paper2: Color(0xFF1E1A14),
    paper3: Color(0xFF272118),
    surface: Color(0xFF1E1A14),
    surfaceEdge: Color(0xFF302A1F),
    rule: Color(0xFF302A1F),
    ruleSoft: Color(0xFF302A1F),
    text: Color(0xFFF1EDE5),
    text2: Color(0xFFD1CBBE),
    text3: Color(0xFFA8A194),
    text4: Color(0xFF817A6D),
    primary: Color(0xFFC27057),
    onPrimary: Color(0xFF1B0F0A),
    onPrimarySoft: Color(0xFF3A221A),
    onPrimaryLight: Color(0xFF572E21),
    mossTint: Color(0xFF261A13),
    mossSoft: Color(0xFF3C2B20),
    vermilionSoft: Color(0xFF331C14),
    amberSoft: Color(0xFF2E2615),
    indigoSoft: Color(0xFF1F1F2A),
    heat: [
      Color(0xFF211A11),
      Color(0xFF2F241A),
      Color(0xFF4A3422),
      Color(0xFF6E452B),
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