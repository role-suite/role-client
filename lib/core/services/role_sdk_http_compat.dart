import 'dart:io';

import 'package:dio/dio.dart';
import 'package:relay/core/constants/app_constants.dart';

class RoleSdkResponse<T> {
  RoleSdkResponse({required this.statusCode, this.statusMessage, this.data, Map<String, List<String>>? headers}) : headers = headers ?? const {};

  final int? statusCode;
  final String? statusMessage;
  final T? data;
  final Map<String, List<String>> headers;

  String? headerValue(String name) {
    final values = headers[name.toLowerCase()] ?? headers[name];
    if (values == null || values.isEmpty) return null;
    return values.join(', ');
  }
}

class RoleSdkFormData {
  RoleSdkFormData({required this.fields});

  final Map<String, String> fields;
}

class RoleSdkHttpException implements Exception {
  RoleSdkHttpException({
    required this.message,
    this.statusCode,
    this.statusMessage,
    this.responseData,
    this.cause,
    this.isOffline = false,
  });

  final String message;
  final int? statusCode;
  final String? statusMessage;
  final dynamic responseData;
  final Object? cause;
  final bool isOffline;
}

class RoleSdkHttpClient {
  RoleSdkHttpClient({
    required String baseUrl,
    String? accessToken,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, String>? defaultHeaders,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
           connectTimeout: connectTimeout ?? AppConstants.defaultConnectTimeout,
           receiveTimeout: receiveTimeout ?? AppConstants.defaultReceiveTimeout,
           headers: {
             ...?defaultHeaders,
             if (accessToken != null && accessToken.trim().isNotEmpty) 'Authorization': 'Bearer ${accessToken.trim()}',
           },
         ),
       );

  factory RoleSdkHttpClient.localBackend({Duration? connectTimeout, Duration? receiveTimeout}) {
    return RoleSdkHttpClient(
      baseUrl: defaultBackendBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  static String get defaultBackendBaseUrl => AppConstants.defaultBackendBaseUrl;

  final Dio _dio;

  Future<RoleSdkResponse<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Map<String, dynamic>? headers}) {
    return request<T>(method: 'GET', path: path, queryParameters: queryParameters, headers: headers);
  }

  Future<RoleSdkResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, dynamic>? headers}) {
    return request<T>(method: 'POST', path: path, data: data, queryParameters: queryParameters, headers: headers);
  }

  Future<RoleSdkResponse<T>> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, dynamic>? headers}) {
    return request<T>(method: 'PATCH', path: path, data: data, queryParameters: queryParameters, headers: headers);
  }

  Future<RoleSdkResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, dynamic>? headers}) {
    return request<T>(method: 'DELETE', path: path, data: data, queryParameters: queryParameters, headers: headers);
  }

  Future<RoleSdkResponse<T>> request<T>({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final payload = switch (data) {
        RoleSdkFormData _ => FormData.fromMap(data.fields),
        _ => data,
      };

      final response = await _dio.request<T>(
        path,
        data: payload,
        queryParameters: queryParameters,
        options: Options(method: method.toUpperCase(), headers: headers),
      );

      return RoleSdkResponse<T>(
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (error) {
      throw RoleSdkHttpException(
        message: _messageFrom(error),
        statusCode: error.response?.statusCode,
        statusMessage: error.response?.statusMessage,
        responseData: error.response?.data,
        cause: error.error ?? error,
        isOffline: _isOffline(error),
      );
    } catch (error) {
      throw RoleSdkHttpException(message: error.toString(), cause: error, isOffline: error is SocketException);
    }
  }

  static String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Network request failed';
  }

  static bool _isOffline(DioException error) {
    return error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout || error.error is SocketException;
  }
}
