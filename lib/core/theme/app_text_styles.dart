import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextTheme light() {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 52, fontWeight: FontWeight.w500, letterSpacing: -0.3, color: AppColors.textLight),
      displayMedium: TextStyle(fontSize: 42, fontWeight: FontWeight.w500, color: AppColors.textLight),
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: AppColors.textLight),
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.textLight),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textLight),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textLight),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textLight),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: AppColors.textLight),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: AppColors.textLight),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: AppColors.textLight),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: AppColors.textLight),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2, color: AppColors.textMutedLight),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.15, color: AppColors.textLight),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: AppColors.textLight),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.25, color: AppColors.textMutedLight),
    );
  }

  static TextTheme dark() {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 52, fontWeight: FontWeight.w500, letterSpacing: -0.3, color: AppColors.textDark),
      displayMedium: TextStyle(fontSize: 42, fontWeight: FontWeight.w500, color: AppColors.textDark),
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: AppColors.textDark),
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.textDark),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: AppColors.textDark),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: AppColors.textDark),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: AppColors.textDark),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: AppColors.textDark),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2, color: AppColors.textMutedDark),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.15, color: AppColors.textDark),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: AppColors.textDark),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.25, color: AppColors.textMutedDark),
    );
  }
}
