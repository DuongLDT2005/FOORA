import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // General Material Light color scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        error: AppColors.red500,
        onError: Colors.white,
        surface: AppColors.background,
        onSurface: AppColors.onBackground,
      ),

      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.fontFamilySans,

      // Attach TextTheme for Light Mode
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ).apply(bodyColor: AppColors.slate800, displayColor: AppColors.slate800),

      // AppBar Light Mode
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineSmall.copyWith(
          color: Colors.white,
        ),
      ),

      // Elevated Button Light Mode
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.slate100,
          disabledForegroundColor: AppColors.slate400,
          textStyle: AppTextStyles.buttonPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),

      // Outlined Button Light Mode
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.slate100,
          foregroundColor: AppColors.slate600,
          side: const BorderSide(color: AppColors.slate100),
          textStyle: AppTextStyles.buttonPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),

      // Card Light Mode
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.slate100),
        ),
        margin: EdgeInsets.zero,
      ),

      // TextField Light Mode
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.slate100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.slate100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        labelStyle: AppTextStyles.inputLabel.copyWith(
          color: AppColors.slate400,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.slate400,
          fontWeight: FontWeight.normal,
        ),
      ),

      // Divider Light Mode
      dividerTheme: const DividerThemeData(
        color: AppColors.slate100,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,

      // General Material Dark color scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        error: AppColors.red500,
        onError: Colors.white,
        surface: AppColors.slate900,
        onSurface: AppColors.slate50,
      ),

      scaffoldBackgroundColor: AppColors.slate900,
      fontFamily: AppTextStyles.fontFamilySans,

      // Attach TextTheme for Dark Mode
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ).apply(bodyColor: AppColors.slate50, displayColor: AppColors.slate50),

      // AppBar Dark Mode
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineSmall.copyWith(
          color: Colors.white,
        ),
      ),

      // Elevated Button Dark Mode
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.slate800,
          disabledForegroundColor: AppColors.slate500,
          textStyle: AppTextStyles.buttonPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),

      // Outlined Button Dark Mode
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.slate800,
          foregroundColor: AppColors.slate50,
          side: const BorderSide(color: AppColors.slate700),
          textStyle: AppTextStyles.buttonPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),

      // Card Dark Mode (Surface slate800, border slate700)
      cardTheme: CardThemeData(
        color: AppColors.slate800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.slate700),
        ),
        margin: EdgeInsets.zero,
      ),

      // TextField Dark Mode
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.slate700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.slate700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        labelStyle: AppTextStyles.inputLabel.copyWith(
          color: AppColors.slate400,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.slate500,
          fontWeight: FontWeight.normal,
        ),
      ),

      // Divider Dark Mode
      dividerTheme: const DividerThemeData(
        color: AppColors.slate800,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
