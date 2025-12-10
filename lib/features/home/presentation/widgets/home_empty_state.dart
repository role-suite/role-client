import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/empty_state.dart';

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

