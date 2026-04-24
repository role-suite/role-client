import 'package:relay/core/services/relay_api/role_sdk_endpoints.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';

class AuthApiClient {
  AuthApiClient({required String baseUrl}) : _http = RelayApiHttp(baseUrl: baseUrl);

  final RelayApiHttp _http;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String accountType,
    String? teamName,
  }) async {
    final data = await _http.post(
      RoleSdkEndpoints.authRegister,
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
    final data = await _http.post(RoleSdkEndpoints.authLogin, data: {'email': email, 'password': password});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final data = await _http.post(RoleSdkEndpoints.authRefresh, data: {'refreshToken': refreshToken});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> logout(String refreshToken) async {
    final data = await _http.post(RoleSdkEndpoints.authLogout, data: {'refreshToken': refreshToken});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final http = RelayApiHttp(baseUrl: _http.baseUrl, accessToken: accessToken);
    final data = await http.get(RoleSdkEndpoints.authMe);
    return _asMap(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
