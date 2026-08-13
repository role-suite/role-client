import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/response_snapshot.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/date_format.dart';
import '../../state/history_notifier.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';
import 'history_snapshot_dialog.dart';

enum _HistoryFilter { all, errors }

class HistorySidebarPanel extends ConsumerStatefulWidget {
  const HistorySidebarPanel({super.key});

  @override
  ConsumerState<HistorySidebarPanel> createState() => _HistorySidebarPanelState();
}

class _HistorySidebarPanelState extends ConsumerState<HistorySidebarPanel> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final query = ref.watch(workbenchProvider.select((s) => s.searchQuery)).toLowerCase();
    final workspaceRequestIds = ref.watch(workspaceProvider).value?.requests.map((r) => r.id).toSet() ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('History'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.xs,
            children: [
              _FilterChip(label: 'All', selected: _filter == _HistoryFilter.all, onTap: () => setState(() => _filter = _HistoryFilter.all)),
              _FilterChip(label: 'Errors', selected: _filter == _HistoryFilter.errors, onTap: () => setState(() => _filter = _HistoryFilter.errors)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (error, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
            data: (snapshots) {
              final filtered = snapshots.where((s) {
                if (_filter == _HistoryFilter.errors && s.result.ok) return false;
                if (query.isNotEmpty && !s.requestName.toLowerCase().contains(query) && !s.url.toLowerCase().contains(query)) return false;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyState(icon: Icons.history, title: 'No history yet', message: 'Send a request to see it appear here.'),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final snapshot = filtered[index];
                  return _HistoryRow(snapshot: snapshot, canReopen: workspaceRequestIds.contains(snapshot.requestId));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colors.accent.withValues(alpha: 0.14) : colors.surfaceSunken,
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: selected ? colors.accent.withValues(alpha: 0.4) : colors.border),
        ),
        child: Text(label, style: context.type.label.copyWith(color: selected ? colors.accent : colors.textSecondary)),
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.snapshot, required this.canReopen});

  final ResponseSnapshot snapshot;
  final bool canReopen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => showHistorySnapshotDialog(context, snapshot),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 40, child: MethodBadge(snapshot.method, compact: true)),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snapshot.requestName, style: context.type.body, overflow: TextOverflow.ellipsis),
                  Text(formatTime(snapshot.timestamp), style: context.type.caption),
                ],
              ),
            ),
            StatusBadge(statusCode: snapshot.result.statusCode, errorMessage: snapshot.result.errorMessage),
            if (canReopen)
              AppIconButton(
                icon: Icons.open_in_new,
                tooltip: 'Open request',
                onPressed: () => ref
                    .read(workbenchProvider.notifier)
                    .openTab(type: WorkbenchTabType.request, title: snapshot.requestName, payloadId: snapshot.requestId),
              ),
          ],
        ),
      ),
    );
  }
}
