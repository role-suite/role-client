import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/environment.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/environments_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../widgets/widgets.dart';

class EnvironmentTabView extends ConsumerStatefulWidget {
  const EnvironmentTabView({super.key, required this.environmentId});

  final String environmentId;

  @override
  ConsumerState<EnvironmentTabView> createState() => _EnvironmentTabViewState();
}

class _EnvironmentTabViewState extends ConsumerState<EnvironmentTabView> {
  Environment? _draft;
  Environment? _saved;

  String get _tabId => WorkbenchTab.idFor(WorkbenchTabType.environment, widget.environmentId);

  void _update(Environment next) {
    setState(() => _draft = next);
    final dirty = _saved == null || _saved!.name != next.name || _saved!.variables.toString() != next.variables.toString();
    ref.read(workbenchProvider.notifier).setTabDirty(_tabId, dirty);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    await ref.read(environmentsProvider.notifier).updateEnvironment(draft);
    setState(() => _saved = draft);
    ref.read(workbenchProvider.notifier)
      ..setTabDirty(_tabId, false)
      ..renameTab(_tabId, draft.name);
  }

  @override
  Widget build(BuildContext context) {
    final environments = ref.watch(environmentsProvider);

    return environments.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => Center(child: Text('$error')),
      data: (envs) {
        Environment? persisted;
        for (final e in envs) {
          if (e.id == widget.environmentId) persisted = e;
        }
        if (persisted == null) {
          return const EmptyState(icon: Icons.public, title: 'Environment not found', message: 'It may have been deleted.');
        }
        if (_draft == null) {
          _saved = persisted;
          _draft = persisted;
        }
        return _buildEditor(context, _draft!);
      },
    );
  }

  Widget _buildEditor(BuildContext context, Environment draft) {
    final colors = context.colors;
    final activeId = ref.watch(activeEnvironmentIdProvider);
    final isActive = activeId == draft.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('env-name-${draft.id}'),
                  initialValue: draft.name,
                  style: context.type.bodyStrong,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Environment name'),
                  onChanged: (v) => _update(draft.copyWith(name: v)),
                ),
              ),
              AppButton(
                label: isActive ? 'Active' : 'Set Active',
                icon: isActive ? Icons.check : null,
                variant: isActive ? AppButtonVariant.secondary : AppButtonVariant.primary,
                onPressed: isActive ? null : () => ref.read(activeEnvironmentIdProvider.notifier).setActiveEnvironment(draft.id),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: KeyValueEditor(
              key: ValueKey('env-vars-${draft.id}'),
              initial: draft.variables,
              keyHint: 'Variable',
              onChanged: (v) => _update(draft.copyWith(variables: v)),
            ),
          ),
        ),
      ],
    );
  }
}
