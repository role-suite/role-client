import 'api_request.dart';
import 'collection.dart';
import 'environment.dart';

class CollectionBundle {
  final Collection collection;
  final List<ApiRequest> requests;

  const CollectionBundle({required this.collection, required this.requests});

  Map<String, dynamic> toJson() => {
    'collection': collection.toJson(),
    'requests': requests.map((r) => r.toJson()).toList(),
  };

  factory CollectionBundle.fromJson(Map<String, dynamic> json) {
    final collectionJson = json['collection'];
    return CollectionBundle(
      collection: collectionJson is Map
          ? Collection.fromJson(Map<String, dynamic>.from(collectionJson))
          : Collection(id: 'imported', name: 'Imported Collection', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      requests: (json['requests'] as List? ?? const []).whereType<Map>().map((e) => ApiRequest.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class WorkspaceBundle {
  static const int currentVersion = 1;

  final int version;
  final DateTime exportedAt;
  final String? source;
  final List<CollectionBundle> collections;
  final List<Environment> environments;

  const WorkspaceBundle({
    this.version = currentVersion,
    required this.exportedAt,
    this.source,
    required this.collections,
    required this.environments,
  });

  static bool matchesSchema(Map<String, dynamic> json) => json.containsKey('version') && json.containsKey('collections');

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportedAt': exportedAt.toIso8601String(),
    'source': source,
    'collections': collections.map((c) => c.toJson()).toList(),
    'environments': environments.map((e) => e.toJson()).toList(),
  };

  factory WorkspaceBundle.fromJson(Map<String, dynamic> json) {
    return WorkspaceBundle(
      version: json['version'] is int ? json['version'] as int : currentVersion,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ?? DateTime.now(),
      source: json['source'] as String?,
      collections: (json['collections'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CollectionBundle.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      environments: (json['environments'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Environment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
