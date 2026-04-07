import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferencesService {
  WorkspacePreferencesService._();

  static String _keyForBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    final safe = Uri.encodeComponent(normalized);
    return 'active_workspace_id_$safe';
  }

  static Future<String?> loadActiveWorkspaceId(String baseUrl) async {
    if (baseUrl.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyForBaseUrl(baseUrl));
  }

  static Future<void> saveActiveWorkspaceId(String baseUrl, String workspaceId) async {
    if (baseUrl.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForBaseUrl(baseUrl), workspaceId);
  }
}
