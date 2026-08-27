import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/workspace/workspace_import_export_service.dart';

ResponseBody _jsonBody(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);
  final ResponseBody Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => _respond(options);
}

WorkspaceImportExportService _serviceWith(ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  return WorkspaceImportExportService(RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio));
}

Map<String, dynamic> _job({required String type, Map<String, dynamic> artifact = const {}}) => {
  'id': 7,
  'workspaceId': 2,
  'type': type,
  'status': 'completed',
  'format': 'json',
  'summary': {'importedCollections': 1, 'importedEnvironments': 0},
  'artifact': artifact,
  'createdAt': '2026-01-01T10:00:00.000Z',
  'completedAt': '2026-01-01T10:00:00.000Z',
};

void main() {
  test('listJobs unwraps the {items} envelope', () async {
    final service = _serviceWith(
      (options) => _jsonBody({
        'success': true,
        'data': {
          'items': [_job(type: 'export'), _job(type: 'import')],
        },
      }, 200),
    );

    final jobs = await service.listJobs(2);
    expect(jobs, hasLength(2));
    expect(jobs.map((j) => j.type), ['export', 'import']);
  });

  test('getJob hits the nested job route', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({'success': true, 'data': _job(type: 'export')}, 200);
    });

    await service.getJob(2, 7);
    expect(sent!.path, '/workspaces/2/import-export/jobs/7');
  });

  test('createExport POSTs the include flags and returns the artifact untouched', () async {
    RequestOptions? sent;
    final artifact = {
      'version': 1,
      'format': 'role-native',
      'collections': [
        {'name': 'Orders API'},
      ],
    };
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({'success': true, 'data': _job(type: 'export', artifact: artifact)}, 201);
    });

    final job = await service.createExport(2);

    expect(sent!.path, '/workspaces/2/import-export/exports');
    expect(sent!.data, {'format': 'json', 'includeCollections': true, 'includeEnvironments': true});
    expect(job.artifact, artifact);
  });

  test('createExport forwards includeCollections/includeEnvironments overrides', () async {
    RequestOptions? sent;
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({'success': true, 'data': _job(type: 'export')}, 201);
    });

    await service.createExport(2, includeCollections: false, includeEnvironments: true);
    expect(sent!.data, {'format': 'json', 'includeCollections': false, 'includeEnvironments': true});
  });

  test('createImport sends the payload through unchanged, no shape mapping', () async {
    RequestOptions? sent;
    final payload = {
      'version': 1,
      'format': 'role-native',
      'collections': [
        {
          'name': 'Orders API',
          'endpoints': [
            {'name': 'Get Orders', 'method': 'GET', 'url': 'https://api.example.com/orders', 'body': null, 'auth': null},
          ],
        },
      ],
      'environments': [],
    };
    final service = _serviceWith((options) {
      sent = options;
      return _jsonBody({'success': true, 'data': _job(type: 'import')}, 201);
    });

    final job = await service.createImport(2, payload);

    expect(sent!.path, '/workspaces/2/import-export/imports');
    expect(sent!.data, {'format': 'json', 'payload': payload});
    expect(job.type, 'import');
    expect(job.summary['importedCollections'], 1);
  });
}
