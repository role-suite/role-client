import '../utils/json_utils.dart';
import 'enums.dart';

class ApiRequest {
  final String id;
  final String collectionId;
  final String name;
  final HttpMethod method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final BodyType bodyType;
  final String? body;
  final Map<String, String> formFields;
  final AuthType authType;
  final Map<String, String> authConfig;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ApiRequest({
    required this.id,
    required this.collectionId,
    required this.name,
    this.method = HttpMethod.get,
    this.url = '',
    this.headers = const {},
    this.queryParams = const {},
    this.bodyType = BodyType.none,
    this.body,
    this.formFields = const {},
    this.authType = AuthType.none,
    this.authConfig = const {},
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  ApiRequest copyWith({
    String? id,
    String? collectionId,
    String? name,
    HttpMethod? method,
    String? url,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    BodyType? bodyType,
    String? body,
    Map<String, String>? formFields,
    AuthType? authType,
    Map<String, String>? authConfig,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiRequest(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      bodyType: bodyType ?? this.bodyType,
      body: body ?? this.body,
      formFields: formFields ?? this.formFields,
      authType: authType ?? this.authType,
      authConfig: authConfig ?? this.authConfig,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'name': name,
    'method': method.name,
    'url': url,
    'headers': headers,
    'queryParams': queryParams,
    'bodyType': bodyType.name,
    'body': body,
    'formFields': formFields,
    'authType': authType.name,
    'authConfig': authConfig,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ApiRequest.fromJson(Map<String, dynamic> json) {
    return ApiRequest(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'default',
      name: json['name'] as String? ?? 'Untitled Request',
      method: HttpMethodX.fromString(json['method'] as String? ?? 'get'),
      url: json['url'] as String? ?? '',
      headers: stringMapFrom(json['headers']),
      queryParams: stringMapFrom(json['queryParams']),
      bodyType: BodyTypeX.fromString(json['bodyType'] as String? ?? 'none'),
      body: json['body'] as String?,
      formFields: stringMapFrom(json['formFields']),
      authType: AuthTypeX.fromString(json['authType'] as String? ?? 'none'),
      authConfig: stringMapFrom(json['authConfig']),
      description: json['description'] as String?,
      createdAt: dateTimeFrom(json['createdAt']),
      updatedAt: dateTimeFrom(json['updatedAt']),
    );
  }
}
