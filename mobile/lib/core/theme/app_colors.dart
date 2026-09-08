import 'package:flutter/material.dart';

import 'theme_preset.dart';

/// 智愈寻真 - 设计系统色彩定义
/// 从 HTML 原型 design-system.css 推导的色彩体系
class AppColors {
  AppColors._();

  // ========== 基础纸色 ==========
  /// --paper: 主背景色（米白/宣纸色）
  static const Color paper = Color(0xFFF5F1E8);

  /// --paper-2: 次级背景（略深纸色）
  static const Color paper2 = Color(0xFFEBE5D6);

  /// --paper-3: 三级背景（热力图底色等）
  static const Color paper3 = Color(0xFFDDD5C5);

  // ========== 墨色文字 ==========
  /// --ink: 主文字色（深墨绿黑）
  static const Color ink = Color(0xFF1A1F1C);

  /// --ink-2: 次级文字
  static const Color ink2 = Color(0xFF3A3F3C);

  /// --ink-3: 辅助文字
  static const Color ink3 = Color(0xFF6B7270);

  /// --ink-4: 占位/禁用文字
  static const Color ink4 = Color(0xFF9AA09D);

  // ========== 苔藓绿（主色调） ==========
  /// --moss: 主色（深苔藓绿）
  static const Color moss = Color(0xFF2D4A3E);

  /// --moss-2: 主色渐变次级
  static const Color moss2 = Color(0xFF3A5A4E);

  /// --moss-3: 主色三级
  static const Color moss3 = Color(0xFF5A7A6B);

  /// --moss-soft: 浅主色边框
  static const Color mossSoft = Color(0xFFC8D4C0);

  /// --moss-tint: 极浅主色背景
  static const Color mossTint = Color(0xFFE8F0E5);

  // ========== 朱砂红（警示/错误） ==========
  /// --vermilion: 错误/紧急色
  static const Color vermilion = Color(0xFFB8412E);

  /// --vermilion-soft: 浅错误背景
  static const Color vermilionSoft = Color(0xFFF3DCD7);

  // ========== 琥珀黄（警告/提示） ==========
  /// --amber: 警告色
  static const Color amber = Color(0xFFB8821E);

  /// --amber-soft: 浅警告背景
  static const Color amberSoft = Color(0xFFF5E6C8);

  // ========== 靛蓝（信息/AI） ==========
  /// --indigo: 信息色
  static const Color indigo = Color(0xFF4A5A8A);

  /// --indigo-soft: 浅信息背景
  static const Color indigoSoft = Color(0xFFD8DCEA);

  // ========== 卡片/边框 ==========
  /// --card: 卡片背景
  static const Color card = Color(0xFFFAF7F0);

  /// --card-edge: 卡片边框
  static const Color cardEdge = Color(0xFFE0D9C8);

  /// --rule: 分割线
  static const Color rule = Color(0xFFD8D0C0);

  /// --rule-soft: 浅分割线
  static const Color ruleSoft = Color(0xFFE8E2D4);

  // ========== 图表色 ==========
  static const Color chart1 = Color(0xFF2D4A3E);
  static const Color chart2 = Color(0xFFB8821E);
  static const Color chart3 = Color(0xFF4A5A8A);
  static const Color chart4 = Color(0xFFB8412E);

  // ========== 热力图色阶 ==========
  static const Color heatL0 = Color(0xFFEBE5D6);
  static const Color heatL1 = Color(0xFFC8D4C0);
  static const Color heatL2 = Color(0xFF8FA787);
  static const Color heatL3 = Color(0xFF5A7A6B);
  static const Color heatL4 = Color(0xFF2D4A3E);

  // ========== 深色模式：热力图色阶（炭灰偏青、提亮去黄，空白格仍清晰可辨）==========
  /// 深色无记录格（比背景略亮，冷调青灰，保证空态可见且不发黄）
  static const Color darkHeatL0 = Color(0xFF181E23);
  static const Color darkHeatL1 = Color(0xFF1F3A33);
  static const Color darkHeatL2 = Color(0xFF2C5247);
  static const Color darkHeatL3 = Color(0xFF3C6E5F);
  static const Color darkHeatL4 = Color(0xFF8FC6B6);

  // ========== 便捷别名 ==========
  static const Color primary = moss;
  static const Color error = vermilion;
  static const Color warning = amber;
  static const Color info = indigo;
  static const Color background = paper;
  static const Color surface = card;
  static const Color onPrimary = paper;
  static const Color onBackground = ink;
  static const Color onSurface = ink;

  // ========== 深色模式（炭灰偏青、护眼夜色）字段 ==========
  /// 深色主背景（炭灰偏青，去暖/去黄）
  static const Color darkBg = Color(0xFF12161A);

  /// 深色卡片/表面
  static const Color darkSurface = Color(0xFF1B2126);

  /// 深色表面边框
  static const Color darkSurfaceEdge = Color(0xFF2C343A);

  /// 深色主文字（微冷米）
  static const Color darkText = Color(0xFFEDF1EF);

  /// 深色次级文字
  static const Color darkText2 = Color(0xFFC6CFCC);

  /// 深色辅助文字
  static const Color darkText3 = Color(0xFF9BA6A5);

  /// 深色禁用/占位文字
  static const Color darkText4 = Color(0xFF737E7D);

  /// 深色 mossSoft（浅主色边框暗色变体）
  static const Color darkMossSoft = Color(0xFF33423A);

  // ========== 深色模式：软色变体 ==========
  /// 深色 mossTint（深绿底色）
  static const Color darkMossTint = Color(0xFF1C2A24);

  /// 深色 vermilionSoft
  static const Color darkVermilionSoft = Color(0xFF2C1B18);

  /// 深色 amberSoft
  static const Color darkAmberSoft = Color(0xFF2B251A);

  /// 深色 indigoSoft
  static const Color darkIndigoSoft = Color(0xFF1A1E2A);

  /// 深色 ruleSoft（与 darkSurfaceEdge 一致）
  static const Color darkRuleSoft = Color(0xFF2C343A);

  /// 深色 paper2
  static const Color darkPaper2 = Color(0xFF1B2126);

  /// 深色 paper3
  static const Color darkPaper3 = Color(0xFF242B30);

  // ========== 语义色：按「预设 × 亮度」自适应 ==========
  /// 直接替换硬编码颜色即可让组件/页面跟随主题预设与深色模式。
  /// 取色源是 [ThemePaletteExtension]，缺省兜底为「本草(默认)」预设当前亮度。
  /// 由此实现个性化预设切换时全 App 统一切换、不串色、对比度不崩。
  static ThemePalette _pal(BuildContext context) {
    final ext =
        Theme.of(context).extension<ThemePaletteExtension>()?.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ext ??
        (dark ? ThemePreset.herb.darkPalette : ThemePreset.herb.lightPalette);
  }

  static Color bgOf(BuildContext context) => _pal(context).bg;

  static Color surfaceOf(BuildContext context) => _pal(context).surface;

  static Color surfaceEdgeOf(BuildContext context) => _pal(context).surfaceEdge;

  static Color ruleOf(BuildContext context) => _pal(context).rule;

  static Color textOf(BuildContext context) => _pal(context).text;

  static Color text2Of(BuildContext context) => _pal(context).text2;

  static Color text3Of(BuildContext context) => _pal(context).text3;

  static Color text4Of(BuildContext context) => _pal(context).text4;

  /// 主色（强调）。深色模式下按各预设提亮保证对比度
  static Color primaryOf(BuildContext context) => _pal(context).primary;

  /// 主色之上的文字/图标色
  static Color onPrimaryOf(BuildContext context) => _pal(context).onPrimary;

  // ========== 软色：按「预设 × 亮度」自适应 ==========
  /// 极浅主色背景（mossTint）
  static Color mossTintOf(BuildContext context) => _pal(context).mossTint;

  /// 浅错误背景（vermilionSoft）
  static Color vermilionSoftOf(BuildContext context) =>
      _pal(context).vermilionSoft;

  /// 浅警告背景（amberSoft）
  static Color amberSoftOf(BuildContext context) => _pal(context).amberSoft;

  /// 浅信息背景（indigoSoft）
  static Color indigoSoftOf(BuildContext context) => _pal(context).indigoSoft;

  /// 浅分割线（ruleSoft）
  static Color ruleSoftOf(BuildContext context) => _pal(context).ruleSoft;

  /// 次级背景（paper2）
  static Color paper2Of(BuildContext context) => _pal(context).paper2;

  /// 三级背景（paper3）
  static Color paper3Of(BuildContext context) => _pal(context).paper3;

  /// 浅主色边框（mossSoft）
  static Color mossSoftOf(BuildContext context) => _pal(context).mossSoft;

  /// 热力图等级色（随预设与亮度自适应，修复深色模式下空白格不可见/泛黄）
  static Color heatOf(BuildContext context, int level) {
    final heat = _pal(context).heat;
    return heat[level.clamp(0, 4)];
  }

  // ========== 强调色：按亮度自适应 ==========
  /// 这四个色原本是 static const，被大量页面直接引用，导致深色模式下
  /// 对比度不足（indigo 约 2.9:1、vermilion 与 moss3 约 3.5:1）。
  /// 统一改为按亮度取值的语义色：浅色沿用原品牌色，深色提亮到可读区间。

  /// 琥珀（警告 / 提示）
  static Color amberOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE3B65A)
          : amber;

  /// 靛蓝（信息 / AI）
  static Color indigoOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF93A3DC)
          : indigo;

  /// 朱砂（错误 / 紧急）
  static Color vermilionOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE9846C)
          : vermilion;

  /// 主色三级（次级强调文字）
  static Color moss3Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF8FB8A5)
          : moss3;

  /// 教师（身份区分色）：采用靛蓝，与主色苔绿互补，契合本草/宣纸整体基调；
  /// 取代原先直接挪用「朱砂红（错误色）」做教师身份的做法，语义更正确、配色更协调。
  static Color teacherOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF93A3DC)
          : indigo;

  // ========== 主色背景上的柔和文字 ==========
  /// 主色背景上的柔和文字（用于 hero 次要文字）
  static Color onPrimarySoftOf(BuildContext context) =>
      _pal(context).onPrimarySoft;

  /// 主色背景上的更浅文字（用于 hero 评级描述）
  static Color onPrimaryLightOf(BuildContext context) =>
      _pal(context).onPrimaryLight;
}
