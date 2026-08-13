import 'package:flutter/material.dart';

import '../widgets/widgets.dart';

class FlowRunTabView extends StatelessWidget {
  const FlowRunTabView({super.key, required this.chainId});

  final String chainId;

  @override
  Widget build(BuildContext context) {
    return const EmptyState(icon: Icons.route_outlined, title: 'Flow run', message: 'Coming soon.');
  }
}
