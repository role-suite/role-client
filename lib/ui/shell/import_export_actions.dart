import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/io/workspace_io.dart';
import '../../core/models/workspace_bundle.dart';
import '../../core/remote/auth/auth_state.dart';
import '../../core/remote/workspace_permissions.dart';
import '../../core/utils/iterable_ext.dart';
import '../../state/auth_notifier.dart';
import '../../state/environments_notifier.dart';
import '../../state/workspace_notifier.dart';
import '../remote_error.dart';
import '../workspace/workspace_import_export_actions.dart';
import 'import_export_dialogs.dart';

enum _ImportExportTarget { local, remote }

Future<void> runImportWorkspaceChoice(BuildContext context, WidgetRef ref) async {
  final target = await _chooseImportExportTarget(context, ref, action: 'Import');
  if (target == null || !context.mounted) return;

  switch (target) {
    case _ImportExportTarget.local:
      await runImportWorkspace(context, ref);
    case _ImportExportTarget.remote:
      final auth = ref.read(authNotifierProvider);
      if (auth is! AuthSignedIn) return;
      await runImportRemoteWorkspace(context, ref, workspaceId: auth.activeWorkspaceId, workspaceName: auth.activeWorkspace.name);
  }
}

Future<void> runExportWorkspaceChoice(BuildContext context, WidgetRef ref) async {
  final target = await _chooseImportExportTarget(context, ref, action: 'Export');
  if (target == null || !context.mounted) return;

  switch (target) {
    case _ImportExportTarget.local:
      await runExportWorkspace(context, ref);
    case _ImportExportTarget.remote:
      final auth = ref.read(authNotifierProvider);
      if (auth is! AuthSignedIn) return;
      await runExportRemoteWorkspace(context, ref, workspaceId: auth.activeWorkspaceId, workspaceName: auth.activeWorkspace.name);
  }
}

Future<_ImportExportTarget?> _chooseImportExportTarget(BuildContext context, WidgetRef ref, {required String action}) {
  final auth = ref.read(authNotifierProvider);
  final signedIn = auth is AuthSignedIn;
  final canUseRemote = signedIn && canWriteRemoteWorkspaceRole(auth.activeWorkspace.role);
  final remoteSubtitle = !signedIn
      ? 'Sign in to use role-node import/export.'
      : canUseRemote
      ? '${auth.activeWorkspace.name} (${auth.activeWorkspace.role})'
      : remoteWorkspaceReadOnlyMessage;

  return showDialog<_ImportExportTarget>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$action workspace'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.computer_outlined),
              title: Text('$action local workspace'),
              subtitle: const Text('Use this device\'s local Röle/Postman workspace data.'),
              onTap: () => Navigator.of(dialogContext).pop(_ImportExportTarget.local),
            ),
            ListTile(
              enabled: canUseRemote,
              leading: const Icon(Icons.cloud_outlined),
              title: Text(action == 'Import' ? 'Import into remote workspace' : 'Export remote workspace'),
              subtitle: Text(remoteSubtitle),
              onTap: canUseRemote ? () => Navigator.of(dialogContext).pop(_ImportExportTarget.remote) : null,
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel'))],
    ),
  );
}

Future<void> runExportWorkspace(BuildContext context, WidgetRef ref) async {
  final workspace = ref.read(workspaceProvider).value;
  final environments = ref.read(environmentsProvider).value ?? const [];
  if (workspace == null) return;

  final bundles = [for (final c in workspace.collections) CollectionBundle(collection: c, requests: workspace.requestsIn(c.id))];
  final json = WorkspaceIo.buildBundleJson(collections: bundles, environments: environments);

  final path = await WorkspaceIo.exportToFile(json);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path != null ? 'Exported local workspace to $path' : 'Local export cancelled')));
}

const _skip = '__skip__';

Future<void> runImportWorkspace(BuildContext context, WidgetRef ref) async {
  final ImportedData? data;
  try {
    data = await WorkspaceIo.pickAndParse();
  } catch (error) {
    if (!context.mounted) return;
    showRemoteErrorSnackBar(context, 'Import failed', error);
    return;
  }
  if (data == null) return;
  if (data.collections.isEmpty && data.environments.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That file is not a local Röle or Postman export Röle understands.')));
    return;
  }

  final existingCollectionNames = ref.read(workspaceProvider).value?.collections.map((c) => c.name).toSet() ?? const {};
  final existingEnvironmentNames = ref.read(environmentsProvider).value?.map((e) => e.name).toSet() ?? const {};

  // Resolve conflicts up front (one dialog per colliding name), then import.
  final collectionIdOverrides = <String, String>{};
  for (final bundle in data.collections) {
    if (!existingCollectionNames.contains(bundle.collection.name)) continue;
    if (!context.mounted) return;
    final choice = await showImportConflictDialog(context, bundle.collection.name);
    if (choice == ImportConflictChoice.skip) {
      collectionIdOverrides[bundle.collection.id] = _skip;
    } else if (choice == ImportConflictChoice.overwrite) {
      final existing = ref.read(workspaceProvider).value?.collections.where((c) => c.name == bundle.collection.name).firstOrNull;
      if (existing != null) collectionIdOverrides[bundle.collection.id] = existing.id;
    }
  }

  final environmentIdOverrides = <String, String>{};
  for (final env in data.environments) {
    if (!existingEnvironmentNames.contains(env.name)) continue;
    if (!context.mounted) return;
    final choice = await showImportConflictDialog(context, env.name);
    if (choice == ImportConflictChoice.skip) {
      environmentIdOverrides[env.id] = _skip;
    } else if (choice == ImportConflictChoice.overwrite) {
      final existing = ref.read(environmentsProvider).value?.where((e) => e.name == env.name).firstOrNull;
      if (existing != null) environmentIdOverrides[env.id] = existing.id;
    }
  }

  final collectionsToImport = data.collections.where((b) => collectionIdOverrides[b.collection.id] != _skip).toList();
  if (collectionsToImport.isNotEmpty) {
    await ref
        .read(workspaceProvider.notifier)
        .importBundles(collectionsToImport, resolveId: (incoming, nameTaken) => collectionIdOverrides[incoming.id]);
  }

  final environmentsToImport = data.environments.where((e) => environmentIdOverrides[e.id] != _skip).toList();
  if (environmentsToImport.isNotEmpty) {
    await ref
        .read(environmentsProvider.notifier)
        .importAll(environmentsToImport, resolveId: (incoming, nameTaken) => environmentIdOverrides[incoming.id]);
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local import complete')));
}
