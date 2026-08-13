import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/api_request.dart';
import '../../core/models/chain.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/iterable_ext.dart';
import '../../state/chains_notifier.dart';
import '../../state/environments_notifier.dart';
import '../../state/network_providers.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../../state/workspace_notifier.dart';
import '../widgets/widgets.dart';
import 'flow_request_picker.dart';

class FlowTabView extends ConsumerStatefulWidget {
  const FlowTabView({super.key, required this.chainId});

  final String chainId;

  @override
  ConsumerState<FlowTabView> createState() => _FlowTabViewState();
}

class _FlowTabViewState extends ConsumerState<FlowTabView> {
  SavedChain? _draft;
  SavedChain? _saved;
  bool _running = false;
  List<ChainStepResult>? _results;

  String get _tabId => WorkbenchTab.idFor(WorkbenchTabType.flow, widget.chainId);

  void _update(SavedChain next) {
    setState(() => _draft = next);
    final dirty = _saved == null || _saved!.name != next.name || _saved!.description != next.description || _stepsDiffer(_saved!.steps, next.steps);
    ref.read(workbenchProvider.notifier).setTabDirty(_tabId, dirty);
  }

  bool _stepsDiffer(List<ChainStep> a, List<ChainStep> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].requestId != b[i].requestId || a[i].delayMs != b[i].delayMs || a[i].usePreviousResponse != b[i].usePreviousResponse) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final updated = draft.copyWith(updatedAt: DateTime.now());
    await ref.read(chainsProvider.notifier).updateChain(updated);
    setState(() => _saved = updated);
    ref.read(workbenchProvider.notifier)
      ..setTabDirty(_tabId, false)
      ..renameTab(_tabId, updated.name);
  }

  Future<void> _addStep(List<ApiRequest> allRequests) async {
    final draft = _draft;
    if (draft == null) return;
    final request = await showFlowRequestPicker(context, ref);
    if (request == null) return;
    _update(
      draft.copyWith(
        steps: [
          ...draft.steps,
          ChainStep(requestId: request.id, requestName: request.name),
        ],
      ),
    );
  }

  Future<void> _runFlow(List<ApiRequest> allRequests) async {
    final draft = _draft;
    if (draft == null || draft.steps.isEmpty) return;

    setState(() {
      _running = true;
      _results = [for (final step in draft.steps) ChainStepResult(step: step, status: RunStatus.pending)];
    });

    final baseVariables = ref.read(activeVariablesProvider);
    final runner = ref.read(requestRunnerProvider);
    String? previousBody;

    for (var i = 0; i < draft.steps.length; i++) {
      final step = draft.steps[i];
      setState(() => _results![i] = ChainStepResult(step: step, status: RunStatus.running));

      final request = allRequests.where((r) => r.id == step.requestId).firstOrNull;
      if (request == null) {
        setState(() => _results![i] = ChainStepResult(step: step, status: RunStatus.failed, errorMessage: 'Request not found'));
        continue;
      }

      if (step.delayMs > 0 && i > 0) await Future.delayed(Duration(milliseconds: step.delayMs));

      final variables = {...baseVariables, if (step.usePreviousResponse && previousBody != null) 'previousResponse': previousBody};
      final result = await runner.run(request, variables);
      previousBody = result.prettyBody;

      if (!mounted) return;
      setState(() {
        _results![i] = ChainStepResult(
          step: step,
          status: result.ok ? RunStatus.success : RunStatus.failed,
          statusCode: result.statusCode,
          duration: result.duration,
          errorMessage: result.errorMessage,
          responseBody: result.body,
        );
      });
    }

    if (!mounted) return;
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final chains = ref.watch(chainsProvider);
    final workspace = ref.watch(workspaceProvider);

    return chains.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => Center(child: Text('$error')),
      data: (list) {
        final persisted = list.where((c) => c.id == widget.chainId).firstOrNull;
        if (persisted == null) {
          return const EmptyState(icon: Icons.alt_route, title: 'Flow not found', message: 'It may have been deleted.');
        }
        if (_draft == null) {
          _saved = persisted;
          _draft = persisted;
        }
        final allRequests = workspace.value?.requests ?? const [];
        return _buildEditor(context, _draft!, allRequests);
      },
    );
  }

  Widget _buildEditor(BuildContext context, SavedChain draft, List<ApiRequest> allRequests) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('flow-name-${draft.id}'),
                  initialValue: draft.name,
                  style: context.type.title,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Flow name'),
                  onChanged: (v) => _update(draft.copyWith(name: v)),
                ),
              ),
              AppButton(
                label: _running ? 'Running…' : 'Run Flow',
                icon: _running ? null : Icons.play_arrow,
                variant: AppButtonVariant.primary,
                onPressed: _running || draft.steps.isEmpty ? null : () => _runFlow(allRequests),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: ValueKey('flow-desc-${draft.id}'),
            initialValue: draft.description ?? '',
            style: context.type.caption,
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'What does this flow do?'),
            onChanged: (v) => _update(draft.copyWith(description: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Steps (${draft.steps.length})', style: context.type.sectionHeader),
              const Spacer(),
              AppButton(label: 'Add Step', icon: Icons.add, onPressed: () => _addStep(allRequests)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: draft.steps.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Text('Add a step to start building this flow.', style: context.type.caption),
                  )
                : ListView.builder(
                    itemCount: draft.steps.length,
                    itemBuilder: (context, index) {
                      final step = draft.steps[index];
                      final request = allRequests.where((r) => r.id == step.requestId).firstOrNull;
                      final result = _results?.where((r) => r.step == step).firstOrNull;
                      return _StepRow(
                        index: index,
                        step: step,
                        request: request,
                        result: result,
                        onDelay: (ms) => _update(draft.copyWith(steps: [for (final s in draft.steps) s == step ? s.copyWith(delayMs: ms) : s])),
                        onUsePrevious: (v) =>
                            _update(draft.copyWith(steps: [for (final s in draft.steps) s == step ? s.copyWith(usePreviousResponse: v) : s])),
                        onRemove: () => _update(
                          draft.copyWith(
                            steps: [
                              for (final s in draft.steps)
                                if (s != step) s,
                            ],
                          ),
                        ),
                        onMoveUp: index == 0
                            ? null
                            : () {
                                final steps = [...draft.steps];
                                steps.removeAt(index);
                                steps.insert(index - 1, step);
                                _update(draft.copyWith(steps: steps));
                              },
                        onMoveDown: index == draft.steps.length - 1
                            ? null
                            : () {
                                final steps = [...draft.steps];
                                steps.removeAt(index);
                                steps.insert(index + 1, step);
                                _update(draft.copyWith(steps: steps));
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.request,
    required this.result,
    required this.onDelay,
    required this.onUsePrevious,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final ChainStep step;
  final ApiRequest? request;
  final ChainStepResult? result;
  final ValueChanged<int> onDelay;
  final ValueChanged<bool> onUsePrevious;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: AppRadius.smRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${index + 1}.', style: context.type.caption),
              const SizedBox(width: AppSpacing.sm),
              if (request != null) SizedBox(width: 44, child: MethodBadge(request!.method, compact: true)),
              Expanded(
                child: Text(request?.name ?? step.requestName, style: context.type.body, overflow: TextOverflow.ellipsis),
              ),
              if (result != null) ...[
                if (result!.status == RunStatus.running) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                if (result!.status == RunStatus.success || result!.status == RunStatus.failed)
                  StatusBadge(statusCode: result!.statusCode, errorMessage: result!.errorMessage),
              ],
              AppIconButton(icon: Icons.arrow_upward, tooltip: 'Move up', onPressed: onMoveUp),
              AppIconButton(icon: Icons.arrow_downward, tooltip: 'Move down', onPressed: onMoveDown),
              AppIconButton(icon: Icons.close, tooltip: 'Remove step', onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Delay (ms)', style: context.type.caption),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 70,
                height: 28,
                child: TextFormField(
                  initialValue: step.delayMs.toString(),
                  style: context.type.monoSmall,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  onChanged: (v) => onDelay(int.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Checkbox(value: step.usePreviousResponse, visualDensity: VisualDensity.compact, onChanged: (v) => onUsePrevious(v ?? false)),
              Text('Use previous response', style: context.type.caption),
            ],
          ),
          if (result?.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(result!.errorMessage!, style: context.type.caption.copyWith(color: colors.danger)),
            ),
        ],
      ),
    );
  }
}
