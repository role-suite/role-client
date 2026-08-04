import 'package:flutter/material.dart';

import '../widgets/app_spacing.dart';

class RoleTopBar extends StatelessWidget {
  const RoleTopBar({
    super.key,
    required this.title,
    required this.searchPlaceholder,
    this.environmentSelector,
    this.actions = const <Widget>[],
    this.onToggleInspector,
    this.inspectorVisible = true,
  });

  final String title;
  final String searchPlaceholder;
  final Widget? environmentSelector;
  final List<Widget> actions;
  final VoidCallback? onToggleInspector;
  final bool inspectorVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            searchPlaceholder,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (environmentSelector != null) ...[
                  const SizedBox(width: AppSpacing.lg),
                  environmentSelector!,
                ],
                const SizedBox(width: AppSpacing.sm),
                ...actions,
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: inspectorVisible ? 'Hide inspector' : 'Show inspector',
                  onPressed: onToggleInspector,
                  icon: Icon(inspectorVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
