import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';

import 'package:relay/core/presentation/widgets/method_badge.dart';

class HomeRequestsView extends ConsumerWidget {
  const HomeRequestsView({super.key, required this.requests, required this.onTapRequest, this.onEditRequest});

  final List<ApiRequestModel> requests;
  final void Function(ApiRequestModel request) onTapRequest;
  final void Function(ApiRequestModel request)? onEditRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: requests.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      itemBuilder: (context, index) {
        final request = requests[index];
        final label = '${request.method.name} request ${request.name} ${request.urlTemplate}';
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
                child: InkWell(
                  onTap: () => onTapRequest(request),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        MethodBadge(method: request.method, size: MethodBadgeSize.small),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                request.name,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (request.urlTemplate.isNotEmpty)
                                Text(
                                  request.urlTemplate,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => onTapRequest(request),
                          tooltip: 'Run',
                          visualDensity: VisualDensity.compact,
                        ),
                        if (onEditRequest != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => onEditRequest!(request),
                            tooltip: 'Edit',
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
