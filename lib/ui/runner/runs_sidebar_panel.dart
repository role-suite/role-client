import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/date_format.dart';
import '../../state/run_history_notifier.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';

class RunsSidebarPanel extends ConsumerStatefulWidget {
  const RunsSidebarPanel({super.key});

  @override
  ConsumerState<RunsSidebarPanel> createState() => _RunsSidebarPanelState();
}

class _RunsSidebarPanelState extends ConsumerState<RunsSidebarPanel> {
  int _visibleCount = AppConstants.runHistoryPageSize;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final runHistory = ref.watch(runHistoryProvider);
    final colors = context.colors;

    return ListView(
      children: [
        const SectionHeader('Collections'),
        workspace.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
          error: (error, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
          data: (state) {
            if (state.collections.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('No collections yet.', style: context.type.caption),
              );
            }
            return Column(
              children: [
                for (final collection in state.collections)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => ref
                          .read(workbenchProvider.notifier)
                          .openTab(type: WorkbenchTabType.runnerSetup, title: 'Run: ${collection.name}', payloadId: collection.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.dns_outlined, size: 14, color: colors.textMuted),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(collection.name, style: context.type.body, overflow: TextOverflow.ellipsis),
                            ),
                            Text('${state.requestsIn(collection.id).length}', style: context.type.caption),
                            const SizedBox(width: 4),
                            Icon(Icons.play_arrow, size: 15, color: colors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SectionHeader('Recent runs'),
        runHistory.when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('No runs yet.', style: context.type.caption),
              );
            }
            final visibleCount = _visibleCount.clamp(0, entries.length);
            final hasMore = visibleCount < entries.length;
            return Column(
              children: [
                for (final entry in entries.take(visibleCount))
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => ref
                          .read(workbenchProvider.notifier)
                          .openTab(type: WorkbenchTabType.runReport, title: entry.collectionName, payloadId: entry.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              entry.failed == 0 ? Icons.check_circle_outline : Icons.error_outline,
                              size: 14,
                              color: entry.failed == 0 ? colors.success : colors.danger,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.collectionName, style: context.type.body, overflow: TextOverflow.ellipsis),
                                  Text('${entry.passed}/${entry.total} passed · ${formatTime(entry.completedAt)}', style: context.type.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (hasMore)
                  InkWell(
                    onTap: () => setState(() => _visibleCount += AppConstants.runHistoryPageSize),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text('Load ${entries.length - visibleCount} more', style: context.type.label.copyWith(color: colors.accent)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
