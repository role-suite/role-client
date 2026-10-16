import 'dart:io';

import 'update_platform.dart';

class SelfUpdateException implements Exception {
  const SelfUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Applies a downloaded, checksum-verified update. Implementations normally
/// end the process themselves (via `exit`), because the running binary has to
/// get out of the way of the replacement.
abstract interface class UpdateApplier {
  Future<void> apply({required String downloadedFile, required String tag, required String version});
}

/// Windows: runs the release's Inno Setup installer silently. The installer
/// closes any running instance, replaces the files in the per-user install
/// directory, and relaunches the app. Workspace data in `%APPDATA%` is not
/// touched.
class WindowsInstallerApplier implements UpdateApplier {
  const WindowsInstallerApplier();

  @override
  Future<void> apply({required String downloadedFile, required String tag, required String version}) async {
    await Process.start(downloadedFile, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
      '/RESTARTAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// macOS: a detached helper waits for this process to exit, unpacks the
/// downloaded zip, swaps the `.app` bundle, clears the quarantine flag, and
/// relaunches. Only reachable for non-sandboxed builds — Mac App Store builds
/// are excluded by [detectUpdatePlatform] before this can run.
class MacOsArchiveApplier implements UpdateApplier {
  const MacOsArchiveApplier();

  @override
  Future<void> apply({required String downloadedFile, required String tag, required String version}) async {
    final bundle = macAppBundlePath(Platform.resolvedExecutable);
    if (bundle == null) {
      throw const SelfUpdateException('Could not locate the app bundle to update.');
    }

    final script = await _writeHelperScript(_helperScript);
    await Process.start('/bin/bash', [script.path, '$pid', bundle, downloadedFile], mode: ProcessStartMode.detached);
    exit(0);
  }

  static const String _helperScript = r'''
#!/bin/bash
set -e
PID="$1"; APP="$2"; ZIP="$3"
while kill -0 "$PID" 2>/dev/null; do sleep 0.5; done
TMP="$(mktemp -d)"
ditto -x -k "$ZIP" "$TMP"
NEW="$(ls -d "$TMP"/*.app | head -1)"
rm -rf "$APP"
ditto "$NEW" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
open "$APP"
''';
}

/// Linux: a detached helper atomically replaces the running AppImage once
/// this process exits, then relaunches it. Only reachable when the app runs
/// from an AppImage (`$APPIMAGE` is set); `tar.gz` installs are updated
/// manually.
class LinuxAppImageApplier implements UpdateApplier {
  const LinuxAppImageApplier();

  @override
  Future<void> apply({required String downloadedFile, required String tag, required String version}) async {
    final appImage = Platform.environment['APPIMAGE'] ?? '';
    if (appImage.isEmpty) {
      throw const SelfUpdateException('Only AppImage builds can update themselves.');
    }

    final script = await _writeHelperScript(_helperScript);
    await Process.start('/bin/bash', [script.path, '$pid', appImage, downloadedFile], mode: ProcessStartMode.detached);
    exit(0);
  }

  static const String _helperScript = r'''
#!/bin/bash
set -e
PID="$1"; APPIMAGE="$2"; NEW="$3"
while kill -0 "$PID" 2>/dev/null; do sleep 0.5; done
DIR="$(dirname "$APPIMAGE")"
TMP="$DIR/.relay-update.$$"
cp "$NEW" "$TMP"
chmod +x "$TMP"
mv -f "$TMP" "$APPIMAGE"
nohup "$APPIMAGE" >/dev/null 2>&1 &
''';
}

Future<File> _writeHelperScript(String contents) async {
  final script = File('${Directory.systemTemp.path}/relay-update-${DateTime.now().microsecondsSinceEpoch}.sh');
  await script.writeAsString(contents);
  await Process.run('chmod', ['+x', script.path]);
  return script;
}
