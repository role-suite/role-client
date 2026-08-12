import 'package:flutter/material.dart';
import 'package:relay/core/presentation/layout/scaffold.dart';
import 'package:relay/features/request_chain/presentation/request_chain_workbench_tab.dart';

class RequestChainConfigScreen extends StatefulWidget {
  const RequestChainConfigScreen({super.key});

  @override
  State<RequestChainConfigScreen> createState() => _RequestChainConfigScreenState();
}

class _RequestChainConfigScreenState extends State<RequestChainConfigScreen> {
  final _workbenchController = RequestChainWorkbenchController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Request Chain',
      actions: [IconButton(icon: const Icon(Icons.folder_open), tooltip: 'View saved chains', onPressed: _workbenchController.openSavedChains)],
      body: RequestChainWorkbenchTab(controller: _workbenchController),
    );
  }
}
