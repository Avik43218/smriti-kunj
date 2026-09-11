import 'package:flutter/material.dart';

class AppColors {
  static const cream          = Color(0xFFFBF5EA);
  static const surface        = Color(0xFFFFFDF8);
  static const ink            = Color(0xFF2E2A24);
  static const inkSoft        = Color(0xFF6B625A);
  static const terracotta     = Color(0xFFB5562F);
  static const terracottaDark = Color(0xFF8C3F20);
  static const mugaGold       = Color(0xFFC9962C);
  static const sageGreen      = Color(0xFF6E8C6A);
  static const alertRed       = Color(0xFFC1272D); // SOS only — do not reuse elsewhere
  static const border         = Color(0xFFE4D9C4);
}

final ThemeData patientTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.terracotta,
    brightness: Brightness.light,
    primary: AppColors.terracotta,
    secondary: AppColors.mugaGold,
    surface: AppColors.surface,
    error: AppColors.alertRed,
  ),
  fontFamily: 'NotoSans',
  fontFamilyFallback: const ['NotoSansBengali', 'NotoSansDevanagari'],
  textTheme: const TextTheme(
    displayLarge:   TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.ink),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.35, color: AppColors.ink),
    bodyLarge:      TextStyle(fontSize: 22, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.ink),
    bodyMedium:     TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.ink),
    labelLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w500, height: 1.2, color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.terracotta,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 88),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      elevation: 2,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 3,
    shadowColor: AppColors.ink.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.all(12),
  ),
);