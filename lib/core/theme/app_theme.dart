import 'package:flutter/material.dart';

/// App theme configuration for Relay
/// Provides light and dark themes with a modern, professional design
class AppTheme {
  // Primary brand colors - Orange/Amber for a modern, energetic feel
  static const Color _primaryLight = Color(0xFFF97316); // Orange-500
  static const Color _primaryDark = Color(0xFFFB923C); // Orange-400

  // Surface colors
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF1E1E1E);
  static const Color _surfaceVariantLight = Color(0xFFF5F5F5);
  static const Color _surfaceVariantDark = Color(0xFF2D2D2D);

  // Text colors
  static const Color _onSurfaceLight = Color(0xFF1A1A1A);
  static const Color _onSurfaceDark = Color(0xFFE5E5E5);
  static const Color _onSurfaceVariantLight = Color(0xFF6B6B6B);
  static const Color _onSurfaceVariantDark = Color(0xFFB0B0B0);

  // Error colors
  static const Color _errorLight = Color(0xFFDC2626);
  static const Color _errorDark = Color(0xFFEF4444);

  // Success colors
  static const Color _successLight = Color(0xFF16A34A);
  static const Color _successDark = Color(0xFF22C55E);

  // Warning colors
  static const Color _warningLight = Color(0xFFF59E0B);
  static const Color _warningDark = Color(0xFFFBBF24);

  // Border colors
  static const Color _outlineLight = Color(0xFFE5E5E5);
  static const Color _outlineDark = Color(0xFF404040);

  /// Light theme configuration
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: _primaryLight,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE4CC),
      onPrimaryContainer: const Color(0xFF7C2D00),
      secondary: const Color(0xFF6366F1), // Indigo
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0E7FF),
      onSecondaryContainer: const Color(0xFF1E1B4B),
      tertiary: const Color(0xFF10B981), // Emerald
      onTertiary: Colors.white,
      error: _errorLight,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: _surfaceLight,
      onSurface: _onSurfaceLight,
      surfaceContainerHighest: _surfaceVariantLight,
      onSurfaceVariant: _onSurfaceVariantLight,
      outline: _outlineLight,
      outlineVariant: const Color(0xFFF5F5F5),
      shadow: Colors.black.withOpacity(0.1),
      scrim: Colors.black.withOpacity(0.5),
      inverseSurface: _onSurfaceLight,
      onInverseSurface: _surfaceLight,
      inversePrimary: _primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _surfaceLight,
        foregroundColor: _onSurfaceLight,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _onSurfaceLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(
          color: _onSurfaceLight,
          size: 24,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _outlineLight, width: 1),
        ),
        color: _surfaceLight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Elevated button theme (slightly more compact)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: _primaryLight,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text button theme (slightly more compact)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundColor: _primaryLight,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined button theme (slightly more compact)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(color: _primaryLight, width: 1.5),
          foregroundColor: _primaryLight,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: _primaryLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _outlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorLight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorLight, width: 2),
        ),
        labelStyle: TextStyle(
          color: _onSurfaceVariantLight,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: _onSurfaceVariantLight.withOpacity(0.6),
          fontSize: 14,
        ),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: _surfaceLight,
        titleTextStyle: TextStyle(
          color: _onSurfaceLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: _onSurfaceVariantLight,
          fontSize: 14,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariantLight,
        deleteIconColor: _onSurfaceVariantLight,
        disabledColor: _surfaceVariantLight.withOpacity(0.5),
        selectedColor: _primaryLight,
        secondarySelectedColor: _primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(
          color: _onSurfaceLight,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: _outlineLight,
        thickness: 1,
        space: 1,
      ),

      // Menu theme (dropdown menus)
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(_surfaceLight),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // Icon theme
      iconTheme: IconThemeData(
        color: _onSurfaceVariantLight,
        size: 24,
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: _onSurfaceLight,
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          color: _onSurfaceLight,
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        displaySmall: TextStyle(
          color: _onSurfaceLight,
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          color: _onSurfaceLight,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: _onSurfaceLight,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          color: _onSurfaceLight,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: _onSurfaceLight,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: _onSurfaceLight,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          color: _onSurfaceLight,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          color: _onSurfaceLight,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: _onSurfaceLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          color: _onSurfaceVariantLight,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          color: _onSurfaceLight,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          color: _onSurfaceLight,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          color: _onSurfaceVariantLight,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primaryDark,
      onPrimary: const Color(0xFF4C1D00),
      primaryContainer: const Color(0xFF7C2D00),
      onPrimaryContainer: const Color(0xFFFFE4CC),
      secondary: const Color(0xFF818CF8), // Indigo-400
      onSecondary: const Color(0xFF1E1B4B),
      secondaryContainer: const Color(0xFF312E81),
      onSecondaryContainer: const Color(0xFFE0E7FF),
      tertiary: const Color(0xFF34D399), // Emerald-400
      onTertiary: const Color(0xFF064E3B),
      error: _errorDark,
      onError: const Color(0xFF7F1D1D),
      errorContainer: const Color(0xFF991B1B),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: _surfaceDark,
      onSurface: _onSurfaceDark,
      surfaceContainerHighest: _surfaceVariantDark,
      onSurfaceVariant: _onSurfaceVariantDark,
      outline: _outlineDark,
      outlineVariant: const Color(0xFF404040),
      shadow: Colors.black.withOpacity(0.3),
      scrim: Colors.black.withOpacity(0.7),
      inverseSurface: _onSurfaceDark,
      onInverseSurface: _surfaceDark,
      inversePrimary: _primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _surfaceDark,
        foregroundColor: _onSurfaceDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _onSurfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(
          color: _onSurfaceDark,
          size: 24,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _outlineDark, width: 1),
        ),
        color: _surfaceVariantDark,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: _primaryDark,
          foregroundColor: const Color(0xFF4C1D00),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundColor: _primaryDark,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(color: _primaryDark, width: 1.5),
          foregroundColor: _primaryDark,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: _primaryDark,
        foregroundColor: const Color(0xFF4C1D00),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _outlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _outlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorDark),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorDark, width: 2),
        ),
        labelStyle: TextStyle(
          color: _onSurfaceVariantDark,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: _onSurfaceVariantDark.withOpacity(0.6),
          fontSize: 14,
        ),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: _surfaceVariantDark,
        titleTextStyle: TextStyle(
          color: _onSurfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: _onSurfaceVariantDark,
          fontSize: 14,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceDark,
        deleteIconColor: _onSurfaceVariantDark,
        disabledColor: _surfaceDark.withOpacity(0.5),
        selectedColor: _primaryDark,
        secondarySelectedColor: _primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(
          color: _onSurfaceDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Color(0xFF4C1D00),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: _outlineDark,
        thickness: 1,
        space: 1,
      ),

      // Menu theme (dropdown menus)
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(_surfaceVariantDark),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // Icon theme
      iconTheme: IconThemeData(
        color: _onSurfaceVariantDark,
        size: 24,
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: _onSurfaceDark,
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          color: _onSurfaceDark,
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        displaySmall: TextStyle(
          color: _onSurfaceDark,
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          color: _onSurfaceDark,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: _onSurfaceDark,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          color: _onSurfaceDark,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: _onSurfaceDark,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: _onSurfaceDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          color: _onSurfaceDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          color: _onSurfaceDark,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: _onSurfaceDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          color: _onSurfaceVariantDark,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          color: _onSurfaceDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          color: _onSurfaceDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          color: _onSurfaceVariantDark,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Helper methods for custom colors
  static Color get successLight => _successLight;
  static Color get successDark => _successDark;
  static Color get warningLight => _warningLight;
  static Color get warningDark => _warningDark;
  static Color get errorLight => _errorLight;
  static Color get errorDark => _errorDark;
}

