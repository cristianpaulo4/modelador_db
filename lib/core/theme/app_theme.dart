import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightCanvasBackground,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF0EA5E9),
        surface: AppColors.lightTableCard,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightGridLine,
      ),
      canvasColor: AppColors.lightTableCard,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
        bodySmall: TextStyle(color: AppColors.lightTextPrimary),
        titleLarge: TextStyle(color: AppColors.lightTextPrimary),
        titleMedium: TextStyle(color: AppColors.lightTextPrimary),
        titleSmall: TextStyle(color: AppColors.lightTextPrimary),
        labelLarge: TextStyle(color: AppColors.lightTextPrimary),
        labelMedium: TextStyle(color: AppColors.lightTextPrimary),
        labelSmall: TextStyle(color: AppColors.lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightTableCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkCanvasBackground,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF60A5FA),
        secondary: Color(0xFF38BDF8),
        surface: AppColors.darkTableCard,
        onSurface: AppColors.darkTextPrimary,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkGridLine,
      ),
      canvasColor: AppColors.darkTableCard,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
        bodySmall: TextStyle(color: AppColors.darkTextPrimary),
        titleLarge: TextStyle(color: AppColors.darkTextPrimary),
        titleMedium: TextStyle(color: AppColors.darkTextPrimary),
        titleSmall: TextStyle(color: AppColors.darkTextPrimary),
        labelLarge: TextStyle(color: AppColors.darkTextPrimary),
        labelMedium: TextStyle(color: AppColors.darkTextPrimary),
        labelSmall: TextStyle(color: AppColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkTableCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252830),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
        ),
      ),
    );
  }
}
