import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';
import 'role_theme.dart';

abstract class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final typography = AppTypography(colors);
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      error: colors.danger,
      onError: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: colors.surfaceRaised,
      focusColor: colors.accent.withValues(alpha: 0.4),
      dividerColor: colors.border,
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(cursorColor: colors.accent, selectionColor: colors.accent.withValues(alpha: 0.3)),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 16),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: colors.borderStrong),
        ),
        textStyle: typography.caption.copyWith(color: colors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.borderStrong),
        radius: const Radius.circular(AppRadius.sm),
        thickness: const WidgetStatePropertyAll(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: BorderSide(color: colors.accent),
        ),
        hintStyle: typography.body.copyWith(color: colors.textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: typography.title,
        contentTextStyle: typography.body,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
          side: BorderSide(color: colors.border),
        ),
        textStyle: typography.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: typography.body,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
          side: BorderSide(color: colors.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: TextTheme(titleMedium: typography.title, bodyMedium: typography.body, labelMedium: typography.label, bodySmall: typography.caption),
      extensions: [RoleThemeExtension(colors: colors, typography: typography)],
    );
  }
}
