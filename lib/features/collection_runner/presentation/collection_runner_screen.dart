import 'package:flutter/material.dart';
import 'package:relay/features/collection_runner/presentation/collection_run_history_screen.dart';
import 'package:relay/features/collection_runner/presentation/collection_runner_workbench_tab.dart';

class CollectionRunnerScreen extends StatelessWidget {
  const CollectionRunnerScreen({super.key, this.initialCollectionId});

  final String? initialCollectionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Runner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Test Run History',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CollectionRunHistoryScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(child: CollectionRunnerWorkbenchTab(initialCollectionId: initialCollectionId)),
    );
  }
}
