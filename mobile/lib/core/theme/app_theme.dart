import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 智愈寻真 - Material Design 3 主题配置
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.moss,
      brightness: Brightness.light,
      primary: AppColors.moss,
      onPrimary: AppColors.paper,
      secondary: AppColors.amber,
      onSecondary: AppColors.paper,
      error: AppColors.vermilion,
      onError: AppColors.paper,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      background: AppColors.paper,
      onBackground: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.paper,
        selectedItemColor: AppColors.moss,
        unselectedItemColor: AppColors.ink4,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.cardEdge, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.rule, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.rule, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.moss, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.ink2,
          letterSpacing: 0.04,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.rule,
        thickness: 1,
        space: 1,
      ),

      // Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.moss,
          foregroundColor: AppColors.paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.moss,
          textStyle: const TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ),

      // Text
      textTheme: const TextTheme(
        // Display
        displayLarge: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.1,
          letterSpacing: -0.02,
        ),
        displayMedium: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.15,
          letterSpacing: -0.02,
        ),
        displaySmall: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.2,
          letterSpacing: -0.01,
        ),
        // Headline
        headlineLarge: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: -0.01,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        // Title
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink2,
        ),
        // Body
        bodyLarge: TextStyle(
          fontSize: 14,
          color: AppColors.ink,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.ink2,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.ink3,
          height: 1.5,
        ),
        // Label
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.ink2,
          letterSpacing: 0.04,
        ),
        labelSmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          color: AppColors.ink3,
          letterSpacing: 0.06,
        ),
      ),
    );
  }

  /// 深色主题（夜间护眼）
  ///
  /// 基于设计系统深色化：米白/墨绿反转为深墨绿黑背景，主色 moss 提亮为 moss3
  /// 以保证在深色背景上的对比度。开启「深色模式」开关后由 [ZhiyuApp] 切换。
  static ThemeData get darkTheme {
    const darkBg = AppColors.darkBg;
    const darkSurface = AppColors.darkSurface;
    const darkSurfaceEdge = AppColors.darkSurfaceEdge;
    const darkRule = AppColors.darkSurfaceEdge;
    const darkText = AppColors.darkText;
    const darkText2 = AppColors.darkText2;
    const darkText3 = AppColors.darkText3;
    const darkText4 = AppColors.darkText4;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.moss,
      brightness: Brightness.dark,
      primary: AppColors.moss3,
      onPrimary: AppColors.paper,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      error: AppColors.vermilion,
      onError: AppColors.paper,
      surface: darkSurface,
      onSurface: darkText,
      background: darkBg,
      onBackground: darkText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBg,
      canvasColor: darkBg,

      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBg,
        selectedItemColor: AppColors.moss3,
        unselectedItemColor: darkText4,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkSurfaceEdge, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: darkSurfaceEdge, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: darkSurfaceEdge, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.moss3, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: darkText2,
          letterSpacing: 0.04,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: darkRule,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.moss3,
          foregroundColor: AppColors.ink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.moss3,
          textStyle: const TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: darkText,
          height: 1.1,
          letterSpacing: -0.02,
        ),
        displayMedium: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: darkText,
          height: 1.15,
          letterSpacing: -0.02,
        ),
        displaySmall: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: darkText,
          height: 1.2,
          letterSpacing: -0.01,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkText,
          letterSpacing: -0.01,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'NotoSerifSC',
          fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: darkText2,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          color: darkText,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: darkText2,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: darkText3,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: darkText2,
          letterSpacing: 0.04,
        ),
        labelSmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          color: darkText3,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}
