import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/api_request.dart';
import '../models/enums.dart';
import '../models/request_body.dart';
import '../models/request_result.dart';
import 'http_client.dart';
import 'template_resolver.dart';

/// Resolves variables, builds the wire request from an [ApiRequest], sends
/// it, and times the round trip.
class RequestRunner {
  RequestRunner(this._client);

  final HttpClient _client;

  Future<RequestResult> run(ApiRequest request, Map<String, String> variables) async {
    final resolver = TemplateResolver(variables);
    final stopwatch = Stopwatch()..start();

    try {
      final uri = _buildUri(request, resolver);
      final headers = _buildHeaders(request, resolver);
      final data = request.method.canHaveBody ? _buildBody(request, resolver, headers) : null;

      final result = await _client.send(method: request.method.name, url: uri.toString(), headers: headers, data: data);
      stopwatch.stop();

      return RequestResult(
        ok: (result.statusCode ?? 0) < 400,
        statusCode: result.statusCode,
        statusMessage: result.statusMessage,
        headers: result.headers,
        body: _tryDecode(result.data),
        duration: stopwatch.elapsed,
      );
    } on HttpCallException catch (error) {
      stopwatch.stop();
      return RequestResult(
        ok: false,
        statusCode: error.statusCode,
        duration: stopwatch.elapsed,
        errorMessage: error.message,
        isOffline: error.isOffline,
      );
    } catch (error) {
      stopwatch.stop();
      return RequestResult(ok: false, duration: stopwatch.elapsed, errorMessage: error.toString());
    }
  }

  Uri _buildUri(ApiRequest request, TemplateResolver resolver) {
    final resolvedUrl = resolver.resolve(request.url);
    var uri = Uri.parse(resolvedUrl.contains('://') ? resolvedUrl : 'https://$resolvedUrl');

    final resolvedParams = resolver.resolveEntries(request.queryParams);
    if (resolvedParams.isNotEmpty) {
      final params = Map<String, String>.from(uri.queryParameters)..addAll(resolvedParams);
      uri = uri.replace(queryParameters: params);
    }

    if (request.authType == AuthType.apiKey && request.authConfig[AuthConfigKeys.addTo] == 'query') {
      final key = resolver.resolve(request.authConfig[AuthConfigKeys.key]);
      final value = resolver.resolve(request.authConfig[AuthConfigKeys.value]);
      if (key.isNotEmpty) {
        final params = Map<String, String>.from(uri.queryParameters)..[key] = value;
        uri = uri.replace(queryParameters: params);
      }
    }

    return uri;
  }

  Map<String, String> _buildHeaders(ApiRequest request, TemplateResolver resolver) {
    final headers = resolver.resolveEntries(request.headers);

    switch (request.authType) {
      case AuthType.bearer:
        final token = resolver.resolve(request.authConfig[AuthConfigKeys.token]);
        if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      case AuthType.basic:
        final username = resolver.resolve(request.authConfig[AuthConfigKeys.username]);
        final password = resolver.resolve(request.authConfig[AuthConfigKeys.password]);
        final encoded = base64Encode(utf8.encode('$username:$password'));
        headers['Authorization'] = 'Basic $encoded';
      case AuthType.apiKey:
        if (request.authConfig[AuthConfigKeys.addTo] != 'query') {
          final key = resolver.resolve(request.authConfig[AuthConfigKeys.key]);
          final value = resolver.resolve(request.authConfig[AuthConfigKeys.value]);
          if (key.isNotEmpty) headers[key] = value;
        }
      case AuthType.none:
        break;
    }

    return headers;
  }

  dynamic _buildBody(ApiRequest request, TemplateResolver resolver, Map<String, String> headers) {
    switch (request.requestBody) {
      case NoneBody():
        return null;
      case RawBody(:final raw, :final contentType):
        if (contentType != null) headers.putIfAbsent('Content-Type', () => contentType);
        return resolver.resolve(raw);
      case UrlEncodedBody(:final entries):
        headers.putIfAbsent('Content-Type', () => 'application/x-www-form-urlencoded');
        final fields = resolver.resolveEntries(entries);
        return fields.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      case FormDataBody(:final parts):
        final fields = <String, dynamic>{};
        for (final part in parts) {
          switch (part) {
            case FormTextPart(:final key, :final value, :final enabled):
              if (enabled) fields[resolver.resolve(key)] = resolver.resolve(value);
            case FormFilePart(:final key, :final fileName, :final contentType, :final dataBase64, :final enabled):
              if (enabled) {
                fields[resolver.resolve(key)] = MultipartFile.fromBytes(
                  base64Decode(dataBase64),
                  filename: fileName,
                  contentType: contentType != null ? MediaType.parse(contentType) : null,
                );
              }
          }
        }
        return FormData.fromMap(fields);
      case BinaryBody(:final dataBase64, :final contentType, :final fileName):
        if (contentType != null) headers.putIfAbsent('Content-Type', () => contentType);
        if (fileName != null) headers.putIfAbsent('Content-Disposition', () => 'attachment; filename="$fileName"');
        return Uint8List.fromList(base64Decode(dataBase64));
    }
  }

  dynamic _tryDecode(dynamic raw) {
    if (raw is! String) return raw;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return raw;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return raw;
    }
  }
}
