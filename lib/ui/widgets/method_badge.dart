import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/role_theme.dart';

class MethodBadge extends StatelessWidget {
  const MethodBadge(this.method, {super.key, this.compact = false});

  final HttpMethod method;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.methodColor(method, dark: isDark);
    return Text(
      method.label,
      style: context.type.monoStrong.copyWith(color: color, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700),
    );
  }
}
