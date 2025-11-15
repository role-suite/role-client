import 'package:flutter/material.dart';
import 'package:relay/core/util/extension.dart';

/// A badge widget for displaying HTTP methods with color coding
class MethodBadge extends StatelessWidget {
  const MethodBadge({
    super.key,
    required this.method,
    this.size = MethodBadgeSize.medium,
  });

  final HttpMethod method;
  final MethodBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final color = _getMethodColor(method);
    final text = method.name;

    return _buildBadge(context, text, color);
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    final theme = Theme.of(context);
    final textStyle = size == MethodBadgeSize.small
        ? theme.textTheme.labelSmall
        : theme.textTheme.labelMedium;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == MethodBadgeSize.small ? 6 : 8,
        vertical: size == MethodBadgeSize.small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: textStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getMethodColor(HttpMethod method) {
    switch (method) {
      case HttpMethod.get:
        return Colors.blue;
      case HttpMethod.post:
        return Colors.green;
      case HttpMethod.put:
        return Colors.orange;
      case HttpMethod.delete:
        return Colors.red;
      case HttpMethod.patch:
        return Colors.purple;
      case HttpMethod.head:
        return Colors.teal;
      case HttpMethod.options:
        return Colors.grey;
    }
  }
}

enum MethodBadgeSize {
  small,
  medium,
}

