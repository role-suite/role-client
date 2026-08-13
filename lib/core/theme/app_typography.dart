import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sans for chrome, monospace for anything code-shaped (URLs, headers,
/// bodies, JSON). Inter and JetBrains Mono ship as bundled assets so the app
/// stays fully offline with no runtime font download.
class AppTypography {
  const AppTypography(this.colors);

  final AppColors colors;

  static const sansFamily = 'Inter';
  static const monoFamily = 'JetBrains Mono';

  TextStyle get title => TextStyle(fontFamily: sansFamily, fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary, height: 1.3);
  TextStyle get body => TextStyle(fontFamily: sansFamily, fontSize: 13, fontWeight: FontWeight.w400, color: colors.textPrimary, height: 1.4);
  TextStyle get bodyStrong => TextStyle(fontFamily: sansFamily, fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary, height: 1.4);
  TextStyle get label => TextStyle(fontFamily: sansFamily, fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary, height: 1.3);
  TextStyle get caption => TextStyle(fontFamily: sansFamily, fontSize: 11, fontWeight: FontWeight.w400, color: colors.textMuted, height: 1.3);
  TextStyle get sectionHeader =>
      TextStyle(fontFamily: sansFamily, fontSize: 11, fontWeight: FontWeight.w700, color: colors.textMuted, letterSpacing: 0.6, height: 1.3);

  TextStyle get mono => TextStyle(fontFamily: monoFamily, fontSize: 13, color: colors.textPrimary, height: 1.45);
  TextStyle get monoSmall => TextStyle(fontFamily: monoFamily, fontSize: 12, color: colors.textSecondary, height: 1.4);
  TextStyle get monoStrong => TextStyle(fontFamily: monoFamily, fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary);
}
