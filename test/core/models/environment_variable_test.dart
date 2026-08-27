import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/environment_variable.dart';

void main() {
  group('EnvironmentVariable.fromJson', () {
    test('a pre-existing (main-shape) row with no remoteId parses with remoteId null', () {
      final variable = EnvironmentVariable.fromJson({
        'key': 'apiUrl',
        'value': 'https://api.example.com',
        'enabled': true,
        'isSecret': false,
        'position': 0,
      });
      expect(variable.remoteId, isNull);
    });

    test('round-trips remoteId through toJson/fromJson', () {
      const variable = EnvironmentVariable(key: 'apiUrl', value: 'v', remoteId: 100);
      final restored = EnvironmentVariable.fromJson(variable.toJson());
      expect(restored.remoteId, 100);
      expect(restored, variable);
    });

    test('toJson omits remoteId entirely when null (stays additive/optional on disk)', () {
      const variable = EnvironmentVariable(key: 'apiUrl', value: 'v');
      expect(variable.toJson().containsKey('remoteId'), isFalse);
    });
  });

  test('copyWith preserves remoteId when not overridden, e.g. renaming a key in the editor', () {
    const variable = EnvironmentVariable(key: 'oldName', value: 'v', remoteId: 100);
    final renamed = variable.copyWith(key: 'newName');
    expect(renamed.remoteId, 100);
    expect(renamed.key, 'newName');
  });
}
