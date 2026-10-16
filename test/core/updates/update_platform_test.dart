import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/updates/update_platform.dart';

void main() {
  group('resolveUpdatePlatform', () {
    test('windows always supports in-app updates', () {
      expect(
        resolveUpdatePlatform(isWindows: true, isMacOS: false, isLinux: false, isMacAppStoreBuild: false, isAppImage: false),
        UpdatePlatform.windows,
      );
    });

    test('macos supports updates unless it is an App Store build', () {
      expect(
        resolveUpdatePlatform(isWindows: false, isMacOS: true, isLinux: false, isMacAppStoreBuild: false, isAppImage: false),
        UpdatePlatform.macos,
      );
      expect(
        resolveUpdatePlatform(isWindows: false, isMacOS: true, isLinux: false, isMacAppStoreBuild: true, isAppImage: false),
        UpdatePlatform.unsupported,
      );
    });

    test('linux supports updates only from an AppImage', () {
      expect(
        resolveUpdatePlatform(isWindows: false, isMacOS: false, isLinux: true, isMacAppStoreBuild: false, isAppImage: true),
        UpdatePlatform.linux,
      );
      expect(
        resolveUpdatePlatform(isWindows: false, isMacOS: false, isLinux: true, isMacAppStoreBuild: false, isAppImage: false),
        UpdatePlatform.unsupported,
      );
    });
  });

  group('macAppBundlePath', () {
    test('walks up from the executable to the bundle', () {
      expect(macAppBundlePath('/Applications/Röle.app/Contents/MacOS/relay'), '/Applications/Röle.app');
    });

    test('returns null outside an app bundle', () {
      expect(macAppBundlePath('/usr/local/bin/relay'), isNull);
    });
  });

  group('selfUpdateAssetName', () {
    test('selects the platform asset', () {
      expect(selfUpdateAssetName(UpdatePlatform.windows, '1.2.0'), 'relay-1.2.0-windows-x64-setup.exe');
      expect(selfUpdateAssetName(UpdatePlatform.macos, '1.2.0'), 'relay-1.2.0-macos.zip');
      expect(selfUpdateAssetName(UpdatePlatform.linux, '1.2.0'), 'relay-1.2.0-x86_64.AppImage');
      expect(selfUpdateAssetName(UpdatePlatform.unsupported, '1.2.0'), isNull);
    });
  });
}
