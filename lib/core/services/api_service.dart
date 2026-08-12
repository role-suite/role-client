import 'dart:io';

import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/services/relay_http_client.dart';

typedef ApiResponse<T> = RelayHttpResponse<T>;

class ApiServiceException implements Exception {
  ApiServiceException({required this.message, this.statusCode, this.statusMessage, this.responseData, this.cause, this.isOffline = false});

  factory ApiServiceException.fromSdk(RelayHttpException error) {
    return ApiServiceException(
      message: error.message,
      statusCode: error.statusCode,
      statusMessage: error.statusMessage,
      responseData: error.responseData,
      cause: error.cause,
      isOffline: error.isOffline,
    );
  }

  final String message;
  final int? statusCode;
  final String? statusMessage;
  final dynamic responseData;
  final Object? cause;
  final bool isOffline;

  bool get isPermissionError {
    final error = cause;
    if (error is! SocketException) {
      return false;
    }
    final osError = error.osError;
    final code = osError?.errorCode;
    final text = osError?.message.toLowerCase() ?? '';
    return code == 1 || text.contains('operation not permitted');
  }

  @override
  String toString() => statusCode == null ? message : 'HTTP $statusCode: $message';
}

class ApiService {
  ApiService._internal() {
    _sdkHttp = RelayHttpClient(baseUrl: '', connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout);
  }
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  static ApiService get instance => _instance;
  late final RelayHttpClient _sdkHttp;

  Future<ApiResponse<T>> send<T>({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic data,
  }) async {
    try {
      return await _sdkHttp.request<T>(method: method, path: url, headers: headers, queryParameters: queryParameters, data: data);
    } on RelayHttpException catch (error) {
      throw ApiServiceException.fromSdk(error);
    } catch (error) {
      throw ApiServiceException(message: error.toString(), cause: error);
    }
  }
}
