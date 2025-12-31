import 'package:flutter/material.dart';

/// A badge widget for displaying HTTP status codes with color coding
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.statusCode, this.size = StatusBadgeSize.medium});

  final int? statusCode;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    if (statusCode == null) {
      return _buildBadge(context, 'N/A', Colors.grey);
    }

    final color = _getStatusColor(statusCode!);
    final text = statusCode.toString();

    return _buildBadge(context, text, color);
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    final theme = Theme.of(context);
    final textStyle = size == StatusBadgeSize.small ? theme.textTheme.labelSmall : theme.textTheme.labelMedium;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: size == StatusBadgeSize.small ? 6 : 8, vertical: size == StatusBadgeSize.small ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: textStyle?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      return Colors.blue;
    } else if (statusCode >= 400 && statusCode < 500) {
      return Colors.orange;
    } else if (statusCode >= 500) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}

enum StatusBadgeSize { small, medium }
