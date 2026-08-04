import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/core/utils/request_build_helper.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

import '../controllers/request_form_controller.dart';
import 'request_editor.dart';
import 'response_panel.dart';

class RequestWorkbenchTab extends ConsumerStatefulWidget {
  const RequestWorkbenchTab({
    super.key,
    required this.request,
    this.onDelete,
    this.onRequestSaved,
  });

  final ApiRequestModel request;
  final VoidCallback? onDelete;
  final ValueChanged<ApiRequestModel>? onRequestSaved;

  @override
  ConsumerState<RequestWorkbenchTab> createState() => _RequestWorkbenchTabState();
}

class _RequestWorkbenchTabState extends ConsumerState<RequestWorkbenchTab> {
  late ApiRequestModel _currentRequest;
  late RequestFormController _formController;
  bool _isSending = false;
  bool _isSaving = false;
  ApiResponse<dynamic>? _response;
  ApiServiceException? _error;
  Duration? _duration;
  bool _isPermissionError = false;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _formController = RequestFormController(initialRequest: _currentRequest);
  }

  @override
  void didUpdateWidget(covariant RequestWorkbenchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id || oldWidget.request.updatedAt != widget.request.updatedAt) {
      _formController.dispose();
      setState(() {
        _currentRequest = widget.request;
        _formController = RequestFormController(initialRequest: _currentRequest);
        _response = null;
        _error = null;
        _duration = null;
      });
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    setState(() {
      _isSending = true;
      _error = null;
      _response = null;
      _duration = null;
      _isPermissionError = false;
    });

    final envRepository = ref.read(environmentRepositoryProvider);
    final request = _formController.buildUpdatedRequest(id: _currentRequest.id, createdAt: _currentRequest.createdAt);

    EnvironmentModel? environment;
    if (request.environmentName != null) {
      environment = await envRepository.getEnvironmentByName(request.environmentName!);
    }
    environment ??= await envRepository.getActiveEnvironment();

    String resolve(String s) => envRepository.resolveTemplate(s, environment);
    final resolvedUrl = resolve(request.urlTemplate);
    final resolvedQueryParams = <String, String>{for (final entry in request.queryParams.entries) entry.key: resolve(entry.value)};
    final built = RequestBuildHelper.buildForSend(request, resolve, rawBody: _formController.bodyController.text);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await ApiService.instance.send<dynamic>(
        method: request.method.name,
        url: resolvedUrl,
        headers: built.headers.isEmpty ? null : built.headers,
        queryParameters: resolvedQueryParams.isEmpty ? null : resolvedQueryParams,
        data: built.body,
      );
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _response = response;
        _duration = stopwatch.elapsed;
      });
    } on ApiServiceException catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _error = e;
        _duration = stopwatch.elapsed;
        _isPermissionError = e.isPermissionError;
      });
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _error = ApiServiceException(message: e.toString(), cause: e);
        _duration = stopwatch.elapsed;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _saveEdits() async {
    final validationError = _formController.validateRequiredFields();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError), backgroundColor: Colors.orange));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final updatedRequest = _formController.buildUpdatedRequest(id: _currentRequest.id, createdAt: _currentRequest.createdAt);

    setState(() => _isSaving = true);
    try {
      await ref.read(requestsNotifierProvider.notifier).updateRequest(updatedRequest);
      if (!mounted) return;
      setState(() {
        _currentRequest = updatedRequest;
        _isSaving = false;
      });
      widget.onRequestSaved?.call(updatedRequest);
      messenger.showSnackBar(SnackBar(content: Text('Request "${updatedRequest.name}" updated successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed to update request: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  MethodBadge(method: _formController.selectedMethod),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentRequest.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RequestEditor(
                      controller: _formController,
                      isSending: _isSending,
                      isSaving: _isSaving,
                      onSend: _sendRequest,
                      onSave: _saveEdits,
                      onDelete: widget.onDelete,
                    ),
                    if (_response != null || _error != null || _isSending) ...[
                      const SizedBox(height: 14),
                      ResponsePanel(
                        isSending: _isSending,
                        response: _response,
                        error: _error,
                        duration: _duration,
                        isPermissionError: _isPermissionError,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
