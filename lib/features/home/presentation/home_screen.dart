import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/constant/app_constants.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/core/model/collection_model.dart';
import 'package:relay/core/model/environment_model.dart';
import 'package:relay/core/model/workspace_bundle.dart';
import 'package:relay/core/util/logger.dart';
import 'package:relay/core/util/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/features/home/presentation/widgets/collection_selector.dart';
import 'package:relay/features/home/presentation/widgets/environment_selector.dart';
import 'package:relay/features/home/presentation/widgets/home_drawer.dart';
import 'package:relay/features/home/presentation/widgets/home_empty_state.dart';
import 'package:relay/features/home/presentation/widgets/home_requests_list.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/create_collection_dialog.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/create_request_dialog.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/delete_collection_dialog.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/delete_environment_dialog.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/delete_request_dialog.dart';
import 'package:relay/features/home/presentation/widgets/dialogs/environment_dialog.dart';
import 'package:relay/features/home/presentation/widgets/request_runner_screen.dart';
import 'package:relay/ui/layout/max_width_layout.dart';
import 'package:relay/ui/layout/scaffold.dart';
import 'package:relay/ui/widgets/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCollectionId = ref.watch(selectedCollectionIdProvider);
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final requestsAsync = ref.watch(requestsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final activeEnvName = ref.watch(activeEnvironmentNameProvider);
    final isMobileLayout = MediaQuery.of(context).size.width < 600;

    // Filter requests by selected collection
    final filteredRequests = requestsAsync.when(
      data: (requests) => selectedCollectionId != null
          ? requests.where((r) => r.collectionId == selectedCollectionId).toList()
          : requests,
      loading: () => <ApiRequestModel>[],
      error: (_, __) => <ApiRequestModel>[],
    );

    return AppScaffold(
      title: AppConstants.appName,
      drawer: HomeDrawer(
        onCreateCollection: () => _openCreateCollectionDialog(context),
        onCreateEnvironment: () => _openCreateEnvironmentDialog(context),
        onImportWorkspace: () => _handleImportWorkspace(context, ref),
        onExportWorkspace: () => _handleExportWorkspace(context, ref),
      ),
      actions: [
        // Collection selector
        collectionsAsync.when(
          data: (collections) => CollectionSelector(
            collections: collections,
            selectedCollectionId: selectedCollectionId,
            onSelect: (id) {
              ref.read(selectedCollectionIdProvider.notifier).state = id;
            },
            onDelete: (collection) => _onDeleteCollection(context, collection),
            iconOnly: isMobileLayout,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        // Environment selector
        environmentsAsync.when(
          data: (envs) => EnvironmentSelector(
            envs: envs,
            activeEnvName: activeEnvName,
            onSelect: (name) {
              if (name != null && name.startsWith('__action__')) {
                // Handle special actions
                return;
              }
              ref.read(activeEnvironmentNameProvider.notifier).state = name;
              ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
            },
            onEdit: (env) => _openEditEnvironmentDialog(context, env),
            onDelete: (env) => _onDeleteEnvironment(context, env),
            iconOnly: isMobileLayout,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateRequestDialog(context, selectedCollectionId),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: MaxWidthLayout(
        maxWidth: 1200,
        child: requestsAsync.when(
          data: (_) => filteredRequests.isEmpty
              ? HomeEmptyState(
                  onCreateRequest: () => _openCreateRequestDialog(context, selectedCollectionId),
                )
              : HomeRequestsList(
                  requests: filteredRequests,
                  onTapRequest: (request) => _showRequestDetails(context, ref, request),
                  onEditRequest: (request) => _showRequestDetails(
                    context,
                    ref,
                    request,
                    startInEditMode: true,
                  ),
                ),
          loading: () => const LoadingIndicator(message: 'Loading requests...'),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading requests: $error'),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.read(requestsNotifierProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Collection and environment selectors are implemented as separate widgets
  // in `CollectionSelector` and `EnvironmentSelector`.

  void _showRequestDetails(
    BuildContext context,
    WidgetRef ref,
    ApiRequestModel request, {
    bool startInEditMode = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => RequestRunnerPage(
          request: request,
          startInEditMode: startInEditMode,
          onDelete: () {
            Navigator.of(pageContext).pop();
            _onDeleteRequest(context, request);
          },
        ),
      ),
    );
  }

  void _openCreateCollectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CreateCollectionDialog(),
    );
  }

  void _openCreateRequestDialog(BuildContext context, String? collectionId) {
    showDialog(
      context: context,
      builder: (_) => CreateRequestDialog(initialCollectionId: collectionId),
    );
  }

  void _openCreateEnvironmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CreateEnvironmentDialog(),
    );
  }

  void _openEditEnvironmentDialog(BuildContext context, EnvironmentModel environment) {
    showDialog(
      context: context,
      builder: (_) => EditEnvironmentDialog(environment: environment),
    );
  }

  void _onDeleteRequest(BuildContext context, ApiRequestModel request) {
    showDialog(
      context: context,
      builder: (_) => DeleteRequestDialog(request: request),
    );
  }

  void _onDeleteCollection(BuildContext context, CollectionModel collection) {
    if (collection.id == 'default') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the default collection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => DeleteCollectionDialog(collection: collection),
    );
  }

  void _onDeleteEnvironment(BuildContext context, EnvironmentModel environment) {
    showDialog(
      context: context,
      builder: (_) => DeleteEnvironmentDialog(environment: environment),
    );
  }

  Future<void> _handleExportWorkspace(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is not supported on web.')),
      );
      return;
    }

    try {
      final service = ref.read(workspaceImportExportServiceProvider);
      final bundle = await service.buildBundle();
      final json = const JsonEncoder.withIndent('  ').convert(bundle.toJson());
      final defaultFileName = 'relay_workspace_${DateTime.now().millisecondsSinceEpoch}.json';
      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {
        targetDir = null;
      }
      targetDir ??= await getApplicationDocumentsDirectory();
      final filePath = p.join(targetDir.path, defaultFileName);
      await File(filePath).writeAsString(json);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workspace exported to $filePath'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      AppLogger.debug(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export workspace: $e')),
      );
    }
  }

  Future<void> _handleImportWorkspace(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import is not supported on web.')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false, // IMPORTANT FIX FOR DESKTOP
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // SAFEST cross-platform read:
      final rawJson = file.path != null
          ? await File(file.path!).readAsString()
          : utf8.decode(file.bytes ?? []);

      if (rawJson.isEmpty) {
        throw const FormatException('Selected file is empty.');
      }

      final service = ref.read(workspaceImportExportServiceProvider);
      final bundle = await service.parseImportFile(rawJson);

      await _importBundle(context, ref, bundle);
      await _refreshData(ref);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${bundle.collections.length} collections and ${bundle.environments.length} environments.',
          ),
        ),
      );
    } catch (e) {
      AppLogger.debug(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import workspace: $e')),
      );
    }
  }

  Future<void> _importBundle(
    BuildContext context,
    WidgetRef ref,
    WorkspaceBundle bundle,
  ) async {
    final collectionRepository = ref.read(collectionRepositoryProvider);
    final requestRepository = ref.read(requestRepositoryProvider);
    final environmentRepository = ref.read(environmentRepositoryProvider);

    final existingCollections = await collectionRepository.getAllCollections();
    final existingCollectionNames = {
      for (final collection in existingCollections) collection.name.toLowerCase(): collection,
    };
    final existingEnvironments = await environmentRepository.getAllEnvironments();
    final existingEnvironmentNames = {
      for (final env in existingEnvironments) env.name.toLowerCase(): env,
    };

    for (final env in bundle.environments) {
      var targetEnv = env;
      final conflict = existingEnvironmentNames[targetEnv.name.toLowerCase()];
      if (conflict != null) {
        final resolution = await _showConflictDialog(
          context: context,
          title: 'Environment conflict',
          message:
              'An environment named "${targetEnv.name}" already exists. What would you like to do?',
        );
        if (resolution == ConflictResolution.skip) {
          continue;
        } else if (resolution == ConflictResolution.keepBoth) {
          final uniqueName =
              _generateUniqueName(targetEnv.name, existingEnvironmentNames.keys);
          targetEnv = targetEnv.copyWith(name: uniqueName);
        }
        // overwrite simply falls through and saves with same name
      }
      await environmentRepository.saveEnvironment(targetEnv);
      existingEnvironmentNames[targetEnv.name.toLowerCase()] = targetEnv;
    }

    for (final bundleCollection in bundle.collections) {
      var targetCollection = bundleCollection.collection;
      final conflict = existingCollectionNames[targetCollection.name.toLowerCase()];

      if (conflict != null) {
        final resolution = await _showConflictDialog(
          context: context,
          title: 'Collection conflict',
          message:
              'A collection named "${targetCollection.name}" already exists. What would you like to do?',
        );
        if (resolution == ConflictResolution.skip) {
          continue;
        } else if (resolution == ConflictResolution.keepBoth ||
            (resolution == ConflictResolution.overwrite && conflict.id == 'default')) {
          final uniqueName =
              _generateUniqueName(targetCollection.name, existingCollectionNames.keys);
          targetCollection = targetCollection.copyWith(
            id: '${targetCollection.id}-${UuidUtils.generate()}',
            name: uniqueName,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else if (resolution == ConflictResolution.overwrite) {
          await collectionRepository.deleteCollection(conflict.id);
        }
      } else {
        targetCollection = targetCollection.copyWith(
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      await collectionRepository.saveCollection(targetCollection);
      existingCollectionNames[targetCollection.name.toLowerCase()] = targetCollection;

      for (final request in bundleCollection.requests) {
        final normalizedRequest = request.copyWith(
          id: UuidUtils.generate(),
          collectionId: targetCollection.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await requestRepository.saveRequest(normalizedRequest);
      }
    }
  }

  Future<void> _refreshData(WidgetRef ref) async {
    ref.read(collectionsNotifierProvider.notifier).refresh();
    ref.read(requestsNotifierProvider.notifier).refresh();
    ref.read(environmentsNotifierProvider.notifier).refresh();
  }

  String _generateUniqueName(String baseName, Iterable<String> existingNames) {
    final normalized = baseName.trim().isEmpty ? 'Untitled' : baseName.trim();
    final lowerSet = existingNames.map((e) => e.toLowerCase()).toSet();
    var candidate = normalized;
    var index = 2;
    while (lowerSet.contains(candidate.toLowerCase())) {
      candidate = '$normalized ($index)';
      index++;
    }
    return candidate;
  }

  Future<ConflictResolution> _showConflictDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    final result = await showDialog<ConflictResolution>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(ConflictResolution.skip),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ConflictResolution.keepBoth),
              child: const Text('Keep both'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ConflictResolution.overwrite),
              child: const Text('Overwrite'),
            ),
          ],
        );
      },
    );
    return result ?? ConflictResolution.skip;
  }
}

enum ConflictResolution { overwrite, keepBoth, skip }

bool get _isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
