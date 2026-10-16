# Changelog

All notable changes to Röle are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- In-app desktop updates: **Update now** in About downloads the release asset, verifies it against
  the release's `SHA256SUMS`, applies it in place, and restarts. Windows uses the new Inno Setup
  installer; Linux AppImage builds replace themselves. Workspace data is untouched (it lives in
  the OS user-data directories).
- `relay-<version>-windows-x64-setup.exe` (per-user Inno Setup installer) and
  `relay-<version>-x86_64.AppImage` release assets.

## [1.1.2] - 2026-10-16

### Added

- The desktop status bar now shows the running version (`Röle vX.Y.Z`) and opens the About
  dialog when clicked, so it is always clear which build is in use.

### Fixed

- Very large response bodies (multi-megabyte JSON) no longer render corrupted values at the
  end: the body viewer virtualizes lines instead of handing megabytes to a single text widget,
  skips pretty-printing above 2 MB, caps the visible text behind a notice, and offers
  "Copy full body". Response size and pretty-printing are now computed once per response
  instead of on every rebuild.
- The update check no longer reports "GitHub rate limit reached" spuriously: it follows the
  GitHub release-page redirect instead of the rate-limited API, persists failed attempts so the
  daily interval also throttles retries, and only claims rate limiting when GitHub's headers
  confirm it.

## [1.1.1] - 2026-10-16

### Added

- In-app release check: an About dialog (account menu) showing the running version, a manual
  "Check for updates" button, an off-by-default daily automatic check, and a status-bar badge
  linking to the release page when a newer GitHub release exists. No telemetry; see the README
  FAQ.

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
  provenance, publishes versioned artifacts for Windows, Linux, macOS, Android (APK), and iOS
  (unsigned) plus checksums from a draft release after the `release` environment gate (Windows
  signed when certificate secrets are configured, otherwise unsigned), uploads the Android App
  Bundle to the Google Play internal track, and builds/uploads the iOS IPA to TestFlight
  (internal testers) when the store and signing secrets are configured.
- fastlane match configuration (`Gemfile`, `ios/fastlane/`) for reproducible iOS release
  signing through a private certificates repository.
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
- Third-party GitHub Actions are pinned to full commit SHAs (with Renovate-maintained `# vX.Y.Z`
  comments) and upgraded to their current major versions; the release concurrency group now
  keys off the dispatched tag.
- The CI build matrix now honors the requested platform list (a matrix `include` quirk
  previously built every platform regardless of the input), and the Android NDK is
  preinstalled with retries to absorb corrupted SDK downloads.
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

[Unreleased]: https://github.com/role-suite/role-client/compare/v1.1.2...HEAD
[1.1.2]: https://github.com/role-suite/role-client/releases/tag/v1.1.2
[1.1.1]: https://github.com/role-suite/role-client/releases/tag/v1.1.1
[1.1.0]: https://github.com/role-suite/role-client/releases/tag/v1.1.0
