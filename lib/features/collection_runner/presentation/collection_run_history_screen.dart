import 'package:flutter/material.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_workbench_tab.dart';

class CollectionRunHistoryScreen extends StatelessWidget {
  const CollectionRunHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Run History')),
      body: const SafeArea(child: CollectionRunHistoryWorkbenchTab()),
    );
  }
}
