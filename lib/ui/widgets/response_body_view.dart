import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/request_result.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import 'app_button.dart';

/// Renders a response body without ever handing a multi-megabyte string to a
/// single text widget. A single `SelectableText` holding several megabytes of
/// pretty-printed JSON exceeds Flutter's text layout limits and renders
/// corrupted glyphs at the end of the text, besides janking the UI, so this
/// viewer instead:
///
/// - skips pretty-printing above [maxPrettyChars] (pretty output is several
///   times the wire size and expensive to build),
/// - renders at most [maxDisplayChars] of text, with a notice and a
///   copy-the-full-body action,
/// - splits the text into lines (hard-wrapping very long lines) and
///   virtualizes them through a `ListView.builder`, so only visible lines are
///   ever laid out.
class ResponseBodyView extends StatefulWidget {
  const ResponseBodyView({
    super.key,
    required this.result,
    this.maxPrettyChars = _defaultMaxPrettyChars,
    this.maxDisplayChars = _defaultMaxDisplayChars,
  });

  static const int _defaultMaxPrettyChars = 2 * 1024 * 1024;
  static const int _defaultMaxDisplayChars = 512 * 1024;

  /// Above this body size the raw text is shown instead of pretty-printing.
  final int maxPrettyChars;

  /// Maximum number of characters handed to the list; the rest is elided
  /// behind a notice (the full body stays available through copy).
  final int maxDisplayChars;

  final RequestResult result;

  @override
  State<ResponseBodyView> createState() => _ResponseBodyViewState();
}

class _ResponseBodyViewState extends State<ResponseBodyView> {
  static const int _maxLineChars = 2000;

  final ScrollController _controller = ScrollController();
  late _BodyPresentation _presentation;
  late List<String> _lines;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(ResponseBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result) ||
        oldWidget.maxPrettyChars != widget.maxPrettyChars ||
        oldWidget.maxDisplayChars != widget.maxDisplayChars) {
      _recompute();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recompute() {
    _presentation = _BodyPresentation.of(widget.result, maxPrettyChars: widget.maxPrettyChars, maxDisplayChars: widget.maxDisplayChars);
    _lines = _splitLines(_presentation.text, maxLineChars: _maxLineChars);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _presentation.fullText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response body copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final presentation = _presentation;

    if (presentation.fullText.isEmpty) {
      return Center(child: Text('No response body.', style: context.type.caption));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presentation.notice != null)
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: colors.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(presentation.notice!, style: context.type.caption)),
                AppIconButton(icon: Icons.copy_all_outlined, tooltip: 'Copy full body', onPressed: _copy),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.xs),
              child: AppIconButton(icon: Icons.copy_all_outlined, tooltip: 'Copy full body', onPressed: _copy),
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _controller,
            child: SelectionArea(
              child: ListView.builder(
                controller: _controller,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _lines.length,
                itemBuilder: (context, index) => Text(_lines[index], style: context.type.mono),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What to show for a result: the text to render, the full text for copying,
/// and an optional notice explaining any elision.
class _BodyPresentation {
  const _BodyPresentation({required this.text, required this.fullText, this.notice});

  final String text;
  final String fullText;
  final String? notice;

  static _BodyPresentation of(RequestResult result, {required int maxPrettyChars, required int maxDisplayChars}) {
    final prettyAllowed = result.sizeBytes <= maxPrettyChars;
    final fullText = prettyAllowed ? result.prettyBody : _rawText(result);
    final truncated = fullText.length > maxDisplayChars;
    final text = truncated ? _truncate(fullText, maxDisplayChars) : fullText;

    final reasons = <String>[];
    if (!prettyAllowed) reasons.add('pretty-printing is disabled above ${formatBodySize(maxPrettyChars)}');
    if (truncated) reasons.add('showing the first ${formatBodySize(text.length)}');
    final notice = reasons.isEmpty ? null : 'Response is ${formatBodySize(result.sizeBytes)}; ${reasons.join('; ')}.';

    return _BodyPresentation(text: text, fullText: fullText, notice: notice);
  }

  static String _rawText(RequestResult result) {
    final body = result.body;
    return body is String ? body : result.prettyBody;
  }

  /// Truncates at the last line break within the cap when there is one close
  /// enough to the cap, so the visible text never ends mid-line.
  static String _truncate(String text, int maxChars) {
    final breakIndex = text.lastIndexOf('\n', maxChars);
    final end = breakIndex > maxChars ~/ 2 ? breakIndex : maxChars;
    final safeEnd = _safeEnd(text, end);
    return text.substring(0, safeEnd);
  }

  static int _safeEnd(String text, int end) {
    if (end <= 0 || end >= text.length) return math.min(end, text.length);
    final unit = text.codeUnitAt(end - 1);
    return _isHighSurrogate(unit) ? end - 1 : end;
  }
}

/// Splits [text] into lines, hard-wrapping any line longer than [maxLineChars]
/// so no single rendered line can itself become a giant text blob.
List<String> _splitLines(String text, {required int maxLineChars}) {
  final lines = <String>[];
  for (final line in text.split('\n')) {
    if (line.length <= maxLineChars) {
      lines.add(line);
      continue;
    }
    var start = 0;
    while (start < line.length) {
      var end = math.min(start + maxLineChars, line.length);
      final unit = line.codeUnitAt(end - 1);
      if (end < line.length && _isHighSurrogate(unit)) end--;
      lines.add(line.substring(start, end));
      start = end;
    }
  }
  return lines;
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

/// Human-readable byte size for the viewer's notices.
String formatBodySize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
