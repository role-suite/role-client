import '../models/api_request.dart';
import '../models/collection.dart';
import '../models/enums.dart';
import '../models/environment.dart';
import '../models/environment_variable.dart';
import '../models/key_value_entry.dart';
import '../models/request_body.dart';
import '../models/workspace_bundle.dart';
import '../utils/id.dart';

/// Parses a Postman v2.x collection export into a [CollectionBundle],
/// flattening any nested folders into a single flat request list.
class PostmanImport {
  static bool looksLikeCollection(Map<String, dynamic> json) {
    return json['info'] is Map && json.containsKey('item');
  }

  static bool looksLikeEnvironment(Map<String, dynamic> json) {
    return json['values'] is List && json.containsKey('name') && !json.containsKey('item');
  }

  static CollectionBundle parseCollection(Map<String, dynamic> json) {
    final info = json['info'] as Map? ?? const {};
    final now = DateTime.now();
    final collectionId = generateId('col');
    final collection = Collection(id: collectionId, name: (info['name'] as String?) ?? 'Imported Collection', createdAt: now, updatedAt: now);

    final requests = <ApiRequest>[];
    _collectItems(json['item'] as List? ?? const [], collectionId, requests);
    return CollectionBundle(collection: collection, requests: requests);
  }

  static Environment parseEnvironment(Map<String, dynamic> json) {
    final now = DateTime.now();
    final variables = <EnvironmentVariable>[];
    var position = 0;
    for (final entry in (json['values'] as List? ?? const [])) {
      if (entry is Map && entry['key'] != null) {
        variables.add(
          EnvironmentVariable(
            key: entry['key'].toString(),
            value: entry['value']?.toString() ?? '',
            enabled: entry['enabled'] != false,
            position: position++,
          ),
        );
      }
    }
    return Environment(
      id: generateId('env'),
      name: (json['name'] as String?) ?? 'Imported Environment',
      variables: variables,
      createdAt: now,
      updatedAt: now,
    );
  }

  static void _collectItems(List items, String collectionId, List<ApiRequest> out) {
    for (final item in items) {
      if (item is! Map) continue;
      if (item['item'] is List) {
        _collectItems(item['item'] as List, collectionId, out);
        continue;
      }
      final request = item['request'];
      if (request is! Map) continue;
      out.add(_parseRequest(item['name'] as String? ?? 'Untitled Request', request, collectionId));
    }
  }

  static ApiRequest _parseRequest(String name, Map request, String collectionId) {
    final now = DateTime.now();
    final method = HttpMethodX.fromString((request['method'] as String?) ?? 'GET');

    final headers = <KeyValueEntry>[];
    for (final h in (request['header'] as List? ?? const [])) {
      if (h is Map && h['key'] != null) {
        headers.add(KeyValueEntry(key: h['key'].toString(), value: h['value']?.toString() ?? '', enabled: h['disabled'] != true));
      }
    }

    String url = '';
    final rawUrl = request['url'];
    if (rawUrl is String) {
      url = rawUrl;
    } else if (rawUrl is Map) {
      url = rawUrl['raw']?.toString() ?? '';
    }

    final queryParams = <KeyValueEntry>[];
    if (rawUrl is Map) {
      for (final q in (rawUrl['query'] as List? ?? const [])) {
        if (q is Map && q['key'] != null) {
          queryParams.add(KeyValueEntry(key: q['key'].toString(), value: q['value']?.toString() ?? '', enabled: q['disabled'] != true));
        }
      }
    }

    RequestBody requestBody = const NoneBody();
    final rawBody = request['body'];
    if (rawBody is Map) {
      switch (rawBody['mode']) {
        case 'raw':
          requestBody = RawBody(raw: rawBody['raw']?.toString() ?? '');
        case 'urlencoded':
          final entries = <KeyValueEntry>[];
          for (final f in (rawBody['urlencoded'] as List? ?? const [])) {
            if (f is Map && f['key'] != null) {
              entries.add(KeyValueEntry(key: f['key'].toString(), value: f['value']?.toString() ?? '', enabled: f['disabled'] != true));
            }
          }
          requestBody = UrlEncodedBody(entries: entries);
        case 'formdata':
          final parts = <FormPart>[];
          for (final f in (rawBody['formdata'] as List? ?? const [])) {
            if (f is Map && f['key'] != null) {
              parts.add(FormTextPart(key: f['key'].toString(), value: f['value']?.toString() ?? '', enabled: f['disabled'] != true));
            }
          }
          requestBody = FormDataBody(parts: parts);
      }
    }

    var authType = AuthType.none;
    final authConfig = <String, String>{};
    final auth = request['auth'];
    if (auth is Map) {
      String? paramValue(String key) {
        final list = auth[auth['type']];
        if (list is! List) return null;
        for (final p in list) {
          if (p is Map && p['key'] == key) return p['value']?.toString();
        }
        return null;
      }

      switch (auth['type']) {
        case 'bearer':
          authType = AuthType.bearer;
          authConfig[AuthConfigKeys.token] = paramValue('token') ?? '';
        case 'basic':
          authType = AuthType.basic;
          authConfig[AuthConfigKeys.username] = paramValue('username') ?? '';
          authConfig[AuthConfigKeys.password] = paramValue('password') ?? '';
        case 'apikey':
          authType = AuthType.apiKey;
          authConfig[AuthConfigKeys.key] = paramValue('key') ?? '';
          authConfig[AuthConfigKeys.value] = paramValue('value') ?? '';
          authConfig[AuthConfigKeys.addTo] = (paramValue('in') ?? 'header').toLowerCase();
      }
    }

    return ApiRequest(
      id: generateId('req'),
      collectionId: collectionId,
      name: name,
      method: method,
      url: url,
      headers: headers,
      queryParams: queryParams,
      requestBody: requestBody,
      authType: authType,
      authConfig: authConfig,
      createdAt: now,
      updatedAt: now,
    );
  }
}
