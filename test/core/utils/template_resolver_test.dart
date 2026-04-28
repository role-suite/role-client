import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/utils/template_resolver.dart';

void main() {
  group('TemplateResolver', () {
    test('resolve replaces known placeholders and keeps unknown ones', () {
      const input = 'URL: {{baseUrl}}, token: {{token}}, keep: {{missing}}';

      final resolved = TemplateResolver.resolve(input, {
        'baseUrl': 'https://api.example.com',
        'token': 'abc123',
      });

      expect(resolved, 'URL: https://api.example.com, token: abc123, keep: {{missing}}');
    });

    test('resolveAll applies maps in order', () {
      const input = '{{host}}/{{version}}/users';

      final resolved = TemplateResolver.resolveAll(input, [
        {'host': 'https://api.example.com'},
        {'version': 'v1'},
      ]);

      expect(resolved, 'https://api.example.com/v1/users');
    });

    test('extractVariables returns unique variable names', () {
      const input = 'A {{host}} B {{token}} C {{host}}';

      final variables = TemplateResolver.extractVariables(input);

      expect(variables.toSet(), {'host', 'token'});
    });
  });
}
