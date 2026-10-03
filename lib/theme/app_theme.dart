import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const maroon = Color(0xFF800000);
  static const maroonDark = Color(0xFF5C0000);
  static const maroonLight = Color(0xFFF5E6E6);

  static const gold = Color(0xFFD4AF37);

  // Semantic
  static const danger = Color(0xFFB3261E);
  static const success = Color(0xFF2E7D32);

  // Light
  static const lightBackground = Color(0xFFF8F6F3);
  static const lightSurface = Colors.white;
  static const lightSurfaceAlt = Color(0xFFFAFAFA);
  static const lightBorder = Color(0xFFE0E0E0);

  static const lightTextPrimary = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF6B6B6B);
  static const lightTextTertiary = Color(0xFF9E9E9E);

  // Dark
  static const darkBackground = Color(0xFF100E0F);
  static const darkSurface = Color(0xFF191617);
  static const darkSurfaceAlt = Color(0xFF211D1E);
  static const darkElevated = Color(0xFF292324);
  static const darkBorder = Color(0xFF3A3032);

  static const darkTextPrimary = Color(0xFFF7F1F2);
  static const darkTextSecondary = Color(0xFFC8BEC0);
  static const darkTextTertiary = Color(0xFF95888B);

  // Strong enough to work as a button background with white text.
  static const maroonOnDark = Color(0xFFB93643);

  // Soft maroon surface for selected tabs/chips/navigation.
  static const maroonLightOnDark = Color(0xFF35191D);

  // Semantic dark-mode colors
  static const successOnDark = Color(0xFF81C784);
  static const dangerTextOnDark = Color(0xFFFFB4AB);

  static const background = lightBackground;
  static const surface = lightSurface;

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

  static Color brandOf(BuildContext context) =>
      _isDark(context) ? maroonOnDark : maroon;

  static Color brandSoftOf(BuildContext context) =>
      _isDark(context) ? maroonLightOnDark : maroonLight;

  static Color successOf(BuildContext context) =>
      _isDark(context) ? successOnDark : success;

  static Color dangerTextOf(BuildContext context) =>
      _isDark(context) ? dangerTextOnDark : danger;

  static Color shadowOf(BuildContext context) => _isDark(context)
      ? Colors.black.withValues(alpha: 0.50)
      : Colors.black.withValues(alpha: 0.06);
}

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
  ),

  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 1,
    shadowColor: Colors.black.withValues(alpha: 0.08),
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
      minimumSize: const Size(48, 48),
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

  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: AppColors.lightSurface,
    indicatorColor: AppColors.maroonLight,
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurface,
    selectedItemColor: AppColors.maroon,
    unselectedItemColor: AppColors.lightTextTertiary,
    showUnselectedLabels: true,
  ),

  chipTheme: ChipThemeData(
    backgroundColor: AppColors.lightSurfaceAlt,
    selectedColor: AppColors.maroonLight,
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
    error: AppColors.dangerTextOnDark,
    onError: Color(0xFF690005),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.maroonDark,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
  ),

  cardTheme: CardThemeData(
    color: AppColors.darkSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.black,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.darkBorder, width: 0.7),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurfaceAlt,
    prefixIconColor: AppColors.darkTextSecondary,
    suffixIconColor: AppColors.darkTextSecondary,
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
      borderSide: const BorderSide(color: AppColors.maroonOnDark, width: 1.7),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.dangerTextOnDark),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AppColors.dangerTextOnDark,
        width: 1.7,
      ),
    ),
    labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
    hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.maroonOnDark,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.darkElevated,
      disabledForegroundColor: AppColors.darkTextTertiary,
      minimumSize: const Size(48, 48),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.darkTextPrimary,
      side: const BorderSide(color: AppColors.darkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.dangerTextOnDark,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),

  iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),

  listTileTheme: const ListTileThemeData(
    iconColor: AppColors.darkTextSecondary,
    textColor: AppColors.darkTextPrimary,
  ),

  dividerTheme: const DividerThemeData(
    color: AppColors.darkBorder,
    thickness: 1,
    space: 1,
  ),

  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.darkElevated,
    contentTextStyle: TextStyle(color: AppColors.darkTextPrimary),
  ),

  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    indicatorColor: AppColors.maroonLightOnDark,
    surfaceTintColor: Colors.transparent,
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    selectedItemColor: AppColors.maroonOnDark,
    unselectedItemColor: AppColors.darkTextTertiary,
    showUnselectedLabels: true,
  ),

  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkSurfaceAlt,
    selectedColor: AppColors.maroonLightOnDark,
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

  dialogTheme: const DialogThemeData(
    backgroundColor: AppColors.darkSurface,
    surfaceTintColor: Colors.transparent,
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.darkSurface,
    surfaceTintColor: Colors.transparent,
  ),

  popupMenuTheme: const PopupMenuThemeData(
    color: AppColors.darkElevated,
    surfaceTintColor: Colors.transparent,
  ),
);

final ThemeData appTheme = lightTheme;
