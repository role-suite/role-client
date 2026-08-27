import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request.dart';
import 'package:relay/core/models/enums.dart';
import 'package:relay/core/models/key_value_entry.dart';
import 'package:relay/core/models/request_body.dart';
import 'package:relay/core/models/workspace_origin.dart';

void main() {
  group('ApiRequest.fromJson — pre-§3.2 shape (main today)', () {
    test('headers/queryParams: old Map shape becomes enabled List<KeyValueEntry>', () {
      final legacyJson = {
        'id': 'req1',
        'collectionId': 'col1',
        'name': 'Get Widgets',
        'method': 'get',
        'url': 'https://example.com/widgets',
        'headers': {'Accept': 'application/json', 'X-Trace': '1'},
        'queryParams': {'q': 'search'},
        'bodyType': 'none',
        'formFields': <String, String>{},
        'authType': 'none',
        'authConfig': <String, String>{},
        'assertions': <Map<String, dynamic>>[],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
      };

      final request = ApiRequest.fromJson(legacyJson);

      expect(request.id, 'req1');
      expect(request.headers, [const KeyValueEntry(key: 'Accept', value: 'application/json'), const KeyValueEntry(key: 'X-Trace', value: '1')]);
      expect(request.queryParams, [const KeyValueEntry(key: 'q', value: 'search')]);
      expect(request.origin, WorkspaceOrigin.local);
      expect(request.remoteWorkspaceId, isNull);
      expect(request.remoteId, isNull);
      expect(request.syncedAt, isNull);
    });

    test('bodyType none maps to NoneBody', () {
      final request = ApiRequest.fromJson(_legacyBodyJson(bodyType: 'none'));
      expect(request.requestBody, isA<NoneBody>());
    });

    test('bodyType raw maps to RawBody carrying the old body string', () {
      final request = ApiRequest.fromJson(_legacyBodyJson(bodyType: 'raw', body: '{"a":1}'));
      expect(request.requestBody, isA<RawBody>());
      expect((request.requestBody as RawBody).raw, '{"a":1}');
      expect((request.requestBody as RawBody).contentType, isNull);
    });

    test('bodyType binary (never real binary data pre-§3.2) migrates to RawBody, not BinaryBody', () {
      final request = ApiRequest.fromJson(_legacyBodyJson(bodyType: 'binary', body: 'plain text payload'));
      expect(request.requestBody, isA<RawBody>());
      expect((request.requestBody as RawBody).raw, 'plain text payload');
    });

    test('bodyType urlEncoded maps formFields Map to UrlEncodedBody entries', () {
      final request = ApiRequest.fromJson(_legacyBodyJson(bodyType: 'urlEncoded', formFields: {'a': '1', 'b': '2'}));
      final body = request.requestBody as UrlEncodedBody;
      expect(body.entries, [const KeyValueEntry(key: 'a', value: '1'), const KeyValueEntry(key: 'b', value: '2')]);
    });

    test('bodyType formData maps formFields Map to FormDataBody text parts', () {
      final request = ApiRequest.fromJson(_legacyBodyJson(bodyType: 'formData', formFields: {'name': 'role'}));
      final body = request.requestBody as FormDataBody;
      expect(body.parts, hasLength(1));
      final part = body.parts.single as FormTextPart;
      expect(part.key, 'name');
      expect(part.value, 'role');
      expect(part.enabled, isTrue);
    });
  });

  group('ApiRequest.fromJson — current shape round-trip', () {
    test('round-trips a remote-origin request with headers/queryParams/requestBody through toJson/fromJson', () {
      final original = ApiRequest(
        id: 'req2',
        collectionId: 'col1',
        name: 'Create Widget',
        method: HttpMethod.post,
        headers: const [KeyValueEntry(key: 'Content-Type', value: 'application/json', enabled: false)],
        queryParams: const [KeyValueEntry(key: 'debug', value: 'true')],
        requestBody: const RawBody(contentType: 'application/json', raw: '{"ok":true}'),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        origin: WorkspaceOrigin.remote,
        remoteWorkspaceId: 42,
        remoteId: 7,
        syncedAt: DateTime.utc(2026, 1, 3),
      );

      final restored = ApiRequest.fromJson(original.toJson());

      expect(restored.headers, original.headers);
      expect(restored.queryParams, original.queryParams);
      expect((restored.requestBody as RawBody).raw, '{"ok":true}');
      expect((restored.requestBody as RawBody).contentType, 'application/json');
      expect(restored.origin, WorkspaceOrigin.remote);
      expect(restored.remoteWorkspaceId, 42);
      expect(restored.remoteId, 7);
      expect(restored.syncedAt, DateTime.utc(2026, 1, 3));
    });

    test('round-trips a FormDataBody with a file part', () {
      final original = ApiRequest(
        id: 'req3',
        collectionId: 'col1',
        name: 'Upload',
        requestBody: const FormDataBody(
          parts: [
            FormTextPart(key: 'title', value: 'doc'),
            FormFilePart(key: 'file', fileName: 'a.txt', contentType: 'text/plain', dataBase64: 'YQ=='),
          ],
        ),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final restored = ApiRequest.fromJson(original.toJson());
      final body = restored.requestBody as FormDataBody;
      expect(body.parts, hasLength(2));
      final filePart = body.parts.whereType<FormFilePart>().single;
      expect(filePart.fileName, 'a.txt');
      expect(filePart.dataBase64, 'YQ==');
    });
  });
}

Map<String, dynamic> _legacyBodyJson({required String bodyType, String? body, Map<String, String>? formFields}) {
  return {
    'id': 'req',
    'collectionId': 'col1',
    'name': 'Legacy Body Request',
    'method': 'post',
    'url': 'https://example.com',
    'headers': <String, String>{},
    'queryParams': <String, String>{},
    'bodyType': bodyType,
    'body': body,
    'formFields': formFields ?? <String, String>{},
    'authType': 'none',
    'authConfig': <String, String>{},
    'assertions': <Map<String, dynamic>>[],
    'createdAt': '2024-01-01T00:00:00.000Z',
    'updatedAt': '2024-01-02T00:00:00.000Z',
  };
}
