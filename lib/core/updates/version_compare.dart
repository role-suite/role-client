/// Parses `MAJOR.MINOR.PATCH` (a `+BUILD` suffix is ignored) and returns null
/// when [raw] is not a plain numeric three-part version.
List<int>? parseReleaseVersion(String raw) {
  final withoutBuild = raw.split('+').first;
  final parts = withoutBuild.split('.');
  if (parts.length != 3) return null;
  final parsed = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0) return null;
    parsed.add(value);
  }
  return parsed;
}

/// Whether [releaseTag] (e.g. `v1.2.0`) is strictly newer than the running
/// [currentVersion] (e.g. `1.1.0`). Returns false when either side cannot be
/// parsed — the app never claims an update based on unparseable input.
bool isReleaseNewer({required String currentVersion, required String releaseTag}) {
  final current = parseReleaseVersion(currentVersion);
  final release = parseReleaseVersion(releaseTag.startsWith('v') ? releaseTag.substring(1) : releaseTag);
  if (current == null || release == null) return false;
  for (var i = 0; i < 3; i++) {
    if (release[i] != current[i]) return release[i] > current[i];
  }
  return false;
}
