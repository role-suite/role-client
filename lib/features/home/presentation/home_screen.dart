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
import 'package:relay/features/home/presentation/widgets/collection_selector.dart';
import 'package:relay/features/home/presentation/widgets/environment_selector.dart';
import 'package:relay/features/home/presentation/widgets/home_requests_view.dart';
import 'package:relay/features/home/presentation/widgets/request_runner_screen.dart';
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
      drawer: _buildHomeDrawer(context, ref),
      actions: [
        // Collection selector
        collectionsAsync.when(
          data: (collections) => CollectionSelector(
            collections: collections,
            selectedCollectionId: selectedCollectionId,
            onSelect: (id) {
              ref.read(selectedCollectionIdProvider.notifier).state = id;
            },
            onDelete: (collection) {
              _confirmDeleteCollection(context, ref, collection);
            },
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
            onEdit: (env) {
              _showEditEnvironmentDialog(context, ref, env);
            },
            onDelete: (env) {
              _confirmDeleteEnvironment(context, ref, env);
            },
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

  // Collection and environment selectors are implemented as separate widgets
  // in `CollectionSelector` and `EnvironmentSelector`.

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
    return HomeRequestsView(
      requests: requests,
      onTapRequest: (request) => _showRequestDetails(context, ref, request),
      onEditRequest: (request) => _showRequestDetails(
        context,
        ref,
        request,
        startInEditMode: true,
      ),
    );
  }

  Drawer _buildHomeDrawer(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quick actions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Create New Collection'),
              subtitle: const Text('Group and share related requests'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateCollectionDialog(context, ref);
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Create New Environment'),
              subtitle: const Text('Store URLs, secrets, and configs'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateEnvironmentDialog(context, ref);
              },
            ),
          ],
        ),
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
    final bodyController = TextEditingController();
    final paramKeys = <TextEditingController>[];
    final paramValues = <TextEditingController>[];
    final methodController = ValueNotifier<HttpMethod>(HttpMethod.get);
    final selectedCollectionId = ValueNotifier<String?>(collectionId ?? 'default');
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final activeEnvironmentName = ref.watch(activeEnvironmentNameProvider);
    String? selectedEnvironmentName = activeEnvironmentName;

    void addParamRow() {
      paramKeys.add(TextEditingController());
      paramValues.add(TextEditingController());
    }

    // Start with a single empty parameter row for convenience
    addParamRow();

    EnvironmentModel? findEnvironmentByName(String? name) {
      if (name == null) return null;
      return environmentsAsync.maybeWhen(
        data: (envs) {
          for (final env in envs) {
            if (env.name == name) {
              return env;
            }
          }
          return null;
        },
        orElse: () => null,
      );
    }

    Future<String?> showVariablePicker(BuildContext dialogContext, EnvironmentModel environment) {
      final entries = environment.variables.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      return showModalBottomSheet<String>(
        context: dialogContext,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert Environment Variable',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a variable to insert its placeholder into the focused field.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(entry.key),
                          subtitle: entry.value.isNotEmpty ? Text(entry.value) : null,
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.of(sheetContext).pop(entry.key),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    Future<void> insertVariableIntoController(TextEditingController controller, BuildContext dialogContext) async {
      final environment = findEnvironmentByName(selectedEnvironmentName);
      if (environment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select an environment with variables to insert.'),
          ),
        );
        return;
      }

      if (environment.variables.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Environment "${environment.name}" has no variables yet.'),
          ),
        );
        return;
      }

      final variableKey = await showVariablePicker(dialogContext, environment);
      if (variableKey == null || variableKey.isEmpty) return;

      final placeholder = '{{${variableKey.trim()}}}';
      final selection = controller.selection;
      final baseText = controller.text;
      final start = selection.start >= 0 ? selection.start : baseText.length;
      final end = selection.end >= 0 ? selection.end : selection.start;
      final newText = baseText.replaceRange(
        start,
        end,
        placeholder,
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + placeholder.length),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Request'),
          content: SizedBox(
            width: 600,
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
                  environmentsAsync.when(
                    data: (envs) {
                      if (envs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final selectedEnvironment = findEnvironmentByName(selectedEnvironmentName);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppDropdown<String?>(
                            label: 'Environment (optional)',
                            value: selectedEnvironmentName,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No environment'),
                              ),
                              ...envs.map(
                                (env) => DropdownMenuItem<String?>(
                                  value: env.name,
                                  child: Text(env.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedEnvironmentName = value;
                              });
                            },
                            isExpanded: true,
                          ),
                          if (selectedEnvironmentName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                selectedEnvironment != null && selectedEnvironment.variables.isNotEmpty
                                    ? 'Variables from "$selectedEnvironmentName" can be inserted as {{variableName}}.'
                                    : 'No variables defined for "$selectedEnvironmentName".',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (selectedEnvironment != null && selectedEnvironment.variables.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedEnvironment.variables.entries.map((entry) {
                                  return Chip(
                                    label: Text('{{${entry.key}}}'),
                                    //tooltip: entry.value.isNotEmpty ? entry.value : null,
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
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
                              setState(() {
                                methodController.value = value;
                              });
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
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.data_object),
                            tooltip: 'Insert environment variable',
                            onPressed: () => insertVariableIntoController(urlController, context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Optional body (mainly for non-GET methods)
                  AppTextField(
                    controller: bodyController,
                    label: 'Body (optional)',
                    hint: '{ "key": "value" }',
                    maxLines: 4,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.data_object),
                      tooltip: 'Insert environment variable',
                      onPressed: () => insertVariableIntoController(bodyController, context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Query / path parameters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Query / Path Parameters (optional)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            addParamRow();
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Param'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(paramKeys.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: paramKeys[index],
                              label: 'Key',
                              hint: 'userId',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              controller: paramValues[index],
                              label: 'Value',
                              hint: '123',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.data_object),
                                tooltip: 'Insert environment variable',
                                onPressed: () => insertVariableIntoController(paramValues[index], context),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove param',
                            onPressed: () {
                              setState(() {
                                paramKeys[index].dispose();
                                paramValues[index].dispose();
                                paramKeys.removeAt(index);
                                paramValues.removeAt(index);
                              });
                            },
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
                for (final c in paramKeys) c.dispose();
                for (final c in paramValues) c.dispose();
                nameController.dispose();
                urlController.dispose();
                bodyController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Create',
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty &&
                    urlController.text.trim().isNotEmpty) {
                  final now = DateTime.now();

                  // Build query/path params map (ignore empty keys)
                  final params = <String, String>{};
                  for (int i = 0; i < paramKeys.length; i++) {
                    final key = paramKeys[i].text.trim();
                    final value = paramValues[i].text.trim();
                    if (key.isNotEmpty) {
                      params[key] = value;
                    }
                  }

                  final request = ApiRequestModel(
                    id: UuidUtils.generate(),
                    name: nameController.text.trim(),
                    method: methodController.value,
                    urlTemplate: urlController.text.trim(),
                    queryParams: params, // may be empty
                    body: bodyController.text.trim().isNotEmpty ? bodyController.text.trim() : null,
                    collectionId: selectedCollectionId.value ?? 'default',
                    createdAt: now,
                    updatedAt: now,
                  );

                  for (final c in paramKeys) c.dispose();
                  for (final c in paramValues) c.dispose();
                  nameController.dispose();
                  urlController.dispose();
                  bodyController.dispose();

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
      ),
    );
  }

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
            _confirmDeleteRequest(context, ref, request);
          },
        ),
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

}
