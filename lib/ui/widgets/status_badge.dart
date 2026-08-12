import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/role_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, this.statusCode, this.errorMessage});

  final int? statusCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isError = errorMessage != null && statusCode == null;
    final color = isError ? colors.danger : AppColors.statusColor(statusCode, colors);
    final label = isError ? 'ERROR' : (statusCode?.toString() ?? '—');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: context.type.monoStrong.copyWith(color: color, fontSize: 12)),
    );
  }
}
