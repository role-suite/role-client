import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sans for chrome, monospace for anything code-shaped (URLs, headers,
/// bodies, JSON). Uses the platform's built-in monospace fallback so the app
/// ships no font assets and stays fully offline.
class AppTypography {
  const AppTypography(this.colors);

  final AppColors colors;

  static const monoFamily = 'monospace';

  TextStyle get title => TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary, height: 1.3);
  TextStyle get body => TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: colors.textPrimary, height: 1.4);
  TextStyle get bodyStrong => TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary, height: 1.4);
  TextStyle get label => TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary, height: 1.3);
  TextStyle get caption => TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: colors.textMuted, height: 1.3);
  TextStyle get sectionHeader =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textMuted, letterSpacing: 0.6, height: 1.3);

  TextStyle get mono => TextStyle(fontFamily: monoFamily, fontSize: 13, color: colors.textPrimary, height: 1.45);
  TextStyle get monoSmall => TextStyle(fontFamily: monoFamily, fontSize: 12, color: colors.textSecondary, height: 1.4);
  TextStyle get monoStrong => TextStyle(fontFamily: monoFamily, fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary);
}
