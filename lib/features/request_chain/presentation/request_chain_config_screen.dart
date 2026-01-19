import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/core/presentation/layout/scaffold.dart';
import 'package:relay/core/presentation/layout/max_width_layout.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';
import 'package:relay/features/request_chain/domain/models/request_chain_item.dart';
import 'package:relay/features/request_chain/domain/models/saved_request_chain.dart';
import 'package:relay/features/request_chain/presentation/providers/request_chain_providers.dart';
import 'package:relay/features/request_chain/presentation/request_chain_execution_screen.dart';

class RequestChainConfigScreen extends ConsumerStatefulWidget {
  const RequestChainConfigScreen({super.key});

  @override
  ConsumerState<RequestChainConfigScreen> createState() => _RequestChainConfigScreenState();
}

class _RequestChainConfigScreenState extends ConsumerState<RequestChainConfigScreen> {
  final List<RequestChainItem> _chainItems = [];
  final Map<String, TextEditingController> _delayControllers = {};

  @override
  void dispose() {
    for (final controller in _delayControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addRequestToChain(ApiRequestModel request) {
    setState(() {
      final item = RequestChainItem(
        requestId: request.id,
        requestName: request.name,
        delayMs: 0,
        usePreviousResponse: _chainItems.isNotEmpty, // Auto-enable for subsequent requests
      );
      _chainItems.add(item);
      _delayControllers[request.id] = TextEditingController(text: '0');
      
      // Ensure first item doesn't have usePreviousResponse enabled
      _ensureFirstItemNoPreviousResponse();
    });
  }

  void _removeRequestFromChain(int index) {
    setState(() {
      final item = _chainItems.removeAt(index);
      _delayControllers[item.requestId]?.dispose();
      _delayControllers.remove(item.requestId);
      
      // Ensure first item doesn't have usePreviousResponse enabled after removal
      _ensureFirstItemNoPreviousResponse();
    });
  }

  /// Ensures the first item in the chain never has usePreviousResponse enabled
  void _ensureFirstItemNoPreviousResponse() {
    if (_chainItems.isNotEmpty && _chainItems[0].usePreviousResponse) {
      _chainItems[0] = _chainItems[0].copyWith(usePreviousResponse: false);
    }
  }

  void _moveRequestUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _chainItems.removeAt(index);
        _chainItems.insert(index - 1, item);
        
        // Ensure first item doesn't have usePreviousResponse enabled
        _ensureFirstItemNoPreviousResponse();
      });
    }
  }

  void _moveRequestDown(int index) {
    if (index < _chainItems.length - 1) {
      setState(() {
        final item = _chainItems.removeAt(index);
        _chainItems.insert(index + 1, item);
        
        // Ensure first item doesn't have usePreviousResponse enabled
        _ensureFirstItemNoPreviousResponse();
      });
    }
  }

  void _updateDelay(String requestId, String value) {
    final delay = int.tryParse(value) ?? 0;
    setState(() {
      final index = _chainItems.indexWhere((item) => item.requestId == requestId);
      if (index != -1) {
        _chainItems[index] = _chainItems[index].copyWith(delayMs: delay);
      }
    });
  }

  void _toggleUsePreviousResponse(int index) {
    // First item can never use previous response
    if (index == 0) return;
    
    setState(() {
      _chainItems[index] = _chainItems[index].copyWith(
        usePreviousResponse: !_chainItems[index].usePreviousResponse,
      );
    });
  }

  Future<void> _startExecution() async {
    if (_chainItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one request to the chain')),
      );
      return;
    }

    final requestsAsync = ref.read(requestsNotifierProvider);
    final allRequests = requestsAsync.value ?? [];

    final chainRequests = _chainItems
        .map((item) => allRequests.firstWhere((r) => r.id == item.requestId))
        .toList();

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RequestChainExecutionScreen(
            chainItems: _chainItems,
            requests: chainRequests,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(requestsNotifierProvider);
    final selectedRequestIds = _chainItems.map((item) => item.requestId).toSet();
    final isLargeScreen = context.isTablet || context.isDesktop;

    return AppScaffold(
      title: 'Request Chain',
      body: MaxWidthLayout(
        maxWidth: 1200,
        child: requestsAsync.when(
          data: (requests) => isLargeScreen
              ? _buildSplitLayout(context, requests, selectedRequestIds)
              : _buildMobileLayout(context, requests, selectedRequestIds),
          loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildSplitLayout(
    BuildContext context,
    List<ApiRequestModel> requests,
    Set<String> selectedRequestIds,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Available requests list
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Request Chain',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select requests to execute sequentially. Selected requests will appear in the chain on the right.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.folder_open),
                              tooltip: 'Load saved chain',
                              onPressed: _loadSavedChain,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Available Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: requests.isEmpty
                      ? Center(
                          child: Text(
                            'No requests available. Create requests first.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            final isInChain = selectedRequestIds.contains(request.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isInChain
                                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                  : null,
                              child: ListTile(
                                leading: MethodBadge(method: request.method),
                                title: Text(request.name),
                                subtitle: Text(
                                  request.urlTemplate,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isInChain
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => _addRequestToChain(request),
                                        tooltip: 'Add to chain',
                                      ),
                                enabled: !isInChain,
                                onTap: isInChain ? null : () => _addRequestToChain(request),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        // Divider
        Container(
          width: 1,
          color: Theme.of(context).dividerColor,
          margin: const EdgeInsets.symmetric(vertical: 16),
        ),
        // Right side: Chain breadcrumb
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chain Order',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _chainItems.isEmpty
                      ? Center(
                          child: Text(
                            'No requests selected.\nSelect requests from the list to build your chain.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                          ),
                        )
                      : _buildVerticalBreadcrumb(context, requests),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Execute Chain',
                  icon: Icons.play_arrow,
                  onPressed: _chainItems.isEmpty ? null : _startExecution,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<ApiRequestModel> requests,
    Set<String> selectedRequestIds,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Request Chain',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select requests to execute sequentially. You can configure delays between requests and use previous response bodies in subsequent requests.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Chain items
        if (_chainItems.isNotEmpty) ...[
          Text(
            'Chain Order',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._chainItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final request = requests.firstWhere((r) => r.id == item.requestId);
            return _buildChainItemCard(context, request, item, index);
          }),
          const SizedBox(height: 16),
        ],

        // Available requests
        Text(
          'Available Requests',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: requests.isEmpty
              ? Center(
                  child: Text(
                    'No requests available. Create requests first.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final isInChain = selectedRequestIds.contains(request.id);
                    return ListTile(
                      leading: MethodBadge(method: request.method),
                      title: Text(request.name),
                      subtitle: Text(request.urlTemplate),
                      trailing: isInChain
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _addRequestToChain(request),
                            ),
                      enabled: !isInChain,
                    );
                  },
                ),
        ),

        // Execute button
        const SizedBox(height: 16),
        AppButton(
          label: 'Execute Chain',
          icon: Icons.play_arrow,
          onPressed: _chainItems.isEmpty ? null : _startExecution,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildVerticalBreadcrumb(BuildContext context, List<ApiRequestModel> requests) {
    return ListView.builder(
      itemCount: _chainItems.length,
      itemBuilder: (context, index) {
        final item = _chainItems[index];
        final request = requests.firstWhere((r) => r.id == item.requestId);
        return _buildChainItemCard(context, request, item, index);
      },
    );
  }

  Future<void> _loadSavedChain() async {
    final requestsAsync = ref.read(requestsNotifierProvider);
    final requests = requestsAsync.value ?? [];
    
    try {
      final repository = ref.read(savedChainRepositoryProvider);
      final savedChains = await repository.getAllSavedChains();

      if (savedChains.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No saved chains found')),
          );
        }
        return;
      }

      final selectedChain = await showModalBottomSheet<SavedRequestChain>(
        context: context,
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
                    'Load Saved Chain',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a saved chain to load',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: savedChains.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final chain = savedChains[index];
                        return ListTile(
                          title: Text(chain.name),
                          subtitle: chain.description != null && chain.description!.isNotEmpty
                              ? Text(chain.description!)
                              : Text('${chain.chainItems.length} requests'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${chain.chainItems.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () => Navigator.of(sheetContext).pop(chain),
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

      if (selectedChain != null && mounted) {
        await _applySavedChain(selectedChain, requests);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved chains: $e')),
        );
      }
    }
  }

  Future<void> _applySavedChain(SavedRequestChain savedChain, List<ApiRequestModel> allRequests) async {
    // Check if all requests in the saved chain still exist
    final missingRequests = <String>[];
    for (final chainItem in savedChain.chainItems) {
      if (!allRequests.any((r) => r.id == chainItem.requestId)) {
        missingRequests.add(chainItem.requestName);
      }
    }

    if (missingRequests.isNotEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some requests not found'),
          content: Text(
            'The following requests from the saved chain are no longer available:\n\n'
            '${missingRequests.join('\n')}\n\n'
            'Do you want to load the chain anyway? Missing requests will be skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Load Anyway'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    setState(() {
      // Clear existing chain
      for (final controller in _delayControllers.values) {
        controller.dispose();
      }
      _chainItems.clear();
      _delayControllers.clear();

      // Load saved chain items
      for (final chainItem in savedChain.chainItems) {
        // Only add if the request still exists
        if (allRequests.any((r) => r.id == chainItem.requestId)) {
          _chainItems.add(chainItem);
          _delayControllers[chainItem.requestId] =
              TextEditingController(text: chainItem.delayMs.toString());
        }
      }

      // Ensure first item doesn't have usePreviousResponse enabled
      _ensureFirstItemNoPreviousResponse();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded chain: ${savedChain.name}')),
      );
    }
  }

  Widget _buildChainItemCard(
    BuildContext context,
    ApiRequestModel request,
    RequestChainItem item,
    int index,
  ) {
    final delayController = _delayControllers[item.requestId]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Step number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Request info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MethodBadge(method: request.method),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              request.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.urlTemplate,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Move buttons
                if (index > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () => _moveRequestUp(index),
                    tooltip: 'Move up',
                  ),
                if (index < _chainItems.length - 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: () => _moveRequestDown(index),
                    tooltip: 'Move down',
                  ),
                // Remove button
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeRequestFromChain(index),
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Delay configuration
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: delayController,
                    label: 'Delay (ms)',
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateDelay(item.requestId, value),
                  ),
                ),
                const SizedBox(width: 16),
                // Use previous response checkbox
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Use previous response'),
                    subtitle: index == 0
                        ? const Text('Not available for first request')
                        : const Text('Inject previous response body'),
                    value: item.usePreviousResponse && index > 0,
                    enabled: index > 0,
                    onChanged: index > 0
                        ? (value) => _toggleUsePreviousResponse(index)
                        : null,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
