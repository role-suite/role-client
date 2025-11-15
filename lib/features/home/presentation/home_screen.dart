import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/constant/app_constants.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/core/model/collection_model.dart';
import 'package:relay/core/model/environment_model.dart';
import 'package:relay/core/util/extension.dart';
import 'package:relay/core/util/uuid.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/ui/layout/max_width_layout.dart';
import 'package:relay/ui/layout/scaffold.dart';
import 'package:relay/ui/widgets/widgets.dart';

/// Provider for selected collection ID
final selectedCollectionIdProvider = StateProvider<String?>((ref) => 'default');

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
      actions: [
        // Collection selector
        collectionsAsync.when(
          data: (collections) => _buildCollectionSelector(context, ref, collections, selectedCollectionId),
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
          data: (envs) => _buildEnvironmentSelector(context, ref, envs, activeEnvName),
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
        // Create environment button
        IconButton(
          icon: const Icon(Icons.cloud),
          onPressed: () => _showCreateEnvironmentDialog(context, ref),
          tooltip: 'Create Environment',
        ),
        const SizedBox(width: 8),
        // Create collection button
        IconButton(
          icon: const Icon(Icons.add_box),
          onPressed: () => _showCreateCollectionDialog(context, ref),
          tooltip: 'Create Collection',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRequestDialog(context, ref, selectedCollectionId),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: MaxWidthLayout(
        maxWidth: 1200,
        child: requestsAsync.when(
          data: (_) => filteredRequests.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildRequestsList(context, ref, filteredRequests),
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

  Widget _buildCollectionSelector(
    BuildContext context,
    WidgetRef ref,
    List<CollectionModel> collections,
    String? selectedCollectionId,
  ) {
    // Ensure default collection exists
    final allCollections = [
      if (!collections.any((c) => c.id == 'default'))
        CollectionModel(
          id: 'default',
          name: 'Default',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ...collections,
    ];

    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder, size: 20),
          const SizedBox(width: 4),
          Text(
            () {
              final collection = allCollections.firstWhere(
                (c) => c.id == selectedCollectionId,
                orElse: () => allCollections.first,
              );
              return collection.name.isNotEmpty ? collection.name : collection.id;
            }(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
      onSelected: (id) {
        ref.read(selectedCollectionIdProvider.notifier).state = id;
      },
      itemBuilder: (context) => [
        ...allCollections.map((collection) {
          // Ensure we have a valid name to display
          final displayName = collection.name.isNotEmpty ? collection.name : collection.id;
          final isDefault = collection.id == 'default';
          return PopupMenuItem(
            value: collection.id,
            child: Row(
              children: [
                if (selectedCollectionId == collection.id)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(displayName)),
                if (!isDefault) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Close the menu
                      _confirmDeleteCollection(context, ref, collection);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEnvironmentSelector(
    BuildContext context,
    WidgetRef ref,
    List<EnvironmentModel> envs,
    String? activeEnvName,
  ) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud, size: 20),
          const SizedBox(width: 4),
          Text(
            activeEnvName ?? 'No Env',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
      onSelected: (name) {
        if (name != null && name.startsWith('__action__')) {
          // Handle special actions
          return;
        }
        ref.read(activeEnvironmentNameProvider.notifier).state = name;
        ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text('No Environment'),
        ),
        if (envs.isNotEmpty) const PopupMenuDivider(),
        ...envs.map((env) => PopupMenuItem(
              value: env.name,
              child: Row(
                children: [
                  if (activeEnvName == env.name)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(env.name)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showEditEnvironmentDialog(context, ref, env);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _confirmDeleteEnvironment(context, ref, env);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final selectedCollectionId = ref.watch(selectedCollectionIdProvider);
    return EmptyState(
      icon: Icons.api,
      title: 'No API Requests',
      message: 'Create your first API request to get started',
      action: AppButton(
        label: 'Create Request',
        icon: Icons.add,
        onPressed: () => _showCreateRequestDialog(context, ref, selectedCollectionId),
        isFullWidth: false,
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    WidgetRef ref,
    List<ApiRequestModel> requests,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(context, ref, request);
      },
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    WidgetRef ref,
    ApiRequestModel request,
  ) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showRequestDetails(context, ref, request),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDeleteRequest(context, ref, request),
          tooltip: 'Delete',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MethodBadge(method: request.method),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  request.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (request.urlTemplate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.urlTemplate,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (request.description != null && request.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(request.updatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final collectionsAsync = ref.watch(collectionsNotifierProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Collection'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameController,
                  label: 'Collection Name',
                  hint: 'My Collection',
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Describe this collection',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Create',
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final now = DateTime.now();
                final collection = CollectionModel(
                  id: UuidUtils.generate(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );

                Navigator.of(context).pop();

                try {
                  await ref.read(collectionsNotifierProvider.notifier).addCollection(collection);
                  // Select the new collection
                  ref.read(selectedCollectionIdProvider.notifier).state = collection.id;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Collection "${collection.name}" created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create collection: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a collection name'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showCreateRequestDialog(BuildContext context, WidgetRef ref, String? collectionId) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final methodController = ValueNotifier<HttpMethod>(HttpMethod.get);
    final selectedCollectionId = ValueNotifier<String?>(collectionId ?? 'default');
    final collectionsAsync = ref.watch(collectionsNotifierProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Request'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameController,
                  label: 'Request Name',
                  hint: 'My API Request',
                ),
                const SizedBox(height: 16),
                collectionsAsync.when(
                  data: (collections) {
                    // Ensure default collection exists
                    final allCollections = [
                      if (!collections.any((c) => c.id == 'default'))
                        CollectionModel(
                          id: 'default',
                          name: 'Default',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      ...collections,
                    ];

                    return AppDropdown<String>(
                      label: 'Collection',
                      value: selectedCollectionId.value,
                      items: allCollections.map((collection) {
                        final displayName = collection.name.isNotEmpty ? collection.name : collection.id;
                        return DropdownMenuItem(
                          value: collection.id,
                          child: Text(displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedCollectionId.value = value;
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppDropdown<HttpMethod>(
                        label: 'Method',
                        value: methodController.value,
                        items: HttpMethod.values.map((method) {
                          return DropdownMenuItem(
                            value: method,
                            child: Text(method.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            methodController.value = value;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: AppTextField(
                        controller: urlController,
                        label: 'URL',
                        hint: 'https://api.example.com/endpoint',
                        keyboardType: TextInputType.url,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Create',
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty &&
                  urlController.text.trim().isNotEmpty) {
                final now = DateTime.now();
                final request = ApiRequestModel(
                  id: UuidUtils.generate(),
                  name: nameController.text.trim(),
                  method: methodController.value,
                  urlTemplate: urlController.text.trim(),
                  collectionId: selectedCollectionId.value ?? 'default',
                  createdAt: now,
                  updatedAt: now,
                );
                
                Navigator.of(context).pop();
                
                try {
                  await ref.read(requestsNotifierProvider.notifier).addRequest(request);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request "${request.name}" created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create request: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(
    BuildContext context,
    WidgetRef ref,
    ApiRequestModel request,
  ) {
    // TODO: Navigate to request detail/edit screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  MethodBadge(method: request.method),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request.urlTemplate,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
              if (request.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(request.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRequest(
    BuildContext context,
    WidgetRef ref,
    ApiRequestModel request,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: Text('Are you sure you want to delete "${request.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await ref.read(requestsNotifierProvider.notifier).removeRequest(request.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Request "${request.name}" deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete request: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCollection(
    BuildContext context,
    WidgetRef ref,
    CollectionModel collection,
  ) {
    // Prevent deleting default collection
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "${collection.name}"?\n\n'
          'This will also delete all requests in this collection. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                final selectedCollectionId = ref.read(selectedCollectionIdProvider);
                
                await ref.read(collectionsNotifierProvider.notifier).removeCollection(collection.id);
                
                // If the deleted collection was selected, switch to default
                if (selectedCollectionId == collection.id) {
                  ref.read(selectedCollectionIdProvider.notifier).state = 'default';
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Collection "${collection.name}" and all its requests deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete collection: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showCreateEnvironmentDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final variableKeys = <TextEditingController>[];
    final variableValues = <TextEditingController>[];

    void addVariableRow() {
      variableKeys.add(TextEditingController());
      variableValues.add(TextEditingController());
    }

    addVariableRow(); // Start with one empty row

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Environment'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Environment Name',
                    hint: 'Production',
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Variables',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            addVariableRow();
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Variable'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(variableKeys.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: variableKeys[index],
                              label: 'Key',
                              hint: 'API_URL',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              controller: variableValues[index],
                              label: 'Value',
                              hint: 'https://api.example.com',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                variableKeys[index].dispose();
                                variableValues[index].dispose();
                                variableKeys.removeAt(index);
                                variableValues.removeAt(index);
                              });
                            },
                            tooltip: 'Remove variable',
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final controller in variableKeys) controller.dispose();
                for (final controller in variableValues) controller.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Create',
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  // Build variables map
                  final vars = <String, String>{};
                  for (int i = 0; i < variableKeys.length; i++) {
                    final key = variableKeys[i].text.trim();
                    final value = variableValues[i].text.trim();
                    if (key.isNotEmpty) {
                      vars[key] = value;
                    }
                  }

                  final environment = EnvironmentModel(
                    name: nameController.text.trim(),
                    variables: vars,
                  );

                  for (final controller in variableKeys) controller.dispose();
                  for (final controller in variableValues) controller.dispose();
                  Navigator.of(context).pop();

                  try {
                    await ref.read(environmentsNotifierProvider.notifier).addEnvironment(environment);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Environment "${environment.name}" created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create environment: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an environment name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEnvironmentDialog(BuildContext context, WidgetRef ref, EnvironmentModel environment) {
    final nameController = TextEditingController(text: environment.name);
    final variableKeys = <TextEditingController>[];
    final variableValues = <TextEditingController>[];

    // Populate with existing variables
    environment.variables.forEach((key, value) {
      variableKeys.add(TextEditingController(text: key));
      variableValues.add(TextEditingController(text: value));
    });

    if (variableKeys.isEmpty) {
      variableKeys.add(TextEditingController());
      variableValues.add(TextEditingController());
    }

    void addVariableRow() {
      variableKeys.add(TextEditingController());
      variableValues.add(TextEditingController());
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Environment'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Environment Name',
                    enabled: false, // Don't allow editing name
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Variables',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            addVariableRow();
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Variable'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(variableKeys.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: variableKeys[index],
                              label: 'Key',
                              hint: 'API_URL',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              controller: variableValues[index],
                              label: 'Value',
                              hint: 'https://api.example.com',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                variableKeys[index].dispose();
                                variableValues[index].dispose();
                                variableKeys.removeAt(index);
                                variableValues.removeAt(index);
                              });
                            },
                            tooltip: 'Remove variable',
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final controller in variableKeys) controller.dispose();
                for (final controller in variableValues) controller.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Save',
              onPressed: () async {
                // Build variables map
                final vars = <String, String>{};
                for (int i = 0; i < variableKeys.length; i++) {
                  final key = variableKeys[i].text.trim();
                  final value = variableValues[i].text.trim();
                  if (key.isNotEmpty) {
                    vars[key] = value;
                  }
                }

                final updatedEnvironment = environment.copyWith(variables: vars);

                for (final controller in variableKeys) controller.dispose();
                for (final controller in variableValues) controller.dispose();
                Navigator.of(context).pop();

                try {
                  await ref.read(environmentsNotifierProvider.notifier).updateEnvironment(updatedEnvironment);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Environment "${updatedEnvironment.name}" updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update environment: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEnvironment(
    BuildContext context,
    WidgetRef ref,
    EnvironmentModel environment,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Environment'),
        content: Text(
          'Are you sure you want to delete "${environment.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                final activeEnvName = ref.read(activeEnvironmentNameProvider);
                
                await ref.read(environmentsNotifierProvider.notifier).removeEnvironment(environment.name);
                
                // If the deleted environment was active, clear it
                if (activeEnvName == environment.name) {
                  ref.read(activeEnvironmentNameProvider.notifier).state = null;
                  ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Environment "${environment.name}" deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete environment: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
