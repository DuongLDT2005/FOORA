import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Ngăn việc khởi tạo class này

  // Primary
  static const Color primary = Color(0xFF0F5238);
  static const Color primaryHover = Color(0xFF0B3D29);
  static const Color primaryContainer = Color(0xFF2D6A4F);
  static const Color onPrimaryContainer = Color(0xFFA8E7C5);
  static const Color primaryFixed = Color(0xFFB1F0CE);
  static const Color primaryFixedDim = Color(0xFF95D4B3);
  static const Color onPrimaryFixedVariant = Color(0xFF0E5138);

  // Secondary
  static const Color secondary = Color(0xFF5F5F50);
  static const Color secondaryContainer = Color(0xFFE4E4CF);
  static const Color onSecondaryContainer = Color(0xFF656555);
  static const Color secondaryFixed = Color(0xFFE4E4CF);
  static const Color secondaryFixedDim = Color(0xFFC8C8B4);

  // Tertiary
  static const Color tertiary = Color(0xFF4A4839);
  static const Color tertiaryContainer = Color(0xFF635F50);
  static const Color onTertiaryContainer = Color(0xFFDFDAC6);
  static const Color tertiaryFixed = Color(0xFFE8E2CF);
  static const Color tertiaryFixedDim = Color(0xFFCCC6B3);

  // Background & Surface
  static const Color background = Color(0xFFF4FBF6);
  static const Color onBackground = Color(0xFF002114);
  static const Color surface = Color(0xFFE8FFF0);
  static const Color onSurface = Color(0xFF002114);
  static const Color onSurfaceVariant = Color(0xFF404943);

  static const Color surfaceContainer = Color(0xFFCCF8DF);
  static const Color surfaceContainerLow = Color(0xFFD1FEE5);
  static const Color surfaceContainerHigh = Color(0xFFC6F2DA);
  static const Color surfaceContainerHighest = Color(0xFFC1ECD4);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  // Màu phụ trợ thường dùng trong app (tương tự Tailwind slate, amber, red...)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A); // Dark mode background

  static const Color amber500 = Color(0xFFF59E0B);
  static const Color red500 = Color(0xFFEF4444);
  static const Color blue500 = Color(0xFF3B82F6);
}
