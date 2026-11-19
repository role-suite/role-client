import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/server_health.dart';

void main() {
  group('normalizeRoleNodeBaseUrl', () {
    test('accepts http and https URLs and trims whitespace/trailing slashes', () {
      expect(normalizeRoleNodeBaseUrl('  https://role.example.com/  '), 'https://role.example.com');
      expect(normalizeRoleNodeBaseUrl('http://localhost:3000///'), 'http://localhost:3000');
    });

    test('rejects empty, relative, and non-http(s) values', () {
      expect(normalizeRoleNodeBaseUrl(''), isNull);
      expect(normalizeRoleNodeBaseUrl('   '), isNull);
      expect(normalizeRoleNodeBaseUrl('role.example.com'), isNull);
      expect(normalizeRoleNodeBaseUrl('ftp://role.example.com'), isNull);
      expect(normalizeRoleNodeBaseUrl('https://'), isNull);
    });
  });
}
