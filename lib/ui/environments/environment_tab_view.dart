import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/environment.dart';
import '../../core/models/workspace_origin.dart';
import '../../core/remote/workspace_permissions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/environments_notifier.dart';
import '../../state/settings_providers.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../remote_error.dart';
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
    final dirty =
        _saved == null ||
        _saved!.name != next.name ||
        _saved!.variables.map((v) => v.toJson()).toString() != next.variables.map((v) => v.toJson()).toString();
    ref.read(workbenchProvider.notifier).setTabDirty(_tabId, dirty);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    try {
      await ref.read(environmentsProvider.notifier).updateEnvironment(draft);
      setState(() => _saved = draft);
      ref.read(workbenchProvider.notifier)
        ..setTabDirty(_tabId, false)
        ..renameTab(_tabId, draft.name);
    } catch (error) {
      if (mounted) showRemoteErrorSnackBar(context, 'Could not save environment', error);
    }
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
    final isRemote = draft.origin == WorkspaceOrigin.remote;
    final canWrite = !isRemote || ref.watch(activeRemoteWorkspaceCanWriteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRemote)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            color: colors.surfaceRaised,
            child: Row(
              children: [
                Icon(Icons.cloud_outlined, size: 14, color: colors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  canWrite ? 'Synced with workspace — saving pushes your change upstream' : remoteWorkspaceReadOnlyMessage,
                  style: context.type.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('env-name-${draft.id}'),
                  initialValue: draft.name,
                  style: context.type.bodyStrong,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Environment name'),
                  enabled: canWrite,
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
              Tooltip(
                message: canWrite ? 'Save environment' : remoteWorkspaceReadOnlyMessage,
                child: AppButton(label: 'Save', icon: Icons.save_outlined, onPressed: canWrite ? _save : null),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: EnvironmentVariableEditor(
              key: ValueKey('env-vars-${draft.id}'),
              initial: draft.variables,
              enabled: canWrite,
              onChanged: (v) => _update(draft.copyWith(variables: v)),
            ),
          ),
        ),
      ],
    );
  }
}
