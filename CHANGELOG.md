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
  release pipeline that publishes signed macOS/Windows/Linux artifacts to GitHub Releases.
- Dependabot for `pub` packages and GitHub Action versions.
- `.editorconfig` for consistent formatting across editors.

### Changed

- Expanded `analysis_options.yaml` with additional lints (leak detection, `unawaited_futures`,
  `require_trailing_commas`, and others) on top of `flutter_lints`.

[Unreleased]: https://github.com/role-suite/role-client/commits/main
