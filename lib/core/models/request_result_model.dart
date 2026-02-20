import 'dart:convert';

class RequestResultModel {
  final int? statusCode;
  final Map<String, List<String>> headers;
  final dynamic data;
  final Duration duration;

  RequestResultModel({required this.statusCode, required this.headers, required this.data, required this.duration});

  RequestResultModel copyWith({int? statusCode, Map<String, List<String>>? headers, dynamic data, Duration? duration}) {
    return RequestResultModel(
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      data: data ?? this.data,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {'statusCode': statusCode, 'headers': headers, 'data': data, 'durationMs': duration.inMilliseconds};
  }

  factory RequestResultModel.fromJson(Map<String, dynamic> json) {
    return RequestResultModel(
      statusCode: json['statusCode'] as int?,
      headers:
          (json['headers'] as Map<String, dynamic>?)?.map((key, value) => MapEntry(key, List<String>.from(value as List))) ??
          <String, List<String>>{},
      data: json['data'],
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    );
  }

  String get prettyBody {
    if (data is Map || data is List) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return data?.toString() ?? '';
  }
}
