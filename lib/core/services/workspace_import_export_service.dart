import 'dart:convert';

import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/core/utils/uuid.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

class WorkspaceImportExportService {
  WorkspaceImportExportService({
    required RequestRepository requestRepository,
    required CollectionRepository collectionRepository,
    required EnvironmentRepository environmentRepository,
  })  : _requestRepository = requestRepository,
        _collectionRepository = collectionRepository,
        _environmentRepository = environmentRepository;

  final RequestRepository _requestRepository;
  final CollectionRepository _collectionRepository;
  final EnvironmentRepository _environmentRepository;

  Future<WorkspaceBundle> buildBundle() async {
    final collections = await _collectionRepository.getAllCollections();
    final bundles = <CollectionBundle>[];

    for (final collection in collections) {
      final requests = await _requestRepository.getRequestsByCollection(collection.id);
      bundles.add(
        CollectionBundle(
          collection: collection,
          requests: requests,
        ),
      );
    }

    final environments = await _environmentRepository.getAllEnvironments();

    return WorkspaceBundle(
      version: WorkspaceBundle.currentVersion,
      exportedAt: DateTime.now().toUtc(),
      source: 'relay',
      collections: bundles,
      environments: environments,
    );
  }

  Future<WorkspaceBundle> parseImportFile(String rawJson) async {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unsupported JSON structure.');
    }

    if (WorkspaceBundle.matchesSchema(decoded)) {
      return WorkspaceBundle.fromJson(decoded);
    }

    if (_PostmanCollectionParser.matches(decoded)) {
      return _PostmanCollectionParser.toWorkspaceBundle(decoded);
    }

    if (_PostmanEnvironmentParser.matches(decoded)) {
      final env = _PostmanEnvironmentParser.toEnvironment(decoded);
      return WorkspaceBundle(
        version: WorkspaceBundle.currentVersion,
        exportedAt: DateTime.now().toUtc(),
        source: 'postman-environment',
        collections: const [],
        environments: [env],
      );
    }

    throw const FormatException('Unsupported import file. Expected a Relay export or Postman file.');
  }
}

class _PostmanCollectionParser {
  static bool matches(Map<String, dynamic> json) {
    final info = json['info'];
    final schema = info is Map<String, dynamic> ? info['schema'] : null;
    if (schema is String && schema.contains('postman.com/json/collection')) {
      return true;
    }
    return json['item'] is List;
  }

  static WorkspaceBundle toWorkspaceBundle(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>? ?? const {};
    final collectionName = (info['name'] as String?)?.trim();
    final collectionId = UuidUtils.generate();
    final requests = _flattenItems(json['item']).map((item) {
      return _PostmanRequest(
        name: item.name,
        requestJson: item.requestJson,
      ).toApiRequest(collectionId);
    }).toList();

    final metadata = CollectionModel(
      id: collectionId,
      name: (collectionName == null || collectionName.isEmpty) ? 'Imported Collection' : collectionName,
      description: 'Imported from Postman',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return WorkspaceBundle(
      version: WorkspaceBundle.currentVersion,
      exportedAt: DateTime.now().toUtc(),
      source: 'postman-collection',
      collections: [
        CollectionBundle(collection: metadata, requests: requests),
      ],
      environments: const [],
    );
  }

  static List<_PostmanItem> _flattenItems(dynamic rawItems, [String? prefix]) {
    final result = <_PostmanItem>[];
    if (rawItems is! List) {
      return result;
    }
    for (final entry in rawItems) {
      if (entry is! Map<String, dynamic>) continue;
      final name = (entry['name'] as String?)?.trim();
      final displayName = (name == null || name.isEmpty)
          ? (prefix ?? 'Untitled Request')
          : (prefix != null ? '$prefix / $name' : name);
      final nestedItems = entry['item'];
      if (nestedItems is List) {
        result.addAll(_flattenItems(nestedItems, displayName));
      } else if (entry['request'] is Map<String, dynamic>) {
        result.add(
          _PostmanItem(
            name: displayName,
            requestJson: Map<String, dynamic>.from(entry['request'] as Map<String, dynamic>),
          ),
        );
      }
    }
    return result;
  }
}

class _PostmanEnvironmentParser {
  static bool matches(Map<String, dynamic> json) {
    return json['values'] is List;
  }

  static EnvironmentModel toEnvironment(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    final vars = <String, String>{};
    final values = json['values'];
    if (values is List) {
      for (final value in values) {
        if (value is! Map<String, dynamic>) continue;
        if (value['enabled'] == false) continue;
        final key = (value['key'] as String?)?.trim();
        if (key == null || key.isEmpty) continue;
        final rawValue = value['value'];
        vars[key] = rawValue?.toString() ?? '';
      }
    }
    return EnvironmentModel(
      name: (name == null || name.isEmpty) ? 'Imported Environment' : name,
      variables: vars,
    );
  }
}

class _PostmanItem {
  _PostmanItem({
    required this.name,
    required this.requestJson,
  });

  final String name;
  final Map<String, dynamic> requestJson;
}

class _PostmanRequest {
  _PostmanRequest({
    required this.name,
    required this.requestJson,
  });

  final String name;
  final Map<String, dynamic> requestJson;

  ApiRequestModel toApiRequest(String collectionId) {
    final now = DateTime.now();
    return ApiRequestModel(
      id: UuidUtils.generate(),
      name: name,
      method: _parseMethod(requestJson['method']),
      urlTemplate: _parseUrl(requestJson['url']),
      headers: _parseHeaders(requestJson),
      queryParams: _parseQueryParams(requestJson['url']),
      body: _parseBody(requestJson['body']),
      description: _parseDescription(requestJson),
      collectionId: collectionId,
      createdAt: now,
      updatedAt: now,
    );
  }

  HttpMethod _parseMethod(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return HttpMethodX.fromString(raw);
      } catch (_) {
        return HttpMethod.get;
      }
    }
    return HttpMethod.get;
  }

  String _parseUrl(dynamic rawUrl) {
    if (rawUrl is String && rawUrl.isNotEmpty) {
      return rawUrl;
    }
    if (rawUrl is Map<String, dynamic>) {
      final raw = rawUrl['raw'];
      if (raw is String && raw.isNotEmpty) {
        return raw;
      }
      final protocol = rawUrl['protocol'];
      final host = _joinSegments(rawUrl['host']);
      final path = _joinSegments(rawUrl['path'], '/');
      final buffer = StringBuffer();
      if (protocol is String && protocol.isNotEmpty) {
        buffer.write('$protocol://');
      }
      if (host.isNotEmpty) {
        buffer.write(host);
      }
      if (path.isNotEmpty) {
        if (!path.startsWith('/') && buffer.isNotEmpty) {
          buffer.write('/');
        }
        buffer.write(path);
      }
      return buffer.isEmpty ? 'https://example.com' : buffer.toString();
    }
    return 'https://example.com';
  }

  Map<String, String> _parseHeaders(Map<String, dynamic> json) {
    final headers = <String, String>{};
    final headerList = json['header'];
    if (headerList is List) {
      for (final header in headerList) {
        if (header is! Map<String, dynamic>) continue;
        if (header['disabled'] == true) continue;
        final key = (header['key'] as String?)?.trim();
        if (key == null || key.isEmpty) continue;
        headers[key] = header['value']?.toString() ?? '';
      }
    }

    final auth = json['auth'];
    if (auth is Map<String, dynamic>) {
      final type = auth['type'];
      if (type == 'bearer') {
        final bearerList = auth['bearer'];
        if (bearerList is List) {
          for (final bearer in bearerList) {
            if (bearer is! Map<String, dynamic>) continue;
            final token = bearer['value']?.toString();
            if (token != null && token.isNotEmpty) {
              headers.putIfAbsent('Authorization', () => 'Bearer $token');
              break;
            }
          }
        }
      }
    }

    return headers;
  }

  Map<String, String> _parseQueryParams(dynamic rawUrl) {
    final params = <String, String>{};
    if (rawUrl is Map<String, dynamic>) {
      final query = rawUrl['query'];
      if (query is List) {
        for (final entry in query) {
          if (entry is! Map<String, dynamic>) continue;
          if (entry['disabled'] == true) continue;
          final key = (entry['key'] as String?)?.trim();
          if (key == null || key.isEmpty) continue;
          params[key] = entry['value']?.toString() ?? '';
        }
      }
    }
    return params;
  }

  String? _parseBody(dynamic body) {
    if (body is! Map<String, dynamic>) {
      return null;
    }
    final mode = body['mode'];
    if (mode == 'raw') {
      final raw = body['raw'];
      return raw is String && raw.trim().isNotEmpty ? raw : null;
    }

    if (mode == 'urlencoded' || mode == 'formdata') {
      final entries = body[mode];
      if (entries is! List) {
        return null;
      }
      final map = <String, dynamic>{};
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;
        if (entry['disabled'] == true) continue;
        final key = (entry['key'] as String?)?.trim();
        if (key == null || key.isEmpty) continue;
        final type = entry['type'] as String? ?? 'text';
        if (type == 'file') {
          map[key] = '[file] ${entry['src'] ?? ''}';
        } else {
          map[key] = entry['value']?.toString() ?? '';
        }
      }
      if (map.isEmpty) {
        return null;
      }
      return const JsonEncoder.withIndent('  ').convert(map);
    }

    return null;
  }

  String? _parseDescription(Map<String, dynamic> requestJson) {
    final description = requestJson['description'];
    if (description is String && description.trim().isNotEmpty) {
      return description.trim();
    }
    return null;
  }

  String _joinSegments(dynamic raw, [String separator = '.']) {
    if (raw is List) {
      return raw.whereType<String>().join(separator);
    }
    if (raw is String) {
      return raw;
    }
    return '';
  }
}

