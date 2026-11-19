import 'package:dio/dio.dart';

import '../constants.dart';
import 'api_client.dart';
import 'remote_api_exception.dart';

/// Normalizes a user-entered role-node base URL: trims surrounding whitespace
/// and trailing slashes. Returns null when it is not an absolute http(s) URL
/// with a host, so callers can show one consistent validation message.
String? normalizeRoleNodeBaseUrl(String raw) {
  final normalized = raw.trim().replaceFirst(RegExp(r'/+$'), '');
  if (normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;
  return normalized;
}

/// Checks `GET /health` on a role-node instance. role-node mounts `/health`
/// at the bare app root (not under `/api/v1`), so this uses its own
/// interceptor-free [Dio] pointed at the raw base URL — same pattern the
/// token-refresh path already uses. Throws [RemoteApiException] on failure.
Future<void> checkRoleNodeHealth(String baseUrl) async {
  final dio = Dio(
    BaseOptions(baseUrl: baseUrl, connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout),
  );
  try {
    final response = await dio.get('/health');
    parseEnvelope(response.data);
  } on DioException catch (error) {
    throw mapDioError(error);
  }
}
