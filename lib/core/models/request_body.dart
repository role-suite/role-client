import 'key_value_entry.dart';

/// A request's body, matching role-node's `endpointBodySchema` union exactly
/// — replaces the old `bodyType` + `body` + `formFields` trio, which could
/// not represent file uploads and left `body`/`formFields` populated even
/// when the other was the active shape.
sealed class RequestBody {
  const RequestBody();

  Map<String, dynamic> toJson();

  /// Parses the current tagged-union shape (`{"type": ...}`).
  factory RequestBody.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'raw':
        return RawBody(contentType: json['contentType'] as String?, raw: json['raw'] as String? ?? '');
      case 'urlencoded':
        return UrlEncodedBody(entries: KeyValueEntry.listFrom(json['entries']));
      case 'formdata':
        return FormDataBody(
          parts: (json['parts'] as List? ?? const []).whereType<Map>().map((e) => FormPart.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
      case 'binary':
        return BinaryBody(
          fileName: json['fileName'] as String?,
          contentType: json['contentType'] as String?,
          dataBase64: json['dataBase64'] as String? ?? '',
        );
      case 'none':
      default:
        return const NoneBody();
    }
  }
}

class NoneBody extends RequestBody {
  const NoneBody();

  @override
  Map<String, dynamic> toJson() => {'type': 'none'};
}

class RawBody extends RequestBody {
  final String? contentType;
  final String raw;

  const RawBody({this.contentType, this.raw = ''});

  @override
  Map<String, dynamic> toJson() => {'type': 'raw', if (contentType != null) 'contentType': contentType, 'raw': raw};
}

class UrlEncodedBody extends RequestBody {
  final List<KeyValueEntry> entries;

  const UrlEncodedBody({this.entries = const []});

  @override
  Map<String, dynamic> toJson() => {'type': 'urlencoded', 'entries': entries.map((e) => e.toJson()).toList()};
}

class FormDataBody extends RequestBody {
  final List<FormPart> parts;

  const FormDataBody({this.parts = const []});

  @override
  Map<String, dynamic> toJson() => {'type': 'formdata', 'parts': parts.map((p) => p.toJson()).toList()};
}

class BinaryBody extends RequestBody {
  final String? fileName;
  final String? contentType;
  final String dataBase64;

  const BinaryBody({this.fileName, this.contentType, this.dataBase64 = ''});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'binary',
    if (fileName != null) 'fileName': fileName,
    if (contentType != null) 'contentType': contentType,
    'dataBase64': dataBase64,
  };
}

/// One entry of a [FormDataBody]: either a plain text field or a file part.
sealed class FormPart {
  const FormPart();

  Map<String, dynamic> toJson();

  factory FormPart.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'file') {
      return FormFilePart(
        key: json['key'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        contentType: json['contentType'] as String?,
        dataBase64: json['dataBase64'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );
    }
    return FormTextPart(key: json['key'] as String? ?? '', value: json['value'] as String? ?? '', enabled: json['enabled'] as bool? ?? true);
  }
}

class FormTextPart extends FormPart {
  final String key;
  final String value;
  final bool enabled;

  const FormTextPart({required this.key, this.value = '', this.enabled = true});

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'key': key, 'value': value, 'enabled': enabled};
}

class FormFilePart extends FormPart {
  final String key;
  final String fileName;
  final String? contentType;
  final String dataBase64;
  final bool enabled;

  const FormFilePart({required this.key, required this.fileName, this.contentType, this.dataBase64 = '', this.enabled = true});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'file',
    'key': key,
    'fileName': fileName,
    if (contentType != null) 'contentType': contentType,
    'dataBase64': dataBase64,
    'enabled': enabled,
  };
}
