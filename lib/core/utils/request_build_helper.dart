import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/request_enums.dart';

/// Builds effective headers (request headers + auth-derived) and body for sending a request.
class RequestBuildHelper {
  RequestBuildHelper._();

  /// [resolve] typically resolves template variables, e.g. `(s) => envRepository.resolveTemplate(s, environment)`.
  /// [rawBody] is the runtime body text for [BodyType.raw] (e.g. from request runner's body editor).
  static ({Map<String, String> headers, dynamic body}) buildForSend(
    ApiRequestModel request,
    String Function(String) resolve, {
    String? rawBody,
  }) {
    final headers = <String, String>{
      for (final e in request.headers.entries) e.key: resolve(e.value),
    };
    _applyAuth(headers, request.authType, request.authConfig, resolve);
    final body = _buildBody(request, resolve, rawBody);
    if (request.bodyType == BodyType.urlEncoded && body != null && body is Map) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    return (headers: headers, body: body);
  }

  static void _applyAuth(
    Map<String, String> headers,
    AuthType authType,
    Map<String, String> authConfig,
    String Function(String) resolve,
  ) {
    switch (authType) {
      case AuthType.none:
        break;
      case AuthType.bearer: {
        final token = authConfig[AuthConfigKeys.token]?.trim();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${resolve(token)}';
        }
      }
        break;
      case AuthType.basic: {
        final username = authConfig[AuthConfigKeys.username]?.trim() ?? '';
        final password = authConfig[AuthConfigKeys.password]?.trim() ?? '';
        if (username.isNotEmpty || password.isNotEmpty) {
          final credentials = '${resolve(username)}:${resolve(password)}';
          final encoded = base64Encode(utf8.encode(credentials));
          headers['Authorization'] = 'Basic $encoded';
        }
      }
        break;
      case AuthType.apiKey: {
        final key = authConfig[AuthConfigKeys.key]?.trim();
        final value = authConfig[AuthConfigKeys.value]?.trim();
        if (key != null && key.isNotEmpty && value != null) {
          headers[key] = resolve(value);
        }
      }
        break;
    }
  }

  static dynamic _buildBody(
    ApiRequestModel request,
    String Function(String) resolve,
    String? rawBody,
  ) {
    switch (request.bodyType) {
      case BodyType.none:
      case BodyType.binary:
        return null;
      case BodyType.raw: {
        final text = (rawBody ?? request.body)?.trim();
        if (text == null || text.isEmpty) return null;
        return resolve(text);
      }
      case BodyType.formData: {
        final fields = request.formDataFields;
        if (fields.isEmpty) return null;
        final formData = FormData();
        for (final e in fields.entries) {
          if (e.key.trim().isEmpty) continue;
          formData.fields.add(MapEntry(e.key, resolve(e.value)));
        }
        return formData;
      }
      case BodyType.urlEncoded: {
        final fields = request.formDataFields;
        if (fields.isEmpty) return null;
        final resolved = <String, String>{};
        for (final e in fields.entries) {
          if (e.key.trim().isEmpty) continue;
          resolved[e.key] = resolve(e.value);
        }
        return resolved;
      }
    }
  }
}
