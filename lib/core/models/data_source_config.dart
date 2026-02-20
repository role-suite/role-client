import 'package:relay/core/constants/api_style.dart';

/// Configuration for API data source (base URL, optional auth, REST vs Serverpod RPC).
class DataSourceConfig {
  const DataSourceConfig({
    required this.baseUrl,
    this.apiKey,
    this.apiStyle = ApiStyle.rest,
  });

  final String baseUrl;
  final String? apiKey;
  final ApiStyle apiStyle;

  DataSourceConfig copyWith({String? baseUrl, String? apiKey, ApiStyle? apiStyle}) {
    return DataSourceConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiStyle: apiStyle ?? this.apiStyle,
    );
  }

  bool get isValid => baseUrl.trim().isNotEmpty;
}
