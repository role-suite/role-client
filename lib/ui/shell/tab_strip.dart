import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';

IconData iconForTabType(WorkbenchTabType type) {
  switch (type) {
    case WorkbenchTabType.request:
      return Icons.dns_outlined;
    case WorkbenchTabType.environment:
      return Icons.public;
    case WorkbenchTabType.runnerSetup:
      return Icons.play_circle_outline;
    case WorkbenchTabType.runReport:
      return Icons.fact_check_outlined;
    case WorkbenchTabType.flow:
      return Icons.alt_route;
    case WorkbenchTabType.flowRun:
      return Icons.route_outlined;
  }
}

class TabStrip extends ConsumerWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tabs = ref.watch(workbenchProvider.select((s) => s.tabs));
    final activeId = ref.watch(workbenchProvider.select((s) => s.activeTabId));

    return Container(
      height: AppSizes.tabStripHeight,
      decoration: BoxDecoration(color: colors.surface, border: Border(bottom: BorderSide(color: colors.border))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return _TabChip(tab: tab, selected: tab.id == activeId);
        },
      ),
    );
  }
}

class _TabChip extends ConsumerWidget {
  const _TabChip({required this.tab, required this.selected});

  final WorkbenchTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.bg : Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(workbenchProvider.notifier).focusTab(tab.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colors.border),
              bottom: BorderSide(color: selected ? colors.accent : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconForTabType(tab.type), size: 13, color: selected ? colors.textPrimary : colors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Text(
                tab.title,
                style: context.type.body.copyWith(color: selected ? colors.textPrimary : colors.textSecondary, fontSize: 12.5),
              ),
              if (tab.isDirty) ...[
                const SizedBox(width: 4),
                Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle)),
              ],
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: () => ref.read(workbenchProvider.notifier).closeTab(tab.id),
                borderRadius: BorderRadius.circular(3),
                child: Icon(Icons.close, size: 13, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
