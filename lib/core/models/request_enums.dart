/// How the request body is encoded.
enum BodyType {
  none,
  formData,
  urlEncoded,
  raw,
  binary,
}

extension BodyTypeX on BodyType {
  String get displayName {
    switch (this) {
      case BodyType.none:
        return 'None';
      case BodyType.formData:
        return 'Form Data';
      case BodyType.urlEncoded:
        return 'URL-encoded';
      case BodyType.raw:
        return 'Raw';
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
      case 'raw':
        return BodyType.raw;
      case 'binary':
        return BodyType.binary;
      default:
        return BodyType.raw;
    }
  }
}

/// Authentication type for the request.
enum AuthType {
  none,
  bearer,
  basic,
  apiKey,
}

extension AuthTypeX on AuthType {
  String get displayName {
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
      case 'none':
        return AuthType.none;
      case 'bearer':
        return AuthType.bearer;
      case 'basic':
        return AuthType.basic;
      case 'apikey':
      case 'api_key':
        return AuthType.apiKey;
      default:
        return AuthType.none;
    }
  }
}

/// Keys used in [ApiRequestModel.authConfig] for each [AuthType].
abstract class AuthConfigKeys {
  static const String token = 'token';
  static const String username = 'username';
  static const String password = 'password';
  static const String key = 'key';
  static const String value = 'value';
}
