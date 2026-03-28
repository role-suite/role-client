import 'package:relay/core/services/role_node_api/role_node_http.dart';

class AuthApiClient {
  AuthApiClient({required String baseUrl}) : _http = RoleNodeHttp(baseUrl: baseUrl);

  final RoleNodeHttp _http;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String accountType,
    String? teamName,
  }) async {
    final data = await _http.post(
      '/api/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'accountType': accountType,
        if (teamName != null && teamName.trim().isNotEmpty) 'teamName': teamName.trim(),
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final data = await _http.post('/api/auth/login', data: {'email': email, 'password': password});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final data = await _http.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> logout(String refreshToken) async {
    final data = await _http.post('/api/auth/logout', data: {'refreshToken': refreshToken});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final http = RoleNodeHttp(baseUrl: _http.baseUrl, accessToken: accessToken);
    final data = await http.get('/api/auth/me');
    return _asMap(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
