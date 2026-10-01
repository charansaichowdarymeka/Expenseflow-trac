import 'package:flutter/material.dart';

class AppColors {
  final Color primary;
  final Color primarySoft;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color secondary;
  final Color placeholder;

  const AppColors({
    required this.primary,
    required this.primarySoft,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.background,
    required this.card,
    required this.border,
    required this.text,
    required this.secondary,
    required this.placeholder,
  });
}

const AppColors kLightColors = AppColors(
  primary: Color(0xFF2563EB),
  primarySoft: Color(0xFFDBEAFE),
  income: Color(0xFF22C55E),
  incomeSoft: Color(0xFFDCFCE7),
  expense: Color(0xFFEF4444),
  expenseSoft: Color(0xFFFEE2E2),
  background: Color(0xFFF8FAFC),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFE5E7EB),
  text: Color(0xFF111827),
  secondary: Color(0xFF6B7280),
  placeholder: Color(0xFF9CA3AF),
);

const AppColors kDarkColors = AppColors(
  primary: Color(0xFF60A5FA),
  primarySoft: Color(0xFF1E3A8A),
  income: Color(0xFF34D399),
  incomeSoft: Color(0xFF064E3B),
  expense: Color(0xFFF87171),
  expenseSoft: Color(0xFF7F1D1D),
  background: Color(0xFF07111F),
  card: Color(0xFF111C2E),
  border: Color(0xFF1F2937),
  text: Color(0xFFF3F8FF),
  secondary: Color(0xFF94A3B8),
  placeholder: Color(0xFF64748B),
);

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double full = 999;
}

ThemeData buildAppTheme(AppColors colors, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    primaryColor: colors.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      surface: colors.card,
    ),
    cardColor: colors.card,
    dividerColor: colors.border,
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: colors.text),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.text),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.text),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: colors.text),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: colors.secondary),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: colors.secondary),
    ),
  );
}
