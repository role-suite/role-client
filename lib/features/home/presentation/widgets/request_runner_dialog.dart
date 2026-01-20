import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/core/utils/json.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';

import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/method_badge.dart';
import '../../../../core/presentation/widgets/variable_highlight_text.dart';

class RequestRunnerPage extends ConsumerStatefulWidget {
  const RequestRunnerPage({super.key, required this.request, this.onDelete});

  final ApiRequestModel request;
  final VoidCallback? onDelete;

  @override
  ConsumerState<RequestRunnerPage> createState() => _RequestRunnerPageState();
}

class _RequestRunnerPageState extends ConsumerState<RequestRunnerPage> {
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
    
    // Use request's saved environment if it exists, otherwise use active environment
    EnvironmentModel? environment;
    if (widget.request.environmentName != null) {
      environment = await envRepository.getEnvironmentByName(widget.request.environmentName!);
    }
    environment ??= await envRepository.getActiveEnvironment();

    // Resolve templates using the selected environment
    final resolvedUrl = envRepository.resolveTemplate(widget.request.urlTemplate, environment);
    final resolvedHeaders = <String, String>{
      for (final entry in widget.request.headers.entries) entry.key: envRepository.resolveTemplate(entry.value, environment),
    };
    final resolvedQueryParams = <String, String>{
      for (final entry in widget.request.queryParams.entries) entry.key: envRepository.resolveTemplate(entry.value, environment),
    };
    final rawBody = widget.request.body;
    final resolvedBody = (rawBody != null && rawBody.trim().isNotEmpty) ? envRepository.resolveTemplate(rawBody, environment) : null;

    // Debug logging for easier troubleshooting
    debugPrint('==== Relay Request ====');
    debugPrint('Name: ${widget.request.name}');
    debugPrint('Method: ${widget.request.method.name}');
    debugPrint('Request environment: ${widget.request.environmentName}');
    debugPrint('Using environment: ${environment?.name}');
    debugPrint('Resolved URL: $resolvedUrl');
    debugPrint('Resolved headers: $resolvedHeaders');
    debugPrint('Resolved query params: $resolvedQueryParams');
    debugPrint('Resolved body: $resolvedBody');

    final dio = ApiService.instance.dio;

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.request<dynamic>(
        resolvedUrl,
        options: Options(method: widget.request.method.name, headers: resolvedHeaders.isEmpty ? null : resolvedHeaders),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            MethodBadge(method: request.method),
            const SizedBox(width: 12),
            Expanded(child: Text(request.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (widget.onDelete != null) IconButton(tooltip: 'Delete request', icon: const Icon(Icons.delete_outline), onPressed: widget.onDelete),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // URL
                    VariableHighlightText(
                      text: request.urlTemplate,
                      style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    if (request.description != null && request.description!.isNotEmpty) ...[
                      Text(request.description!, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 12),
                    ],
                    // Request/response details combined into a single tab controller
                    DefaultTabController(
                      length: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TabBar(
                            isScrollable: true,
                            labelColor: theme.colorScheme.primary,
                            indicatorColor: theme.colorScheme.primary,
                            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                            tabs: const [
                              Tab(text: 'Request Body'),
                              Tab(text: 'Request Headers'),
                              Tab(text: 'Response Body'),
                              Tab(text: 'Response Headers'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 320,
                            child: TabBarView(
                              children: [
                                _buildRequestBodyTab(context),
                                _buildRequestHeadersTab(context),
                                _buildResponseBodyTab(context),
                                _buildResponseHeadersTab(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Send button + meta
                    Row(
                      children: [
                        AppButton(label: _isSending ? 'Sending...' : 'Send', icon: Icons.play_arrow, onPressed: _isSending ? null : _sendRequest),
                        const SizedBox(width: 16),
                        if (_response != null || _error != null) _buildMetaInfo(context),
                        const Spacer(),
                        if (_isSending) const SizedBox(width: 120, child: LinearProgressIndicator()),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaInfo(BuildContext context) {
    final statusCode = _response?.statusCode;
    final statusText = _response?.statusMessage;

    final durationText = _duration != null ? '${_duration!.inMilliseconds} ms' : null;

    return Row(
      children: [
        if (statusCode != null) ...[
          Text(
            '$statusCode ${statusText ?? ''}'.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: statusCode >= 200 && statusCode < 300 ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
        ],
        if (durationText != null) Text(durationText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildRequestBodyTab(BuildContext context) {
    final body = widget.request.body;
    final content = body == null || body.trim().isEmpty ? 'No request body' : _prettifyContent(body);
    return _buildMonospacePanel(context, content);
  }

  Widget _buildRequestHeadersTab(BuildContext context) {
    final headers = widget.request.headers;
    final content = headers.isEmpty ? 'No request headers' : _prettifyMap(headers);
    return _buildMonospacePanel(context, content);
  }

  Widget _buildResponseBodyTab(BuildContext context) {
    if (_isSending) {
      return _buildStatusPanel(context, 'Sending request...');
    }

    if (_error != null && _response == null) {
      final baseError = _error!.message ?? _error!.error?.toString() ?? _error.toString();
      if (_isPermissionError) {
        return _buildPermissionErrorPanel(context, baseError);
      }
      return _buildStatusPanel(context, 'Error: $baseError', color: Theme.of(context).colorScheme.error);
    }

    if (_response == null) {
      return _buildStatusPanel(context, 'Send the request to see the response.', color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    final isHtml = _isHtmlResponseBody();
    final rawBody = _extractResponseBodyAsString();
    if (isHtml && rawBody != null && rawBody.trim().isNotEmpty) {
      return _buildHtmlPanel(context, rawBody);
    }

    final bodyText = _prettifyContent(_response!.data);
    final content = bodyText.isEmpty ? 'No response body' : bodyText;
    return _buildMonospacePanel(context, content);
  }

  Widget _buildResponseHeadersTab(BuildContext context) {
    if (_isSending) {
      return _buildStatusPanel(context, 'Sending request...');
    }

    if (_error != null && _response == null) {
      final baseError = _error!.message ?? _error!.error?.toString() ?? _error.toString();
      if (_isPermissionError) {
        return _buildPermissionErrorPanel(context, baseError);
      }
      return _buildStatusPanel(context, 'Error: $baseError', color: Theme.of(context).colorScheme.error);
    }

    if (_response == null) {
      return _buildStatusPanel(context, 'Send the request to see the response headers.', color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    final headers = _response!.headers.map.map((key, values) => MapEntry(key, values.join(', ')));
    final content = headers.isEmpty ? 'No response headers' : _prettifyMap(headers);
    return _buildMonospacePanel(context, content);
  }

  Widget _buildPermissionErrorPanel(BuildContext context, String baseError) {
    final theme = Theme.of(context);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network access is blocked by the operating system (permission error).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(baseError, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Text(
              'On macOS, please:\n'
              '- Ensure any firewall or security tool allows this app to access the network.\n'
              '- If using a VPN or proxy, verify it permits outbound HTTPS connections.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context, String message, {Color? color}) {
    final theme = Theme.of(context);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ),
    );
  }

  Widget _buildMonospacePanel(BuildContext context, String content) {
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: VariableHighlightText(
          text: content,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildPanelContainer(BuildContext context, Widget child) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildHtmlPanel(BuildContext context, String html) {
    final theme = Theme.of(context);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HtmlWidget(html, textStyle: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('Raw HTML', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(html, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  bool _isHtmlResponseBody() {
    if (_response == null) {
      return false;
    }

    final contentType = _response!.headers.value('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('text/html') || contentType.contains('application/xhtml')) {
      return true;
    }

    final body = _extractResponseBodyAsString();
    if (body == null) {
      return false;
    }

    final snippet = body.trimLeft().toLowerCase();
    if (snippet.isEmpty) {
      return false;
    }

    return snippet.startsWith('<!doctype html') || snippet.startsWith('<html') || (snippet.contains('<html') && snippet.contains('</html>'));
  }

  String? _extractResponseBodyAsString() {
    final data = _response?.data;
    if (data == null) {
      return null;
    }

    if (data is String) {
      return data;
    }

    if (data is List<int>) {
      try {
        return utf8.decode(data);
      } catch (_) {
        return String.fromCharCodes(data);
      }
    }

    return null;
  }

  String _prettifyContent(dynamic data) {
    return JsonUtils.pretty(data);
  }

  String _prettifyMap(Map data) {
    return JsonUtils.pretty(data);
  }
}
