import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/import_export_job.dart';

void main() {
  test('ImportExportJob.fromJson maps role-node\'s job response shape', () {
    final job = ImportExportJob.fromJson({
      'id': 7,
      'workspaceId': 2,
      'type': 'export',
      'status': 'completed',
      'format': 'json',
      'summary': {'includeCollections': true, 'includeEnvironments': true, 'collectionCount': 1, 'environmentCount': 0},
      'artifact': {
        'version': 1,
        'format': 'role-native',
        'collections': [
          {'name': 'Orders API'},
        ],
      },
      'createdAt': '2026-01-01T10:00:00.000Z',
      'completedAt': '2026-01-01T10:00:00.000Z',
    });

    expect(job.id, 7);
    expect(job.workspaceId, 2);
    expect(job.type, 'export');
    expect(job.status, 'completed');
    expect(job.summary['collectionCount'], 1);
    expect(job.artifact['format'], 'role-native');
    expect((job.artifact['collections'] as List).single, {'name': 'Orders API'});
  });

  test('missing summary/artifact default to empty maps rather than throwing', () {
    final job = ImportExportJob.fromJson({
      'id': 1,
      'workspaceId': 1,
      'type': 'import',
      'status': 'completed',
      'format': 'json',
      'createdAt': '2026-01-01T10:00:00.000Z',
      'completedAt': '2026-01-01T10:00:00.000Z',
    });

    expect(job.summary, isEmpty);
    expect(job.artifact, isEmpty);
  });
}
