import 'dart:io';

import 'update_assets.dart';

/// How (or whether) an in-app update can be applied on this platform.
///
/// - `windows`: the release's Inno Setup installer runs the update in place.
/// - `macos`: the release's `.app` zip replaces the running bundle. Only for
///   builds that are not sandboxed, which excludes Mac App Store builds
///   (the App Store updates those itself).
/// - `linux`: only for AppImage builds, which can atomically replace
///   themselves; `tar.gz` installs are updated manually.
enum UpdatePlatform { windows, macos, linux, unsupported }

/// Pure decision function, injectable for tests.
UpdatePlatform resolveUpdatePlatform({
  required bool isWindows,
  required bool isMacOS,
  required bool isLinux,
  required bool isMacAppStoreBuild,
  required bool isAppImage,
}) {
  if (isWindows) return UpdatePlatform.windows;
  if (isMacOS) return isMacAppStoreBuild ? UpdatePlatform.unsupported : UpdatePlatform.macos;
  if (isLinux) return isAppImage ? UpdatePlatform.linux : UpdatePlatform.unsupported;
  return UpdatePlatform.unsupported;
}

UpdatePlatform detectUpdatePlatform() {
  return resolveUpdatePlatform(
    isWindows: Platform.isWindows,
    isMacOS: Platform.isMacOS,
    isLinux: Platform.isLinux,
    isMacAppStoreBuild: isMacAppStoreBuild(),
    isAppImage: (Platform.environment['APPIMAGE'] ?? '').isNotEmpty,
  );
}

/// Whether the running macOS bundle was installed from the Mac App Store
/// (which ships a `_MASReceipt` and updates the app itself, so the in-app
/// updater must stay out of the way).
bool isMacAppStoreBuild() {
  if (!Platform.isMacOS) return false;
  final bundle = macAppBundlePath(Platform.resolvedExecutable);
  if (bundle == null) return false;
  return File('$bundle/Contents/_MASReceipt/receipt').existsSync();
}

/// Walks up from `.../Foo.app/Contents/MacOS/foo` to `.../Foo.app`.
/// Returns null when [resolvedExecutable] is not inside an app bundle.
String? macAppBundlePath(String resolvedExecutable) {
  var path = resolvedExecutable;
  for (var i = 0; i < 4; i++) {
    if (path.endsWith('.app')) return path;
    final separator = path.lastIndexOf('/');
    if (separator <= 0) return null;
    path = path.substring(0, separator);
  }
  return null;
}

/// The expected release asset for self-updates on [platform].
String? selfUpdateAssetName(UpdatePlatform platform, String version) {
  return switch (platform) {
    UpdatePlatform.windows => windowsInstallerAsset(version),
    UpdatePlatform.macos => macosArchiveAsset(version),
    UpdatePlatform.linux => linuxAppImageAsset(version),
    UpdatePlatform.unsupported => null,
  };
}
