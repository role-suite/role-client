import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/models/app_release_model.dart';
import 'package:relay/core/utils/logger.dart';

/// Service for checking GitHub releases and managing app updates.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _baseUrl = 'https://api.github.com';

  /// Fetches the latest release from GitHub.
  /// Returns null if the request fails or no releases are found.
  Future<AppReleaseModel?> getLatestRelease() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/repos/${AppConstants.githubRepoOwner}/${AppConstants.githubRepoName}/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        return AppReleaseModel.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      // 404 means no releases yet, which is not an error
      if (e.response?.statusCode == 404) {
        AppLogger.debug('No releases found on GitHub');
        return null;
      }
      AppLogger.debug('Failed to fetch latest release: ${e.message}');
    } catch (e) {
      AppLogger.debug('Error checking for updates: $e');
    }
    return null;
  }

  /// Compares two semantic version strings.
  /// Returns true if [latest] is newer than [current].
  bool isNewerVersion(String latest, String current) {
    try {
      final latestParts = _parseVersion(latest);
      final currentParts = _parseVersion(current);

      for (int i = 0; i < 3; i++) {
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        final currentPart = i < currentParts.length ? currentParts[i] : 0;

        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }
      return false; // Versions are equal
    } catch (e) {
      AppLogger.debug('Error comparing versions: $e');
      return false;
    }
  }

  /// Parses a version string like "1.2.3" into a list of integers [1, 2, 3].
  List<int> _parseVersion(String version) {
    // Remove 'v' prefix if present
    final cleanVersion = version.startsWith('v') || version.startsWith('V') ? version.substring(1) : version;

    // Handle versions with build metadata (e.g., "1.0.0+1")
    final versionWithoutBuild = cleanVersion.split('+').first;

    return versionWithoutBuild.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  /// Gets the current platform name for asset matching.
  String getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Gets the download URL for the current platform from a release.
  /// Falls back to the release HTML URL if no matching asset is found.
  String getDownloadUrl(AppReleaseModel release) {
    final platform = getCurrentPlatform();
    return release.getDownloadUrlForPlatform(platform) ?? release.htmlUrl;
  }

  /// Checks if an update is available.
  /// Returns the latest release if a newer version exists, null otherwise.
  Future<AppReleaseModel?> checkForUpdate() async {
    final latestRelease = await getLatestRelease();
    if (latestRelease == null) return null;

    if (isNewerVersion(latestRelease.version, AppConstants.appVersion)) {
      return latestRelease;
    }
    return null;
  }
}
