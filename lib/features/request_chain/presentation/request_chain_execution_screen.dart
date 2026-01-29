import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/core/presentation/widgets/status_badge.dart';
import 'package:relay/core/presentation/layout/scaffold.dart';
import 'package:relay/core/presentation/layout/max_width_layout.dart';
import 'package:relay/core/utils/uuid.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/request_chain/domain/models/request_chain_item.dart';
import 'package:relay/features/request_chain/domain/models/request_chain_result.dart';
import 'package:relay/features/request_chain/domain/models/saved_request_chain.dart';
import 'package:relay/features/request_chain/presentation/providers/request_chain_providers.dart';

class RequestChainExecutionScreen extends ConsumerStatefulWidget {
  const RequestChainExecutionScreen({
    super.key,
    required this.chainItems,
    required this.requests,
  });

  final List<RequestChainItem> chainItems;
  final List<ApiRequestModel> requests;

  @override
  ConsumerState<RequestChainExecutionScreen> createState() => _RequestChainExecutionScreenState();
}

class _RequestChainExecutionScreenState extends ConsumerState<RequestChainExecutionScreen> {
  RequestChainResult? _result;
  bool _isExecuting = false;
  int _currentRequestIndex = -1;
  final Map<int, RequestChainItemResult> _completedResults = {};

  Future<void> _executeChain() async {
    setState(() {
      _isExecuting = true;
      _currentRequestIndex = -1;
      _completedResults.clear();
      _result = null;
    });

    try {
      final chainService = ref.read(requestChainServiceProvider);
      final environmentRepository = ref.read(environmentRepositoryProvider);
      final activeEnvironment = await environmentRepository.getActiveEnvironment();

      final result = await chainService.executeChain(
        chainItems: widget.chainItems,
        requests: widget.requests,
        environment: activeEnvironment,
        onRequestStart: (index, request) {
          if (mounted) {
            setState(() {
              _currentRequestIndex = index;
            });
          }
        },
        onRequestComplete: (index, result) {
          if (mounted) {
            setState(() {
              _completedResults[index] = result;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isExecuting = false;
          _currentRequestIndex = -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _currentRequestIndex = -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error executing chain: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Request Chain Execution',
      body: MaxWidthLayout(
        maxWidth: 1200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chain Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (!_isExecuting && _result == null)
                          AppButton(
                            label: 'Start Execution',
                            icon: Icons.play_arrow,
                            onPressed: _executeChain,
                          )
                        else if (!_isExecuting && _result != null)
                          AppButton(
                            label: 'Save Chain',
                            icon: Icons.save,
                            onPressed: _showSaveChainDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Total requests: ${widget.chainItems.length}'),
                    if (_result != null) ...[
                      const SizedBox(height: 4),
                      Text('Success: ${_result!.successCount}'),
                      const SizedBox(height: 4),
                      Text('Failed: ${_result!.failureCount}'),
                      const SizedBox(height: 4),
                      Text('Total duration: ${_formatDuration(_result!.totalDuration)}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Request list
            Expanded(
              child: ListView.builder(
                itemCount: widget.chainItems.length,
                itemBuilder: (context, index) {
                  final chainItem = widget.chainItems[index];
                  final request = widget.requests[index];
                  final result = _completedResults[index];
                  final isCurrent = _currentRequestIndex == index;
                  final isExecuting = _isExecuting && isCurrent;
                  final isCompleted = result != null;
                  // First request (index 0) can never use previous response
                  final canUsePreviousResponse = index > 0 && chainItem.usePreviousResponse;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isCurrent && _isExecuting
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
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
                                  color: isCompleted
                                      ? (result.success ? Colors.green : Colors.red)
                                      : isCurrent
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isExecuting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: isCompleted || isCurrent
                                                ? Colors.white
                                                : Colors.black,
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
                                        if (isCompleted) StatusBadge(statusCode: result.response?.statusCode),
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
                            ],
                          ),

                          // Configuration info
                          if (chainItem.delayMs > 0 || canUsePreviousResponse) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (chainItem.delayMs > 0)
                                  Chip(
                                    label: Text('Delay: ${chainItem.delayMs}ms'),
                                    avatar: const Icon(Icons.timer, size: 16),
                                  ),
                                if (canUsePreviousResponse)
                                  Chip(
                                    label: const Text('Uses previous response'),
                                    avatar: const Icon(Icons.link, size: 16),
                                  ),
                              ],
                            ),
                          ],

                          // Result details
                          if (isCompleted) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Duration: ${_formatDuration(result.duration)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  result.success ? '✓ Success' : '✗ Failed',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: result.success ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            if (result.error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Error: ${result.error!.message}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.red,
                                    ),
                              ),
                            ],
                            if (result.response != null) ...[
                              const SizedBox(height: 8),
                              ExpansionTile(
                                title: const Text('Response Body'),
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        _formatResponseBody(result.response!.data),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontFamily: 'monospace',
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
    }
  }

  String _formatResponseBody(dynamic data) {
    if (data == null) return 'null';
    if (data is String) return data;
    if (data is Map || data is List) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return data.toString();
  }

  Future<void> _showSaveChainDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Request Chain'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: nameController,
                  label: 'Chain Name',
                  hint: 'e.g., User Registration Flow',
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: descriptionController,
                  label: 'Description (optional)',
                  hint: 'Describe what this chain does',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      await _saveChain(
        name: nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );
    }

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _saveChain({required String name, String? description}) async {
    try {
      final repository = ref.read(savedChainRepositoryProvider);
      final now = DateTime.now();
      final chain = SavedRequestChain(
        id: UuidUtils.generate(),
        name: name,
        description: description,
        chainItems: widget.chainItems,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveChain(chain);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chain "$name" saved successfully'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving chain: $e')),
        );
      }
    }
  }
}
