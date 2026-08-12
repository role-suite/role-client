import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/run_history.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/date_format.dart';
import '../../state/run_history_notifier.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../widgets/widgets.dart';

class RunReportTabView extends ConsumerWidget {
  const RunReportTabView({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runHistoryProvider);
    return runs.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => Center(child: Text('$error')),
      data: (entries) {
        RunHistoryEntry? entry;
        for (final e in entries) {
          if (e.id == runId) entry = e;
        }
        if (entry == null) {
          return const EmptyState(icon: Icons.fact_check_outlined, title: 'Run not found', message: 'It may have been deleted.');
        }
        return _buildReport(context, ref, entry);
      },
    );
  }

  Widget _buildReport(BuildContext context, WidgetRef ref, RunHistoryEntry entry) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.collectionName, style: context.type.title),
          const SizedBox(height: 2),
          Text(
            '${formatDateTime(entry.completedAt)}${entry.environmentName != null ? ' · ${entry.environmentName}' : ''}',
            style: context.type.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatChip(label: 'Passed', value: '${entry.passed}', color: colors.success),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(label: 'Failed', value: '${entry.failed}', color: colors.danger),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(label: 'Total', value: '${entry.total}', color: colors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(label: 'Duration', value: '${entry.totalDuration.inMilliseconds} ms', color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.builder(
              itemCount: entry.results.length,
              itemBuilder: (context, index) {
                final result = entry.results[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: AppRadius.smRadius),
                  child: Row(
                    children: [
                      SizedBox(width: 44, child: MethodBadge(result.method, compact: true)),
                      Expanded(child: Text(result.requestName, style: context.type.body, overflow: TextOverflow.ellipsis)),
                      if (result.errorMessage != null)
                        Expanded(
                          flex: 2,
                          child: Text(result.errorMessage!, style: context.type.caption.copyWith(color: colors.danger), overflow: TextOverflow.ellipsis),
                        ),
                      StatusBadge(statusCode: result.statusCode, errorMessage: result.errorMessage),
                      const SizedBox(width: AppSpacing.sm),
                      Text(result.duration != null ? '${result.duration!.inMilliseconds} ms' : '—', style: context.type.caption),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Delete run',
              variant: AppButtonVariant.ghost,
              onPressed: () async {
                await ref.read(runHistoryProvider.notifier).delete(entry.id);
                ref.read(workbenchProvider.notifier).closeTab(WorkbenchTab.idFor(WorkbenchTabType.runReport, entry.id));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.smRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.type.bodyStrong.copyWith(color: color)),
          Text(label, style: context.type.caption),
        ],
      ),
    );
  }
}
