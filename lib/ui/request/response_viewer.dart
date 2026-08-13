import 'package:flutter/material.dart';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: switch (_tab) {
              _ResponseTab.body => MonoText(result.prettyBody),
              _ResponseTab.headers => _HeadersList(headers: result.headers),
              _ResponseTab.tests => _TestsList(results: widget.assertionResults),
            },
          ),
        ),
      ],
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
