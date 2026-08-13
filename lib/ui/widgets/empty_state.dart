import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: context.type.bodyStrong),
            if (message != null) ...[const SizedBox(height: AppSpacing.xs), Text(message!, textAlign: TextAlign.center, style: context.type.caption)],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
