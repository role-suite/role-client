// Version tooling for Röle.
//
// `pubspec.yaml`'s `version: MAJOR.MINOR.PATCH+BUILD` field is the single
// source of truth for the app version (see docs/09-VERSIONING.md). This script
// reads, bumps, and validates it without any third-party dependencies.
//
// Usage:
//   dart run tool/version.dart show [--pubspec <path>]
//   dart run tool/version.dart tag [--pubspec <path>]
//   dart run tool/version.dart bump <major|minor|patch|build> [--pubspec <path>]
//   dart run tool/version.dart validate [--tag vX.Y.Z] [--pubspec <path>]

import 'dart:io';

const String toolUsage = '''
Röle version tooling

Usage:
  dart run tool/version.dart show [--pubspec <path>]
  dart run tool/version.dart tag [--pubspec <path>]
  dart run tool/version.dart bump <major|minor|patch|build> [--pubspec <path>]
  dart run tool/version.dart validate [--tag vX.Y.Z] [--pubspec <path>]

Commands:
  show      Print the current version, release tag, and store mapping.
  tag       Print the release tag for the current version (e.g. v1.1.0).
  bump      Bump the version in pubspec.yaml and print the release steps.
  validate  Fail if the version or the given tag does not match the policy.
''';

const String defaultPubspecPath = 'pubspec.yaml';

final RegExp _pubspecVersionLine = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);
final RegExp _releaseVersionPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$');
final RegExp _releaseTagPattern = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');

/// Which part of the version to bump. Every bump also increments the build
/// number, which must strictly increase for every store upload.
enum BumpPart { major, minor, patch, build }

/// `MAJOR.MINOR.PATCH+BUILD` — the only version format allowed in pubspec.yaml.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({required this.major, required this.minor, required this.patch, required this.build});

  final int major;
  final int minor;
  final int patch;
  final int build;

  static AppVersion parse(String raw) {
    final match = _releaseVersionPattern.firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('Invalid app version "$raw". Expected MAJOR.MINOR.PATCH+BUILD, e.g. 1.2.3+5.');
    }
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.parse(match.group(4)!),
    );
  }

  /// Reads the top-level `version:` field from pubspec.yaml contents.
  static AppVersion fromPubspec(String contents) {
    final match = _pubspecVersionLine.firstMatch(contents);
    if (match == null) {
      throw const FormatException('No top-level "version:" field found in pubspec.yaml.');
    }
    return parse(match.group(1)!);
  }

  /// `MAJOR.MINOR.PATCH` — what Android/iOS see as the release version.
  String get release => '$major.$minor.$patch';

  /// `vMAJOR.MINOR.PATCH` — the Git tag for this version (never includes build).
  String get tag => 'v$release';

  AppVersion bump(BumpPart part) {
    return switch (part) {
      BumpPart.major => AppVersion(major: major + 1, minor: 0, patch: 0, build: build + 1),
      BumpPart.minor => AppVersion(major: major, minor: minor + 1, patch: 0, build: build + 1),
      BumpPart.patch => AppVersion(major: major, minor: minor, patch: patch + 1, build: build + 1),
      BumpPart.build => AppVersion(major: major, minor: minor, patch: patch, build: build + 1),
    };
  }

  /// Semver precedence: the build number does not participate.
  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersion && major == other.major && minor == other.minor && patch == other.patch && build == other.build;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$release+$build';
}

/// A `vMAJOR.MINOR.PATCH` Git tag.
class ReleaseTag implements Comparable<ReleaseTag> {
  const ReleaseTag(this.name, this.version);

  final String name;
  final AppVersion version;

  static ReleaseTag? tryParse(String raw) {
    final match = _releaseTagPattern.firstMatch(raw.trim());
    if (match == null) return null;
    return ReleaseTag(
      raw.trim(),
      AppVersion(major: int.parse(match.group(1)!), minor: int.parse(match.group(2)!), patch: int.parse(match.group(3)!), build: 0),
    );
  }

  @override
  int compareTo(ReleaseTag other) => version.compareTo(other.version);

  @override
  bool operator ==(Object other) => other is ReleaseTag && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// Rewrites the top-level `version:` field, leaving the rest of the file intact.
String replacePubspecVersion(String contents, AppVersion version) {
  final updated = contents.replaceFirst(_pubspecVersionLine, 'version: $version');
  if (updated == contents) {
    throw const FormatException('No top-level "version:" field found in pubspec.yaml.');
  }
  return updated;
}

/// Returns an error message when [tag] is not the release tag for [version],
/// or null when it matches.
String? validateTag(AppVersion version, String tag) {
  final parsed = ReleaseTag.tryParse(tag);
  if (parsed == null) {
    return 'Invalid tag "$tag". Expected vMAJOR.MINOR.PATCH.';
  }
  if (parsed.version.release != version.release) {
    return 'Tag $tag does not match pubspec.yaml version $version (expected ${version.tag}).';
  }
  return null;
}

/// Parses every valid `vMAJOR.MINOR.PATCH` tag and returns the highest one,
/// or null when [tags] contains none.
ReleaseTag? highestReleaseTag(Iterable<String> tags) {
  ReleaseTag? highest;
  for (final raw in tags) {
    final tag = ReleaseTag.tryParse(raw);
    if (tag == null) continue;
    if (highest == null || tag.compareTo(highest) > 0) highest = tag;
  }
  return highest;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(toolUsage);
    exitCode = 64;
    return;
  }

  final command = args.first;
  final rest = args.sublist(1);

  try {
    switch (command) {
      case 'show':
        _show(_readVersion(rest));
      case 'tag':
        stdout.writeln(_readVersion(rest).tag);
      case 'bump':
        await _bump(rest);
      case 'validate':
        await _validate(rest);
      default:
        stderr.writeln('Unknown command "$command".\n\n$toolUsage');
        exitCode = 64;
    }
  } on FormatException catch (error) {
    stderr.writeln('error: ${error.message}');
    exitCode = 1;
  }
}

AppVersion _readVersion(List<String> args) {
  final file = File(_optionValue(args, '--pubspec') ?? defaultPubspecPath);
  if (!file.existsSync()) {
    throw FormatException('pubspec.yaml not found at ${file.path}. Run from the repository root.');
  }
  return AppVersion.fromPubspec(file.readAsStringSync());
}

void _show(AppVersion version) {
  stdout
    ..writeln('Röle version')
    ..writeln('  pubspec version : $version')
    ..writeln('  release tag     : ${version.tag}')
    ..writeln('  Android         : versionName ${version.release}, versionCode ${version.build}')
    ..writeln('  iOS             : CFBundleShortVersionString ${version.release}, CFBundleVersion ${version.build}');
}

Future<void> _bump(List<String> args) async {
  final partName = _positional(args, 0);
  if (partName == null) {
    throw const FormatException('Missing bump part. Expected one of: major, minor, patch, build.');
  }
  final part = BumpPart.values.where((value) => value.name == partName).firstOrNull;
  if (part == null) {
    throw FormatException('Unknown bump part "$partName". Expected one of: major, minor, patch, build.');
  }

  final path = _optionValue(args, '--pubspec') ?? defaultPubspecPath;
  final file = File(path);
  if (!file.existsSync()) {
    throw FormatException('pubspec.yaml not found at ${file.path}. Run from the repository root.');
  }

  final current = AppVersion.fromPubspec(file.readAsStringSync());
  final next = current.bump(part);
  file.writeAsStringSync(replacePubspecVersion(file.readAsStringSync(), next));

  stdout
    ..writeln('Bumped $current -> $next ($path)')
    ..writeln('')
    ..writeln('Next steps:')
    ..writeln('  1. Add a "## [${next.release}]" section at the top of CHANGELOG.md.')
    ..writeln('  2. Commit:  git commit -am "chore(release): ${next.tag}"')
    ..writeln('  3. Tag:     git tag ${next.tag}')
    ..writeln('  4. Push:    git push origin main ${next.tag}');

  final highest = await _highestGitTag();
  if (highest != null && next.compareTo(highest.version) <= 0) {
    stdout
      ..writeln('')
      ..writeln(
        'warning: ${next.tag} is not higher than the existing tag $highest; '
        'store builds and existing tags may collide.',
      );
  }
}

Future<void> _validate(List<String> args) async {
  final version = _readVersion(args);
  if (version.build < 1) {
    throw FormatException('Build number must be at least 1: $version.');
  }
  stdout.writeln('pubspec version: $version (release tag ${version.tag})');

  final tag = _optionValue(args, '--tag');
  if (tag == null) return;

  final error = validateTag(version, tag);
  if (error != null) throw FormatException(error);
  stdout.writeln('tag $tag matches pubspec version.');
}

Future<ReleaseTag?> _highestGitTag() async {
  try {
    final result = await Process.run('git', ['tag', '--list', 'v*']);
    if (result.exitCode != 0) return null;
    return highestReleaseTag(result.stdout.toString().split('\n'));
  } on ProcessException {
    return null;
  }
}

String? _optionValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String? _positional(List<String> args, int index) {
  final positionals = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    positionals.add(args[i]);
  }
  if (index >= positionals.length) return null;
  return positionals[index];
}
