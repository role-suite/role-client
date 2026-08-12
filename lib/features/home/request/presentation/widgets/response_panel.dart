import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:relay/core/presentation/widgets/code_block.dart';
import 'package:relay/core/presentation/widgets/status_badge.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/core/utils/json.dart';

enum ResponseBodyViewMode { pretty, raw, preview }

/// A standard REST-client style response viewer: a status/time/size meta
/// row followed by Body/Headers tabs.
class ResponsePanel extends StatefulWidget {
  const ResponsePanel({
    super.key,
    required this.isSending,
    required this.response,
    required this.error,
    required this.duration,
    required this.isPermissionError,
  });

  final bool isSending;
  final ApiResponse<dynamic>? response;
  final ApiServiceException? error;
  final Duration? duration;
  final bool isPermissionError;

  @override
  State<ResponsePanel> createState() => _ResponsePanelState();
}

class _ResponsePanelState extends State<ResponsePanel> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ResponseBodyViewMode _viewMode = ResponseBodyViewMode.pretty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewMode = _looksLikeHtml(widget.response) ? ResponseBodyViewMode.preview : ResponseBodyViewMode.pretty;
  }

  @override
  void didUpdateWidget(covariant ResponsePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.response != widget.response) {
      _viewMode = _looksLikeHtml(widget.response) ? ResponseBodyViewMode.preview : ResponseBodyViewMode.pretty;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetaRow(context),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              indicator: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [Tab(text: 'Body'), Tab(text: 'Headers')],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 360,
            child: TabBarView(controller: _tabController, children: [_buildBodyTab(context), _buildHeadersTab(context)]),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context) {
    final theme = Theme.of(context);
    final statusCode = widget.response?.statusCode;
    final durationText = widget.duration != null ? '${widget.duration!.inMilliseconds} ms' : '--';
    final sizeText = widget.response != null ? _formatBytes(_estimateSizeInBytes(widget.response!.data)) : '--';

    Widget metricChip(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: Text(
          '$label: $value',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusBadge(statusCode: statusCode),
        metricChip('Time', durationText),
        metricChip('Size', sizeText),
        if (widget.isSending) const SizedBox(width: 120, child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _buildBodyTab(BuildContext context) {
    if (widget.isSending) {
      return _statusMessage(context, 'Sending request...');
    }
    if (widget.error != null && widget.response == null) {
      if (widget.isPermissionError) {
        return _permissionErrorPanel(context);
      }
      return _statusMessage(context, 'Error: ${widget.error!.message}', color: Theme.of(context).colorScheme.error);
    }
    if (widget.response == null) {
      return _statusMessage(context, 'Send the request to see the response.');
    }

    final response = widget.response!;
    final isHtml = _looksLikeHtml(response);
    final rawBody = _extractBodyAsString(response);
    final prettyBody = JsonUtils.pretty(response.data);
    final effectiveMode = _viewMode == ResponseBodyViewMode.preview && !isHtml ? ResponseBodyViewMode.pretty : _viewMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildViewModeSwitcher(canPreview: isHtml),
        const SizedBox(height: 8),
        Expanded(child: _buildBodyContent(context, effectiveMode, rawBody, prettyBody, isHtml)),
      ],
    );
  }

  Widget _buildBodyContent(BuildContext context, ResponseBodyViewMode mode, String? rawBody, String prettyBody, bool isHtml) {
    switch (mode) {
      case ResponseBodyViewMode.pretty:
        final rendered = prettyBody.isEmpty ? (rawBody ?? '') : prettyBody;
        return CodeBlock(code: rendered.isEmpty ? 'No response body' : rendered);
      case ResponseBodyViewMode.raw:
        final rendered = rawBody ?? prettyBody;
        return CodeBlock(code: rendered.isEmpty ? 'No response body' : rendered);
      case ResponseBodyViewMode.preview:
        if (isHtml && rawBody != null && rawBody.trim().isNotEmpty) {
          return _htmlPanel(context, rawBody);
        }
        return _statusMessage(context, 'Preview is available for HTML responses only.');
    }
  }

  Widget _buildViewModeSwitcher({required bool canPreview}) {
    final switcher = SegmentedButton<ResponseBodyViewMode>(
      segments: [
        const ButtonSegment(value: ResponseBodyViewMode.pretty, label: Text('Pretty')),
        const ButtonSegment(value: ResponseBodyViewMode.raw, label: Text('Raw')),
        ButtonSegment(value: ResponseBodyViewMode.preview, enabled: canPreview, label: const Text('Preview')),
      ],
      selected: {_viewMode},
      showSelectedIcon: false,
      onSelectionChanged: (modes) {
        if (modes.isEmpty) return;
        setState(() => _viewMode = modes.first);
      },
    );
    return Align(alignment: Alignment.centerLeft, child: switcher);
  }

  Widget _buildHeadersTab(BuildContext context) {
    if (widget.isSending) {
      return _statusMessage(context, 'Sending request...');
    }
    if (widget.error != null && widget.response == null) {
      if (widget.isPermissionError) {
        return _permissionErrorPanel(context);
      }
      return _statusMessage(context, 'Error: ${widget.error!.message}', color: Theme.of(context).colorScheme.error);
    }
    if (widget.response == null) {
      return _statusMessage(context, 'Send the request to see the response headers.');
    }

    final headers = widget.response!.headers.map((key, values) => MapEntry(key, values.join(', ')));
    final content = headers.isEmpty ? 'No response headers' : JsonUtils.pretty(headers);
    return CodeBlock(code: content);
  }

  Widget _permissionErrorPanel(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Network access is blocked by the operating system (permission error).',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(widget.error!.message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          Text(
            'On macOS, please:\n'
            '- Ensure any firewall or security tool allows this app to access the network.\n'
            '- If using a VPN or proxy, verify it permits outbound HTTPS connections.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _htmlPanel(BuildContext context, String html) {
    final theme = Theme.of(context);
    final hasTableTag = RegExp(r'<\s*table[\s>]', caseSensitive: false).hasMatch(html);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTableTag)
            Text(
              'HTML preview is unavailable for responses containing table markup. Use Raw to inspect the response body.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            HtmlWidget(html, textStyle: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('Raw HTML', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CodeBlock(code: html),
        ],
      ),
    );
  }

  Widget _statusMessage(BuildContext context, String message, {Color? color}) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color), textAlign: TextAlign.center),
    );
  }

  bool _looksLikeHtml(ApiResponse<dynamic>? response) {
    if (response == null) return false;
    final contentType = response.headerValue('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('text/html') || contentType.contains('application/xhtml')) {
      return true;
    }
    final body = _extractBodyAsString(response);
    if (body == null) return false;
    final snippet = body.trimLeft().toLowerCase();
    if (snippet.isEmpty) return false;
    return snippet.startsWith('<!doctype html') || snippet.startsWith('<html') || (snippet.contains('<html') && snippet.contains('</html>'));
  }

  String? _extractBodyAsString(ApiResponse<dynamic> response) {
    final data = response.data;
    if (data == null) return null;
    if (data is String) return data;
    if (data is List<int>) {
      try {
        return utf8.decode(data);
      } catch (_) {
        return String.fromCharCodes(data);
      }
    }
    return null;
  }

  int _estimateSizeInBytes(dynamic data) {
    if (data == null) return 0;
    if (data is List<int>) return data.length;
    if (data is String) return utf8.encode(data).length;
    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return utf8.encode(data.toString()).length;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}
