import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';

/// Centralized class for defining and managing the application's light and dark themes
/// based on the Material 3 design system and a single brand seed color.
class AppTheme {
  /// The primary color used as the seed for generating the entire color scheme.
  static final Color _seedColor = Constants.primaryColor;

  /// Generates the complete Light ThemeData configuration.
  ///
  /// This includes a custom ColorScheme, and tailored styles for AppBar, Card,
  /// Buttons, and Input Fields.
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

      /// Customizing card appearance with elevation, margin, and border radius.
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

      /// Adjusting text styles for better readability and hierarchy.
      textTheme: base.textTheme.copyWith(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface.withOpacity(0.85)),
        headlineSmall: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      /// Customizing text field appearance with borders and fill color.
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

      /// Defining the default style for primary elevated buttons.
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

      /// Defining the default style for secondary outlined buttons.
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

      /// Styling for the application's bottom navigation bar.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        elevation: 8,
      ),

      /// Styling for the main Floating Action Button.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      /// Customizing the appearance of dividers.
      dividerTheme: DividerThemeData(
        color: Constants.lightDivider,
        thickness: 0.8,
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  /// Generates the complete Dark ThemeData configuration.
  ///
  /// This includes a custom ColorScheme, and tailored styles for AppBar, Card,
  /// Buttons, and Input Fields, optimized for dark backgrounds.
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

      /// Customizing card appearance with elevation, margin, and border radius.
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

      /// Adjusting text styles for better readability and hierarchy in dark mode.
      textTheme: base.textTheme.copyWith(
        bodyLarge: TextStyle(color: colorScheme.onSurface.withOpacity(0.9)),
        bodyMedium: TextStyle(color: colorScheme.onSurface.withOpacity(0.75)),
        headlineSmall: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      /// Customizing text field appearance with borders and fill color.
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

      /// Defining the default style for primary elevated buttons.
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

      /// Defining the default style for secondary outlined buttons.
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

      /// Styling for the application's bottom navigation bar.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        elevation: 8,
      ),

      /// Styling for the main Floating Action Button.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      /// Customizing the appearance of dividers.
      dividerTheme: DividerThemeData(
        color: Constants.darkDivider,
        thickness: 0.8,
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  /// Sets the system status bar style to light icons on a dark background.
  ///
  /// This is typically used for full-screen media or Reels content to ensure
  /// status bar visibility against a black background.
  static void setStatusBarForReels() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  /// Restores the system status bar style to match the current application theme's brightness.
  ///
  /// This reverts any temporary system overlay changes (like those made for Reels).
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
