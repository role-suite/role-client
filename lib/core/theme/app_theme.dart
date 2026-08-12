import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.brandLight,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE2CB),
      onPrimaryContainer: const Color(0xFF612A00),
      secondary: AppColors.accentLight,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFDCEAFE),
      onSecondaryContainer: const Color(0xFF102A56),
      tertiary: AppColors.successLight,
      onTertiary: Colors.white,
      error: AppColors.errorLight,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textLight,
      surfaceContainerLow: AppColors.panelAltLight,
      surfaceContainerHighest: AppColors.panelAltLight,
      onSurfaceVariant: AppColors.textMutedLight,
      outline: AppColors.borderLight,
      outlineVariant: const Color(0xFFE5EBF1),
      shadow: Colors.black.withValues(alpha: 0.08),
      scrim: Colors.black.withValues(alpha: 0.45),
      inverseSurface: AppColors.textLight,
      onInverseSurface: AppColors.surfaceLight,
      inversePrimary: AppColors.brandDark,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      surfaceColor: AppColors.surfaceLight,
      panelColor: AppColors.panelLight,
      panelAltColor: AppColors.panelAltLight,
      textColor: AppColors.textLight,
      mutedTextColor: AppColors.textMutedLight,
      borderColor: AppColors.borderLight,
      editorColor: AppColors.editorLight,
      textTheme: AppTextStyles.light(),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.brandDark,
      onPrimary: const Color(0xFF472000),
      primaryContainer: const Color(0xFF6F3300),
      onPrimaryContainer: const Color(0xFFFFE2CB),
      secondary: AppColors.accentDark,
      onSecondary: const Color(0xFF0B2348),
      secondaryContainer: const Color(0xFF153B73),
      onSecondaryContainer: const Color(0xFFDCEAFE),
      tertiary: AppColors.successDark,
      onTertiary: const Color(0xFF063B1D),
      error: AppColors.errorDark,
      onError: const Color(0xFF5F1111),
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      surfaceContainerLow: AppColors.panelDark,
      surfaceContainerHighest: AppColors.panelAltDark,
      onSurfaceVariant: AppColors.textMutedDark,
      outline: AppColors.borderDark,
      outlineVariant: const Color(0xFF334155),
      shadow: Colors.black.withValues(alpha: 0.35),
      scrim: Colors.black.withValues(alpha: 0.65),
      inverseSurface: AppColors.textDark,
      onInverseSurface: AppColors.surfaceDark,
      inversePrimary: AppColors.brandLight,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      surfaceColor: AppColors.surfaceDark,
      panelColor: AppColors.panelDark,
      panelAltColor: AppColors.panelAltDark,
      textColor: AppColors.textDark,
      mutedTextColor: AppColors.textMutedDark,
      borderColor: AppColors.borderDark,
      editorColor: AppColors.editorDark,
      textTheme: AppTextStyles.dark(),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color surfaceColor,
    required Color panelColor,
    required Color panelAltColor,
    required Color textColor,
    required Color mutedTextColor,
    required Color borderColor,
    required Color editorColor,
    required TextTheme textTheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceColor,
      canvasColor: panelColor,
      cardColor: panelColor,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: panelAltColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: mutedTextColor, size: 20),
        actionsIconTheme: IconThemeData(color: mutedTextColor, size: 20),
      ),
      cardTheme: CardThemeData(
        elevation: AppTokens.panelElevation,
        color: panelColor,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: borderColor, width: AppTokens.borderWidth),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: mutedTextColor, size: 20),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, AppTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: AppTokens.borderWidth),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTokens.compactControlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panelAltColor,
        disabledColor: panelAltColor.withValues(alpha: 0.55),
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        deleteIconColor: mutedTextColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium!.copyWith(color: textColor),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(color: colorScheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: borderColor, width: AppTokens.borderWidth),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: AppTokens.dialogElevation,
        backgroundColor: panelColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: editorColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: textTheme.bodySmall?.copyWith(color: mutedTextColor),
        hintStyle: textTheme.bodySmall?.copyWith(color: mutedTextColor.withValues(alpha: 0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: borderColor, width: AppTokens.borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: borderColor, width: AppTokens.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: AppTokens.focusBorderWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: AppTokens.borderWidth),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: AppTokens.focusBorderWidth),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(panelColor),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              side: BorderSide(color: borderColor, width: AppTokens.borderWidth),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panelAltColor,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected) ? colorScheme.onPrimaryContainer : mutedTextColor,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colorScheme.onPrimaryContainer : mutedTextColor,
            size: 20,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: panelAltColor,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: panelAltColor,
      ),
    );
  }

  static Color get successLight => AppColors.successLight;
  static Color get successDark => AppColors.successDark;
  static Color get warningLight => AppColors.warningLight;
  static Color get warningDark => AppColors.warningDark;
  static Color get errorLight => AppColors.errorLight;
  static Color get errorDark => AppColors.errorDark;
}
