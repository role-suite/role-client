import '../models/api_request.dart';
import '../models/collection.dart';
import '../models/enums.dart';
import '../models/environment.dart';
import '../models/environment_variable.dart';
import '../models/key_value_entry.dart';
import '../models/request_body.dart';
import 'remote_api_exception.dart';

void validateRemoteName(String field, String value, {int min = 2, int max = 120}) {
  _validateLength(field, value.trim(), min: min, max: max);
}

void validateRemoteCollectionInput({required String name, String description = ''}) {
  final errors = <String, String>{};
  _addLengthError(errors, 'name', name.trim(), min: 2, max: 120);
  _addLengthError(errors, 'description', description.trim(), max: 2000);
  _throwIfInvalid(errors);
}

void validateRemoteCollection(Collection collection) {
  validateRemoteCollectionInput(name: collection.name, description: collection.description);
}

void validateRemoteRequest(ApiRequest request, {bool allowEmptyUrlAsDraft = false}) {
  final errors = <String, String>{};
  _addLengthError(errors, 'name', request.name.trim(), min: 2, max: 120);
  final url = request.url.trim();
  if (url.isEmpty && !allowEmptyUrlAsDraft) {
    errors['url'] = 'Must not be empty.';
  } else if (url.length > 5000) {
    errors['url'] = 'Must be at most 5000 characters.';
  }
  _validateKeyValues(errors, 'headers', request.headers, maxEntries: 200, valueMax: 5000);
  _validateKeyValues(errors, 'queryParams', request.queryParams, maxEntries: 200, valueMax: 5000);
  _validateRequestBody(errors, request.requestBody);
  _validateAuth(errors, request.authType, request.authConfig);
  _throwIfInvalid(errors);
}

void validateRemoteEnvironmentInput({required String name, List<EnvironmentVariable> variables = const []}) {
  final errors = <String, String>{};
  _addLengthError(errors, 'name', name.trim(), min: 2, max: 120);
  _validateEnvironmentVariables(errors, variables);
  _throwIfInvalid(errors);
}

void validateRemoteEnvironment(Environment environment) {
  validateRemoteEnvironmentInput(name: environment.name, variables: environment.variables);
}

void _validateKeyValues(Map<String, String> errors, String field, List<KeyValueEntry> entries, {required int maxEntries, required int valueMax}) {
  if (entries.length > maxEntries) errors[field] = 'Must have at most $maxEntries entries.';
  for (var i = 0; i < entries.length; i++) {
    _addLengthError(errors, '$field[$i].key', entries[i].key.trim(), min: 1, max: 200);
    _addLengthError(errors, '$field[$i].value', entries[i].value, max: valueMax);
  }
}

void _validateRequestBody(Map<String, String> errors, RequestBody body) {
  switch (body) {
    case NoneBody():
      return;
    case RawBody(:final contentType, :final raw):
      _addOptionalTrimmedLengthError(errors, 'body.contentType', contentType, min: 1, max: 120);
      _addLengthError(errors, 'body.raw', raw, max: 200000);
    case UrlEncodedBody(:final entries):
      _validateKeyValues(errors, 'body.entries', entries, maxEntries: 500, valueMax: 5000);
    case FormDataBody(:final parts):
      if (parts.length > 500) errors['body.parts'] = 'Must have at most 500 entries.';
      for (var i = 0; i < parts.length; i++) {
        switch (parts[i]) {
          case FormTextPart(:final key, :final value):
            _addLengthError(errors, 'body.parts[$i].key', key.trim(), min: 1, max: 200);
            _addLengthError(errors, 'body.parts[$i].value', value, max: 50000);
          case FormFilePart(:final key, :final fileName, :final contentType, :final dataBase64):
            _addLengthError(errors, 'body.parts[$i].key', key.trim(), min: 1, max: 200);
            _addLengthError(errors, 'body.parts[$i].fileName', fileName.trim(), min: 1, max: 255);
            _addOptionalTrimmedLengthError(errors, 'body.parts[$i].contentType', contentType, min: 1, max: 120);
            _addLengthError(errors, 'body.parts[$i].dataBase64', dataBase64, min: 1, max: 2000000);
        }
      }
    case BinaryBody(:final fileName, :final contentType, :final dataBase64):
      _addLengthError(errors, 'body.fileName', (fileName ?? '').trim(), min: 1, max: 255);
      _addOptionalTrimmedLengthError(errors, 'body.contentType', contentType, min: 1, max: 120);
      _addLengthError(errors, 'body.dataBase64', dataBase64, min: 1, max: 2000000);
  }
}

void _validateAuth(Map<String, String> errors, AuthType type, Map<String, String> config) {
  switch (type) {
    case AuthType.none:
    case AuthType.apiKey:
      return;
    case AuthType.bearer:
      _addLengthError(errors, 'auth.token', (config[AuthConfigKeys.token] ?? '').trim(), min: 1, max: 2000);
    case AuthType.basic:
      _addLengthError(errors, 'auth.username', (config[AuthConfigKeys.username] ?? '').trim(), min: 1, max: 200);
      _addLengthError(errors, 'auth.password', config[AuthConfigKeys.password] ?? '', min: 1, max: 500);
  }
}

void _validateEnvironmentVariables(Map<String, String> errors, List<EnvironmentVariable> variables) {
  for (var i = 0; i < variables.length; i++) {
    _addLengthError(errors, 'variables[$i].key', variables[i].key.trim(), min: 1, max: 200);
    _addLengthError(errors, 'variables[$i].value', variables[i].value, max: 10000);
    final position = variables[i].position;
    if (position < 0 || position > 100000) errors['variables[$i].position'] = 'Must be between 0 and 100000.';
  }
}

void _validateLength(String field, String value, {int? min, required int max}) {
  final errors = <String, String>{};
  _addLengthError(errors, field, value, min: min, max: max);
  _throwIfInvalid(errors);
}

void _addOptionalTrimmedLengthError(Map<String, String> errors, String field, String? value, {int? min, required int max}) {
  if (value == null) return;
  _addLengthError(errors, field, value.trim(), min: min, max: max);
}

void _addLengthError(Map<String, String> errors, String field, String value, {int? min, required int max}) {
  if (min != null && value.length < min) {
    errors[field] = 'Must be at least $min character${min == 1 ? '' : 's'}.';
  } else if (value.length > max) {
    errors[field] = 'Must be at most $max characters.';
  }
}

void _throwIfInvalid(Map<String, String> fieldErrors) {
  if (fieldErrors.isEmpty) return;
  throw RemoteApiException(code: 'VALIDATION_FAILED', message: 'Validation failed.', details: {'fieldErrors': fieldErrors});
}
