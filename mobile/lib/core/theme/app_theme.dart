import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_preset.dart';
import '../constants/app_constants.dart';

/// 智愈寻真 - Material Design 3 主题配置
class AppTheme {
  AppTheme._();

  /// 主题工厂：根据「预设 × 亮度」生成主题，并把对应色板注册进 extensions，
  /// 使全 App 的上下文取色（AppColors.*Of）与主题同步切换。
  static ThemeData of(ThemePreset preset, bool dark) =>
      dark ? darkTheme(preset.darkPalette) : lightTheme(preset.lightPalette);

  static ThemeData lightTheme(ThemePalette p) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: Brightness.light,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: AppColors.amber,
      onSecondary: AppColors.paper,
      error: AppColors.vermilion,
      onError: AppColors.paper,
      surface: p.surface,
      onSurface: p.text,
      background: p.bg,
      onBackground: p.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      extensions: [ThemePaletteExtension(p)],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // 全局页面转场：柔和淡入 + 轻上移，一处生效，避免生硬切换
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // 各平台统一使用自定义的柔和转场（lower/higher，纵向轻上移+淡入）
          TargetPlatform.android: _SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.macOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.windows: _SoftPageTransitionsBuilder(),
          TargetPlatform.linux: _SoftPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SoftPageTransitionsBuilder(),
        },
      ),

      // Bottom Navigation（悬浮胶囊导航由 AppBottomTabBar 自绘，这里仅兜底）
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bg,
        selectedItemColor: p.primary,
        unselectedItemColor: p.text4,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Card
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: p.surfaceEdge),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.rule, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.rule, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.primary, width: 1.8),
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: p.text2,
          letterSpacing: 0.04,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: p.rule,
        thickness: 1,
        space: 1,
      ),

      // Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: p.text,
          height: 1.1,
          letterSpacing: -0.02,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: p.text,
          height: 1.15,
          letterSpacing: -0.02,
        ),
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: p.text,
          height: 1.2,
          letterSpacing: -0.01,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.text,
          letterSpacing: -0.01,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: p.text,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.text2,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          color: p.text,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: p.text2,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: p.text3,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.text,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: p.text2,
          letterSpacing: 0.04,
        ),
        labelSmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          color: p.text3,
          letterSpacing: 0.06,
        ),
      ),
    );
  }

  /// 深色主题（夜间护眼）
  ///
  /// 基于设计系统深色化：米白/墨绿反转为深墨绿黑背景，主色提亮
  /// 以保证在深色背景上的对比度。每套预设均有各自的深色色板。
  static ThemeData darkTheme(ThemePalette p) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: Brightness.dark,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      error: AppColors.vermilion,
      onError: AppColors.paper,
      surface: p.surface,
      onSurface: p.text,
      background: p.bg,
      onBackground: p.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      extensions: [ThemePaletteExtension(p)],

      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.macOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.windows: _SoftPageTransitionsBuilder(),
          TargetPlatform.linux: _SoftPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SoftPageTransitionsBuilder(),
        },
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bg,
        selectedItemColor: p.primary,
        unselectedItemColor: p.text4,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: p.surfaceEdge),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.surfaceEdge, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.surfaceEdge, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.primary, width: 1.8),
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: p.text2,
          letterSpacing: 0.04,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: p.surfaceEdge,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: p.text,
          height: 1.1,
          letterSpacing: -0.02,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: p.text,
          height: 1.15,
          letterSpacing: -0.02,
        ),
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: p.text,
          height: 1.2,
          letterSpacing: -0.01,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.text,
          letterSpacing: -0.01,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: p.text,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.text2,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          color: p.text,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: p.text2,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: p.text3,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.text,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: p.text2,
          letterSpacing: 0.04,
        ),
        labelSmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          color: p.text3,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

/// 柔和页面转场 Builder —— 「淡入 + 轻上移」
///
/// 取代系统生硬的水平/无过度切换：
/// - push：目标页自下而上轻滑进入，同时整体淡入，营造自然的层级递进感；
/// - pop：目标页淡出并微微下移，方向感统一、不突兀。
/// 动效克制（240ms + easeOutCubic），不干扰操作、不制造眩晕感。
class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 统一柔和「淡入 + 轻上移」：push 时自下而上轻滑淡入；
    // pop 时主动画自动反向（淡出+轻微回落），方向感一致、不突兀。
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
