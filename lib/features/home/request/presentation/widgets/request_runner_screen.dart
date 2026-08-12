import 'package:flutter/material.dart';
import 'package:relay/core/models/api_request_model.dart';

import 'request_workbench_tab.dart';

class RequestRunnerPage extends StatelessWidget {
  const RequestRunnerPage({super.key, required this.request, this.onDelete});

  final ApiRequestModel request;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(request.name, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: RequestWorkbenchTab(request: request, onDelete: onDelete),
          ),
        ),
      ),
    );
  }
}
