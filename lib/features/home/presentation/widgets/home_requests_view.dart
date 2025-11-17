import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/ui/widgets/widgets.dart';

class HomeRequestsView extends ConsumerWidget {
  const HomeRequestsView({
    super.key,
    required this.requests,
    required this.onTapRequest,
    this.onEditRequest,
  });

  final List<ApiRequestModel> requests;
  final void Function(ApiRequestModel request) onTapRequest;
  final void Function(ApiRequestModel request)? onEditRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        final label =
            '${request.method.name} request ${request.name} ${request.urlTemplate}';
        return Semantics(
          button: true,
          label: label,
          hint: 'Press Enter or Space to open details. Use the edit and delete buttons for more actions.',
          child: Focus(
            child: Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (intent) {
                      onTapRequest(request);
                      return null;
                    },
                  ),
                },
                child: AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => onTapRequest(request),
                  actions: [
                    Tooltip(
                      message: 'Run request "${request.name}"',
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => onTapRequest(request),
                        tooltip: 'Run',
                      ),
                    ),
                    if (onEditRequest != null)
                      Tooltip(
                        message: 'Edit request "${request.name}"',
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => onEditRequest!(request),
                          tooltip: 'Edit',
                        ),
                      ),
                  ],
                  child: _RequestCardContent(request: request),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RequestCardContent extends StatelessWidget {
  const _RequestCardContent({required this.request});

  final ApiRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MethodBadge(method: request.method),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                request.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        if (request.urlTemplate.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            request.urlTemplate,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (request.description != null && request.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            request.description!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              _formatDate(request.updatedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}


