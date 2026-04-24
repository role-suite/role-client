import 'package:role_sdk/role_sdk_http.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/services/relay_api/role_sdk_endpoints.dart';

class RelayApiException implements Exception {
  RelayApiException(this.message, {this.statusCode, this.isOffline = false});

  final String message;
  final int? statusCode;
  final bool isOffline;

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => statusCode == null ? message : 'HTTP $statusCode: $message';
}

class RelayApiHttp {
  RelayApiHttp({required String baseUrl, String? accessToken, String? workspaceId})
    : _baseUrl = _normalizeBaseUrl(baseUrl),
      _accessToken = accessToken?.trim(),
      _workspaceIdCache = workspaceId?.trim() {
    _sdkHttp = RoleSdkHttpClient(
      baseUrl: _baseUrl,
      accessToken: _accessToken,
      connectTimeout: AppConstants.defaultConnectTimeout,
      receiveTimeout: AppConstants.defaultReceiveTimeout,
    );
  }

  final String _baseUrl;
  final String? _accessToken;
  late final RoleSdkHttpClient _sdkHttp;
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
      final response = await _sdkHttp.get<dynamic>(path, queryParameters: queryParameters);
      return _unwrap(response.data);
    } on RoleSdkHttpException catch (error) {
      throw _handleSdkHttpError(error);
    }
  }

  Future<dynamic> post(String path, {Object? data}) async {
    requireBaseUrl();
    try {
      final response = await _sdkHttp.post<dynamic>(path, data: data);
      return _unwrap(response.data);
    } on RoleSdkHttpException catch (error) {
      throw _handleSdkHttpError(error);
    }
  }

  Future<dynamic> patch(String path, {Object? data}) async {
    requireBaseUrl();
    try {
      final response = await _sdkHttp.patch<dynamic>(path, data: data);
      return _unwrap(response.data);
    } on RoleSdkHttpException catch (error) {
      throw _handleSdkHttpError(error);
    }
  }

  Future<dynamic> delete(String path) async {
    requireBaseUrl();
    try {
      final response = await _sdkHttp.delete<dynamic>(path);
      return _unwrap(response.data);
    } on RoleSdkHttpException catch (error) {
      throw _handleSdkHttpError(error);
    }
  }

  Future<String> resolveWorkspaceId() async {
    if (_workspaceIdCache != null && _workspaceIdCache!.isNotEmpty) {
      return _workspaceIdCache!;
    }

    final payload = await get(RoleSdkEndpoints.workspaces);
    final list = _asList(payload);
    if (list.isEmpty) {
      throw Exception('No workspace membership found for current user');
    }

    final first = list.first;
    final id = _asString(first['id']);
    if (id == null || id.isEmpty) {
      throw Exception('Workspace id was missing in workspaces response');
    }
    _workspaceIdCache = id;
    return id;
  }

  dynamic _unwrap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic> && data.containsKey('success')) {
      final rawSuccess = data['success'];
      final failed = rawSuccess == false || rawSuccess == 0 || (rawSuccess is String && rawSuccess.toLowerCase().trim() == 'false');
      if (failed) {
        final message = data['message']?.toString() ?? 'Request failed';
        throw Exception(message);
      }
      if (data.containsKey('data')) {
        return data['data'];
      }
      return data;
    }
    return data;
  }

  RelayApiException _handleSdkHttpError(RoleSdkHttpException error) {
    return RelayApiException(error.message, statusCode: error.statusCode, isOffline: error.isOffline);
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

  static String? _asString(dynamic value) {
    final str = value?.toString();
    if (str == null) return null;
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return RoleSdkHttpClient.defaultBackendBaseUrl;
  }
}
