import '../utils/extension.dart';

class ApiRequestModel {
  final String id;
  final String name;
  final HttpMethod method;
  final String urlTemplate;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final String? body;
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
      description: json['description'] as String?,
      filePath: json['filePath'] as String?,
      collectionId: json['collectionId'] as String? ?? 'default',
      environmentName: json['environmentName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
