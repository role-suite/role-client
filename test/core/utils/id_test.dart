import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/utils/id.dart';

void main() {
  group('generateId', () {
    final uuidV4Pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

    test('produces a spec-compliant UUIDv4 with no prefix', () {
      expect(generateId(), matches(uuidV4Pattern));
    });

    test('prefixes the UUID with a dash-separated prefix', () {
      final id = generateId('col');
      expect(id, startsWith('col-'));
      expect(id.substring(4), matches(uuidV4Pattern));
    });

    test('generates unique ids across many calls', () {
      final ids = List.generate(1000, (_) => generateId());
      expect(ids.toSet().length, 1000);
    });
  });
}
