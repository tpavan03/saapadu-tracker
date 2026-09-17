import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF17241D);
  static const forest = Color(0xFF215C3F);
  static const leaf = Color(0xFF4D8B65);
  static const lime = Color(0xFFC9E265);
  static const cream = Color(0xFFF7F3E8);
  static const paper = Color(0xFFFFFDF7);
  static const terracotta = Color(0xFFD96C4E);
  static const sky = Color(0xFF7EB6C4);
  static const muted = Color(0xFF6C766F);
  static const line = Color(0xFFE2DED2);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    brightness: Brightness.light,
    primary: AppColors.forest,
    secondary: AppColors.terracotta,
    surface: AppColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: 'sans-serif',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: AppColors.ink,
        fontSize: 36,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineMedium: TextStyle(
        color: AppColors.ink,
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -.8,
      ),
      titleLarge: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      ),
      titleMedium: TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
      bodyMedium: TextStyle(color: AppColors.ink, fontSize: 14, height: 1.35),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .1),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.paper,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.lime,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    dividerColor: AppColors.line,
  );
}
