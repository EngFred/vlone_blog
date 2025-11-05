// lib/core/presentation/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';

/// Centralized class for managing light and dark themes using Material 3.
class AppTheme {
  // Use a single seed color for brand consistency across both themes.
  static final Color _seedColor = Constants.primaryColor;

  /// Light Theme
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      background: Constants.lightSurfaceVariant,
      surface: Constants.lightSurface,
      error: Constants.errorColor,
      onPrimary: Colors.white,
      onSurface: Constants.lightOnSurface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: colorScheme.background,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 4,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Use CardThemeData (Material 3) to match ThemeData API
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        margin: const EdgeInsets.symmetric(
          horizontal: Constants.spacingMD,
          vertical: Constants.spacingSM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Constants.radiusMedium),
        ),
      ),

      textTheme: base.textTheme.copyWith(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface.withOpacity(0.85)),
        headlineSmall: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Constants.radiusMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Constants.radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        fillColor: colorScheme.surfaceVariant.withOpacity(0.6),
        filled: true,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.radiusMedium),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.radiusMedium),
          ),
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        elevation: 8,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: Constants.lightDivider,
        thickness: 0.8,
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  /// Dark Theme
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      background: Constants.darkSurface,
      surface: Constants.darkSurfaceAlt,
      error: Constants.errorColor,
      onPrimary: Colors.black,
      onSurface: Constants.darkOnSurface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: colorScheme.background,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 4,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // Use CardThemeData here as well
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        margin: const EdgeInsets.symmetric(
          horizontal: Constants.spacingMD,
          vertical: Constants.spacingSM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Constants.radiusMedium),
        ),
      ),

      textTheme: base.textTheme.copyWith(
        bodyLarge: TextStyle(color: colorScheme.onSurface.withOpacity(0.9)),
        bodyMedium: TextStyle(color: colorScheme.onSurface.withOpacity(0.75)),
        headlineSmall: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Constants.radiusMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Constants.radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        fillColor: colorScheme.surfaceVariant,
        filled: true,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.radiusMedium),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.radiusMedium),
          ),
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        elevation: 8,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: Constants.darkDivider,
        thickness: 0.8,
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  /// Helper for Reels / fullscreen black backgrounds
  static void setStatusBarForReels() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  /// Restore default status bar style based on current theme brightness
  static void restoreDefaultStatusBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }
}
