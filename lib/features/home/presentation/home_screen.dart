import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/constant/app_constants.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/core/model/collection_model.dart';
import 'package:relay/core/model/environment_model.dart';
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
}
