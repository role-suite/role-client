import 'package:package_info_plus/package_info_plus.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/utils/logger.dart';

/// Service for retrieving the current app version.
/// Uses package_info_plus to get the version from the app's metadata.
class VersionService {
  static PackageInfo? _cachedPackageInfo;
  static String? _cachedVersion;

  /// Gets the current app version.
  /// Returns the version from package_info_plus, or falls back to AppConstants.appVersion.
  static Future<String> getCurrentVersion() async {
    if (_cachedVersion != null) {
      return _cachedVersion!;
    }

    try {
      _cachedPackageInfo ??= await PackageInfo.fromPlatform();
      _cachedVersion = _cachedPackageInfo!.version;
      return _cachedVersion!;
    } catch (e) {
      AppLogger.debug('Failed to get app version from package_info: $e');
      // Fallback to constant if package_info fails
      _cachedVersion = AppConstants.appVersion;
      return _cachedVersion!;
    }
  }

  /// Gets the current app version synchronously.
  /// Returns cached version if available, otherwise falls back to AppConstants.appVersion.
  static String getCurrentVersionSync() {
    return _cachedVersion ?? AppConstants.appVersion;
  }

  /// Clears the cached version info.
  /// Useful for testing or when version might have changed.
  static void clearCache() {
    _cachedPackageInfo = null;
    _cachedVersion = null;
  }
}
