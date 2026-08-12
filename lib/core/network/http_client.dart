import 'dart:io';

import 'package:dio/dio.dart';

class HttpCallResult {
  const HttpCallResult({required this.statusCode, this.statusMessage, this.data, this.headers = const {}});

  final int? statusCode;
  final String? statusMessage;
  final dynamic data;
  final Map<String, List<String>> headers;
}

class HttpCallException implements Exception {
  const HttpCallException({required this.message, this.statusCode, this.isOffline = false});

  final String message;
  final int? statusCode;
  final bool isOffline;
}

/// Thin Dio wrapper. Requests always carry an absolute, already-resolved URL —
/// there's no shared base URL, since every request can point anywhere.
class HttpClient {
  HttpClient({Duration connectTimeout = const Duration(seconds: 15), Duration receiveTimeout = const Duration(seconds: 30)})
    : _dio = Dio(BaseOptions(connectTimeout: connectTimeout, receiveTimeout: receiveTimeout, followRedirects: true));

  final Dio _dio;

  Future<HttpCallResult> send({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic data,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        url,
        data: data,
        options: Options(method: method.toUpperCase(), headers: headers, responseType: ResponseType.plain),
      );
      return HttpCallResult(
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (error) {
      throw HttpCallException(
        message: _messageFrom(error),
        statusCode: error.response?.statusCode,
        isOffline: _isOffline(error),
      );
    } catch (error) {
      throw HttpCallException(message: error.toString(), isOffline: error is SocketException);
    }
  }

  static String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return error.message ?? 'Network request failed';
  }

  static bool _isOffline(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.error is SocketException;
  }
}
