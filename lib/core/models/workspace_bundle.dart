import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';

class WorkspaceBundle {
  WorkspaceBundle({
    required this.version,
    required this.exportedAt,
    required this.collections,
    required this.environments,
    this.source,
  });

  static const int currentVersion = 1;

  final int version;
  final DateTime exportedAt;
  final List<CollectionBundle> collections;
  final List<EnvironmentModel> environments;
  final String? source;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'source': source,
      'collections': collections.map((c) => c.toJson()).toList(),
      'environments': environments.map((e) => e.toJson()).toList(),
    };
  }

  static bool matchesSchema(Map<String, dynamic> json) {
    return json.containsKey('version') && json.containsKey('collections');
  }

  factory WorkspaceBundle.fromJson(Map<String, dynamic> json) {
    final version = json['version'] is int ? json['version'] as int : currentVersion;
    final exportedAtRaw = json['exportedAt'];
    DateTime exportedAt;
    if (exportedAtRaw is String) {
      exportedAt = DateTime.tryParse(exportedAtRaw) ?? DateTime.now();
    } else {
      exportedAt = DateTime.now();
    }

    final collectionsJson = json['collections'];
    final environmentsJson = json['environments'];

    return WorkspaceBundle(
      version: version,
      exportedAt: exportedAt,
      source: json['source'] as String?,
      collections: collectionsJson is List
          ? collectionsJson
              .whereType<Map<String, dynamic>>()
              .map(CollectionBundle.fromJson)
              .toList()
          : const [],
      environments: environmentsJson is List
          ? environmentsJson
              .whereType<Map<String, dynamic>>()
              .map(EnvironmentModel.fromJson)
              .toList()
          : const [],
    );
  }
}

class CollectionBundle {
  CollectionBundle({
    required this.collection,
    required this.requests,
  });

  final CollectionModel collection;
  final List<ApiRequestModel> requests;

  Map<String, dynamic> toJson() {
    return {
      'collection': collection.toJson(),
      'requests': requests.map((r) => r.toJson()).toList(),
    };
  }

  factory CollectionBundle.fromJson(Map<String, dynamic> json) {
    final collectionJson = json['collection'];
    final requestsJson = json['requests'];
    return CollectionBundle(
      collection: collectionJson is Map<String, dynamic>
          ? CollectionModel.fromJson(collectionJson)
          : CollectionModel(
              id: 'imported-${DateTime.now().millisecondsSinceEpoch}',
              name: 'Imported Collection',
              description: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      requests: requestsJson is List
          ? requestsJson
              .whereType<Map<String, dynamic>>()
              .map(ApiRequestModel.fromJson)
              .toList()
          : const [],
    );
  }
}

