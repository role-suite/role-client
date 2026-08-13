import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/api_request.dart';
import '../../core/models/enums.dart';
import '../../core/models/response_snapshot.dart';
import '../../core/models/run_history.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/id.dart';
import '../../core/utils/iterable_ext.dart';
import '../../state/environments_notifier.dart';
import '../../state/history_notifier.dart';
import '../../state/network_providers.dart';
import '../../state/run_history_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';

class RunnerSetupTabView extends ConsumerStatefulWidget {
  const RunnerSetupTabView({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<RunnerSetupTabView> createState() => _RunnerSetupTabViewState();
}

class _RunnerSetupTabViewState extends ConsumerState<RunnerSetupTabView> {
  final Set<String> _excluded = {};
  int _delayMs = 0;
  bool _running = false;
  List<RunItemResult>? _liveResults;

  Future<void> _startRun(List<ApiRequest> requests, String collectionName) async {
    final selected = requests.where((r) => !_excluded.contains(r.id)).toList();
    if (selected.isEmpty) return;

    setState(() {
      _running = true;
      _liveResults = [for (final r in selected) RunItemResult(requestId: r.id, requestName: r.name, method: r.method, status: RunStatus.pending)];
    });

    final startedAt = DateTime.now();
    final variables = ref.read(activeVariablesProvider);
    final runner = ref.read(requestRunnerProvider);
    final activeEnvId = ref.read(activeEnvironmentIdProvider);
    final envName = activeEnvId == null
        ? null
        : ref.read(environmentsProvider).value?.where((e) => e.id == activeEnvId).map((e) => e.name).firstOrNull;

    for (var i = 0; i < selected.length; i++) {
      final request = selected[i];
      setState(() => _liveResults![i] = _liveResults![i].copyWith(status: RunStatus.running));
      if (_delayMs > 0 && i > 0) await Future.delayed(Duration(milliseconds: _delayMs));

      final result = await runner.run(request, variables);
      await ref
          .read(historyProvider.notifier)
          .record(
            ResponseSnapshot(
              id: generateId('snap'),
              requestId: request.id,
              requestName: request.name,
              method: request.method,
              url: request.url,
              timestamp: DateTime.now(),
              result: result,
            ),
          );

      if (!mounted) return;
      setState(() {
        _liveResults![i] = _liveResults![i].copyWith(
          status: result.ok ? RunStatus.success : RunStatus.failed,
          statusCode: result.statusCode,
          duration: result.duration,
          errorMessage: result.errorMessage,
        );
      });
    }

    await ref
        .read(runHistoryProvider.notifier)
        .record(
          collectionId: widget.collectionId,
          collectionName: collectionName,
          environmentName: envName,
          startedAt: startedAt,
          results: _liveResults!,
        );

    if (!mounted) return;
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);

    return workspace.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => Center(child: Text('$error')),
      data: (state) {
        final collection = state.collections.where((c) => c.id == widget.collectionId).firstOrNull;
        if (collection == null) {
          return const EmptyState(icon: Icons.play_circle_outline, title: 'Collection not found', message: 'It may have been deleted.');
        }
        final requests = state.requestsIn(widget.collectionId);
        return _buildBody(context, collection.name, requests);
      },
    );
  }

  Widget _buildBody(BuildContext context, String collectionName, List<ApiRequest> requests) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Run: $collectionName', style: context.type.title),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              LabeledField(
                label: 'Delay between requests (ms)',
                child: SizedBox(
                  width: 140,
                  child: TextFormField(
                    initialValue: _delayMs.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => _delayMs = int.tryParse(v) ?? 0,
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: _running ? 'Running…' : 'Start Run',
                icon: _running ? null : Icons.play_arrow,
                variant: AppButtonVariant.primary,
                onPressed: _running || requests.isEmpty ? null : () => _startRun(requests, collectionName),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Requests (${requests.length})', style: context.type.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: requests.isEmpty
                ? Text('This collection has no requests.', style: context.type.caption)
                : ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final live = _liveResults?.where((r) => r.requestId == request.id).firstOrNull;
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: !_excluded.contains(request.id),
                              visualDensity: VisualDensity.compact,
                              onChanged: _running
                                  ? null
                                  : (v) => setState(() {
                                      if (v == true) {
                                        _excluded.remove(request.id);
                                      } else {
                                        _excluded.add(request.id);
                                      }
                                    }),
                            ),
                            SizedBox(width: 44, child: MethodBadge(request.method, compact: true)),
                            Expanded(
                              child: Text(request.name, style: context.type.body, overflow: TextOverflow.ellipsis),
                            ),
                            if (live != null) ...[
                              if (live.status == RunStatus.running)
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              if (live.status == RunStatus.success || live.status == RunStatus.failed)
                                StatusBadge(statusCode: live.statusCode, errorMessage: live.errorMessage),
                              if (live.duration != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Text('${live.duration!.inMilliseconds} ms', style: context.type.caption),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
