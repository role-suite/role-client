import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/services/role_sdk_http_compat.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/core/utils/request_build_helper.dart';

ApiRequestModel _baseRequest({
  BodyType bodyType = BodyType.raw,
  AuthType authType = AuthType.none,
  Map<String, String> headers = const {},
  Map<String, String> formDataFields = const {},
  Map<String, String> authConfig = const {},
  String? body,
}) {
  final now = DateTime.now();
  return ApiRequestModel(
    id: 'req-1',
    name: 'Test Request',
    method: HttpMethod.post,
    urlTemplate: 'https://example.com',
    headers: headers,
    bodyType: bodyType,
    formDataFields: formDataFields,
    authType: authType,
    authConfig: authConfig,
    body: body,
    collectionId: 'default',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RequestBuildHelper.buildForSend', () {
    test('builds bearer auth header and resolves raw body override', () {
      final request = _baseRequest(
        authType: AuthType.bearer,
        authConfig: {AuthConfigKeys.token: ' {{token}} '},
        headers: {'X-Trace': '{{traceId}}'},
        body: 'old-body',
      );

      final built = RequestBuildHelper.buildForSend(
        request,
        (value) => value.replaceAll('{{token}}', 'secret').replaceAll('{{traceId}}', 'trace-1').replaceAll('{{payload}}', '{"ok":true}'),
        rawBody: '{{payload}}',
      );

      expect(built.headers['Authorization'], 'Bearer secret');
      expect(built.headers['X-Trace'], 'trace-1');
      expect(built.body, '{"ok":true}');
    });

    test('builds basic auth and urlEncoded body with content type', () {
      final request = _baseRequest(
        bodyType: BodyType.urlEncoded,
        authType: AuthType.basic,
        authConfig: {
          AuthConfigKeys.username: ' user ',
          AuthConfigKeys.password: ' pass ',
        },
        formDataFields: {
          '': 'ignored',
          'page': '1',
          'q': '{{query}}',
        },
      );

      final built = RequestBuildHelper.buildForSend(
        request,
        (value) => value.replaceAll('{{query}}', 'flutter'),
      );

      final expectedAuth = base64Encode(utf8.encode('user:pass'));
      expect(built.headers['Authorization'], 'Basic $expectedAuth');
      expect(built.headers['Content-Type'], 'application/x-www-form-urlencoded');
      expect(built.body, {'page': '1', 'q': 'flutter'});
    });

    test('returns RoleSdkFormData for form-data body', () {
      final request = _baseRequest(
        bodyType: BodyType.formData,
        formDataFields: {
          '': 'ignored',
          'fileName': '{{name}}',
        },
      );

      final built = RequestBuildHelper.buildForSend(
        request,
        (value) => value.replaceAll('{{name}}', 'invoice.pdf'),
      );

      expect(built.body, isA<RoleSdkFormData>());
      expect(built.headers.containsKey('Content-Type'), isFalse);
    });
  });
}
