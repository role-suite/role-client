import 'package:relay/core/models/collection_model.dart';

String? resolvePreferredCollectionId({required List<CollectionModel> loadedCollections, required String? selectedCollectionId}) {
  if (loadedCollections.isEmpty) return null;

  final selectedExists = selectedCollectionId != null && loadedCollections.any((collection) => collection.id == selectedCollectionId);
  if (selectedExists) return selectedCollectionId;

  final hasDefault = loadedCollections.any((collection) => collection.id == 'default');
  return hasDefault ? 'default' : loadedCollections.first.id;
}
