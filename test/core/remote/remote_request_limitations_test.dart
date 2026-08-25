import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request.dart';
import 'package:relay/core/models/assertion.dart';
import 'package:relay/core/models/enums.dart';
import 'package:relay/core/remote/remote_request_limitations.dart';

void main() {
  test('remoteRequestLocalOnlyFields reports only unsupported fields currently in use', () {
    final now = DateTime.utc(2026);
    final request = ApiRequest(
      id: 'req-1',
      collectionId: 'col-1',
      name: 'Request',
      authType: AuthType.apiKey,
      description: 'Important request',
      assertions: [Assertion(id: 'assert-1', type: AssertionType.statusEquals, expected: '200')],
      createdAt: now,
      updatedAt: now,
    );

    expect(remoteRequestLocalOnlyFields(request), ['description', 'tests', 'API key auth']);
  });

  test('remoteRequestLocalOnlyFields returns empty when no unsupported field is active', () {
    final now = DateTime.utc(2026);
    final request = ApiRequest(id: 'req-1', collectionId: 'col-1', name: 'Request', createdAt: now, updatedAt: now);

    expect(remoteRequestLocalOnlyFields(request), isEmpty);
  });
}
