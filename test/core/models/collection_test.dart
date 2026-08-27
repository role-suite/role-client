import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/collection.dart';
import 'package:relay/core/models/workspace_origin.dart';

void main() {
  group('Collection.fromJson', () {
    test('parses a pre-existing (main-shape) JSON file with no origin/sync fields', () {
      final legacyJson = {
        'id': 'abc123',
        'name': 'My Collection',
        'description': 'Some notes',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
      };

      final collection = Collection.fromJson(legacyJson);

      expect(collection.id, 'abc123');
      expect(collection.name, 'My Collection');
      expect(collection.description, 'Some notes');
      expect(collection.origin, WorkspaceOrigin.local);
      expect(collection.remoteWorkspaceId, isNull);
      expect(collection.remoteId, isNull);
      expect(collection.syncedAt, isNull);
    });

    test('round-trips a remote-origin collection through toJson/fromJson', () {
      final original = Collection(
        id: 'xyz',
        name: 'Team Collection',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        origin: WorkspaceOrigin.remote,
        remoteWorkspaceId: 42,
        remoteId: 7,
        syncedAt: DateTime.utc(2026, 1, 3),
      );

      final restored = Collection.fromJson(original.toJson());

      expect(restored.origin, WorkspaceOrigin.remote);
      expect(restored.remoteWorkspaceId, 42);
      expect(restored.remoteId, 7);
      expect(restored.syncedAt, DateTime.utc(2026, 1, 3));
    });
  });
}
