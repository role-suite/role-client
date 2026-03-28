import 'package:relay/core/constants/api_style.dart';

/// Configuration for API data source (base URL and optional auth).
class DataSourceConfig {
  const DataSourceConfig({required this.baseUrl, this.apiKey, this.refreshToken, this.apiStyle = ApiStyle.rest});

  final String baseUrl;
  final String? apiKey;
  final String? refreshToken;
  final ApiStyle apiStyle;

  DataSourceConfig copyWith({String? baseUrl, String? apiKey, String? refreshToken, ApiStyle? apiStyle}) {
    return DataSourceConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      refreshToken: refreshToken ?? this.refreshToken,
      apiStyle: apiStyle ?? this.apiStyle,
    );
  }

  bool get isValid => baseUrl.trim().isNotEmpty;
}
