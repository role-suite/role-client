import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class EnvironmentsSidebarPanel extends ConsumerWidget {
  const EnvironmentsSidebarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environments = ref.watch(environmentsProvider);
    final activeId = ref.watch(activeEnvironmentIdProvider);
    final activeTabId = ref.watch(workbenchProvider.select((s) => s.activeTabId));
    final canWriteRemoteWorkspace = ref.watch(activeRemoteWorkspaceCanWriteProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Environments',
          trailing: AppIconButton(
            icon: Icons.add,
            tooltip: canWriteRemoteWorkspace ? 'New environment' : remoteWorkspaceReadOnlyMessage,
            onPressed: canWriteRemoteWorkspace
                ? () async {
                    try {
                      final env = await ref.read(environmentsProvider.notifier).create(name: 'New Environment');
                      ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.environment, title: env.name, payloadId: env.id);
                    } catch (error) {
                      if (!context.mounted) return;
                      showRemoteErrorSnackBar(context, 'Could not create environment', error);
                    }
                  }
                : null,
          ),
        ),
        Expanded(
          child: environments.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (error, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
            data: (envs) {
              if (envs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyState(icon: Icons.public, title: 'No environments yet', message: 'Create one to hold variables like baseUrl.'),
                );
              }
              return ListView(
                children: [
                  for (final env in envs)
                    Builder(
                      builder: (context) {
                        final isRemote = env.origin == WorkspaceOrigin.remote;
                        final canWrite = !isRemote || canWriteRemoteWorkspace;
                        return Material(
                          color: activeTabId == WorkbenchTab.idFor(WorkbenchTabType.environment, env.id)
                              ? colors.accent.withValues(alpha: 0.1)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.environment, title: env.name, payloadId: env.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    env.id == activeId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 15,
                                    color: env.id == activeId ? colors.accent : colors.textMuted,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(env.name, style: context.type.body, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text('${env.variables.length}', style: context.type.caption),
                                  if (isRemote)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Tooltip(
                                        message: 'Synced with workspace',
                                        child: Icon(Icons.cloud_outlined, size: 14, color: colors.textMuted),
                                      ),
                                    ),
                                  if (canWrite)
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_horiz, size: 14, color: colors.textMuted),
                                      color: colors.surfaceRaised,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: AppRadius.mdRadius,
                                        side: BorderSide(color: colors.border),
                                      ),
                                      itemBuilder: (context) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                                      onSelected: (action) async {
                                        if (action == 'delete') {
                                          try {
                                            ref.read(workbenchProvider.notifier).closeTab(WorkbenchTab.idFor(WorkbenchTabType.environment, env.id));
                                            await ref.read(environmentsProvider.notifier).delete(env.id);
                                          } catch (error) {
                                            if (!context.mounted) return;
                                            showRemoteErrorSnackBar(context, 'Could not delete environment', error);
                                          }
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
