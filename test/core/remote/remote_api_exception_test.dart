import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/remote_api_exception.dart';

void main() {
  group('RemoteApiException.fromEnvelope', () {
    test('defaults code/message when the envelope omits them', () {
      final error = RemoteApiException.fromEnvelope(const {});
      expect(error.code, 'UNKNOWN_ERROR');
      expect(error.message, 'Something went wrong.');
      expect(error.requestId, isNull);
      expect(error.details, isNull);
    });

    test('carries through code, message, requestId, and details', () {
      final error = RemoteApiException.fromEnvelope({
        'code': 'WORKSPACE_ACCESS_DENIED',
        'message': 'No access',
        'requestId': 'req-9',
        'details': {'workspaceId': 5},
      });
      expect(error.code, 'WORKSPACE_ACCESS_DENIED');
      expect(error.message, 'No access');
      expect(error.requestId, 'req-9');
      expect(error.details, {'workspaceId': 5});
    });
  });
}
