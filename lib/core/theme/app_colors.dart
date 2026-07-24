import 'package:flutter/material.dart';

abstract class AppColors {
  // Light Mode Colors
  static const Color lightCanvasBackground = Color(0xFFFFFFFF);
  static const Color lightOuterBackground = Color(0xFFE9ECEF);
  static const Color lightGridLine = Color(0xFFE2E8F0);
  static const Color lightTableHeader = Color(0xFFEDF2F7);
  static const Color lightTableCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Mode Colors
  static const Color darkCanvasBackground = Color(0xFF1A1A1A);
  static const Color darkOuterBackground = Color(0xFF0D0D0D);
  static const Color darkGridLine = Color(0xFF23272E);
  static const Color darkTableHeader = Color(0xFF1E222A);
  static const Color darkTableCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF3A3F4B);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Key & Attribute Accents
  static const Color primaryKeyGold = Color(0xFFFFB703);
  static const Color foreignKeyCyan = Color(0xFF00E5FF);
  static const Color uniquePurple = Color(0xFFB5179E);
  static const Color autoIncrementGreen = Color(0xFF10B981);
  static const Color notNullRed = Color(0xFFEF4444);

  // Connection Lines
  static const Color lightLine = Color(0xFF2563EB);
  static const Color darkLine = Color(0xFF60A5FA);
  static const Color selectedLine = Color(0xFFF59E0B);
}
