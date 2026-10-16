import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/updates/update_assets.dart';

void main() {
  test('builds deterministic download URLs from the release tag', () {
    expect(
      assetDownloadUrl(tag: 'v1.2.0', assetName: 'relay-1.2.0-windows-x64-setup.exe'),
      'https://github.com/role-suite/role-client/releases/download/v1.2.0/relay-1.2.0-windows-x64-setup.exe',
    );
    expect(checksumsDownloadUrl('v1.2.0'), 'https://github.com/role-suite/role-client/releases/download/v1.2.0/SHA256SUMS');
  });

  test('asset names carry the release version', () {
    expect(windowsInstallerAsset('1.2.0'), 'relay-1.2.0-windows-x64-setup.exe');
    expect(macosArchiveAsset('1.2.0'), 'relay-1.2.0-macos.zip');
    expect(linuxAppImageAsset('1.2.0'), 'relay-1.2.0-x86_64.AppImage');
  });

  group('findChecksum', () {
    const sums = '''
9f2a4bf7e2c1d5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0  relay-1.2.0-windows-x64.zip
11aa22bb33cc44dd55ee66ff77008899aabbccddeeff00112233445566778899  relay-1.2.0-windows-x64-setup.exe
''';

    test('finds the checksum for an asset', () {
      expect(findChecksum(sums, 'relay-1.2.0-windows-x64-setup.exe'), '11aa22bb33cc44dd55ee66ff77008899aabbccddeeff00112233445566778899');
    });

    test('returns null for an asset that is not listed', () {
      expect(findChecksum(sums, 'relay-1.2.0-macos.zip'), isNull);
    });

    test('tolerates binary-mode markers, CRLF, and blank lines', () {
      const crlf = '\r\n9f2a4bf7e2c1d5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0 *relay-1.2.0-macos.zip\r\n';
      expect(findChecksum(crlf, 'relay-1.2.0-macos.zip'), '9f2a4bf7e2c1d5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0');
    });
  });
}
