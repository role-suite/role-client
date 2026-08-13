import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

@immutable
class RoleThemeExtension extends ThemeExtension<RoleThemeExtension> {
  const RoleThemeExtension({required this.colors, required this.typography});

  final AppColors colors;
  final AppTypography typography;

  @override
  RoleThemeExtension copyWith({AppColors? colors, AppTypography? typography}) {
    return RoleThemeExtension(colors: colors ?? this.colors, typography: typography ?? this.typography);
  }

  @override
  RoleThemeExtension lerp(ThemeExtension<RoleThemeExtension>? other, double t) {
    if (other is! RoleThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension RoleThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<RoleThemeExtension>()!.colors;
  AppTypography get type => Theme.of(this).extension<RoleThemeExtension>()!.typography;
}
