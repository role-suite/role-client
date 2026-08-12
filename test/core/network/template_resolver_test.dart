import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/network/template_resolver.dart';

void main() {
  group('TemplateResolver', () {
    test('substitutes known variables', () {
      final resolver = TemplateResolver({'baseUrl': 'https://api.example.com'});
      expect(resolver.resolve('{{baseUrl}}/users'), 'https://api.example.com/users');
    });

    test('leaves unknown variables untouched', () {
      final resolver = TemplateResolver(const {});
      expect(resolver.resolve('{{missing}}/users'), '{{missing}}/users');
    });

    test('resolveMap substitutes both keys and values', () {
      final resolver = TemplateResolver({'token': 'abc123'});
      final result = resolver.resolveMap({'Authorization': 'Bearer {{token}}'});
      expect(result['Authorization'], 'Bearer abc123');
    });

    test('unresolvedIn reports only missing variables', () {
      final unresolved = TemplateResolver.unresolvedIn('{{baseUrl}}/{{path}}', {'baseUrl': 'x'});
      expect(unresolved, {'path'});
    });
  });
}
