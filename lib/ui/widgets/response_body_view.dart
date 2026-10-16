import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/request_result.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import 'app_button.dart';

/// Renders the complete response body, pretty-printed when it is JSON.
///
/// A single `SelectableText` holding several megabytes of text exceeds
/// Flutter's text-layout limits and renders corrupted glyphs at the end of
/// large responses, besides janking the UI. This viewer instead splits the
/// body into line-sized chunks and virtualizes them with a
/// `ListView.builder`, so only the visible lines are ever laid out and every
/// rendered chunk is bounded — while nothing is elided: scrolling always
/// reaches the last line, and pretty-printing applies to the whole body
/// regardless of size.
class ResponseBodyView extends StatefulWidget {
  const ResponseBodyView({super.key, required this.result});

  final RequestResult result;

  @override
  State<ResponseBodyView> createState() => _ResponseBodyViewState();
}

class _ResponseBodyViewState extends State<ResponseBodyView> {
  static const int _maxLineChars = 2000;

  final ScrollController _controller = ScrollController();
  late String _text;
  late _RenderedLines _lines;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(ResponseBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) _recompute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recompute() {
    _text = widget.result.prettyBody;
    _lines = _RenderedLines(_text, maxLineChars: _maxLineChars);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response body copied.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) {
      return Center(child: Text('No response body.', style: context.type.caption));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                itemBuilder: (context, index) => Text(_lines.chunk(index), style: context.type.mono),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A lazily-sliced view of [text] split into lines: stores line-start offsets
/// rather than a `String` per line, so a multi-megabyte body costs one copy of
/// the text plus an integer list instead of hundreds of thousands of string
/// objects. Lines longer than [maxLineChars] (e.g. non-JSON or minified text)
/// are hard-wrapped into several chunks, so no single rendered widget can
/// itself become a giant text blob.
class _RenderedLines {
  _RenderedLines(this.text, {required int maxLineChars}) {
    var lineStart = 0;
    final length = text.length;
    while (lineStart <= length) {
      var lineEnd = text.indexOf('\n', lineStart);
      if (lineEnd == -1) lineEnd = length;

      if (lineEnd == lineStart) {
        _starts.add(lineStart);
        _ends.add(lineStart);
      } else {
        var chunkStart = lineStart;
        while (chunkStart < lineEnd) {
          var chunkEnd = math.min(chunkStart + maxLineChars, lineEnd);
          if (chunkEnd < lineEnd && _isHighSurrogate(text.codeUnitAt(chunkEnd - 1))) chunkEnd--;
          _starts.add(chunkStart);
          _ends.add(chunkEnd);
          chunkStart = chunkEnd;
        }
      }

      if (lineEnd == length) break;
      lineStart = lineEnd + 1;
    }
  }

  final String text;
  final List<int> _starts = <int>[];
  final List<int> _ends = <int>[];

  int get length => _starts.length;

  String chunk(int index) => text.substring(_starts[index], _ends[index]);
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
