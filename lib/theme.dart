import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF153C31);
  static const forest = Color(0xFF145C47);
  static const leaf = Color(0xFF54866B);
  static const lime = Color(0xFFF3C56B);
  static const cream = Color(0xFFF2F7F4);
  static const paper = Color(0xFFFFFFFF);
  static const terracotta = Color(0xFFCA684E);
  static const sky = Color(0xFF427F9B);
  static const muted = Color(0xFF61776C);
  static const line = Color(0xFFDDE8E1);
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
    fontFamily: 'DM Sans',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontFamily: 'Sora',
        color: AppColors.ink,
        fontSize: 36,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Sora',
        color: AppColors.ink,
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -.8,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Sora',
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
    appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false),
    chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.lime.withValues(alpha: .6),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(
            fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
    scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.dragged)
                ? AppColors.forest
                : states.contains(WidgetState.hovered)
                    ? AppColors.leaf
                    : AppColors.muted.withValues(alpha: .5)),
        trackColor: const WidgetStatePropertyAll(AppColors.cream),
        thickness: const WidgetStatePropertyAll(7),
        radius: const Radius.circular(8)),
    dividerColor: AppColors.line,
  );
}
