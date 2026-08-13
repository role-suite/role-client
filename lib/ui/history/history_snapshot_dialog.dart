import 'package:flutter/material.dart';

import '../../core/models/response_snapshot.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/date_format.dart';
import '../widgets/widgets.dart';

Future<void> showHistorySnapshotDialog(BuildContext context, ResponseSnapshot snapshot) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  MethodBadge(snapshot.method),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(snapshot.requestName, style: context.type.title, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 2),
              Text(snapshot.url, style: context.type.monoSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  StatusBadge(statusCode: snapshot.result.statusCode, errorMessage: snapshot.result.errorMessage),
                  const SizedBox(width: AppSpacing.md),
                  Text('${snapshot.result.duration.inMilliseconds} ms', style: context.type.caption),
                  const SizedBox(width: AppSpacing.md),
                  Text(formatDateTime(snapshot.timestamp), style: context.type.caption),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: snapshot.result.errorMessage != null && snapshot.result.body == null
                      ? Text(snapshot.result.errorMessage!, style: context.type.body.copyWith(color: context.colors.danger))
                      : MonoText(snapshot.result.prettyBody),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
