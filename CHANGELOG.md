# Changelog

All notable changes to Röle are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-10-14

First release since the local-workbench rebuild. The app version line was reset during the
rebuild, so this release intentionally starts above every version shipped from the old line —
see [docs/09-VERSIONING.md](docs/09-VERSIONING.md) for the policy.

### Added

- Optional online mode: sign in to a `role-node` backend and sync team workspaces alongside
  local collections. Includes sign-in/register, session/device management, workspace switching,
  members/roles/invitations, "convert to team", and remote import/export. Local-only usage is
  unchanged and never requires an account or a network connection.
- Offline-first remote editing: changes to remote workspaces are written locally first and
  queued in a persisted outbox that retries when connectivity returns (last-write-wins, no
  merge UI).
- Request-level response assertions, with results surfaced in the Collection Runner.
- HTML response preview: the response viewer detects HTML bodies (via `Content-Type` or
  content sniffing) and offers a rendered Preview alongside the raw-text view, with off-thread
  DOM parsing for large bodies.
- History and run lists are now paginated in the sidebar.
- File-upload request bodies (form-data file parts and binary bodies) and ordered,
  enable-able header/query-parameter rows.
- Environment variables now support per-row enable/disable, secret masking, and ordering.
- Version tooling (`tool/version.dart`) and the versioning policy in
  [docs/09-VERSIONING.md](docs/09-VERSIONING.md).
- CI/CD via GitHub Actions: version validation, format/analyze/test on every push and PR
  (with a coverage artifact and run-summary coverage), compile-only release builds for Windows,
  Linux, macOS, Android, and iOS, a Conventional-Commits PR title check, a nightly check
  against the latest stable Flutter SDK that opens an issue on drift, and a tag-triggered
  release pipeline that verifies the tag is on `main`, reuses the build workflow, attests build
  provenance, and publishes versioned Windows and Linux artifacts plus checksums from a draft
  release after the `release` environment gate (Windows signed when certificate secrets are
  configured, otherwise unsigned).
- Renovate dependency-update PRs (`renovate.json`) for pub packages, GitHub Actions, and the
  `.fvmrc` Flutter SDK pin.
- `.editorconfig` for consistent formatting across editors.

### Changed

- Local data model reshaped to match the online-mode wire format: headers and query parameters
  are ordered key/value entries, request bodies are a typed union, environment variables carry
  per-row metadata, and entity ids are UUIDv4. Pre-existing local JSON files are migrated on
  read.
- Expanded `analysis_options.yaml` with additional lints (leak detection, `unawaited_futures`,
  `require_trailing_commas`, and others) on top of `flutter_lints`.
- Upgraded the Riverpod stack to 3.4.3 and `riverpod_lint` to 3.1.9, which runs as a native
  analyzer plugin. Analysis now uses `dart analyze --fatal-infos` because `flutter analyze`
  does not load analyzer plugins; the deprecated `unnecessary_await_in_return` lint was removed.
- GitHub Actions workflows deduplicated into a shared `.github/actions/setup-flutter` composite
  action; the Flutter SDK is now pinned via `.fvmrc` and CI fetches dependencies with
  `flutter pub get --enforce-lockfile`.
- `pubspec.lock`, `ios/Podfile.lock`, and `macos/Podfile.lock` are now committed (an app, unlike
  a published package, should pin its resolved dependency graph for reproducible builds) —
  `.gitignore` no longer blanket-excludes `*.lock`.
- Android release builds fall back to debug signing when `android/key.properties` is absent, so
  release builds compile locally and in PR checks without signing secrets.

### Removed

- Dependabot: version bumps for `pub` packages and GitHub Actions are no longer opened
  automatically.

[Unreleased]: https://github.com/role-suite/role-client/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/role-suite/role-client/releases/tag/v1.1.0
