import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/collection_model.dart';

String? resolvePreferredCollectionId({
  required List<CollectionModel> loadedCollections,
  required String? selectedCollectionId,
  required DataSourceMode mode,
}) {
  if (loadedCollections.isEmpty) return null;

  final selectedExists = selectedCollectionId != null && loadedCollections.any((collection) => collection.id == selectedCollectionId);
  if (selectedExists) return selectedCollectionId;

  if (mode == DataSourceMode.api) {
    return loadedCollections.first.id;
  }

  final hasDefault = loadedCollections.any((collection) => collection.id == 'default');
  return hasDefault ? 'default' : loadedCollections.first.id;
}
