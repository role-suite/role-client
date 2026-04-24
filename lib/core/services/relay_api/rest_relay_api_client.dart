import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/services/relay_api/role_sdk_endpoints.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';
import 'package:relay/core/utils/extension.dart';

class RestRelayApiClient implements RelayApiClient {
  RestRelayApiClient({required String baseUrl, String? apiKey, String? workspaceId})
    : _http = RelayApiHttp(baseUrl: baseUrl, accessToken: apiKey, workspaceId: workspaceId);

  final RelayApiHttp _http;

  @override
  Future<List<CollectionModel>> listCollections() async {
    final workspaceId = await _http.resolveWorkspaceId();
    final data = await _http.get(RoleSdkEndpoints.workspaceCollections(workspaceId));
    final list = _asList(data).map(_collectionFromApi).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<CollectionModel?> getCollection(String id) async {
    final workspaceId = await _http.resolveWorkspaceId();
    final data = await _http.get(RoleSdkEndpoints.workspaceCollection(workspaceId, id));
    if (data is! Map<String, dynamic>) return null;
    return _collectionFromApi(data);
  }

  @override
  Future<void> createCollection(CollectionModel collection) async {
    final workspaceId = await _http.resolveWorkspaceId();
    await _http.post(RoleSdkEndpoints.workspaceCollections(workspaceId), data: {'name': collection.name, 'description': collection.description});
  }

  @override
  Future<void> updateCollection(CollectionModel collection) async {
    final workspaceId = await _http.resolveWorkspaceId();
    await _http.patch(
      RoleSdkEndpoints.workspaceCollection(workspaceId, collection.id),
      data: {'name': collection.name, 'description': collection.description},
    );
  }

  @override
  Future<void> deleteCollection(String id) async {
    final workspaceId = await _http.resolveWorkspaceId();
    await _http.delete(RoleSdkEndpoints.workspaceCollection(workspaceId, id));
  }

  @override
  Future<List<EnvironmentModel>> listEnvironments() async {
    final workspaceId = await _http.resolveWorkspaceId();
    final envData = await _http.get(RoleSdkEndpoints.workspaceEnvironments(workspaceId));
    final envList = _asList(envData);
    final output = <EnvironmentModel>[];

    for (final env in envList) {
      final id = _readString(env, ['id', '_id']);
      final name = _readString(env, ['name']);
      if (id == null || name == null) continue;
      final vars = await _http.get(RoleSdkEndpoints.workspaceEnvironmentVariables(workspaceId, id));
      output.add(EnvironmentModel(name: name, variables: _variablesFromApi(vars)));
    }

    output.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output;
  }

  @override
  Future<EnvironmentModel?> getEnvironment(String name) async {
    final list = await listEnvironments();
    try {
      return list.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createEnvironment(EnvironmentModel environment) async {
    final workspaceId = await _http.resolveWorkspaceId();
    final created = await _http.post(RoleSdkEndpoints.workspaceEnvironments(workspaceId), data: {'name': environment.name});
    if (created is! Map<String, dynamic>) return;
    final envId = _readString(created, ['id', '_id']);
    if (envId == null) return;
    await _replaceEnvironmentVariables(workspaceId, envId, environment.variables);
  }

  @override
  Future<void> updateEnvironment(EnvironmentModel environment) async {
    final workspaceId = await _http.resolveWorkspaceId();
    final existing = await _findEnvironmentByName(workspaceId, environment.name);
    if (existing == null) {
      await createEnvironment(environment);
      return;
    }

    await _http.patch(RoleSdkEndpoints.workspaceEnvironment(workspaceId, existing.id), data: {'name': environment.name});
    await _replaceEnvironmentVariables(workspaceId, existing.id, environment.variables);
  }

  @override
  Future<void> deleteEnvironment(String name) async {
    final workspaceId = await _http.resolveWorkspaceId();
    final existing = await _findEnvironmentByName(workspaceId, name);
    if (existing == null) return;
    await _http.delete(RoleSdkEndpoints.workspaceEnvironment(workspaceId, existing.id));
  }

  @override
  Future<List<ApiRequestModel>> listRequests(String collectionId) async {
    final workspaceId = await _http.resolveWorkspaceId();
    final data = await _http.get(RoleSdkEndpoints.workspaceCollectionEndpoints(workspaceId, collectionId));
    return _asList(data).map((e) => _requestFromApi(e, collectionId)).toList();
  }

  @override
  Future<ApiRequestModel?> getRequest(String requestId) async {
    final collections = await listCollections();
    for (final collection in collections) {
      final requests = await listRequests(collection.id);
      for (final request in requests) {
        if (request.id == requestId) {
          return request;
        }
      }
    }
    return null;
  }

  @override
  Future<void> createRequest(ApiRequestModel request) async {
    final workspaceId = await _http.resolveWorkspaceId();
    await _http.post(RoleSdkEndpoints.workspaceCollectionEndpoints(workspaceId, request.collectionId), data: _requestToApi(request));
  }

  @override
  Future<void> updateRequest(ApiRequestModel request) async {
    final workspaceId = await _http.resolveWorkspaceId();
    await _http.patch(RoleSdkEndpoints.workspaceCollectionEndpoint(workspaceId, request.collectionId, request.id), data: _requestToApi(request));
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    final request = await getRequest(requestId);
    if (request == null) return;

    final workspaceId = await _http.resolveWorkspaceId();
    await _http.delete(RoleSdkEndpoints.workspaceCollectionEndpoint(workspaceId, request.collectionId, requestId));
  }

  Future<_RemoteEnvironment?> _findEnvironmentByName(String workspaceId, String name) async {
    final envData = await _http.get(RoleSdkEndpoints.workspaceEnvironments(workspaceId));
    final envList = _asList(envData);
    for (final env in envList) {
      final envName = _readString(env, ['name']);
      if (envName != name) continue;
      final envId = _readString(env, ['id', '_id']);
      if (envId == null) return null;
      return _RemoteEnvironment(id: envId, name: envName!);
    }
    return null;
  }

  Future<void> _replaceEnvironmentVariables(String workspaceId, String envId, Map<String, String> vars) async {
    final existingVars = _asList(await _http.get(RoleSdkEndpoints.workspaceEnvironmentVariables(workspaceId, envId)));
    for (final item in existingVars) {
      final id = _readString(item, ['id']);
      if (id == null) continue;
      await _http.delete(RoleSdkEndpoints.workspaceEnvironmentVariable(workspaceId, envId, id));
    }

    var position = 0;
    for (final entry in vars.entries) {
      await _http.post(
        RoleSdkEndpoints.workspaceEnvironmentVariables(workspaceId, envId),
        data: {'key': entry.key, 'value': entry.value, 'enabled': true, 'isSecret': false, 'position': position},
      );
      position += 1;
    }
  }

  static CollectionModel _collectionFromApi(Map<String, dynamic> json) {
    final now = DateTime.now();
    return CollectionModel(
      id: _readString(json, ['id', '_id']) ?? 'unknown',
      name: _readString(json, ['name']) ?? 'Collection',
      description: _readString(json, ['description']) ?? '',
      createdAt: _readDate(json, ['createdAt', 'created_at']) ?? now,
      updatedAt: _readDate(json, ['updatedAt', 'updated_at']) ?? now,
    );
  }

  static ApiRequestModel _requestFromApi(Map<String, dynamic> json, String collectionId) {
    final now = DateTime.now();
    final body = _readMap(json, ['body']);
    final auth = _readMap(json, ['auth']);
    return ApiRequestModel(
      id: _readString(json, ['id', '_id']) ?? 'unknown',
      name: _readString(json, ['name']) ?? 'Request',
      method: HttpMethodX.fromString(_readString(json, ['method']) ?? 'GET'),
      urlTemplate: _readString(json, ['url', 'urlTemplate']) ?? '',
      headers: _entriesToMap(json['headers']),
      queryParams: _entriesToMap(json['queryParams']),
      body: _bodyTextFromApi(body),
      bodyType: _bodyTypeFromApi(body),
      formDataFields: _formDataFromApi(body),
      authType: _authTypeFromApi(auth),
      authConfig: _authConfigFromApi(auth),
      description: _readString(json, ['description']),
      filePath: null,
      collectionId: collectionId,
      environmentName: null,
      createdAt: _readDate(json, ['createdAt', 'created_at']) ?? now,
      updatedAt: _readDate(json, ['updatedAt', 'updated_at']) ?? now,
    );
  }

  static Map<String, dynamic> _requestToApi(ApiRequestModel request) {
    final headers = request.headers.entries
        .where((e) => e.key.trim().isNotEmpty)
        .map((e) => {'key': e.key, 'value': e.value, 'enabled': true})
        .toList();
    final queryParams = request.queryParams.entries
        .where((e) => e.key.trim().isNotEmpty)
        .map((e) => {'key': e.key, 'value': e.value, 'enabled': true})
        .toList();

    return {
      'name': request.name,
      'method': request.method.name.toUpperCase(),
      'url': request.urlTemplate,
      'folderId': null,
      'headers': headers,
      'queryParams': queryParams,
      'body': _bodyToApi(request),
      'auth': _authToApi(request),
      'position': 0,
    };
  }

  static Map<String, String> _variablesFromApi(dynamic data) {
    final map = <String, String>{};
    final list = _asList(data);
    for (final item in list) {
      final enabled = item['enabled'];
      if (enabled is bool && !enabled) continue;
      final key = _readString(item, ['key', 'keyName']);
      if (key == null || key.isEmpty) continue;
      map[key] = _readString(item, ['value', 'valueText']) ?? '';
    }
    return map;
  }

  static Map<String, dynamic> _bodyToApi(ApiRequestModel request) {
    switch (request.bodyType) {
      case BodyType.none:
        return {'mode': 'none'};
      case BodyType.raw:
        return {
          'mode': 'raw',
          'contentType': request.headers['Content-Type'] ?? request.headers['content-type'] ?? 'application/json',
          'raw': request.body ?? '',
        };
      case BodyType.urlEncoded:
        return {
          'mode': 'urlencoded',
          'entries': request.formDataFields.entries.map((e) => {'key': e.key, 'value': e.value}).toList(),
        };
      case BodyType.formData:
        return {
          'mode': 'formdata',
          'entries': request.formDataFields.entries.map((e) => {'type': 'text', 'key': e.key, 'value': e.value}).toList(),
        };
      case BodyType.binary:
        final fileName = _fileNameFromPath(request.filePath) ?? 'file.bin';
        return {
          'mode': 'binary',
          'fileName': fileName,
          'dataBase64': request.body ?? '',
          'contentType': request.headers['Content-Type'] ?? request.headers['content-type'] ?? 'application/octet-stream',
        };
    }
  }

  static Map<String, dynamic> _authToApi(ApiRequestModel request) {
    switch (request.authType) {
      case AuthType.none:
        return {'type': 'none'};
      case AuthType.bearer:
        return {'type': 'bearer', 'token': request.authConfig[AuthConfigKeys.token] ?? ''};
      case AuthType.basic:
        return {
          'type': 'basic',
          'username': request.authConfig[AuthConfigKeys.username] ?? '',
          'password': request.authConfig[AuthConfigKeys.password] ?? '',
        };
      case AuthType.apiKey:
        return {'type': 'apiKey', 'key': request.authConfig[AuthConfigKeys.key] ?? '', 'value': request.authConfig[AuthConfigKeys.value] ?? ''};
    }
  }

  static BodyType _bodyTypeFromApi(Map<String, dynamic>? body) {
    final mode = (body?['mode']?.toString() ?? 'raw').toLowerCase();
    switch (mode) {
      case 'none':
        return BodyType.none;
      case 'urlencoded':
        return BodyType.urlEncoded;
      case 'formdata':
        return BodyType.formData;
      case 'binary':
        return BodyType.binary;
      default:
        return BodyType.raw;
    }
  }

  static String? _bodyTextFromApi(Map<String, dynamic>? body) {
    if (body == null) return null;
    final mode = (body['mode']?.toString() ?? '').toLowerCase();
    if (mode == 'raw') return body['raw']?.toString();
    if (mode == 'binary') {
      final dataBase64 = body['dataBase64'];
      if (dataBase64 != null) return dataBase64.toString();
      final file = body['file'];
      if (file is Map<String, dynamic>) {
        return file['dataBase64']?.toString() ?? file['contentBase64']?.toString();
      }
    }
    return null;
  }

  static Map<String, String> _formDataFromApi(Map<String, dynamic>? body) {
    if (body == null) return const {};
    final mode = (body['mode']?.toString() ?? '').toLowerCase();
    if (mode != 'formdata' && mode != 'urlencoded') return const {};
    final entries = body['entries'] ?? body[mode];
    if (entries is! List) return const {};
    final output = <String, String>{};
    for (final item in entries.whereType<Map<String, dynamic>>()) {
      if (mode == 'formdata' && (item['type']?.toString().toLowerCase() ?? 'text') == 'file') {
        continue;
      }
      final k = _readString(item, ['key']);
      if (k == null || k.isEmpty) continue;
      output[k] = _readString(item, ['value']) ?? '';
    }
    return output;
  }

  static AuthType _authTypeFromApi(Map<String, dynamic>? auth) {
    final type = (auth?['type']?.toString() ?? 'none').toLowerCase();
    switch (type) {
      case 'bearer':
        return AuthType.bearer;
      case 'basic':
        return AuthType.basic;
      case 'apikey':
      case 'api_key':
        return AuthType.apiKey;
      default:
        return AuthType.none;
    }
  }

  static Map<String, String> _authConfigFromApi(Map<String, dynamic>? auth) {
    if (auth == null) return const {};
    final type = _authTypeFromApi(auth);
    switch (type) {
      case AuthType.none:
        return const {};
      case AuthType.bearer:
        return {
          AuthConfigKeys.token: _readString(auth, ['token']) ?? '',
        };
      case AuthType.basic:
        return {
          AuthConfigKeys.username: _readString(auth, ['username']) ?? '',
          AuthConfigKeys.password: _readString(auth, ['password']) ?? '',
        };
      case AuthType.apiKey:
        return {
          AuthConfigKeys.key: _readString(auth, ['key']) ?? '',
          AuthConfigKeys.value: _readString(auth, ['value']) ?? '',
        };
    }
  }

  static Map<String, String> _entriesToMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    }
    if (value is Map) {
      final output = <String, String>{};
      value.forEach((k, v) {
        if (k == null) return;
        output[k.toString()] = v?.toString() ?? '';
      });
      return output;
    }
    if (value is! List) return const {};
    final output = <String, String>{};
    for (final item in value.whereType<Map<String, dynamic>>()) {
      final enabled = item['enabled'];
      if (enabled is bool && !enabled) continue;
      final key = _readString(item, ['key']);
      if (key == null || key.isEmpty) continue;
      output[key] = _readString(item, ['value']) ?? '';
    }
    return output;
  }

  static String? _fileNameFromPath(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final name = parts.isEmpty ? '' : parts.last.trim();
    return name.isEmpty ? null : name;
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }

    if (value is Map<String, dynamic>) {
      final items = value['items'] ?? value['data'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }

    return const [];
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return null;
  }

  static DateTime? _readDate(Map<String, dynamic> json, List<String> keys) {
    final value = _readString(json, keys);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  static Map<String, dynamic>? _readMap(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) return value;
    }
    return null;
  }
}

class _RemoteEnvironment {
  _RemoteEnvironment({required this.id, required this.name});

  final String id;
  final String name;
}
