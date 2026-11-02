import 'package:flutter/material.dart';

class AppColors {
  // An after-hours kitchen: rice, brass and green leaves against deep teal.
  // Legacy names remain stable for existing screens; foregrounds and feature
  // surfaces deliberately have separate semantic tokens.
  static const ink = Color(0xFFF4F2E9);
  static const forest = Color(0xFFA2DDC2);
  static const leaf = Color(0xFFABCABB);
  static const lime = Color(0xFFE9BE75);
  static const cream = Color(0xFF091719);
  static const paper = Color(0xFF12292B);
  static const hero = Color(0xFF173F40);
  static const onAccent = Color(0xFF09201B);
  static const terracotta = Color(0xFFF3AC93);
  static const dangerSurface = Color(0xFF713D35);
  static const sky = Color(0xFFA0D3ED);
  static const muted = Color(0xFFAAC1BB);
  static const line = Color(0xFF2D4848);
  static const lavender = Color(0xFFC5B9EA);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.forest,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.lime,
    onSecondary: AppColors.onAccent,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.hero,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    error: AppColors.terracotta,
    onError: AppColors.onAccent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: 'DM Sans',
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
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
      bodySmall: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
      labelLarge: TextStyle(
          color: AppColors.ink, fontWeight: FontWeight.w700, letterSpacing: .1),
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
      labelStyle: TextStyle(color: AppColors.muted),
      helperStyle: TextStyle(color: AppColors.muted, height: 1.5),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.forest, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.onAccent,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.forest,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
      foregroundColor: AppColors.forest,
      minimumSize: const Size(48, 48),
    )),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
      foregroundColor: AppColors.forest,
      minimumSize: const Size(48, 48),
    )),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.lime,
      surfaceTintColor: Colors.transparent,
      height: 80,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.onAccent
                : AppColors.muted,
            size: 24,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          )),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      selectedIconTheme: IconThemeData(color: AppColors.onAccent),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle:
          TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
    ),
    dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.paper, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.hero,
      contentTextStyle: TextStyle(color: AppColors.ink),
      behavior: SnackBarBehavior.floating,
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false),
    chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.hero,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(
            color: AppColors.ink,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600)),
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
