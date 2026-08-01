import 'package:flutter/material.dart';

abstract final class AppColors {
  static const red = Color(0xFFE50914);
  static const redDark = Color(0xFFB20710);
  static const black = Color(0xFF070707);
  static const surface = Color(0xFF141414);
  static const surfaceRaised = Color(0xFF232323);
  static const muted = Color(0xFFB3B3B3);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: AppColors.red,
        secondary: AppColors.red,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.black,
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
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      focusColor: AppColors.red,
      visualDensity: VisualDensity.standard,
    );
  }
}
