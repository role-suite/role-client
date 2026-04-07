import 'package:dio/dio.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/services/role_node_api/role_node_endpoints.dart';

class RoleNodeHttp {
  RoleNodeHttp({required String baseUrl, String? accessToken, String? workspaceId})
    : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      _accessToken = accessToken?.trim(),
      _workspaceIdCache = workspaceId?.trim() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.defaultConnectTimeout,
        receiveTimeout: AppConstants.defaultReceiveTimeout,
        headers: {'Content-Type': 'application/json', if (_accessToken != null && _accessToken.isNotEmpty) 'Authorization': 'Bearer $_accessToken'},
      ),
    );
  }

  final String _baseUrl;
  final String? _accessToken;
  late final Dio _dio;
  String? _workspaceIdCache;

  String get baseUrl => _baseUrl;

  void requireBaseUrl() {
    if (_baseUrl.isEmpty) {
      throw ArgumentError('Remote API base URL is not set');
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    requireBaseUrl();
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_baseUrl$path', queryParameters: queryParameters);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  Future<dynamic> post(String path, {Object? data}) async {
    requireBaseUrl();
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_baseUrl$path', data: data);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  Future<dynamic> patch(String path, {Object? data}) async {
    requireBaseUrl();
    try {
      final response = await _dio.patch<Map<String, dynamic>>('$_baseUrl$path', data: data);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  Future<dynamic> delete(String path) async {
    requireBaseUrl();
    try {
      final response = await _dio.delete<Map<String, dynamic>>('$_baseUrl$path');
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  Future<String> resolveWorkspaceId() async {
    if (_workspaceIdCache != null && _workspaceIdCache!.isNotEmpty) {
      return _workspaceIdCache!;
    }

    final payload = await get(RoleNodeEndpoints.workspaces);
    final list = _asList(payload);
    if (list.isEmpty) {
      throw Exception('No workspace membership found for current user');
    }

    final first = list.first;
    final id = _asString(first['id']);
    if (id == null || id.isEmpty) {
      throw Exception('Workspace id was missing in /api/workspaces response');
    }
    _workspaceIdCache = id;
    return id;
  }

  dynamic _unwrap(Map<String, dynamic>? data) {
    if (data == null) return null;
    if (data.containsKey('success')) {
      final success = data['success'] == true;
      if (!success) {
        final message = data['message']?.toString() ?? 'Request failed';
        throw Exception(message);
      }
      return data['data'];
    }
    return data;
  }

  Exception _handleDioError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String message = 'Request failed';
    if (data is Map<String, dynamic>) {
      message = data['message']?.toString() ?? data['error']?.toString() ?? message;
    } else if (data != null) {
      message = data.toString();
    } else if (error.message != null && error.message!.trim().isNotEmpty) {
      message = error.message!.trim();
    }
    if (status != null) {
      return Exception('HTTP $status: $message');
    }
    return Exception(message);
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static String? _asString(dynamic value) {
    final str = value?.toString();
    if (str == null) return null;
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
