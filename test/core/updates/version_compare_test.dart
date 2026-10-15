import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/updates/version_compare.dart';

void main() {
  group('isReleaseNewer', () {
    test('detects newer major, minor, and patch releases', () {
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'v2.0.0'), isTrue);
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'v1.2.0'), isTrue);
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'v1.1.1'), isTrue);
    });

    test('is false for equal and older releases', () {
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'v1.1.0'), isFalse);
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'v1.0.9'), isFalse);
      expect(isReleaseNewer(currentVersion: '2.0.0', releaseTag: 'v1.9.9'), isFalse);
    });

    test('ignores the local +build suffix', () {
      expect(isReleaseNewer(currentVersion: '1.1.0+3', releaseTag: 'v1.1.0'), isFalse);
      expect(isReleaseNewer(currentVersion: '1.1.0+3', releaseTag: 'v1.1.1'), isTrue);
    });

    test('accepts tags without a v prefix', () {
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: '1.2.0'), isTrue);
    });

    test('returns false for unparseable input', () {
      expect(isReleaseNewer(currentVersion: '', releaseTag: 'v1.2.0'), isFalse);
      expect(isReleaseNewer(currentVersion: '1.1', releaseTag: 'v1.2.0'), isFalse);
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'nightly'), isFalse);
      expect(isReleaseNewer(currentVersion: '1.1.0', releaseTag: 'v1.2.0-rc.1'), isFalse);
    });
  });
}
