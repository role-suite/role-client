import 'package:flutter/material.dart';

import '../models/enums.dart';

class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.warning,
    required this.success,
    required this.info,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color warning;
  final Color success;
  final Color info;

  static const dark = AppColors(
    bg: Color(0xFF12141A),
    surface: Color(0xFF1A1D25),
    surfaceRaised: Color(0xFF232733),
    surfaceSunken: Color(0xFF0D0F14),
    border: Color(0xFF2E3340),
    borderStrong: Color(0xFF3F4759),
    textPrimary: Color(0xFFDEE1E8),
    textSecondary: Color(0xFFA7ADBB),
    textMuted: Color(0xFF767C8C),
    accent: Color(0xFF7C9EF2),
    onAccent: Color(0xFF0B1220),
    danger: Color(0xFFE37B72),
    warning: Color(0xFFE0B15E),
    success: Color(0xFF5FC08F),
    info: Color(0xFF7C9EF2),
  );

  static const light = AppColors(
    bg: Color(0xFFE7E8EC),
    surface: Color(0xFFEEEFF2),
    surfaceRaised: Color(0xFFF7F7FA),
    surfaceSunken: Color(0xFFDCDEE3),
    border: Color(0xFFD2D5DC),
    borderStrong: Color(0xFFB7BBC7),
    textPrimary: Color(0xFF23262E),
    textSecondary: Color(0xFF565B68),
    textMuted: Color(0xFF7A7F8C),
    accent: Color(0xFF3F63C7),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB84A42),
    warning: Color(0xFF87600E),
    success: Color(0xFF206A4B),
    info: Color(0xFF3F63C7),
  );

  static Color methodColor(HttpMethod method, {bool dark = true}) {
    switch (method) {
      case HttpMethod.get:
        return dark ? const Color(0xFF7C9EF2) : const Color(0xFF3F63C7);
      case HttpMethod.post:
        return dark ? const Color(0xFF5FC08F) : const Color(0xFF206A4B);
      case HttpMethod.put:
        return dark ? const Color(0xFFE0B15E) : const Color(0xFF87600E);
      case HttpMethod.patch:
        return dark ? const Color(0xFFB79CE0) : const Color(0xFF7357B8);
      case HttpMethod.delete:
        return dark ? const Color(0xFFE37B72) : const Color(0xFFB84A42);
      case HttpMethod.head:
      case HttpMethod.options:
        return dark ? const Color(0xFFA7ADBB) : const Color(0xFF7A7F8C);
    }
  }

  static Color statusColor(int? statusCode, AppColors palette) {
    if (statusCode == null) return palette.textMuted;
    if (statusCode < 300) return palette.success;
    if (statusCode < 400) return palette.info;
    if (statusCode < 500) return palette.warning;
    return palette.danger;
  }
}
