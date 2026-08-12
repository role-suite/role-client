enum HttpMethod { get, post, put, delete, patch, head, options }

extension HttpMethodX on HttpMethod {
  String get label => name.toUpperCase();

  bool get canHaveBody => this != HttpMethod.get && this != HttpMethod.head;

  static HttpMethod fromString(String value) {
    return HttpMethod.values.firstWhere(
      (m) => m.name.toLowerCase() == value.toLowerCase(),
      orElse: () => HttpMethod.get,
    );
  }
}

enum BodyType { none, raw, formData, urlEncoded, binary }

extension BodyTypeX on BodyType {
  String get label {
    switch (this) {
      case BodyType.none:
        return 'None';
      case BodyType.raw:
        return 'Raw';
      case BodyType.formData:
        return 'Form Data';
      case BodyType.urlEncoded:
        return 'URL-encoded';
      case BodyType.binary:
        return 'Binary';
    }
  }

  static BodyType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return BodyType.none;
      case 'formdata':
      case 'form_data':
        return BodyType.formData;
      case 'urlencoded':
      case 'url_encoded':
        return BodyType.urlEncoded;
      case 'binary':
        return BodyType.binary;
      case 'raw':
      default:
        return BodyType.raw;
    }
  }
}

enum AuthType { none, bearer, basic, apiKey }

extension AuthTypeX on AuthType {
  String get label {
    switch (this) {
      case AuthType.none:
        return 'No Auth';
      case AuthType.bearer:
        return 'Bearer Token';
      case AuthType.basic:
        return 'Basic Auth';
      case AuthType.apiKey:
        return 'API Key';
    }
  }

  static AuthType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'bearer':
        return AuthType.bearer;
      case 'basic':
        return AuthType.basic;
      case 'apikey':
      case 'api_key':
        return AuthType.apiKey;
      case 'none':
      default:
        return AuthType.none;
    }
  }
}

/// Keys used inside [ApiRequest.authConfig], keyed by [AuthType].
abstract class AuthConfigKeys {
  static const token = 'token';
  static const username = 'username';
  static const password = 'password';
  static const key = 'key';
  static const value = 'value';
  static const addTo = 'addTo'; // 'header' | 'query', for apiKey
}

enum RunStatus { pending, running, success, failed }

extension RunStatusX on RunStatus {
  static RunStatus fromString(String value) {
    return RunStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RunStatus.pending,
    );
  }
}
