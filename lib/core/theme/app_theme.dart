import 'package:flutter/material.dart';
import 'package:hypetv/services/content_preferences_service.dart';

abstract final class AppColors {
  static const red = Color(0xFFE50914);
  static const redDark = Color(0xFFB20710);
  static const black = Color(0xFF070707);
  static const surface = Color(0xFF141414);
  static const surfaceRaised = Color(0xFF232323);
  static const muted = Color(0xFFB3B3B3);
}

class LayoutPalette {
  const LayoutPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.accent,
    required this.focus,
    required this.backgroundAlt,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color accent;
  final Color focus;
  final Color backgroundAlt;

  static LayoutPalette forLayout(InterfaceLayout layout) => switch (layout) {
        InterfaceLayout.hypetv => const LayoutPalette(
            background: AppColors.black,
            surface: AppColors.surface,
            surfaceRaised: AppColors.surfaceRaised,
            accent: AppColors.red,
            focus: Colors.white,
            backgroundAlt: Color(0xFF120709),
          ),
        InterfaceLayout.tivimate => const LayoutPalette(
            background: Color(0xFF111111),
            surface: Color(0xFF252525),
            surfaceRaised: Color(0xFF323232),
            accent: Color(0xFF8B8B8B),
            focus: Colors.white,
            backgroundAlt: Color(0xFF1A1A1A),
          ),
        InterfaceLayout.sky => const LayoutPalette(
            background: Color(0xFF071B4A),
            surface: Color(0xFF123777),
            surfaceRaised: Color(0xFF2054A3),
            accent: Color(0xFF55B9FF),
            focus: Colors.white,
            backgroundAlt: Color(0xFF4B126E),
          ),
        InterfaceLayout.xc => const LayoutPalette(
            background: Color(0xFF072E65),
            surface: Color(0xFF0A4B9C),
            surfaceRaised: Color(0xFF7433B7),
            accent: Color(0xFF2EA9FF),
            focus: Colors.white,
            backgroundAlt: Color(0xFF35105E),
          ),
        InterfaceLayout.virgin => const LayoutPalette(
            background: Color(0xFF100916),
            surface: Color(0xFF24152D),
            surfaceRaised: Color(0xFF3B2047),
            accent: Color(0xFFD71968),
            focus: Colors.white,
            backgroundAlt: Color(0xFF26062A),
          ),
        InterfaceLayout.skyClassic => const LayoutPalette(
            background: Color(0xFF0F2F8D),
            surface: Color(0xFF2D55B6),
            surfaceRaised: Color(0xFF4F73CC),
            accent: Color(0xFF76B8FF),
            focus: Color(0xFFFFD900),
            backgroundAlt: Color(0xFF061A57),
          ),
      };
}

abstract final class AppTheme {
  static ThemeData forLayout(InterfaceLayout layout) {
    final palette = LayoutPalette.forLayout(layout);
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.dark,
      surface: palette.surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: palette.accent,
        secondary: palette.accent,
        surface: palette.surface,
      ),
      scaffoldBackgroundColor: palette.background,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
        headlineLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 18, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      focusColor: palette.focus,
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeData get dark => forLayout(InterfaceLayout.hypetv);
}
