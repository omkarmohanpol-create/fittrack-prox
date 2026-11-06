import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4F46E5);
  static const secondary = Color(0xFF8B5CF6);
  static const accent = Color(0xFFEC4899);

  static const background = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceElevated = Color(0xFF334155);
  static const border = Color(0xFF334155);

  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);

  static const workouts = primary;
  static const calories = Color(0xFFF59E0B);
  static const water = Color(0xFF06B6D4);
  static const steps = Color(0xFF10B981);
  static const cardio = accent;

  static const gradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.background : const Color(0xFFF8FAFC);
    final surface = dark ? AppColors.surface : Colors.white;
    final onSurface = dark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final border = dark ? AppColors.border : const Color(0xFFE2E8F0);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: surface,
      onSurface: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      cardColor: surface,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardBg => Theme.of(this).cardColor;
  Color get borderColor => Theme.of(this).dividerColor;
  Color get muted =>
      isDark ? AppColors.textSecondary : const Color(0xFF64748B);
  Color get faint =>
      isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);
}
