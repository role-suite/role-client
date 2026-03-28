import 'package:flutter/material.dart';

import 'package:relay/core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/empty_state.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onCreateRequest,
    this.title = 'No API Requests',
    this.message = 'Create your first API request to get started',
  });

  final VoidCallback onCreateRequest;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.api,
      title: title,
      message: message,
      action: AppButton(label: 'Create Request', icon: Icons.add, isFullWidth: false, onPressed: onCreateRequest),
    );
  }
}
