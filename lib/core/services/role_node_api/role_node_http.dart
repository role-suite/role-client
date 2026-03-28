import 'package:dio/dio.dart';
import 'package:relay/core/constants/app_constants.dart';

class RoleNodeHttp {
  RoleNodeHttp({required String baseUrl, String? accessToken})
    : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      _accessToken = accessToken?.trim() {
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
    final response = await _dio.get<Map<String, dynamic>>('$_baseUrl$path', queryParameters: queryParameters);
    return _unwrap(response.data);
  }

  Future<dynamic> post(String path, {Object? data}) async {
    requireBaseUrl();
    final response = await _dio.post<Map<String, dynamic>>('$_baseUrl$path', data: data);
    return _unwrap(response.data);
  }

  Future<dynamic> patch(String path, {Object? data}) async {
    requireBaseUrl();
    final response = await _dio.patch<Map<String, dynamic>>('$_baseUrl$path', data: data);
    return _unwrap(response.data);
  }

  Future<dynamic> delete(String path) async {
    requireBaseUrl();
    final response = await _dio.delete<Map<String, dynamic>>('$_baseUrl$path');
    return _unwrap(response.data);
  }

  Future<String> resolveWorkspaceId() async {
    if (_workspaceIdCache != null && _workspaceIdCache!.isNotEmpty) {
      return _workspaceIdCache!;
    }

    final payload = await get('/api/workspaces');
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
