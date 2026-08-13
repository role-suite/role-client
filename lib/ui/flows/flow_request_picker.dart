import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/api_request.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';

Future<ApiRequest?> showFlowRequestPicker(BuildContext context, WidgetRef ref) {
  final workspace = ref.read(workspaceProvider).value;
  final collections = workspace?.collections ?? const [];

  return showDialog<ApiRequest>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add a request', style: context.type.title),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final collection in collections) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(collection.name, style: context.type.sectionHeader),
                      ),
                      for (final request in workspace!.requestsIn(collection.id))
                        InkWell(
                          onTap: () => Navigator.of(context).pop(request),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(width: 44, child: MethodBadge(request.method, compact: true)),
                                Expanded(
                                  child: Text(request.name, style: context.type.body, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
