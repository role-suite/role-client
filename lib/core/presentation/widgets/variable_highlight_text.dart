import 'package:flutter/material.dart';
import 'package:relay/core/utils/template_resolver.dart';

/// A widget that displays text with environment variables highlighted
class VariableHighlightText extends StatelessWidget {
  const VariableHighlightText({
    super.key,
    required this.text,
    this.style,
    this.variableStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? variableStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final defaultVariableStyle = variableStyle ??
        defaultStyle.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
        );

    final regex = TemplateResolver.placeholderRegex;
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: defaultStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }

      // Add the variable (with braces) in highlighted style
      spans.add(TextSpan(
        text: match.group(0), // The full match including {{ }}
        style: defaultVariableStyle,
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
