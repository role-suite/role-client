/// Model representing a GitHub release for the Röle app.
/// Used by [UpdateService] to check for available updates.
class AppReleaseModel {
  final String version;
  final String tagName;
  final String? releaseNotes;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  const AppReleaseModel({
    required this.version,
    required this.tagName,
    this.releaseNotes,
    required this.htmlUrl,
    this.publishedAt,
    this.assets = const [],
  });

  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    // Remove 'v' prefix if present for version comparison
    final version = tagName.startsWith('v') || tagName.startsWith('V') ? tagName.substring(1) : tagName;

    return AppReleaseModel(
      version: version,
      tagName: tagName,
      releaseNotes: json['body'] as String?,
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
      assets: (json['assets'] as List<dynamic>?)?.map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }

  /// Get download URL for a specific platform.
  /// Matches asset names like: relay-windows.zip, relay-macos.dmg, relay-linux.tar.gz
  String? getDownloadUrlForPlatform(String platform) {
    final platformLower = platform.toLowerCase();
    for (final asset in assets) {
      final nameLower = asset.name.toLowerCase();
      if (nameLower.contains(platformLower)) {
        return asset.downloadUrl;
      }
    }
    // Fallback to release page if no matching asset
    return null;
  }
}

/// Represents a downloadable asset attached to a GitHub release.
class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String? contentType;

  const ReleaseAsset({required this.name, required this.downloadUrl, required this.size, this.contentType});

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      contentType: json['content_type'] as String?,
    );
  }

  /// Format the file size as a human-readable string.
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
