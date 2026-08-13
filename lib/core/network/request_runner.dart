import 'dart:convert';

import 'package:dio/dio.dart' show FormData;

import '../models/api_request.dart';
import '../models/enums.dart';
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

    final resolvedParams = resolver.resolveMap(request.queryParams);
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
    final headers = resolver.resolveMap(request.headers);

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
    switch (request.bodyType) {
      case BodyType.none:
        return null;
      case BodyType.raw:
      case BodyType.binary:
        return resolver.resolve(request.body);
      case BodyType.formData:
        return FormData.fromMap(resolver.resolveMap(request.formFields));
      case BodyType.urlEncoded:
        headers.putIfAbsent('Content-Type', () => 'application/x-www-form-urlencoded');
        final fields = resolver.resolveMap(request.formFields);
        return fields.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
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
