import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppColorPalette {
  material,
  nord,
  catppuccin,
  oneDark,
  tokyoNight,
  dracula,
  gruvbox,
}

extension AppColorPaletteCodec on AppColorPalette {
  String get key => name;

  static AppColorPalette fromKey(String? value) {
    return AppColorPalette.values.firstWhere(
      (it) => it.name == value,
      orElse: () => AppColorPalette.material,
    );
  }
}

class _PaletteColors {
  const _PaletteColors({
    required this.primary,
    required this.secondary,
    required this.lightScaffold,
    required this.lightAccent,
    required this.lightSurface,
    required this.lightOnSurface,
    required this.darkScaffold,
    required this.darkAccent,
    required this.darkSurface,
    required this.darkOnSurface,
  });

  final Color primary;
  final Color secondary;
  final Color lightScaffold;
  final Color lightAccent;
  final Color lightSurface;
  final Color lightOnSurface;
  final Color darkScaffold;
  final Color darkAccent;
  final Color darkSurface;
  final Color darkOnSurface;
}

class AppTheme {
  static const Color cream = Color(0xFFF6EFE4);
  static const Color sand = Color(0xFFE8D9C4);
  static const Color ink = Color(0xFF1B1714);
  static const Color moss = Color(0xFF28544B);
  static const Color copper = Color(0xFFAD6C3D);
  static const Color blush = Color(0xFFE8C7BB);
  static const Color card = Color(0xFFFFFBF6);

  static ThemeData light([AppColorPalette palette = AppColorPalette.material]) {
    final _PaletteColors p = _palette(palette);
    final TextTheme base = ThemeData.light().textTheme;
    final Color primaryContainer = _blend(p.primary, p.lightSurface, 0.18);
    final Color secondaryContainer = _blend(p.secondary, p.lightSurface, 0.2);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: p.lightScaffold,
      canvasColor: p.lightSurface,
      dividerColor: p.lightOnSurface.withValues(alpha: 0.12),
      colorScheme: ColorScheme.light(
        primary: p.primary,
        onPrimary: _bestOnColor(p.primary),
        secondary: p.secondary,
        onSecondary: _bestOnColor(p.secondary),
        primaryContainer: primaryContainer,
        onPrimaryContainer: _bestOnColor(primaryContainer),
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: _bestOnColor(secondaryContainer),
        surface: p.lightSurface,
        onSurface: p.lightOnSurface,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 44,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: p.lightOnSurface,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: p.lightOnSurface,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: p.lightOnSurface,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.lightOnSurface,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: p.lightOnSurface,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: p.lightOnSurface.withValues(alpha: 0.82),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.lightOnSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: p.lightOnSurface,
        ),
      ),
      iconTheme: IconThemeData(color: p.lightOnSurface),
      listTileTheme: ListTileThemeData(
        iconColor: p.lightOnSurface,
        textColor: p.lightOnSurface,
      ),
      dividerTheme: DividerThemeData(
        color: p.lightOnSurface.withValues(alpha: 0.12),
        thickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.lightSurface,
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.lightOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: p.lightOnSurface.withValues(alpha: 0.05)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _blend(p.primary, p.lightSurface, 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: p.lightOnSurface.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: p.lightAccent.withValues(alpha: 0.45),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.lightOnSurface,
        ),
        side: BorderSide.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.24),
        selectionHandleColor: p.primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark([AppColorPalette palette = AppColorPalette.material]) {
    final _PaletteColors p = _palette(palette);
    final TextTheme base = ThemeData.light().textTheme;
    final Color primaryContainer = _blend(p.primary, p.darkSurface, 0.34);
    final Color secondaryContainer = _blend(p.secondary, p.darkSurface, 0.32);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: p.darkScaffold,
      canvasColor: p.darkSurface,
      dividerColor: p.darkOnSurface.withValues(alpha: 0.14),
      colorScheme: ColorScheme.dark(
        primary: p.primary,
        onPrimary: _bestOnColor(p.primary),
        secondary: p.secondary,
        onSecondary: _bestOnColor(p.secondary),
        primaryContainer: primaryContainer,
        onPrimaryContainer: _bestOnColor(primaryContainer),
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: _bestOnColor(secondaryContainer),
        surface: p.darkSurface,
        onSurface: p.darkOnSurface,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base)
          .apply(bodyColor: p.darkOnSurface, displayColor: p.darkOnSurface)
          .copyWith(
            displayLarge: GoogleFonts.playfairDisplay(
              fontSize: 44,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: p.darkOnSurface,
            ),
            displayMedium: GoogleFonts.playfairDisplay(
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: p.darkOnSurface,
            ),
            headlineMedium: GoogleFonts.playfairDisplay(
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: p.darkOnSurface,
            ),
            titleLarge: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.darkOnSurface,
            ),
            bodyLarge: GoogleFonts.dmSans(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: p.darkOnSurface,
            ),
            bodyMedium: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: p.darkOnSurface,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.darkOnSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: p.darkOnSurface,
        ),
      ),
      iconTheme: IconThemeData(color: p.darkOnSurface),
      listTileTheme: ListTileThemeData(
        iconColor: p.darkOnSurface,
        textColor: p.darkOnSurface,
      ),
      dividerTheme: DividerThemeData(
        color: p.darkOnSurface.withValues(alpha: 0.14),
        thickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.darkSurface,
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.darkOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: p.darkOnSurface.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _blend(p.primary, p.darkSurface, 0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: p.darkOnSurface.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: p.darkAccent.withValues(alpha: 0.22),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.darkOnSurface,
        ),
        side: BorderSide.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.28),
        selectionHandleColor: p.primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: const Color(0xFF0F1513),
      ),
    );
  }

  static _PaletteColors _palette(AppColorPalette palette) {
    return switch (palette) {
      AppColorPalette.material => const _PaletteColors(
        primary: Color(0xFF6750A4),
        secondary: Color(0xFFB5835A),
        lightScaffold: Color(0xFFF5F1FB),
        lightAccent: Color(0xFFEADFF9),
        lightSurface: Color(0xFFFFFBFF),
        lightOnSurface: Color(0xFF1D1B20),
        darkScaffold: Color(0xFF17141F),
        darkAccent: Color(0xFF2B233F),
        darkSurface: Color(0xFF1F1B2A),
        darkOnSurface: Color(0xFFE7E1E8),
      ),
      AppColorPalette.nord => const _PaletteColors(
        primary: Color(0xFF88C0D0),
        secondary: Color(0xFFD08770),
        lightScaffold: Color(0xFFECEFF4),
        lightAccent: Color(0xFFE5E9F0),
        lightSurface: Color(0xFFF5F7FA),
        lightOnSurface: Color(0xFF2E3440),
        darkScaffold: Color(0xFF2E3440),
        darkAccent: Color(0xFF3B4252),
        darkSurface: Color(0xFF3B4252),
        darkOnSurface: Color(0xFFECEFF4),
      ),
      AppColorPalette.catppuccin => const _PaletteColors(
        primary: Color(0xFF7287FD),
        secondary: Color(0xFFEA76CB),
        lightScaffold: Color(0xFFEFF1F5),
        lightAccent: Color(0xFFDCE0E8),
        lightSurface: Color(0xFFFFFFFF),
        lightOnSurface: Color(0xFF4C4F69),
        darkScaffold: Color(0xFF1E1E2E),
        darkAccent: Color(0xFF313244),
        darkSurface: Color(0xFF313244),
        darkOnSurface: Color(0xFFCDD6F4),
      ),
      AppColorPalette.oneDark => const _PaletteColors(
        primary: Color(0xFF61AFEF),
        secondary: Color(0xFFE5C07B),
        lightScaffold: Color(0xFFF4F6FA),
        lightAccent: Color(0xFFE6EBF4),
        lightSurface: Color(0xFFFFFFFF),
        lightOnSurface: Color(0xFF2C313C),
        darkScaffold: Color(0xFF282C34),
        darkAccent: Color(0xFF2F3540),
        darkSurface: Color(0xFF2F3540),
        darkOnSurface: Color(0xFFABB2BF),
      ),
      AppColorPalette.tokyoNight => const _PaletteColors(
        primary: Color(0xFF7AA2F7),
        secondary: Color(0xFFBB9AF7),
        lightScaffold: Color(0xFFE9ECF6),
        lightAccent: Color(0xFFDCE0EE),
        lightSurface: Color(0xFFF7F8FC),
        lightOnSurface: Color(0xFF1A1B26),
        darkScaffold: Color(0xFF1A1B26),
        darkAccent: Color(0xFF24283B),
        darkSurface: Color(0xFF24283B),
        darkOnSurface: Color(0xFFA9B1D6),
      ),
      AppColorPalette.dracula => const _PaletteColors(
        primary: Color(0xFFBD93F9),
        secondary: Color(0xFFFF79C6),
        lightScaffold: Color(0xFFF6F2FD),
        lightAccent: Color(0xFFECE6FA),
        lightSurface: Color(0xFFFFFFFF),
        lightOnSurface: Color(0xFF282A36),
        darkScaffold: Color(0xFF282A36),
        darkAccent: Color(0xFF313442),
        darkSurface: Color(0xFF313442),
        darkOnSurface: Color(0xFFF8F8F2),
      ),
      AppColorPalette.gruvbox => const _PaletteColors(
        primary: Color(0xFF458588),
        secondary: Color(0xFFD79921),
        lightScaffold: Color(0xFFFBF1C7),
        lightAccent: Color(0xFFEBDBB2),
        lightSurface: Color(0xFFFFF7DF),
        lightOnSurface: Color(0xFF3C3836),
        darkScaffold: Color(0xFF282828),
        darkAccent: Color(0xFF3C3836),
        darkSurface: Color(0xFF3C3836),
        darkOnSurface: Color(0xFFEBDBB2),
      ),
    };
  }

  static Color _blend(Color foreground, Color background, double opacity) {
    return Color.alphaBlend(
      foreground.withValues(alpha: opacity.clamp(0, 1)),
      background,
    );
  }

  static Color _bestOnColor(Color color) {
    const Color lightForeground = Color(0xFF000000);
    const Color darkForeground = Colors.white;
    final double lightContrast = _contrastRatio(color, lightForeground);
    final double darkContrast = _contrastRatio(color, darkForeground);
    return lightContrast >= darkContrast ? lightForeground : darkForeground;
  }

  static double _contrastRatio(Color a, Color b) {
    final double l1 = a.computeLuminance();
    final double l2 = b.computeLuminance();
    final double lighter = l1 > l2 ? l1 : l2;
    final double darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
