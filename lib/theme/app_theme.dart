import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// BRAND PALETTE (fixed brand identity, does not change per theme)
// ─────────────────────────────────────────────────────────────
class AppColors {
  // Primary brand
  static const maroon = Color(0xFF800000);
  static const maroonDark = Color(0xFF5C0000);
  static const maroonLight = Color(0xFFF5E6E6);

  // Accent
  static const gold = Color(0xFFD4AF37);

  // Semantic
  static const danger = Color(0xFFB00020);
  static const success = Color(0xFF2E7D32);

  // ─────────────────────────────────────────────────────────────
  // LIGHT SCHEME
  // ─────────────────────────────────────────────────────────────
  static const lightBackground = Color(0xFFF5F5F5);
  static const lightSurface = Colors.white;
  static const lightSurfaceAlt = Color(0xFFFAFAFA);
  static const lightBorder = Color(0xFFE0E0E0);
  static const lightTextPrimary = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF6B6B6B);
  static const lightTextTertiary = Color(0xFF9E9E9E);

  // ─────────────────────────────────────────────────────────────
  // DARK SCHEME
  // Lifted from pure black to a warm neutral so the maroon
  // brand color reads well without glare.
  // ─────────────────────────────────────────────────────────────
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkSurfaceAlt = Color(0xFF252525);
  static const darkElevated = Color(0xFF2A2A2A);
  static const darkBorder = Color(0xFF2E2E2E);
  static const darkTextPrimary = Color(0xFFF0F0F0);
  static const darkTextSecondary = Color(0xFFB0B0B0);
  static const darkTextTertiary = Color(0xFF808080);

  // Slightly brighter maroon for dark surfaces — the pure
  // #800000 reads too muddy against near-black.
  static const maroonOnDark = Color(0xFFB22222);
  static const maroonLightOnDark = Color(0xFF3A1A1A);

  // ─────────────────────────────────────────────────────────────
  // BACKWARDS-COMPATIBLE ALIASES
  // Existing widgets that reference these still compile.
  // ─────────────────────────────────────────────────────────────
  static const background = lightBackground;
  static const surface = lightSurface;

  // ─────────────────────────────────────────────────────────────
  // CONTEXT-AWARE HELPERS
  // Preferred in new code — flip automatically with the theme.
  // ─────────────────────────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      _isDark(context) ? darkBackground : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? darkSurface : lightSurface;

  static Color surfaceAltOf(BuildContext context) =>
      _isDark(context) ? darkSurfaceAlt : lightSurfaceAlt;

  static Color borderOf(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textTertiaryOf(BuildContext context) =>
      _isDark(context) ? darkTextTertiary : lightTextTertiary;

  /// A brand color that stays legible on both light and dark
  /// surfaces. In light mode returns the standard maroon; in dark
  /// mode returns a slightly brighter maroon.
  static Color brandOf(BuildContext context) =>
      _isDark(context) ? maroonOnDark : maroon;

  /// A soft brand tint for backgrounds (pills, avatar circles).
  static Color brandSoftOf(BuildContext context) =>
      _isDark(context) ? maroonLightOnDark : maroonLight;

  /// A hairline shadow that's subtle on light and nearly invisible
  /// on dark — used to keep "elevated" cards from looking flat.
  static Color shadowOf(BuildContext context) => _isDark(context)
      ? Colors.black.withOpacity(0.4)
      : Colors.black.withOpacity(0.06);
}

// ─────────────────────────────────────────────────────────────
// LIGHT THEME
// ─────────────────────────────────────────────────────────────
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  primaryColor: AppColors.maroon,
  scaffoldBackgroundColor: AppColors.lightBackground,
  canvasColor: AppColors.lightSurface,
  colorScheme: const ColorScheme.light(
    primary: AppColors.maroon,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: Colors.black,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    error: AppColors.danger,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.maroon,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    systemOverlayStyle: null,
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 1,
    shadowColor: Colors.black.withOpacity(0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.maroon, width: 1.6),
    ),
    labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
    hintStyle: const TextStyle(color: AppColors.lightTextTertiary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.maroon,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.maroon,
      side: const BorderSide(color: AppColors.lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.maroon,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.lightBorder,
    thickness: 1,
    space: 1,
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurface,
    selectedItemColor: AppColors.maroon,
    unselectedItemColor: AppColors.lightTextTertiary,
    showUnselectedLabels: true,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.lightSurfaceAlt,
    selectedColor: AppColors.maroon,
    labelStyle: const TextStyle(color: AppColors.lightTextPrimary),
    side: const BorderSide(color: AppColors.lightBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
    bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
    bodySmall: TextStyle(color: AppColors.lightTextSecondary),
    titleLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: AppColors.lightTextPrimary,
      fontWeight: FontWeight.w600,
    ),
  ),
);

// ─────────────────────────────────────────────────────────────
// DARK THEME
// ─────────────────────────────────────────────────────────────
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  primaryColor: AppColors.maroonOnDark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  canvasColor: AppColors.darkSurface,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.maroonOnDark,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: Colors.black,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    error: AppColors.danger,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.maroonDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.darkBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.darkBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.maroonOnDark, width: 1.6),
    ),
    labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
    hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.maroonOnDark,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.maroonOnDark,
      side: const BorderSide(color: AppColors.darkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.maroonOnDark,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.darkBorder,
    thickness: 1,
    space: 1,
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    selectedItemColor: AppColors.maroonOnDark,
    unselectedItemColor: AppColors.darkTextTertiary,
    showUnselectedLabels: true,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkSurfaceAlt,
    selectedColor: AppColors.maroonOnDark,
    labelStyle: const TextStyle(color: AppColors.darkTextPrimary),
    side: const BorderSide(color: AppColors.darkBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
    bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
    bodySmall: TextStyle(color: AppColors.darkTextSecondary),
    titleLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: AppColors.darkTextPrimary,
      fontWeight: FontWeight.w600,
    ),
  ),
  dialogTheme: const DialogThemeData(backgroundColor: AppColors.darkSurface),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.darkSurface,
  ),
  popupMenuTheme: const PopupMenuThemeData(color: AppColors.darkSurface),
);

// Alias for code that still imports `appTheme`.
final ThemeData appTheme = lightTheme;
