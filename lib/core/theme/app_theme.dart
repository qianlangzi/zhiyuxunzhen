import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Medical Teal palette — from ui-ux-pro-max Healthcare App
  static const primary = Color(0xFF0891B2);
  static const primaryLight = Color(0xFFECFEFF);
  static const primaryHover = Color(0xFF0E7490);
  static const accent = Color(0xFF16A34A);
  static const accentLight = Color(0xFFDCFCE7);

  // Light theme
  static const bgLight = Color(0xFFF0FDFA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const fgLight = Color(0xFF134E4A);
  static const fgDimLight = Color(0xFF475569);
  static const mutedLight = Color(0xFFE8F1F6);
  static const borderLight = Color(0xFFCCFBF1);

  // Dark theme
  static const bgDark = Color(0xFF0B1120);
  static const surfaceDark = Color(0xFF1E293B);
  static const fgDark = Color(0xFFE2E8F0);
  static const fgDimDark = Color(0xFF94A3B8);
  static const mutedDark = Color(0xFF334155);
  static const borderDark = Color(0xFF1E3A5F);

  // Semantic
  static const destructive = Color(0xFFDC2626);
  static const destructiveLight = Color(0xFFFEF2F2);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFFFBEB);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surfaceLight,
    );

    final textTheme = GoogleFonts.notoSansTextTheme().copyWith(
      displayLarge: GoogleFonts.figtree(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
        color: AppColors.fgLight,
      ),
      displayMedium: GoogleFonts.figtree(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: -0.3,
        color: AppColors.fgLight,
      ),
      headlineMedium: GoogleFonts.figtree(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: AppColors.fgLight,
      ),
      titleLarge: GoogleFonts.figtree(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: AppColors.fgLight,
      ),
      titleMedium: GoogleFonts.figtree(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: AppColors.fgLight,
      ),
      bodyLarge: GoogleFonts.notoSans(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: AppColors.fgLight,
      ),
      bodyMedium: GoogleFonts.notoSans(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.fgLight,
      ),
      bodySmall: GoogleFonts.notoSans(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: AppColors.fgDimLight,
      ),
      labelLarge: GoogleFonts.notoSans(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.fgLight,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgLight,
        foregroundColor: AppColors.fgLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: GoogleFonts.figtree(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.fgLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.fgDimLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.fgDimLight,
        indicatorColor: AppColors.primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mutedLight,
        selectedColor: AppColors.primaryLight,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.fgLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: AppColors.borderLight),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF22D3EE),
      brightness: Brightness.dark,
      primary: const Color(0xFF22D3EE),
      surface: AppColors.surfaceDark,
    );

    final textTheme = GoogleFonts.notoSansTextTheme().copyWith(
      displayLarge: GoogleFonts.figtree(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
        color: AppColors.fgDark,
      ),
      displayMedium: GoogleFonts.figtree(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: -0.3,
        color: AppColors.fgDark,
      ),
      headlineMedium: GoogleFonts.figtree(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: AppColors.fgDark,
      ),
      titleLarge: GoogleFonts.figtree(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: AppColors.fgDark,
      ),
      titleMedium: GoogleFonts.figtree(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: AppColors.fgDark,
      ),
      bodyLarge: GoogleFonts.notoSans(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: AppColors.fgDark,
      ),
      bodyMedium: GoogleFonts.notoSans(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.fgDark,
      ),
      bodySmall: GoogleFonts.notoSans(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: AppColors.fgDimDark,
      ),
      labelLarge: GoogleFonts.notoSans(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.fgDark,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.fgDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: GoogleFonts.figtree(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.fgDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF22D3EE), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E7490),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: Color(0xFF22D3EE),
        unselectedItemColor: AppColors.fgDimDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mutedDark,
        selectedColor: const Color(0xFF0F2C33),
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.fgDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: AppColors.borderDark),
      ),
    );
  }
}
