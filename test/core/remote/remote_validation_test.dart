import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request.dart';
import 'package:relay/core/models/enums.dart';
import 'package:relay/core/models/environment_variable.dart';
import 'package:relay/core/models/key_value_entry.dart';
import 'package:relay/core/models/request_body.dart';
import 'package:relay/core/remote/remote_api_exception.dart';
import 'package:relay/core/remote/remote_validation.dart';

void main() {
  test('validateRemoteCollectionInput enforces backend name and description limits', () {
    expect(() => validateRemoteCollectionInput(name: 'A'), throwsA(isA<RemoteApiException>()));
    expect(() => validateRemoteCollectionInput(name: 'Orders', description: List.filled(2001, 'x').join()), throwsA(isA<RemoteApiException>()));
    expect(() => validateRemoteCollectionInput(name: 'Orders', description: List.filled(2000, 'x').join()), returnsNormally);
  });

  test('validateRemoteRequest enforces endpoint field limits', () {
    final now = DateTime.utc(2026);
    final request = ApiRequest(
      id: 'req-1',
      collectionId: 'col-1',
      name: 'R',
      url: '',
      headers: const [KeyValueEntry(key: '', value: 'ok')],
      authType: AuthType.bearer,
      authConfig: const {AuthConfigKeys.token: ''},
      createdAt: now,
      updatedAt: now,
    );

    expect(() => validateRemoteRequest(request), throwsA(isA<RemoteApiException>()));
  });

  test('validateRemoteRequest permits empty draft URLs only for create', () {
    final now = DateTime.utc(2026);
    final request = ApiRequest(id: 'req-1', collectionId: 'col-1', name: 'Request', url: '', createdAt: now, updatedAt: now);

    expect(() => validateRemoteRequest(request), throwsA(isA<RemoteApiException>()));
    expect(() => validateRemoteRequest(request, allowEmptyUrlAsDraft: true), returnsNormally);
  });

  test('validateRemoteRequest validates body-specific limits', () {
    final now = DateTime.utc(2026);
    final request = ApiRequest(
      id: 'req-1',
      collectionId: 'col-1',
      name: 'Upload',
      url: '/upload',
      requestBody: const BinaryBody(fileName: '', dataBase64: ''),
      createdAt: now,
      updatedAt: now,
    );

    expect(() => validateRemoteRequest(request), throwsA(isA<RemoteApiException>()));
  });

  test('validateRemoteEnvironmentInput enforces environment and variable limits', () {
    expect(
      () => validateRemoteEnvironmentInput(
        name: 'Staging',
        variables: const [EnvironmentVariable(key: '', value: 'ok')],
      ),
      throwsA(isA<RemoteApiException>()),
    );
    expect(
      () => validateRemoteEnvironmentInput(
        name: 'Staging',
        variables: [EnvironmentVariable(key: 'TOKEN', value: List.filled(10001, 'x').join())],
      ),
      throwsA(isA<RemoteApiException>()),
    );
    expect(
      () => validateRemoteEnvironmentInput(
        name: 'Staging',
        variables: const [EnvironmentVariable(key: 'TOKEN', value: 'ok')],
      ),
      returnsNormally,
    );
  });
}
