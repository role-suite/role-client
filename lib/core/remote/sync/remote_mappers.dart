import '../../models/api_request.dart';
import '../../models/collection.dart';
import '../../models/enums.dart';
import '../../models/environment.dart';
import '../../models/environment_variable.dart';
import '../../models/key_value_entry.dart';
import '../../models/request_body.dart';
import '../../models/workspace_origin.dart';
import '../../utils/json_utils.dart';

/// Translates role-node's wire shapes (checked directly against
/// `role-node/src/modules/{collections,environments}/service.ts` response
/// mappers, not guessed) into Röle's own domain models, stamped as
/// remote-origin. Pure and network-free — see §3.3 of
/// docs/08-ONLINE-MODE-INTEGRATION.md: these are an anti-corruption-layer
/// boundary, not shared types with the server.
///
/// Local ids for remote-derived entities are deterministic
/// (`remote-<kind>-<workspaceId>-<remoteId>`), not random — this phase only
/// reads, so a stable derived id (rather than a separate id-mapping table)
/// is enough to survive repeated refetches untouched.
String remoteCollectionLocalId(int workspaceId, int remoteId) => 'remote-col-$workspaceId-$remoteId';
String remoteRequestLocalId(int workspaceId, int remoteId) => 'remote-req-$workspaceId-$remoteId';
String remoteEnvironmentLocalId(int workspaceId, int remoteId) => 'remote-env-$workspaceId-$remoteId';

Collection collectionFromRemote(Map<String, dynamic> json, {required int workspaceId}) {
  final remoteId = json['id'] as int;
  return Collection(
    id: remoteCollectionLocalId(workspaceId, remoteId),
    name: json['name'] as String? ?? 'Untitled Collection',
    description: json['description'] as String? ?? '',
    createdAt: dateTimeFrom(json['createdAt']),
    updatedAt: dateTimeFrom(json['updatedAt']),
    origin: WorkspaceOrigin.remote,
    remoteWorkspaceId: workspaceId,
    remoteId: remoteId,
    syncedAt: DateTime.now(),
  );
}

ApiRequest apiRequestFromRemoteEndpoint(Map<String, dynamic> json, {required int workspaceId, required String collectionId}) {
  final remoteId = json['id'] as int;
  final auth = _authFromWire(json['auth']);
  return ApiRequest(
    id: remoteRequestLocalId(workspaceId, remoteId),
    collectionId: collectionId,
    name: json['name'] as String? ?? 'Untitled Request',
    method: HttpMethodX.fromString(json['method'] as String? ?? 'GET'),
    url: json['url'] as String? ?? '',
    headers: KeyValueEntry.listFrom(json['headers']),
    queryParams: KeyValueEntry.listFrom(json['queryParams']),
    requestBody: _requestBodyFromWire(json['body']),
    authType: auth.$1,
    authConfig: auth.$2,
    createdAt: dateTimeFrom(json['createdAt']),
    updatedAt: dateTimeFrom(json['updatedAt']),
    origin: WorkspaceOrigin.remote,
    remoteWorkspaceId: workspaceId,
    remoteId: remoteId,
    syncedAt: DateTime.now(),
  );
}

Environment environmentFromRemote(Map<String, dynamic> json, {required int workspaceId, List<EnvironmentVariable> variables = const []}) {
  final remoteId = json['id'] as int;
  return Environment(
    id: remoteEnvironmentLocalId(workspaceId, remoteId),
    name: json['name'] as String? ?? 'Untitled Environment',
    variables: variables,
    createdAt: dateTimeFrom(json['createdAt']),
    updatedAt: dateTimeFrom(json['updatedAt']),
    origin: WorkspaceOrigin.remote,
    remoteWorkspaceId: workspaceId,
    remoteId: remoteId,
    syncedAt: DateTime.now(),
  );
}

/// `environment_variables` rows already use `key`/`value`/`enabled`/
/// `isSecret`/`position` field names identical to [EnvironmentVariable]'s own
/// shape (role-node/src/modules/environments/service.ts `mapEnvironmentVariable`)
/// — only `id` needs an explicit rename to `remoteId`, so
/// `WorkspacePushService.reconcileVariables` can match a row across a key
/// rename instead of only by `key`.
EnvironmentVariable environmentVariableFromRemote(Map<String, dynamic> json) =>
    EnvironmentVariable.fromJson(json).copyWith(remoteId: json['id'] as int?);

/// role-node's `endpointBodySchema` tags variants with `mode`; Röle's
/// [RequestBody] tags them with `type` and uses `parts` (not `entries`) for
/// form-data — translate field-by-field rather than reusing
/// `RequestBody.fromJson` directly.
RequestBody _requestBodyFromWire(dynamic wire) {
  if (wire is! Map) return const NoneBody();
  final json = Map<String, dynamic>.from(wire);
  switch (json['mode']) {
    case 'raw':
      return RawBody(contentType: json['contentType'] as String?, raw: json['raw'] as String? ?? '');
    case 'urlencoded':
      return UrlEncodedBody(entries: KeyValueEntry.listFrom(json['entries']));
    case 'formdata':
      final entries = (json['entries'] as List? ?? const []).whereType<Map>().map(Map<String, dynamic>.from);
      return FormDataBody(
        parts: entries.map((e) {
          if (e['type'] == 'file') {
            return FormFilePart(
              key: e['key'] as String? ?? '',
              fileName: e['fileName'] as String? ?? '',
              contentType: e['contentType'] as String?,
              dataBase64: e['dataBase64'] as String? ?? '',
              enabled: e['enabled'] as bool? ?? true,
            );
          }
          return FormTextPart(key: e['key'] as String? ?? '', value: e['value'] as String? ?? '', enabled: e['enabled'] as bool? ?? true);
        }).toList(),
      );
    case 'binary':
      return BinaryBody(
        fileName: json['fileName'] as String?,
        contentType: json['contentType'] as String?,
        dataBase64: json['dataBase64'] as String? ?? '',
      );
    case 'none':
    default:
      return const NoneBody();
  }
}

/// role-node's `endpointAuthSchema`: `{type: none|bearer|basic, ...}`. No
/// remote equivalent for [AuthType.apiKey] yet.
(AuthType, Map<String, String>) _authFromWire(dynamic wire) {
  if (wire is! Map) return (AuthType.none, const {});
  final json = Map<String, dynamic>.from(wire);
  switch (json['type']) {
    case 'bearer':
      return (AuthType.bearer, {AuthConfigKeys.token: json['token'] as String? ?? ''});
    case 'basic':
      return (
        AuthType.basic,
        {AuthConfigKeys.username: json['username'] as String? ?? '', AuthConfigKeys.password: json['password'] as String? ?? ''},
      );
    case 'none':
    default:
      return (AuthType.none, const {});
  }
}

/// The push-side inverse of [_requestBodyFromWire] — Röle's [RequestBody] (a
/// `type`-tagged union with `parts` for form-data) back to role-node's
/// `endpointBodySchema` (a `mode`-tagged union with `entries`). Used by
/// `WorkspacePushService` when sending a local edit upstream.
Map<String, dynamic> requestBodyToWire(RequestBody body) {
  switch (body) {
    case NoneBody():
      return {'mode': 'none'};
    case RawBody(:final contentType, :final raw):
      return {'mode': 'raw', 'contentType': ?contentType, 'raw': raw};
    case UrlEncodedBody(:final entries):
      return {'mode': 'urlencoded', 'entries': entries.map((e) => e.toJson()).toList()};
    case FormDataBody(:final parts):
      return {
        'mode': 'formdata',
        'entries': parts.map((part) {
          if (part is FormFilePart) {
            return {
              'type': 'file',
              'key': part.key,
              'fileName': part.fileName,
              if (part.contentType != null) 'contentType': part.contentType,
              'dataBase64': part.dataBase64,
              'enabled': part.enabled,
            };
          }
          final text = part as FormTextPart;
          return {'type': 'text', 'key': text.key, 'value': text.value, 'enabled': text.enabled};
        }).toList(),
      };
    case BinaryBody(:final fileName, :final contentType, :final dataBase64):
      return {'mode': 'binary', 'fileName': ?fileName, 'contentType': ?contentType, 'dataBase64': dataBase64};
  }
}

/// The push-side inverse of [_authFromWire]. [AuthType.apiKey] has no
/// role-node equivalent — sent as `{type: "none"}` rather than dropping the
/// field, since the endpoint's `auth` key isn't optional-with-omit on update.
Map<String, dynamic> authToWire(AuthType type, Map<String, String> config) {
  switch (type) {
    case AuthType.bearer:
      return {'type': 'bearer', 'token': config[AuthConfigKeys.token] ?? ''};
    case AuthType.basic:
      return {'type': 'basic', 'username': config[AuthConfigKeys.username] ?? '', 'password': config[AuthConfigKeys.password] ?? ''};
    case AuthType.none:
    case AuthType.apiKey:
      return {'type': 'none'};
  }
}
