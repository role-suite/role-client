/// Deterministic URLs and asset names for GitHub release downloads. Asset
/// names are fixed by the release workflow, so the updater never needs the
/// GitHub API (and never hits its rate limits) to find an update.
const String _releaseDownloadBase = 'https://github.com/role-suite/role-client/releases/download';

String assetDownloadUrl({required String tag, required String assetName}) => '$_releaseDownloadBase/$tag/$assetName';

String checksumsDownloadUrl(String tag) => '$_releaseDownloadBase/$tag/SHA256SUMS';

String windowsInstallerAsset(String version) => 'relay-$version-windows-x64-setup.exe';

String macosArchiveAsset(String version) => 'relay-$version-macos.zip';

String linuxAppImageAsset(String version) => 'relay-$version-x86_64.AppImage';

/// Parses the `<sha256>  <name>` lines of a release's `SHA256SUMS` file and
/// returns the lowercase checksum for [assetName], or null when absent.
String? findChecksum(String checksumsContents, String assetName) {
  final linePattern = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');
  for (final rawLine in checksumsContents.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final match = linePattern.firstMatch(line);
    if (match == null) continue;
    if (match.group(2)!.trim() == assetName) return match.group(1)!.toLowerCase();
  }
  return null;
}
