import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/remote_api_exception.dart';
import 'package:relay/ui/remote_error.dart';

void main() {
  test('remoteErrorMessage uses role-node message instead of exception toString', () {
    const error = RemoteApiException(code: 'WORKSPACE_ACCESS_DENIED', message: 'You no longer have access');

    expect(remoteErrorMessage(error), 'You no longer have access');
  });

  test('remoteErrorMessage appends validation field errors when present', () {
    const error = RemoteApiException(
      code: 'VALIDATION_FAILED',
      message: 'Validation failed.',
      details: {
        'fieldErrors': {'name': 'Must be at least 2 characters'},
      },
    );

    expect(remoteErrorMessage(error), 'Validation failed. name: Must be at least 2 characters');
  });
}
