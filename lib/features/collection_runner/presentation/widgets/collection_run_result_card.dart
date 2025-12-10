import 'package:flutter/material.dart';
import 'package:relay/core/presentation/widgets/app_card.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_result.dart';

class CollectionRunResultCard extends StatelessWidget {
  const CollectionRunResultCard({
    super.key,
    required this.result,
    required this.isActive,
  });

  final CollectionRunResult result;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _buildStatusLabel();
    final statusColor = _statusColor(theme);
    final durationText = result.duration != null ? '${result.duration!.inMilliseconds} ms' : '—';

    return AppCard(
      title: result.request.name,
      subtitle: result.request.urlTemplate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MethodBadge(method: result.request.method),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isActive) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ] else
                Text(
                  durationText,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          if (result.errorMessage != null && result.errorMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                result.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildStatusLabel() {
    if (result.statusCode != null) {
      final base = result.statusMessage ?? '';
      return '${result.statusCode} ${base.trim()}'.trim();
    }

    switch (result.status) {
      case CollectionRunStatus.pending:
        return 'Pending...';
      case CollectionRunStatus.running:
        return 'Running...';
      case CollectionRunStatus.success:
        return 'Success';
      case CollectionRunStatus.failed:
        return 'Failed';
    }
  }

  Color _statusColor(ThemeData theme) {
    switch (result.status) {
      case CollectionRunStatus.success:
        return Colors.green.shade600;
      case CollectionRunStatus.failed:
        return theme.colorScheme.error;
      case CollectionRunStatus.running:
        return theme.colorScheme.secondary;
      case CollectionRunStatus.pending:
      return theme.colorScheme.onSurfaceVariant;
    }
  }
}

