import '../utils/json_utils.dart';
import 'assertion.dart';
import 'enums.dart';
import 'key_value_entry.dart';
import 'request_body.dart';
import 'workspace_origin.dart';

class ApiRequest {
  final String id;
  final String collectionId;
  final String name;
  final HttpMethod method;
  final String url;
  final List<KeyValueEntry> headers;
  final List<KeyValueEntry> queryParams;
  final RequestBody requestBody;
  final AuthType authType;
  final Map<String, String> authConfig;
  final List<Assertion> assertions;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WorkspaceOrigin origin;
  final int? remoteWorkspaceId;
  final int? remoteId;
  final DateTime? syncedAt;

  const ApiRequest({
    required this.id,
    required this.collectionId,
    required this.name,
    this.method = HttpMethod.get,
    this.url = '',
    this.headers = const [],
    this.queryParams = const [],
    this.requestBody = const NoneBody(),
    this.authType = AuthType.none,
    this.authConfig = const {},
    this.assertions = const [],
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.origin = WorkspaceOrigin.local,
    this.remoteWorkspaceId,
    this.remoteId,
    this.syncedAt,
  });

  ApiRequest copyWith({
    String? id,
    String? collectionId,
    String? name,
    HttpMethod? method,
    String? url,
    List<KeyValueEntry>? headers,
    List<KeyValueEntry>? queryParams,
    RequestBody? requestBody,
    AuthType? authType,
    Map<String, String>? authConfig,
    List<Assertion>? assertions,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    WorkspaceOrigin? origin,
    int? remoteWorkspaceId,
    int? remoteId,
    DateTime? syncedAt,
  }) {
    return ApiRequest(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      requestBody: requestBody ?? this.requestBody,
      authType: authType ?? this.authType,
      authConfig: authConfig ?? this.authConfig,
      assertions: assertions ?? this.assertions,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      origin: origin ?? this.origin,
      remoteWorkspaceId: remoteWorkspaceId ?? this.remoteWorkspaceId,
      remoteId: remoteId ?? this.remoteId,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'name': name,
    'method': method.name,
    'url': url,
    'headers': headers.map((e) => e.toJson()).toList(),
    'queryParams': queryParams.map((e) => e.toJson()).toList(),
    'requestBody': requestBody.toJson(),
    'authType': authType.name,
    'authConfig': authConfig,
    'assertions': assertions.map((a) => a.toJson()).toList(),
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'origin': origin.toJson(),
    if (remoteWorkspaceId != null) 'remoteWorkspaceId': remoteWorkspaceId,
    if (remoteId != null) 'remoteId': remoteId,
    if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
  };

  factory ApiRequest.fromJson(Map<String, dynamic> json) {
    return ApiRequest(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'default',
      name: json['name'] as String? ?? 'Untitled Request',
      method: HttpMethodX.fromString(json['method'] as String? ?? 'get'),
      url: json['url'] as String? ?? '',
      headers: KeyValueEntry.listFrom(json['headers']),
      queryParams: KeyValueEntry.listFrom(json['queryParams']),
      requestBody: _requestBodyFrom(json),
      authType: AuthTypeX.fromString(json['authType'] as String? ?? 'none'),
      authConfig: stringMapFrom(json['authConfig']),
      assertions: (json['assertions'] as List? ?? const []).whereType<Map>().map((e) => Assertion.fromJson(Map<String, dynamic>.from(e))).toList(),
      description: json['description'] as String?,
      createdAt: dateTimeFrom(json['createdAt']),
      updatedAt: dateTimeFrom(json['updatedAt']),
      origin: WorkspaceOrigin.fromJson(json['origin']),
      remoteWorkspaceId: json['remoteWorkspaceId'] as int?,
      remoteId: json['remoteId'] as int?,
      syncedAt: json['syncedAt'] != null ? DateTime.tryParse(json['syncedAt'] as String) : null,
    );
  }

  /// New shape carries a `requestBody` union. A file written by `main` today
  /// instead carries the old `{bodyType, body, formFields}` triple — map that
  /// onto exactly one [RequestBody] variant. `BodyType.binary` never actually
  /// held binary data (the old editor just showed it in the same plain-text
  /// field as `raw`), so it migrates to [RawBody], not [BinaryBody].
  static RequestBody _requestBodyFrom(Map<String, dynamic> json) {
    final rawRequestBody = json['requestBody'];
    if (rawRequestBody is Map) {
      return RequestBody.fromJson(Map<String, dynamic>.from(rawRequestBody));
    }

    final legacyBodyType = BodyTypeX.fromString(json['bodyType'] as String? ?? 'none');
    final legacyBody = json['body'] as String?;
    final legacyFormFields = KeyValueEntry.listFrom(json['formFields']);

    switch (legacyBodyType) {
      case BodyType.none:
        return const NoneBody();
      case BodyType.raw:
      case BodyType.binary:
        return RawBody(raw: legacyBody ?? '');
      case BodyType.urlEncoded:
        return UrlEncodedBody(entries: legacyFormFields);
      case BodyType.formData:
        return FormDataBody(
          parts: legacyFormFields.map((e) => FormTextPart(key: e.key, value: e.value, enabled: e.enabled)).toList(),
        );
    }
  }
}
