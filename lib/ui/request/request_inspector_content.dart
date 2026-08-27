import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/api_request.dart';
import '../../core/network/template_resolver.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/date_format.dart';
import '../../state/environments_notifier.dart';
import '../../state/history_notifier.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';

class RequestInspectorContent extends ConsumerWidget {
  const RequestInspectorContent({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider).value;
    ApiRequest? request;
    if (workspace != null) {
      for (final r in workspace.requests) {
        if (r.id == requestId) request = r;
      }
    }
    if (request == null) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('Request not found.'));
    }

    final variables = ref.watch(activeVariablesProvider);
    final referenced = {
      ...TemplateResolver.unresolvedIn(request.url, variables).union(_resolvedIn(request.url, variables)),
      for (final h in request.headers) ...TemplateResolver.unresolvedIn(h.value, variables).union(_resolvedIn(h.value, variables)),
    };
    final unresolved = referenced.where((name) => !variables.containsKey(name)).toSet();
    final history = ref.watch(historyProvider).value?.where((s) => s.requestId == requestId).take(5).toList() ?? const [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Variables', style: context.type.sectionHeader),
        const SizedBox(height: AppSpacing.sm),
        if (referenced.isEmpty)
          Text('No variables referenced.', style: context.type.caption)
        else
          for (final name in referenced)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    unresolved.contains(name) ? Icons.error_outline : Icons.check_circle_outline,
                    size: 13,
                    color: unresolved.contains(name) ? context.colors.warning : context.colors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(name, style: context.type.monoSmall),
                ],
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        Text('Metadata', style: context.type.sectionHeader),
        const SizedBox(height: AppSpacing.sm),
        _MetaRow(label: 'Created', value: formatDateTime(request.createdAt)),
        _MetaRow(label: 'Updated', value: formatDateTime(request.updatedAt)),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: Text('Recent history', style: context.type.sectionHeader)),
            AppIconButton(
              icon: Icons.history,
              tooltip: 'View all history',
              onPressed: () => ref.read(workbenchProvider.notifier).selectSection(WorkspaceSection.history),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (history.isEmpty)
          Text('No sends yet.', style: context.type.caption)
        else
          for (final snapshot in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  StatusBadge(statusCode: snapshot.result.statusCode, errorMessage: snapshot.result.errorMessage),
                  const SizedBox(width: 6),
                  Text(formatTime(snapshot.timestamp), style: context.type.caption),
                  const Spacer(),
                  Text('${snapshot.result.duration.inMilliseconds} ms', style: context.type.caption),
                ],
              ),
            ),
      ],
    );
  }

  Set<String> _resolvedIn(String input, Map<String, String> variables) {
    final pattern = RegExp(r'\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}');
    return pattern.allMatches(input).map((m) => m.group(1)!).where(variables.containsKey).toSet();
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: context.type.caption),
          const Spacer(),
          Text(value, style: context.type.monoSmall),
        ],
      ),
    );
  }
}
