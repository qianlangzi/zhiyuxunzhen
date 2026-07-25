import 'package:flutter/material.dart';

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

  // ========== 深色模式（护眼夜色）字段 ==========
  /// 深色主背景（深墨绿黑）
  static const Color darkBg = Color(0xFF121513);

  /// 深色卡片/表面
  static const Color darkSurface = Color(0xFF1A201C);

  /// 深色表面边框
  static const Color darkSurfaceEdge = Color(0xFF2A322C);

  /// 深色主文字（米白）
  static const Color darkText = Color(0xFFF5F1E8);

  /// 深色次级文字
  static const Color darkText2 = Color(0xFFD8D2C4);

  /// 深色辅助文字
  static const Color darkText3 = Color(0xFFA8A99E);

  /// 深色禁用/占位文字
  static const Color darkText4 = Color(0xFF7A7E78);

  // ========== 语义色：按主题亮度自适应 ==========
  /// 直接替换硬编码颜色即可让组件/页面跟随深色模式。
  /// light 模式返回原设计值，dark 模式返回护眼夜色，行为完全可控。
  static Color bgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : paper;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : card;

  static Color surfaceEdgeOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceEdge : cardEdge;

  static Color ruleOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceEdge : rule;

  static Color textOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : ink;

  static Color text2Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText2 : ink2;

  static Color text3Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText3 : ink3;

  static Color text4Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText4 : ink4;

  /// 主色（强调）。深色模式下提亮为 moss3 保证对比度
  static Color primaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? moss3 : moss;

  /// 主色之上的文字/图标色
  static Color onPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : paper;
}
