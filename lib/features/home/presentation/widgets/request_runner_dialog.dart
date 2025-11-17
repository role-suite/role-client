import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/core/service/api_service.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/ui/widgets/widgets.dart';

class RequestRunnerDialog extends ConsumerStatefulWidget {
  const RequestRunnerDialog({
    super.key,
    required this.request,
    this.onDelete,
  });

  final ApiRequestModel request;
  final VoidCallback? onDelete;

  @override
  ConsumerState<RequestRunnerDialog> createState() => _RequestRunnerDialogState();
}

class _RequestRunnerDialogState extends ConsumerState<RequestRunnerDialog> {
  bool _isSending = false;
  Response<dynamic>? _response;
  DioException? _error;
  Duration? _duration;
  bool _isPermissionError = false;

  Future<void> _sendRequest() async {
    setState(() {
      _isSending = true;
      _error = null;
      _response = null;
      _duration = null;
      _isPermissionError = false;
    });

    final envRepository = ref.read(environmentRepositoryProvider);
    final activeEnv = await envRepository.getActiveEnvironment();

    // Resolve templates using the active environment
    final resolvedUrl = envRepository.resolveTemplate(widget.request.urlTemplate, activeEnv);
    final resolvedHeaders = <String, String>{
      for (final entry in widget.request.headers.entries)
        entry.key: envRepository.resolveTemplate(entry.value, activeEnv),
    };
    final resolvedQueryParams = <String, String>{
      for (final entry in widget.request.queryParams.entries)
        entry.key: envRepository.resolveTemplate(entry.value, activeEnv),
    };
    final rawBody = widget.request.body;
    final resolvedBody = (rawBody != null && rawBody.trim().isNotEmpty)
        ? envRepository.resolveTemplate(rawBody, activeEnv)
        : null;

    // Debug logging for easier troubleshooting
    debugPrint('==== Relay Request ====');
    debugPrint('Name: ${widget.request.name}');
    debugPrint('Method: ${widget.request.method.name}');
    debugPrint('Active environment: ${activeEnv?.name}');
    debugPrint('Resolved URL: $resolvedUrl');
    debugPrint('Resolved headers: $resolvedHeaders');
    debugPrint('Resolved query params: $resolvedQueryParams');
    debugPrint('Resolved body: $resolvedBody');

    final dio = ApiService.instance.dio;

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.request<dynamic>(
        resolvedUrl,
        options: Options(
          method: widget.request.method.name,
          headers: resolvedHeaders.isEmpty ? null : resolvedHeaders,
        ),
        queryParameters: resolvedQueryParams.isEmpty ? null : resolvedQueryParams,
        data: resolvedBody,
      );
      stopwatch.stop();
      setState(() {
        _response = response;
        _duration = stopwatch.elapsed;
      });
    } on DioException catch (e) {
      stopwatch.stop();
      debugPrint('DioException while sending request:');
      debugPrint('  type: ${e.type}');
      debugPrint('  message: ${e.message}');
      debugPrint('  error: ${e.error}');
      debugPrint('  status code: ${e.response?.statusCode}');
      debugPrint('  status message: ${e.response?.statusMessage}');
      debugPrint('  data: ${e.response?.data}');

      // Detect macOS-style permission errors (Operation not permitted / errno = 1)
      bool permissionError = false;
      final underlying = e.error;
      if (underlying is SocketException) {
        final osError = underlying.osError;
        final code = osError?.errorCode;
        final message = osError?.message.toLowerCase() ?? '';
        if (code == 1 || message.contains('operation not permitted')) {
          permissionError = true;
        }
      }

      setState(() {
        _error = e;
        _response = e.response;
        _duration = stopwatch.elapsed;
        _isPermissionError = permissionError;
      });
    } catch (e) {
      stopwatch.stop();
      debugPrint('Unexpected error while sending request: $e');
      setState(() {
        _error = DioException(
          requestOptions: RequestOptions(path: resolvedUrl),
          error: e,
        );
        _duration = stopwatch.elapsed;
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return AlertDialog(
      title: Row(
        children: [
          MethodBadge(method: request.method),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // URL
              Text(
                request.urlTemplate,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              if (request.description != null && request.description!.isNotEmpty) ...[
                Text(
                  request.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              // Send button + meta
              Row(
                children: [
                  AppButton(
                    label: _isSending ? 'Sending...' : 'Send',
                    icon: Icons.play_arrow,
                    onPressed: _isSending ? null : _sendRequest,
                  ),
                  const SizedBox(width: 16),
                  if (_response != null || _error != null)
                    _buildMetaInfo(context),
                ],
              ),
              const SizedBox(height: 16),
              if (_isSending) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              // Response section
              _buildResponseSection(context),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: widget.onDelete,
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildMetaInfo(BuildContext context) {
    final statusCode = _response?.statusCode;
    final statusText = _response?.statusMessage;

    final durationText = _duration != null
        ? '${_duration!.inMilliseconds} ms'
        : null;

    return Row(
      children: [
        if (statusCode != null) ...[
          Text(
            '$statusCode ${statusText ?? ''}'.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusCode >= 200 && statusCode < 300
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 12),
        ],
        if (durationText != null)
          Text(
            durationText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildResponseSection(BuildContext context) {
    if (_isSending) {
      return Text(
        'Sending request...',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    if (_error != null && _response == null) {
      final baseError =
          _error!.message ?? _error!.error?.toString() ?? _error.toString();

      if (_isPermissionError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network access is blocked by the operating system (permission error).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              baseError,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'On macOS, please:\n'
              '- Ensure any firewall or security tool allows this app to access the network.\n'
              '- If using a VPN or proxy, verify it permits outbound HTTPS connections.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }

      return Text(
        'Error: $baseError',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
      );
    }

    if (_response == null) {
      return Text(
        'Send the request to see the response.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    final headers = _response!.headers.map.map(
      (key, values) => MapEntry(key, values.join(', ')),
    );

    final bodyText = _formatBody(_response!.data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Response Body',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: SelectableText(
              bodyText,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Response Headers',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: SelectableText(
              headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }

  String _formatBody(dynamic data) {
    try {
      if (data is Map<String, dynamic> || data is List<dynamic>) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
      if (data is String) {
        // Try to pretty-print JSON if possible
        final dynamic decoded = json.decode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }
      return data.toString();
    } catch (_) {
      return data?.toString() ?? '';
    }
  }
}


