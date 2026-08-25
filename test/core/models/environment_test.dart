import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/environment.dart';
import 'package:relay/core/models/environment_variable.dart';
import 'package:relay/core/models/workspace_origin.dart';

void main() {
  group('Environment.fromJson', () {
    test('§3.2: old Map<String,String> variables shape becomes an enabled, positioned List<EnvironmentVariable>', () {
      final legacyJson = {
        'id': 'env1',
        'name': 'Staging',
        'variables': {'baseUrl': 'https://staging.example.com', 'apiKey': 'abc123'},
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
      };

      final environment = Environment.fromJson(legacyJson);

      expect(environment.id, 'env1');
      expect(environment.variables, [
        const EnvironmentVariable(key: 'baseUrl', value: 'https://staging.example.com', position: 0),
        const EnvironmentVariable(key: 'apiKey', value: 'abc123', position: 1),
      ]);
      expect(environment.variables.every((v) => v.enabled && !v.isSecret), isTrue);
      expect(environment.origin, WorkspaceOrigin.local);
      expect(environment.remoteWorkspaceId, isNull);
      expect(environment.remoteId, isNull);
      expect(environment.syncedAt, isNull);
    });

    test('round-trips a remote-origin environment with typed variables through toJson/fromJson', () {
      final original = Environment(
        id: 'env2',
        name: 'Team Prod',
        variables: const [
          EnvironmentVariable(key: 'token', value: 'secret', isSecret: true, position: 0),
          EnvironmentVariable(key: 'region', value: 'eu', enabled: false, position: 1),
        ],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        origin: WorkspaceOrigin.remote,
        remoteWorkspaceId: 42,
        remoteId: 7,
        syncedAt: DateTime.utc(2026, 1, 3),
      );

      final restored = Environment.fromJson(original.toJson());

      expect(restored.variables, original.variables);
      expect(restored.origin, WorkspaceOrigin.remote);
      expect(restored.remoteWorkspaceId, 42);
      expect(restored.remoteId, 7);
      expect(restored.syncedAt, DateTime.utc(2026, 1, 3));
    });
  });

  group('EnvironmentVariable.enabledMap', () {
    test('drops disabled and empty-key entries', () {
      const variables = [
        EnvironmentVariable(key: 'a', value: '1'),
        EnvironmentVariable(key: 'b', value: '2', enabled: false),
        EnvironmentVariable(key: '', value: '3'),
      ];
      expect(EnvironmentVariable.enabledMap(variables), {'a': '1'});
    });
  });
}
