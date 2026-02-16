import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_style.dart';
import '../constants/data_source_mode.dart';
import '../models/data_source_config.dart';

/// Persists user's choice of data source (local vs API) and API configuration.
class DataSourcePreferencesService {
  DataSourcePreferencesService._();
  static const _modeKey = 'data_source_mode';
  static const _baseUrlKey = 'data_source_api_base_url';
  static const _apiKeyKey = 'data_source_api_key';
  static const _apiStyleKey = 'data_source_api_style';

  static Future<DataSourceMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    if (value == null) return DataSourceMode.local;
    return switch (value) {
      'api' => DataSourceMode.api,
      _ => DataSourceMode.local,
    };
  }

  static Future<void> saveMode(DataSourceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  static Future<DataSourceConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey) ?? '';
    final apiKey = prefs.getString(_apiKeyKey);
    final styleStr = prefs.getString(_apiStyleKey);
    final apiStyle = styleStr == 'serverpod' ? ApiStyle.serverpod : ApiStyle.rest;
    return DataSourceConfig(baseUrl: baseUrl, apiKey: apiKey, apiStyle: apiStyle);
  }

  static Future<void> saveConfig(DataSourceConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, config.baseUrl);
    await prefs.setString(_apiStyleKey, config.apiStyle.name);
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      await prefs.setString(_apiKeyKey, config.apiKey!);
    } else {
      await prefs.remove(_apiKeyKey);
    }
  }
}
