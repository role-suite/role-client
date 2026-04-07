import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/utils/extension.dart';

class SharedRequestModel {
  SharedRequestModel({required this.id, required this.fromWorkspaceId, required this.fromTeamName, required this.requestData, this.createdAt});

  final String id;
  final String fromWorkspaceId;
  final String fromTeamName;
  final Map<String, dynamic> requestData;
  final DateTime? createdAt;

  factory SharedRequestModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    DateTime? createdAt;
    if (createdAtRaw != null) {
      try {
        createdAt = DateTime.parse(createdAtRaw.toString());
      } catch (_) {
        createdAt = null;
      }
    }

    final requestPayload = json['request'] ?? json['endpoint'] ?? json['payload'] ?? const {};
    final requestData = requestPayload is Map<String, dynamic> ? requestPayload : <String, dynamic>{};

    return SharedRequestModel(
      id: (json['id'] ?? json['sharedId'] ?? '').toString(),
      fromWorkspaceId: (json['fromWorkspaceId'] ?? json['sourceWorkspaceId'] ?? '').toString(),
      fromTeamName: (json['fromTeamName'] ?? json['teamName'] ?? json['sourceTeamName'] ?? '').toString(),
      requestData: requestData,
      createdAt: createdAt,
    );
  }

  String get title {
    final value = requestData['name'] ?? requestData['title'] ?? 'Shared request';
    return value.toString();
  }

  String get method {
    final value = requestData['method'] ?? 'GET';
    return value.toString().toUpperCase();
  }

  String get url {
    final value = requestData['urlTemplate'] ?? requestData['url'] ?? '';
    return value.toString();
  }

  ApiRequestModel toApiRequestModel({required String collectionId}) {
    final now = DateTime.now();
    final methodRaw = requestData['method']?.toString() ?? 'GET';
    final bodyTypeRaw = requestData['bodyType']?.toString();
    final authTypeRaw = requestData['authType']?.toString();

    return ApiRequestModel(
      id: (requestData['id'] ?? 'shared_${now.millisecondsSinceEpoch}').toString(),
      name: title,
      method: HttpMethodX.fromString(methodRaw),
      urlTemplate: url,
      headers: _stringMap(requestData['headers']),
      queryParams: _stringMap(requestData['queryParams']),
      body: requestData['body']?.toString(),
      bodyType: bodyTypeRaw == null ? BodyType.raw : BodyTypeX.fromString(bodyTypeRaw),
      formDataFields: _stringMap(requestData['formDataFields']),
      authType: authTypeRaw == null ? AuthType.none : AuthTypeX.fromString(authTypeRaw),
      authConfig: _stringMap(requestData['authConfig']),
      description: requestData['description']?.toString(),
      filePath: requestData['filePath']?.toString(),
      collectionId: collectionId,
      environmentName: requestData['environmentName']?.toString(),
      createdAt: now,
      updatedAt: now,
    );
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is Map) {
      final result = <String, String>{};
      value.forEach((key, val) {
        result[key.toString()] = val?.toString() ?? '';
      });
      return result;
    }
    return const {};
  }
}
