import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/assertion.dart';
import '../../core/models/request_result.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../widgets/widgets.dart';

enum _ResponseTab { body, headers, tests }

class ResponseViewer extends StatefulWidget {
  const ResponseViewer({super.key, required this.result, required this.sending, this.assertionResults = const []});

  final RequestResult? result;
  final bool sending;
  final List<AssertionResult> assertionResults;

  @override
  State<ResponseViewer> createState() => _ResponseViewerState();
}

class _ResponseViewerState extends State<ResponseViewer> {
  _ResponseTab _tab = _ResponseTab.body;
  bool _showRawHtml = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final result = widget.result;

    if (widget.sending) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (result == null) {
      return const EmptyState(icon: Icons.arrow_upward, title: 'No response yet', message: 'Send the request to see its response here.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              StatusBadge(statusCode: result.statusCode, errorMessage: result.errorMessage),
              const SizedBox(width: AppSpacing.md),
              Text('${result.duration.inMilliseconds} ms', style: context.type.caption),
              const SizedBox(width: AppSpacing.md),
              Text('${(result.sizeBytes / 1024).toStringAsFixed(1)} KB', style: context.type.caption),
              const Spacer(),
              if (_tab == _ResponseTab.body && result.isHtml) ...[
                _TabButton(label: 'Preview', selected: !_showRawHtml, onTap: () => setState(() => _showRawHtml = false)),
                const SizedBox(width: AppSpacing.md),
                _TabButton(label: 'Raw', selected: _showRawHtml, onTap: () => setState(() => _showRawHtml = true)),
                const SizedBox(width: AppSpacing.lg),
              ],
              _TabButton(label: 'Body', selected: _tab == _ResponseTab.body, onTap: () => setState(() => _tab = _ResponseTab.body)),
              const SizedBox(width: AppSpacing.md),
              _TabButton(
                label: 'Headers (${result.headers.length})',
                selected: _tab == _ResponseTab.headers,
                onTap: () => setState(() => _tab = _ResponseTab.headers),
              ),
              if (widget.assertionResults.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                _TabButton(
                  label: 'Tests (${widget.assertionResults.where((r) => r.passed).length}/${widget.assertionResults.length})',
                  selected: _tab == _ResponseTab.tests,
                  onTap: () => setState(() => _tab = _ResponseTab.tests),
                ),
              ],
            ],
          ),
        ),
        if (result.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(result.errorMessage!, style: context.type.body.copyWith(color: colors.danger)),
          ),
        Expanded(
          child: switch (_tab) {
            _ResponseTab.body when result.isHtml && !_showRawHtml => _HtmlPreview(html: result.prettyBody),
            _ResponseTab.body => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: MonoText(result.prettyBody),
            ),
            _ResponseTab.headers => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _HeadersList(headers: result.headers),
            ),
            _ResponseTab.tests => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _TestsList(results: widget.assertionResults),
            ),
          },
        ),
      ],
    );
  }
}

class _HtmlPreview extends StatefulWidget {
  const _HtmlPreview({required this.html});

  final String html;

  @override
  State<_HtmlPreview> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<_HtmlPreview> {
  // Below this size, parsing is fast enough to do inline during build.
  // Above it, hand the parse off to a background isolate via `compute`
  // so a large response body can't jank the UI thread.
  static const _syncParseThreshold = 40000;

  late Future<dom.Document> _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = _parse(widget.html);
  }

  @override
  void didUpdateWidget(covariant _HtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _parsed = _parse(widget.html);
    }
  }

  static Future<dom.Document> _parse(String html) {
    if (html.length <= _syncParseThreshold) {
      return SynchronousFuture(html_parser.parse(html));
    }
    return compute(html_parser.parse, html);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.surfaceRaised,
      child: FutureBuilder<dom.Document>(
        future: _parsed,
        builder: (context, snapshot) {
          final document = snapshot.data;
          if (document == null) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectionArea(
              // Isolates the (potentially large) rendered HTML tree from
              // repaints triggered elsewhere in the response panel.
              child: RepaintBoundary(
                child: Html.fromDom(
                  document: document,
                  // Links open in the system browser instead of doing
                  // nothing — flutter_html has no in-app navigation here.
                  onLinkTap: (url, attributes, element) {
                    final uri = url == null ? null : Uri.tryParse(url);
                    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  style: {
                    'body': Style(
                      color: colors.textPrimary,
                      backgroundColor: colors.surfaceRaised,
                      margin: Margins.zero,
                      fontSize: FontSize(14),
                    ),
                    'a': Style(color: colors.accent, textDecoration: TextDecoration.underline),
                    'code': Style(backgroundColor: colors.surfaceSunken, fontFamily: 'JetBrains Mono'),
                    'pre': Style(backgroundColor: colors.surfaceSunken, padding: HtmlPaddings.all(AppSpacing.sm)),
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Text(label, style: context.type.label.copyWith(color: selected ? colors.textPrimary : colors.textMuted)),
    );
  }
}

class _TestsList extends StatelessWidget {
  const _TestsList({required this.results});

  final List<AssertionResult> results;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (results.isEmpty) {
      return Text('No assertions defined for this request.', style: context.type.caption);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final result in results)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.passed ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: result.passed ? colors.success : colors.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.assertion.type.label, style: context.type.body),
                      Text(result.message, style: context.type.caption.copyWith(color: result.passed ? colors.textMuted : colors.danger)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeadersList extends StatelessWidget {
  const _HeadersList({required this.headers});

  final Map<String, List<String>> headers;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return Text('No headers.', style: context.type.caption);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in headers.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: RichText(
              text: TextSpan(
                style: context.type.monoSmall,
                children: [
                  TextSpan(
                    text: '${entry.key}: ',
                    style: context.type.monoSmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: entry.value.join(', ')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
