import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_providers.dart';
import '../constants.dart';
import '../utils/logger.dart';
import 'remote_api_exception.dart';

/// Extracts `data` from a role-node success envelope, or throws the typed
/// [RemoteApiException] carried by a `{success:false, error:{...}}` envelope.
/// Pure and network-free so it's directly unit-testable.
dynamic parseEnvelope(dynamic body) {
  if (body is Map) {
    if (body['success'] == true) return body['data'];
    if (body['success'] == false) {
      final error = body['error'];
      if (error is Map) return throw RemoteApiException.fromEnvelope(Map<String, dynamic>.from(error));
    }
  }
  throw RemoteApiException.malformedResponse();
}

/// Maps a [DioException] to a [RemoteApiException]: prefers role-node's own
/// error envelope when the server answered with one (e.g. a 4xx/5xx body),
/// otherwise falls back to a network-level classification. Pure and
/// network-free so it's directly unit-testable.
RemoteApiException mapDioError(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['success'] == false && data['error'] is Map) {
    final retryAfterHeader = error.response?.headers.value('retry-after');
    return RemoteApiException.fromEnvelope(Map<String, dynamic>.from(data['error'] as Map), retryAfterSeconds: int.tryParse(retryAfterHeader ?? ''));
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return RemoteApiException.network(error.message);
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return RemoteApiException.unknown(error.message ?? error.toString());
  }
}

/// Talks to exactly one role-node instance (base URL + fixed `/api/v1`
/// prefix). Deliberately separate from [HttpClient] (`core/network/`),
/// which executes arbitrary user-defined requests — see §6 of
/// docs/08-ONLINE-MODE-INTEGRATION.md for why these must never merge.
///
/// No auth interceptor yet: this client has nothing to attach a token from
/// until AuthNotifier exists. Exposes [dio] so that phase can add one.
class RemoteApiClient {
  RemoteApiClient({required String baseUrl, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: '$baseUrl${AppConstants.apiPrefix}',
              connectTimeout: AppConstants.defaultConnectTimeout,
              receiveTimeout: AppConstants.defaultReceiveTimeout,
            ),
          );

  final Dio dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _send('GET', path, () => dio.get(path, queryParameters: queryParameters));

  Future<dynamic> post(String path, {dynamic data}) => _send('POST', path, () => dio.post(path, data: data));

  Future<dynamic> patch(String path, {dynamic data}) => _send('PATCH', path, () => dio.patch(path, data: data));

  Future<dynamic> delete(String path, {dynamic data}) => _send('DELETE', path, () => dio.delete(path, data: data));

  Future<dynamic> _send(String method, String path, Future<Response> Function() request) async {
    Log.d('$method $path', tag: 'remote-api');
    try {
      final response = await request();
      Log.d('$method $path -> ${response.statusCode}', tag: 'remote-api');
      return parseEnvelope(response.data);
    } on DioException catch (error) {
      final mapped = mapDioError(error);
      Log.e('$method $path failed', error: mapped, tag: 'remote-api');
      throw mapped;
    }
  }
}

/// Null until a base URL is configured (§9) — online mode simply isn't
/// offered until then.
final remoteApiClientProvider = Provider<RemoteApiClient?>((ref) {
  final baseUrl = ref.watch(remoteBaseUrlProvider);
  if (baseUrl == null) return null;
  return RemoteApiClient(baseUrl: baseUrl);
});
