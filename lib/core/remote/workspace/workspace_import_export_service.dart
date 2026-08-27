import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/import_export_job.dart';
import '../api_client.dart';

/// role-node's own async, job-based import/export (§8 of
/// docs/08-ONLINE-MODE-INTEGRATION.md), scoped to a remote workspace —
/// distinct from and unaffected by Röle's local (synchronous, file-picker
/// based) import/export in `lib/core/io/workspace_io.dart`. Jobs complete
/// synchronously today (role-node's own docs say so), so there's no polling
/// loop here: `createExport`/`createImport` return the finished job directly,
/// `listJobs`/`getJob` exist for completeness (role-node's "job history
/// timeline") but aren't required for the create-and-done flow this phase's
/// UI uses.
///
/// The wire payload (`ImportExportJob.artifact`) is a third shape distinct
/// from both the live collections/environments REST shape and Röle's own
/// `WorkspaceBundle` — role-node's "role-native" portable tree
/// (`role-node/src/modules/import-export/schema.ts`
/// `roleNativeImportPayloadSchema`). Its `body`/`auth` fields are untyped
/// (`z.record(unknown)`) and passed through byte-for-byte by role-node
/// itself, so this service never needs to parse or rebuild that tree — it's
/// pure passthrough.
class WorkspaceImportExportService {
  const WorkspaceImportExportService(this._client);

  final RemoteApiClient _client;

  Future<List<ImportExportJob>> listJobs(int workspaceId) async {
    final data = Map<String, dynamic>.from(await _client.get('/workspaces/$workspaceId/import-export/jobs') as Map);
    return (data['items'] as List? ?? const []).whereType<Map>().map((e) => ImportExportJob.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ImportExportJob> getJob(int workspaceId, int jobId) async {
    final data = Map<String, dynamic>.from(await _client.get('/workspaces/$workspaceId/import-export/jobs/$jobId') as Map);
    return ImportExportJob.fromJson(data);
  }

  Future<ImportExportJob> createExport(int workspaceId, {bool includeCollections = true, bool includeEnvironments = true}) async {
    final data = Map<String, dynamic>.from(
      await _client.post(
            '/workspaces/$workspaceId/import-export/exports',
            data: {'format': 'json', 'includeCollections': includeCollections, 'includeEnvironments': includeEnvironments},
          )
          as Map,
    );
    return ImportExportJob.fromJson(data);
  }

  /// [payload] is whatever was read and `jsonDecode`d from a picked file —
  /// sent through unchanged, since role-node interprets the whole tree
  /// itself and this service has no reason to parse it.
  Future<ImportExportJob> createImport(int workspaceId, Map<String, dynamic> payload) async {
    final data = Map<String, dynamic>.from(
      await _client.post('/workspaces/$workspaceId/import-export/imports', data: {'format': 'json', 'payload': payload}) as Map,
    );
    return ImportExportJob.fromJson(data);
  }
}

/// Null until a base URL is configured, same shape as [remoteApiClientProvider].
final workspaceImportExportServiceProvider = Provider<WorkspaceImportExportService?>((ref) {
  final client = ref.watch(remoteApiClientProvider);
  return client == null ? null : WorkspaceImportExportService(client);
});
