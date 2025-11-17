import 'package:flutter/material.dart';
import 'package:relay/ui/widgets/widgets.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onCreateRequest,
  });

  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.api,
      title: 'No API Requests',
      message: 'Create your first API request to get started',
      action: AppButton(
        label: 'Create Request',
        icon: Icons.add,
        isFullWidth: false,
        onPressed: onCreateRequest,
      ),
    );
  }
}

