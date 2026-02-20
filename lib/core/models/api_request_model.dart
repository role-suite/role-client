import 'request_enums.dart';
import '../utils/extension.dart';

class ApiRequestModel {
  final String id;
  final String name;
  final HttpMethod method;
  final String urlTemplate;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final String? body;
  final BodyType bodyType;
  final Map<String, String> formDataFields;
  final AuthType authType;
  final Map<String, String> authConfig;
  final String? description;
  final String? filePath;
  final String collectionId;
  final String? environmentName;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApiRequestModel({
    required this.id,
    required this.name,
    required this.method,
    required this.urlTemplate,
    this.headers = const {},
    this.queryParams = const {},
    this.body,
    this.bodyType = BodyType.raw,
    this.formDataFields = const {},
    this.authType = AuthType.none,
    this.authConfig = const {},
    this.description,
    this.filePath,
    this.collectionId = 'default',
    this.environmentName,
    required this.createdAt,
    required this.updatedAt,
  });

  ApiRequestModel copyWith({
    String? id,
    String? name,
    HttpMethod? method,
    String? urlTemplate,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? body,
    BodyType? bodyType,
    Map<String, String>? formDataFields,
    AuthType? authType,
    Map<String, String>? authConfig,
    String? description,
    String? filePath,
    String? collectionId,
    String? environmentName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiRequestModel(
      id: id ?? this.id,
      name: name ?? this.name,
      method: method ?? this.method,
      urlTemplate: urlTemplate ?? this.urlTemplate,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      body: body ?? this.body,
      bodyType: bodyType ?? this.bodyType,
      formDataFields: formDataFields ?? this.formDataFields,
      authType: authType ?? this.authType,
      authConfig: authConfig ?? this.authConfig,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      collectionId: collectionId ?? this.collectionId,
      environmentName: environmentName ?? this.environmentName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'method': method.name,
      'urlTemplate': urlTemplate,
      'headers': headers,
      'queryParams': queryParams,
      'body': body,
      'bodyType': bodyType.name,
      'formDataFields': formDataFields,
      'authType': authType.name,
      'authConfig': authConfig,
      'description': description,
      'filePath': filePath,
      'collectionId': collectionId,
      'environmentName': environmentName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ApiRequestModel.fromJson(Map<String, dynamic> json) {
    return ApiRequestModel(
      id: json['id'] as String,
      name: json['name'] as String,
      method: HttpMethodX.fromString(json['method'] as String),
      urlTemplate: json['urlTemplate'] as String,
      headers: Map<String, String>.from(json['headers'] ?? const {}),
      queryParams: Map<String, String>.from(json['queryParams'] ?? const {}),
      body: json['body'] as String?,
      bodyType: json['bodyType'] != null ? BodyTypeX.fromString(json['bodyType'] as String) : BodyType.raw,
      formDataFields: Map<String, String>.from(json['formDataFields'] ?? const {}),
      authType: json['authType'] != null ? AuthTypeX.fromString(json['authType'] as String) : AuthType.none,
      authConfig: Map<String, String>.from(json['authConfig'] ?? const {}),
      description: json['description'] as String?,
      filePath: json['filePath'] as String?,
      collectionId: json['collectionId'] as String? ?? 'default',
      environmentName: json['environmentName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
