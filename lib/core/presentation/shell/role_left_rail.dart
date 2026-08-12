import 'package:flutter/material.dart';

import '../widgets/app_spacing.dart';

class RoleRailDestination {
  const RoleRailDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class RoleLeftRail extends StatelessWidget {
  const RoleLeftRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<RoleRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 76,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: _RailButton(
                destination: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.destination, required this.selected, required this.onTap});

  final RoleRailDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = selected ? theme.colorScheme.primaryContainer : Colors.transparent;
    final foregroundColor = selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
          child: Column(
            children: [
              Icon(destination.icon, color: foregroundColor),
              const SizedBox(height: AppSpacing.xs),
              Text(
                destination.label,
                style: theme.textTheme.labelSmall?.copyWith(color: foregroundColor, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
