import 'package:flutter/material.dart';

/// UM Campus Marketplace brand colors, matched to the official
/// University of Mindanao Student Portal (maroon + gold).
class AppColors {
  AppColors._();

  // Primary brand maroon — used for AppBars, buttons, selected states.
  static const Color maroon = Color(0xFF8B1D2E);
  static const Color maroonDark = Color(0xFF6E1523);
  static const Color maroonLight = Color(0xFFF3DDE1);

  // Accent gold — used sparingly for highlights (FAB, badges, icons).
  static const Color gold = Color(0xFFF5A623);

  // Neutral background matching the portal's light grey page background.
  static const Color background = Color(0xFFF1F1F1);

  // Semantic colors — kept separate from brand colors on purpose.
  // Price/available = green, sold/delete = red. These carry meaning
  // (success/danger) rather than brand identity, so they stay as-is
  // even though the brand color is also a shade of red.
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
}

/// Shared ThemeData for the whole app. Import this in main.dart and pass
/// it to MaterialApp(theme: appTheme).
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,

  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.maroon,
    primary: AppColors.maroon,
    secondary: AppColors.gold,
    brightness: Brightness.light,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.maroon,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.white),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.maroon,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.maroon,
      side: const BorderSide(color: AppColors.maroon),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.gold,
    foregroundColor: Colors.black87,
  ),

  chipTheme: ChipThemeData(
    backgroundColor: Colors.grey[200],
    selectedColor: AppColors.maroon,
    labelStyle: const TextStyle(color: Colors.black87),
    secondaryLabelStyle: const TextStyle(color: Colors.white),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.maroon, width: 2),
    ),
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: AppColors.maroon,
    unselectedItemColor: Colors.grey,
    showUnselectedLabels: true,
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.maroon,
  ),
);
