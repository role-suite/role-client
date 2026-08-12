import 'package:flutter/material.dart';

import '../models/enums.dart';

/// A single neutral graphite scale plus one restrained accent — the
/// tool-grade palette both themes are built from. 0 = darkest, 100 = lightest.
class _Scale {
  const _Scale();
  static const c950 = Color(0xFF0B0D10);
  static const c900 = Color(0xFF111418);
  static const c850 = Color(0xFF15181D);
  static const c700 = Color(0xFF262B33);
  static const c600 = Color(0xFF343B45);
  static const c400 = Color(0xFF6B7280);
  static const c300 = Color(0xFF9AA2AF);
  static const c200 = Color(0xFFC3C9D1);
  static const c100 = Color(0xFFE4E7EB);
  static const c50 = Color(0xFFF3F4F6);
  static const c0 = Color(0xFFFFFFFF);
}

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
    bg: _Scale.c950,
    surface: _Scale.c900,
    surfaceRaised: _Scale.c850,
    surfaceSunken: Color(0xFF08090B),
    border: _Scale.c700,
    borderStrong: _Scale.c600,
    textPrimary: Color(0xFFEDEFF2),
    textSecondary: _Scale.c300,
    textMuted: _Scale.c400,
    accent: Color(0xFF4C9EFF),
    onAccent: Color(0xFF04101F),
    danger: Color(0xFFEF5A5A),
    warning: Color(0xFFE0A339),
    success: Color(0xFF4CC38A),
    info: Color(0xFF4C9EFF),
  );

  static const light = AppColors(
    bg: _Scale.c50,
    surface: _Scale.c0,
    surfaceRaised: _Scale.c0,
    surfaceSunken: Color(0xFFEBEDF0),
    border: _Scale.c100,
    borderStrong: _Scale.c200,
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF454B54),
    textMuted: _Scale.c400,
    accent: Color(0xFF1E6FE0),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD1372F),
    warning: Color(0xFFA9640C),
    success: Color(0xFF1D8A57),
    info: Color(0xFF1E6FE0),
  );

  static Color methodColor(HttpMethod method, {bool dark = true}) {
    switch (method) {
      case HttpMethod.get:
        return dark ? const Color(0xFF4C9EFF) : const Color(0xFF1E6FE0);
      case HttpMethod.post:
        return dark ? const Color(0xFF4CC38A) : const Color(0xFF1D8A57);
      case HttpMethod.put:
        return dark ? const Color(0xFFE0A339) : const Color(0xFFA9640C);
      case HttpMethod.patch:
        return dark ? const Color(0xFFB48CE0) : const Color(0xFF7C4CC4);
      case HttpMethod.delete:
        return dark ? const Color(0xFFEF5A5A) : const Color(0xFFD1372F);
      case HttpMethod.head:
      case HttpMethod.options:
        return dark ? const Color(0xFF9AA2AF) : const Color(0xFF6B7280);
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
