import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/features/home/presentation/providers/collection_selection_utils.dart';

CollectionModel _collection(String id) {
  final now = DateTime.now();
  return CollectionModel(id: id, name: id, createdAt: now, updatedAt: now);
}

void main() {
  group('resolvePreferredCollectionId', () {
    test('returns null when no collections are loaded', () {
      final selected = resolvePreferredCollectionId(loadedCollections: const [], selectedCollectionId: 'any');

      expect(selected, isNull);
    });

    test('keeps selected id when selected collection exists', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: [_collection('default'), _collection('team')],
        selectedCollectionId: 'team',
      );

      expect(selected, 'team');
    });

    test('uses default collection first when available', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: [_collection('c2'), _collection('default')],
        selectedCollectionId: 'unknown',
      );

      expect(selected, 'default');
    });

    test('falls back to first collection when no default exists', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: [_collection('c2'), _collection('c3')],
        selectedCollectionId: 'unknown',
      );

      expect(selected, 'c2');
    });
  });
}
