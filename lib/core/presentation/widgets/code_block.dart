import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget for displaying code with syntax highlighting support
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language, this.maxHeight, this.showCopyButton = true, this.onCopy});

  final String code;
  final String? language;
  final double? maxHeight;
  final bool showCopyButton;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight!) : null,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCopyButton || language != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  if (language != null)
                    Text(
                      language!.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  const Spacer(),
                  if (showCopyButton)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: onCopy ?? () => _copyToClipboard(context),
                      tooltip: 'Copy',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(code, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 13)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}
