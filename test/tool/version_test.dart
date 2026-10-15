import 'package:flutter_test/flutter_test.dart';

import '../../tool/version.dart';

void main() {
  group('AppVersion.parse', () {
    test('parses MAJOR.MINOR.PATCH+BUILD', () {
      final version = AppVersion.parse('1.2.3+45');
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
      expect(version.build, 45);
    });

    test('tolerates surrounding whitespace', () {
      expect(AppVersion.parse('  2.0.0+7\n').toString(), '2.0.0+7');
    });

    test('rejects a missing build number', () {
      expect(() => AppVersion.parse('1.2.3'), throwsFormatException);
    });

    test('rejects prerelease suffixes', () {
      expect(() => AppVersion.parse('1.2.3-beta.1+4'), throwsFormatException);
    });

    test('rejects non-numeric parts', () {
      expect(() => AppVersion.parse('1.x.3+4'), throwsFormatException);
    });
  });

  group('AppVersion.fromPubspec', () {
    test('reads the top-level version field', () {
      const contents = 'name: relay\nversion: 1.1.0+3\ndescription: app\n';
      expect(AppVersion.fromPubspec(contents).toString(), '1.1.0+3');
    });

    test('ignores indented version fields in dependencies', () {
      const contents = 'name: relay\nversion: 1.1.0+3\ndependencies:\n  dio:\n    version: 9.9.9\n';
      expect(AppVersion.fromPubspec(contents).toString(), '1.1.0+3');
    });

    test('throws when the field is missing', () {
      expect(() => AppVersion.fromPubspec('name: relay\n'), throwsFormatException);
    });
  });

  group('AppVersion.bump', () {
    const current = AppVersion(major: 1, minor: 2, patch: 3, build: 4);

    test('major resets minor and patch and increments build', () {
      expect(current.bump(BumpPart.major).toString(), '2.0.0+5');
    });

    test('minor resets patch and increments build', () {
      expect(current.bump(BumpPart.minor).toString(), '1.3.0+5');
    });

    test('patch increments build', () {
      expect(current.bump(BumpPart.patch).toString(), '1.2.4+5');
    });

    test('build only increments the build number', () {
      expect(current.bump(BumpPart.build).toString(), '1.2.3+5');
    });
  });

  group('AppVersion.compareTo', () {
    test('follows semver precedence and ignores the build number', () {
      const a = AppVersion(major: 1, minor: 0, patch: 0, build: 9);
      const b = AppVersion(major: 1, minor: 0, patch: 1, build: 1);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), 0);
    });

    test('equality includes the build number', () {
      const a = AppVersion(major: 1, minor: 0, patch: 0, build: 1);
      const b = AppVersion(major: 1, minor: 0, patch: 0, build: 2);
      expect(a == b, isFalse);
      expect(a.compareTo(b), 0);
    });
  });

  group('replacePubspecVersion', () {
    test('rewrites only the top-level version field', () {
      const contents = 'name: relay\nversion: 1.0.0+2\ndependencies:\n  dio: ^5.9.0\n';
      final updated = replacePubspecVersion(contents, const AppVersion(major: 1, minor: 1, patch: 0, build: 3));
      expect(updated, 'name: relay\nversion: 1.1.0+3\ndependencies:\n  dio: ^5.9.0\n');
    });

    test('throws when there is nothing to replace', () {
      expect(() => replacePubspecVersion('name: relay\n', const AppVersion(major: 1, minor: 0, patch: 0, build: 1)), throwsFormatException);
    });
  });

  group('highestReleaseTag', () {
    test('picks the highest semver tag and ignores non-release tags', () {
      final highest = highestReleaseTag(['v1.0.28', 'v0.0.1-prod-dev.0', 'v1.0.34', 'v1.0.32', 'not-a-tag']);
      expect(highest?.name, 'v1.0.34');
    });

    test('returns null when there are no release tags', () {
      expect(highestReleaseTag(['v0.0.1-prod-dev.0', 'release-notes']), isNull);
    });
  });

  group('validateTag', () {
    const version = AppVersion(major: 1, minor: 1, patch: 0, build: 3);

    test('accepts the matching tag', () {
      expect(validateTag(version, 'v1.1.0'), isNull);
    });

    test('rejects a mismatched tag', () {
      expect(validateTag(version, 'v1.0.33'), contains('does not match'));
    });

    test('rejects a tag with a build number', () {
      expect(validateTag(version, 'v1.1.0+3'), contains('Invalid tag'));
    });

    test('rejects a tag without the v prefix', () {
      expect(validateTag(version, '1.1.0'), contains('Invalid tag'));
    });
  });
}
