import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color cream = Color(0xFFF6EFE4);
  static const Color sand = Color(0xFFE8D9C4);
  static const Color ink = Color(0xFF1B1714);
  static const Color moss = Color(0xFF28544B);
  static const Color copper = Color(0xFFAD6C3D);
  static const Color blush = Color(0xFFE8C7BB);
  static const Color card = Color(0xFFFFFBF6);

  static ThemeData light() {
    final TextTheme base = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: const ColorScheme.light(
        primary: moss,
        onPrimary: Colors.white,
        secondary: copper,
        onSecondary: Colors.white,
        surface: card,
        onSurface: ink,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 44,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: ink.withValues(alpha: 0.82),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: moss, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: sand.withValues(alpha: 0.62),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: moss,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark() {
    final TextTheme base = ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF161C1A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6DB4A6),
        onPrimary: Color(0xFF0F1513),
        secondary: Color(0xFFD69A70),
        onSecondary: Color(0xFF1C130D),
        surface: Color(0xFF1F2724),
        onSurface: Color(0xFFE7E1D8),
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 44,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE7E1D8),
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE7E1D8),
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE7E1D8),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE7E1D8),
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE7E1D8),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F2724),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF6DB4A6), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE7E1D8),
        ),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6DB4A6),
        foregroundColor: Color(0xFF0F1513),
      ),
    );
  }
}
