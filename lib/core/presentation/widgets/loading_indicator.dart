import 'package:flutter/material.dart';

/// A centered loading indicator
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message, this.size = 40});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: size, height: size, child: const CircularProgressIndicator()),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
