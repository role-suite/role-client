import 'package:flutter/material.dart';
import 'package:relay/core/presentation/layout/scaffold.dart';
import 'package:relay/features/request_chain/presentation/request_chain_workbench_tab.dart';

class RequestChainConfigScreen extends StatelessWidget {
  const RequestChainConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Request Chain',
      body: RequestChainWorkbenchTab(),
    );
  }
}
