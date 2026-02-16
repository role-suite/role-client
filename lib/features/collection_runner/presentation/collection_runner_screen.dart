import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_card.dart';
import 'package:relay/core/presentation/widgets/app_dropdown.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_result.dart';
import 'package:relay/features/collection_runner/presentation/controllers/collection_runner_controller.dart';
import 'package:relay/features/collection_runner/presentation/providers/collection_runner_providers.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_screen.dart';
import 'package:relay/features/collection_runner/presentation/widgets/collection_run_result_card.dart';
import 'package:relay/features/home/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/presentation/providers/environment_providers.dart';

const _noEnvironmentOption = '__collection_runner_no_environment__';

class CollectionRunnerScreen extends ConsumerStatefulWidget {
  const CollectionRunnerScreen({super.key, this.initialCollectionId});

  final String? initialCollectionId;

  @override
  ConsumerState<CollectionRunnerScreen> createState() => _CollectionRunnerScreenState();
}

class _CollectionRunnerScreenState extends ConsumerState<CollectionRunnerScreen> {
  CollectionModel? _selectedCollection;
  EnvironmentModel? _selectedEnvironment;
  bool _didSyncInitialCollection = false;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final runnerState = ref.watch(collectionRunnerControllerProvider);
    final envs = environmentsAsync.asData?.value ?? const <EnvironmentModel>[];

    // Listen for state changes and scroll to running request
    ref.listen<CollectionRunnerState>(collectionRunnerControllerProvider, (previous, next) {
      if (next.isRunning && next.results.isNotEmpty) {
        _scrollToRunningRequest(next.results);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Runner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Test Run History',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CollectionRunHistoryScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a collection, choose an environment, and run every request sequentially.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              collectionsAsync.when(
                data: (collections) {
                  _syncInitialCollectionSelection(collections);
                  if (collections.isEmpty) {
                    return _buildEmptyCollectionsHint(context);
                  }
                  return AppDropdown<String>(
                    label: 'Collection',
                    value: _selectedCollection?.id,
                    isExpanded: true,
                    hint: 'Pick the collection to test',
                    items: collections
                        .map(
                          (collection) => DropdownMenuItem<String>(
                            value: collection.id,
                            child: Text(collection.name.isNotEmpty ? collection.name : collection.id, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (collectionId) => _handleCollectionChange(collectionId, collections, envs),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Failed to load collections: $error'),
              ),
              const SizedBox(height: 16),
              _buildEnvironmentSelector(context, environmentsAsync.isLoading, envs),
              const SizedBox(height: 16),
              AppButton(
                label: runnerState.isRunning ? 'Running...' : 'Run Collection',
                icon: Icons.play_arrow,
                onPressed: _selectedCollection == null || runnerState.isRunning ? null : () => _runCollection(),
                isLoading: runnerState.isRunning && runnerState.totalRequests == 0,
              ),
              const SizedBox(height: 24),
              if (runnerState.errorMessage != null) ...[_buildErrorBanner(context, runnerState.errorMessage!), const SizedBox(height: 16)],
              if (runnerState.hasResults) ...[_buildProgressSection(context, runnerState), const SizedBox(height: 16)],
              if (_isRunComplete(runnerState)) ...[_buildExportButton(context, runnerState), const SizedBox(height: 16)],
              Expanded(child: _buildResultsList(context, runnerState)),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToRunningRequest(List<CollectionRunResult> results) {
    // Find the index of the currently running request
    final runningIndex = results.indexWhere((result) => result.status == CollectionRunStatus.running);

    if (runningIndex == -1) {
      return;
    }

    // Ensure the key exists for this index
    if (!_itemKeys.containsKey(runningIndex)) {
      _itemKeys[runningIndex] = GlobalKey();
    }

    // Scroll to the item after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[runningIndex];
      final context = key?.currentContext;
      if (context != null && mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1, // Position item near the top (10% from top)
        );
      }
    });
  }

  void _syncInitialCollectionSelection(List<CollectionModel> collections) {
    if (_didSyncInitialCollection || collections.isEmpty) {
      return;
    }

    final initialId = widget.initialCollectionId;
    CollectionModel? match;

    if (initialId != null) {
      match = _findCollectionById(collections, initialId);
    }

    match ??= collections.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedCollection = match;
        _didSyncInitialCollection = true;
      });
    });
  }

  void _handleCollectionChange(String? collectionId, List<CollectionModel> collections, List<EnvironmentModel> environments) {
    if (collectionId == null) {
      return;
    }

    final match = _findCollectionById(collections, collectionId);
    if (match == null) {
      return;
    }

    setState(() {
      _selectedCollection = match;
    });

    _promptEnvironmentSelection(environments);
  }

  Future<void> _promptEnvironmentSelection(List<EnvironmentModel> environments) async {
    if (_selectedCollection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a collection before selecting an environment.')));
      return;
    }

    if (environments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No environments defined. Requests will run without variables.')));
      setState(() {
        _selectedEnvironment = null;
      });
      return;
    }

    final selectedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Select Environment'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(_noEnvironmentOption),
              child: Row(
                children: [
                  const Icon(Icons.block),
                  const SizedBox(width: 8),
                  Text('No environment', style: Theme.of(dialogContext).textTheme.bodyMedium),
                ],
              ),
            ),
            const Divider(),
            ...environments.map((env) => SimpleDialogOption(onPressed: () => Navigator.of(dialogContext).pop(env.name), child: Text(env.name))),
          ],
        );
      },
    );

    if (!mounted || selectedName == null) {
      return;
    }

    if (selectedName == _noEnvironmentOption) {
      setState(() {
        _selectedEnvironment = null;
      });
      return;
    }

    final match = _findEnvironmentByName(environments, selectedName);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Environment "$selectedName" no longer exists.')));
      return;
    }

    setState(() {
      _selectedEnvironment = match;
    });
  }

  Future<void> _runCollection() async {
    final collection = _selectedCollection;
    if (collection == null) {
      return;
    }

    await ref.read(collectionRunnerControllerProvider.notifier).runCollection(collection: collection, environment: _selectedEnvironment);
  }

  Widget _buildEnvironmentSelector(BuildContext context, bool isLoading, List<EnvironmentModel> environments) {
    final theme = Theme.of(context);
    final label = _selectedEnvironment?.name ?? 'No environment selected';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        AppButton(
          label: 'Change',
          icon: Icons.swap_horiz,
          variant: AppButtonVariant.outlined,
          onPressed: _selectedCollection == null || isLoading ? null : () => _promptEnvironmentSelection(environments),
        ),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context, CollectionRunnerState state) {
    if (state.isLoadingRequests && !state.hasResults) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.results.isEmpty) {
      return Center(
        child: Text('Run a collection to see a detailed report.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
      );
    }

    // Clear and rebuild keys when results change
    if (_itemKeys.length != state.results.length) {
      _itemKeys.clear();
      for (int i = 0; i < state.results.length; i++) {
        _itemKeys[i] = GlobalKey();
      }
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: state.results.length,
      itemBuilder: (_, index) {
        final result = state.results[index];
        final isActive = result.status == CollectionRunStatus.running;
        return Container(
          key: _itemKeys[index],
          child: CollectionRunResultCard(result: result, isActive: isActive),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
    );
  }

  Widget _buildProgressSection(BuildContext context, CollectionRunnerState state) {
    final theme = Theme.of(context);
    final total = state.totalRequests;
    final completed = state.completedRequests;
    final label = '$completed of $total requests completed';
    final progressValue = state.isRunning ? state.progress : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progressValue),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCollectionsHint(BuildContext context) {
    return AppCard(
      title: 'No collections found',
      subtitle: 'Create a collection from the Home screen to start running requests.',
      child: Text('Use the + button on the Home screen to add your first collection.', style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  CollectionModel? _findCollectionById(List<CollectionModel> collections, String id) {
    for (final collection in collections) {
      if (collection.id == id) {
        return collection;
      }
    }
    return null;
  }

  EnvironmentModel? _findEnvironmentByName(List<EnvironmentModel> environments, String name) {
    for (final env in environments) {
      if (env.name == name) {
        return env;
      }
    }
    return null;
  }

  bool _isRunComplete(CollectionRunnerState state) {
    return !state.isRunning && state.completedAt != null && state.hasResults;
  }

  Widget _buildExportButton(BuildContext context, CollectionRunnerState state) {
    return AppButton(
      label: 'Export Results',
      icon: Icons.file_download,
      variant: AppButtonVariant.outlined,
      onPressed: () => _exportResults(context, state),
    );
  }

  Future<void> _exportResults(BuildContext context, CollectionRunnerState state) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export is not supported on web.')));
      return;
    }

    try {
      final collection = state.collection;
      if (collection == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No collection information available.')));
        return;
      }

      // Build export data
      final exportData = {
        'collection': {'id': collection.id, 'name': collection.name},
        'environment': state.environment != null ? {'name': state.environment!.name, 'variables': state.environment!.variables} : null,
        'completedAt': state.completedAt?.toIso8601String(),
        'summary': {
          'totalRequests': state.totalRequests,
          'completedRequests': state.completedRequests,
          'successfulRequests': state.results.where((r) => r.isSuccess).length,
          'failedRequests': state.results.where((r) => r.status == CollectionRunStatus.failed).length,
        },
        'results': state.results.map((result) {
          return {
            'request': result.request.toJson(),
            'status': result.status.name,
            'statusCode': result.statusCode,
            'statusMessage': result.statusMessage,
            'duration': result.duration?.inMilliseconds,
            'durationFormatted': result.duration != null ? '${result.duration!.inSeconds}s ${result.duration!.inMilliseconds % 1000}ms' : null,
            'errorMessage': result.errorMessage,
            'isSuccess': result.isSuccess,
            'isComplete': result.isComplete,
          };
        }).toList(),
      };

      // Convert to JSON
      final json = const JsonEncoder.withIndent('  ').convert(exportData);
      final defaultFileName = 'collection_run_${collection.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {
        targetDir = null;
      }
      targetDir ??= await getApplicationDocumentsDirectory();
      final filePath = p.join(targetDir.path, defaultFileName);
      await File(filePath).writeAsString(json);
      messenger.showSnackBar(SnackBar(content: Text('Results exported to $filePath'), duration: const Duration(seconds: 4)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to export results: $e')));
    }
  }
}
