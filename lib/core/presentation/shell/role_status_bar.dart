import 'package:flutter/material.dart';

import '../widgets/app_spacing.dart';

class RoleStatusItem {
  const RoleStatusItem({required this.label, this.value});

  final String label;
  final String? value;
}

class RoleStatusBar extends StatelessWidget {
  const RoleStatusBar({super.key, required this.items});

  final List<RoleStatusItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 32,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Text(
              items[i].value == null ? items[i].label : '${items[i].label}: ${items[i].value}',
              style: theme.textTheme.labelSmall,
            ),
            if (i != items.length - 1) ...[
              const SizedBox(width: AppSpacing.sm),
              Text('•', style: theme.textTheme.labelSmall),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}
