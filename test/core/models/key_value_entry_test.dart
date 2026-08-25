import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/key_value_entry.dart';

void main() {
  group('KeyValueEntry.listFrom', () {
    test('converts an old Map<String,String> shape to enabled entries in map iteration order', () {
      final entries = KeyValueEntry.listFrom({'b': '2', 'a': '1'});
      expect(entries, [const KeyValueEntry(key: 'b', value: '2'), const KeyValueEntry(key: 'a', value: '1')]);
    });

    test('parses the current List<KeyValueEntry> shape, preserving duplicate keys and disabled entries', () {
      final entries = KeyValueEntry.listFrom([
        {'key': 'a', 'value': '1', 'enabled': true},
        {'key': 'a', 'value': '2', 'enabled': false},
      ]);
      expect(entries, [const KeyValueEntry(key: 'a', value: '1'), const KeyValueEntry(key: 'a', value: '2', enabled: false)]);
    });

    test('returns empty for neither shape', () {
      expect(KeyValueEntry.listFrom(null), isEmpty);
    });
  });

  group('KeyValueEntry.enabledMap', () {
    test('later duplicate keys win, disabled and empty-key entries are dropped', () {
      const entries = [
        KeyValueEntry(key: 'a', value: '1'),
        KeyValueEntry(key: 'a', value: '2'),
        KeyValueEntry(key: 'b', value: '3', enabled: false),
        KeyValueEntry(key: '', value: '4'),
      ];
      expect(KeyValueEntry.enabledMap(entries), {'a': '2'});
    });
  });
}
