import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/io/workspace_io.dart';
import '../../core/remote/workspace/workspace_import_export_service.dart';
import '../remote_error.dart';
import '../widgets/widgets.dart';

/// role-node's own import/export (§8 of docs/08-ONLINE-MODE-INTEGRATION.md),
/// scoped to one remote workspace — a distinct feature from
/// `lib/ui/shell/import_export_actions.dart`'s local, synchronous
/// import/export, not a replacement for or merge with it. Jobs complete
/// synchronously (role-node's own docs say so), so there's no polling here:
/// `createExport`/`createImport` already return the finished job.
Future<void> runExportRemoteWorkspace(BuildContext context, WidgetRef ref, {required int workspaceId, required String workspaceName}) async {
  final service = ref.read(workspaceImportExportServiceProvider);
  if (service == null) return;

  try {
    final job = await service.createExport(workspaceId);
    final json = const JsonEncoder.withIndent('  ').convert(job.artifact);
    final fileName = '${_sanitizeFileName(workspaceName)}-export.json';
    final path = await WorkspaceIo.exportToFile(json, fileName: fileName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(path != null ? 'Exported remote workspace "$workspaceName" to $path' : 'Remote export cancelled')));
  } catch (error) {
    if (!context.mounted) return;
    showRemoteErrorSnackBar(context, 'Export failed', error);
  }
}

Future<void> runImportRemoteWorkspace(BuildContext context, WidgetRef ref, {required int workspaceId, required String workspaceName}) async {
  final service = ref.read(workspaceImportExportServiceProvider);
  if (service == null) return;

  final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
  final file = result?.files.length == 1 ? result!.files.single : null;
  final bytes = file?.bytes;
  if (bytes == null) return;

  final Map<String, dynamic> payload;
  try {
    payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That file is not valid JSON.')));
    return;
  }

  final collectionCount = (payload['collections'] as List?)?.length ?? 0;
  final environmentCount = (payload['environments'] as List?)?.length ?? 0;

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Import into remote workspace?'),
      content: Text(
        'Import $collectionCount collection(s) and $environmentCount environment(s) into "$workspaceName"? '
        "This writes to the remote role-node workspace as one all-or-nothing operation and can't be partially undone.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        AppButton(label: 'Import into remote workspace', variant: AppButtonVariant.primary, onPressed: () => Navigator.of(dialogContext).pop(true)),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    final job = await service.createImport(workspaceId, payload);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${job.summary['importedCollections'] ?? 0} collection(s) and '
          "${job.summary['importedEnvironments'] ?? 0} environment(s) — they'll appear shortly via sync.",
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    showRemoteErrorSnackBar(context, 'Import failed', error);
  }
}

String _sanitizeFileName(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9-_ ]'), '_');
