# Changelog

All notable changes to Röle are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

Entries below are since the local-workbench rebuild (version reset to `1.0.0+1` in `pubspec.yaml`).
Nothing has been tagged/released under this architecture yet.

### Added

- CI/CD via GitHub Actions: format/analyze/test on every push and PR, compile-only build
  checks for macOS/Windows/Linux, a Conventional-Commits PR title check, and a tag-triggered
  release pipeline that publishes macOS/Windows/Linux artifacts to GitHub Releases (macOS and
  Windows signed when certificate secrets are configured, otherwise unsigned).
- `.editorconfig` for consistent formatting across editors.
- Request-level response assertions, with results surfaced in the Collection Runner.
- HTML response preview: the response viewer detects HTML bodies (via `Content-Type` or
  content sniffing) and offers a rendered Preview alongside the raw-text view, with
  off-thread DOM parsing for large bodies.
- History and run lists are now paginated in the sidebar.

### Changed

- Expanded `analysis_options.yaml` with additional lints (leak detection, `unawaited_futures`,
  `require_trailing_commas`, and others) on top of `flutter_lints`.
- GitHub Actions workflows deduplicated into a shared `.github/actions/setup-flutter`
  composite action; fixed a Flutter version-resolution failure caused by
  `flutter-version-file` having no `flutter:` constraint to read from `pubspec.yaml`.
- `pubspec.lock`, `ios/Podfile.lock`, and `macos/Podfile.lock` are now committed (an app,
  unlike a published package, should pin its resolved dependency graph for reproducible
  builds) — `.gitignore` no longer blanket-excludes `*.lock`.

### Removed

- Dependabot: version bumps for `pub` packages and GitHub Actions are no longer opened
  automatically.

[Unreleased]: https://github.com/role-suite/role-client/commits/main
