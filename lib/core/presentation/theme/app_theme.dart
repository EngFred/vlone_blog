import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';

/// Centralized class for managing light and dark themes using Material 3.
class AppTheme {
  // Use a single seed color for brand consistency across both themes.
  static final Color _seedColor = Constants.primaryColor;

  /// Defines the Light Theme
  static ThemeData lightTheme() {
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData.light().copyWith(
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: lightColorScheme.surface,

      // --- Status Bar Configuration for Light Theme ---
      appBarTheme: AppBarTheme(
        backgroundColor: lightColorScheme.surface,
        foregroundColor: lightColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 4,
        centerTitle: false,
        // IMPORTANT: This makes status bar icons dark in light theme
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.dark, // Dark icons for light background
          statusBarBrightness: Brightness.light, // iOS specific
        ),
      ),

      textTheme: TextTheme(
        bodyLarge: TextStyle(color: lightColorScheme.onSurface),
        bodyMedium: TextStyle(
          color: lightColorScheme.onSurface.withOpacity(0.8),
        ),
        headlineMedium: TextStyle(
          color: lightColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
        ),
        fillColor: lightColorScheme.surfaceContainerHighest.withOpacity(0.2),
        filled: true,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightColorScheme.surface,
        selectedItemColor: lightColorScheme.primary,
        unselectedItemColor: lightColorScheme.onSurfaceVariant,
        showUnselectedLabels: true,
      ),
    );
  }

  /// Defines the Dark Theme
  static ThemeData darkTheme() {
    final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      background: Colors.grey[900]!,
      surface: Colors.grey[850]!,
      surfaceContainer: Colors.grey[800]!,
    );

    return ThemeData.dark().copyWith(
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: darkColorScheme.surface,

      // --- Status Bar Configuration for Dark Theme ---
      appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.surface,
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 4,
        centerTitle: false,
        // IMPORTANT: This makes status bar icons light in dark theme
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.light, // Light icons for dark background
          statusBarBrightness: Brightness.dark, // iOS specific
        ),
      ),

      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: darkColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: darkColorScheme.onSurface.withOpacity(0.85),
        ),
        bodyMedium: TextStyle(
          color: darkColorScheme.onSurface.withOpacity(0.7),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkColorScheme.primary, width: 2),
        ),
        fillColor: darkColorScheme.surfaceContainer,
        filled: true,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: darkColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Helper method to set status bar style for special pages (like Reels with black background)
  static void setStatusBarForReels() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.light, // Always light icons on black
        statusBarBrightness: Brightness.dark, // iOS
      ),
    );
  }

  /// Helper method to restore default status bar style based on theme
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
