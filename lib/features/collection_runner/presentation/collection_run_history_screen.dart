import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_card.dart';
import 'package:relay/core/presentation/widgets/empty_state.dart';
import 'package:relay/core/presentation/widgets/loading_indicator.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_history.dart';
import 'package:relay/features/collection_runner/presentation/providers/collection_runner_providers.dart';
import 'package:relay/features/collection_runner/presentation/widgets/collection_run_result_card.dart';

class CollectionRunHistoryScreen extends ConsumerWidget {
  const CollectionRunHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historiesAsync = ref.watch(collectionRunHistoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Test Run History')),
      body: SafeArea(
        child: historiesAsync.when(
          data: (histories) {
            if (histories.isEmpty) {
              return EmptyState(icon: Icons.history, title: 'No test runs yet', message: 'Run a collection to see test history here.');
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(collectionRunHistoriesProvider);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: histories.length,
                itemBuilder: (context, index) {
                  final history = histories[index];
                  return _HistoryCard(history: history);
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
              ),
            );
          },
          loading: () => const LoadingIndicator(),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Failed to load history', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(error.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Retry',
                  onPressed: () {
                    ref.invalidate(collectionRunHistoriesProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.history});

  final CollectionRunHistory history;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final history = widget.history;
    final dateTime = history.completedAt;
    final dateStr =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    final successRate = history.totalRequests > 0 ? (history.successfulRequests / history.totalRequests * 100).toStringAsFixed(0) : '0';

    return AppCard(
      title: history.collection.name,
      subtitle: '$dateStr • ${history.environment?.name ?? "No environment"}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(label: 'Total', value: '${history.totalRequests}', icon: Icons.list),
              ),
              Expanded(
                child: _StatItem(label: 'Success', value: '${history.successfulRequests}', icon: Icons.check_circle, color: Colors.green),
              ),
              Expanded(
                child: _StatItem(label: 'Failed', value: '${history.failedRequests}', icon: Icons.error, color: Colors.red),
              ),
              Expanded(
                child: _StatItem(label: 'Success Rate', value: '$successRate%', icon: Icons.percent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_isExpanded ? 'Hide Details' : 'Show Details'),
              ),
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.outlined,
                onPressed: () => _confirmDelete(context, history),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const Divider(),
            const SizedBox(height: 16),
            ...history.results.map((result) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CollectionRunResultCard(result: result, isActive: false),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CollectionRunHistory history) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Test Run'),
        content: Text('Are you sure you want to delete this test run from ${history.collection.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final service = ref.read(collectionRunHistoryServiceProvider);
        await service.deleteHistory(history.id);
        if (context.mounted) {
          ref.invalidate(collectionRunHistoriesProvider);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test run deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.icon, this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
