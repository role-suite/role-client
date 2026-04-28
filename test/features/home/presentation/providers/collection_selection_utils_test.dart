import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/features/home/presentation/providers/collection_selection_utils.dart';

CollectionModel _collection(String id) {
  final now = DateTime.now();
  return CollectionModel(id: id, name: id, createdAt: now, updatedAt: now);
}

void main() {
  group('resolvePreferredCollectionId', () {
    test('returns null when no collections are loaded', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: const [],
        selectedCollectionId: 'any',
        mode: DataSourceMode.local,
      );

      expect(selected, isNull);
    });

    test('keeps selected id when selected collection exists', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: [_collection('default'), _collection('team')],
        selectedCollectionId: 'team',
        mode: DataSourceMode.local,
      );

      expect(selected, 'team');
    });

    test('uses first collection in api mode when selection is missing', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: [_collection('c2'), _collection('default')],
        selectedCollectionId: 'unknown',
        mode: DataSourceMode.api,
      );

      expect(selected, 'c2');
    });

    test('uses default collection first in local mode when available', () {
      final selected = resolvePreferredCollectionId(
        loadedCollections: [_collection('c2'), _collection('default')],
        selectedCollectionId: 'unknown',
        mode: DataSourceMode.local,
      );

      expect(selected, 'default');
    });
  });
}
