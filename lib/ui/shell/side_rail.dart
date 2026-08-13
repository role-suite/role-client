import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';

class SideRail extends ConsumerWidget {
  const SideRail({super.key});

  static const _entries = [
    (section: WorkspaceSection.requests, icon: Icons.dns_outlined, label: 'Requests'),
    (section: WorkspaceSection.history, icon: Icons.history, label: 'History'),
    (section: WorkspaceSection.runs, icon: Icons.play_circle_outline, label: 'Runs'),
    (section: WorkspaceSection.flows, icon: Icons.alt_route, label: 'Flows'),
    (section: WorkspaceSection.environments, icon: Icons.public, label: 'Environments'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final section = ref.watch(workbenchProvider.select((s) => s.section));

    return Container(
      width: AppSizes.iconRailWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          for (final entry in _entries)
            _RailButton(
              icon: entry.icon,
              label: entry.label,
              selected: section == entry.section,
              onTap: () => ref.read(workbenchProvider.notifier).selectSection(entry.section),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdRadius,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              height: 36,
              width: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.accent.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: AppRadius.mdRadius,
                border: selected ? Border.all(color: colors.accent.withValues(alpha: 0.4)) : null,
              ),
              child: Icon(icon, size: 18, color: selected ? colors.accent : colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
