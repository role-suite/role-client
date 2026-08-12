import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chain.dart';
import '../../core/theme/app_tokens.dart';
import '../../state/chains_notifier.dart';
import '../widgets/widgets.dart';

Future<void> showDeleteFlowDialog(BuildContext context, WidgetRef ref, SavedChain chain) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete flow?'),
      content: Text('"${chain.name}" will be deleted. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(chainsProvider.notifier).delete(chain.id);
}

class NameDialog extends StatelessWidget {
  const NameDialog({super.key, required this.title, required this.controller, required this.confirmLabel});

  final String title;
  final TextEditingController controller;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Name'), onSubmitted: (v) => Navigator.of(context).pop(v)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        const SizedBox(width: AppSpacing.xs),
        AppButton(label: confirmLabel, variant: AppButtonVariant.primary, onPressed: () => Navigator.of(context).pop(controller.text)),
      ],
    );
  }
}
