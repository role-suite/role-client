import 'package:flutter/material.dart';

import '../widgets/widgets.dart';

enum ImportConflictChoice { skip, keepBoth, overwrite }

Future<ImportConflictChoice> showImportConflictDialog(BuildContext context, String name) async {
  final choice = await showDialog<ImportConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Name already exists'),
      content: Text('"$name" already exists in your workspace. What would you like to do?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(ImportConflictChoice.skip), child: const Text('Skip')),
        TextButton(onPressed: () => Navigator.of(context).pop(ImportConflictChoice.keepBoth), child: const Text('Keep both')),
        AppButton(
          label: 'Overwrite',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(ImportConflictChoice.overwrite),
        ),
      ],
    ),
  );
  return choice ?? ImportConflictChoice.skip;
}
