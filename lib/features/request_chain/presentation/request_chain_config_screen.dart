import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/core/presentation/layout/scaffold.dart';
import 'package:relay/core/presentation/layout/max_width_layout.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';
import 'package:relay/features/request_chain/domain/models/request_chain_item.dart';
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
    });
  }

  void _removeRequestFromChain(int index) {
    setState(() {
      final item = _chainItems.removeAt(index);
      _delayControllers[item.requestId]?.dispose();
      _delayControllers.remove(item.requestId);
    });
  }

  void _moveRequestUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _chainItems.removeAt(index);
        _chainItems.insert(index - 1, item);
      });
    }
  }

  void _moveRequestDown(int index) {
    if (index < _chainItems.length - 1) {
      setState(() {
        final item = _chainItems.removeAt(index);
        _chainItems.insert(index + 1, item);
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

    return AppScaffold(
      title: 'Request Chain',
      body: MaxWidthLayout(
        maxWidth: 1200,
        child: requestsAsync.when(
          data: (requests) => Column(
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
                ...List.generate(_chainItems.length, (index) {
                  final item = _chainItems[index];
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
          ),
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
