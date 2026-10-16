# 5. Deployment

This document covers building and distributing the Röle (role-client) app. The app is a standard, fully local Flutter application; there is no backend to deploy.

## Prerequisites

- **Flutter SDK** 3.9+ (see [flutter.dev](https://flutter.dev)).
- **Platform tooling** for the target platform (Xcode for iOS/macOS, Android SDK for Android, Visual Studio / MSVC for Windows, etc.).

## Build for Release

From the **role-client** repository root:

```bash
flutter pub get
flutter build <platform> --release
```

Replace `<platform>` with one of:

| Platform | Command | Output |
|----------|---------|--------|
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| macOS | `flutter build macos --release` | `build/macos/Build/Products/Release/` (app bundle) |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` |
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android App Bundle | `flutter build appbundle --release` | For Play Store. |
| iOS | `flutter build ios --release` | Xcode archive / IPA (requires Mac, signing). |

## Dependencies for Distribution

- Flutter dependencies are resolved directly from `pubspec.yaml` with `flutter pub get`.

## Code Signing and Store Submission

- **Windows**: No code signing required for local distribution. For store (e.g. Microsoft Store), follow Flutter and store guidelines.
- **macOS**: Sign and notarize the app for distribution outside the App Store; use Xcode or `codesign`/`notarytool`. For App Store, use Xcode archive and submit.
- **Android**: Release signing uses `android/key.properties` + the upload keystore (or debug signing as a local fallback). The CI release pipeline signs the AAB and uploads it to the Play internal track when the secrets are configured — see `.github/workflows/README.md`.
- **iOS**: CI signs with [fastlane match](https://docs.fastlane.tools/actions/match/) (`appstore` type, readonly in CI) and uploads to TestFlight for internal testers. Certificates/profiles live in a private certificates repo; see `.github/workflows/README.md` for the secrets and one-time setup.

## Automated Releases (GitHub Actions)

All platform builds are produced and published automatically by
`.github/workflows/release.yml` whenever a `v*.*.*` tag is pushed to `main`:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow:

1. Fails fast unless the tag matches the `version:` in `pubspec.yaml` **and** the tag is an
   ancestor of `main`.
2. Calls the reusable `.github/workflows/build.yml` to build and package every platform:
   Windows (portable zip + per-user Inno Setup installer), Linux (`tar.gz` + AppImage), macOS
   (unsigned), Android APK and AAB, and an unsigned iOS app bundle.
3. Attaches build-provenance attestations (`gh attestation verify`) and a `SHA256SUMS` file.
4. Creates a **draft** GitHub Release with versioned assets and auto-generated notes, then
   publishes it through the `release` GitHub Environment — configure required reviewers there to
   make publishing a manual approval.
5. After publishing, uploads the AAB to the Google Play **internal** track and the IPA to
   TestFlight (internal testers) when the corresponding secrets are configured.

No secrets are required to cut a release — see `.github/workflows/README.md` for the asset list
and the optional signing/store secrets. Without secrets the release still goes out with unsigned
Windows/macOS/iOS builds and a debug-signed Android APK. The Android AAB is only built when the
Play service account is configured (its sole purpose is the Play upload), while the installable
APK is always attached to the GitHub release.

macOS is compile-checked on PRs and attached to releases as an unsigned zip (no signing or
notarization yet). Android releases land on the Play **internal** track and are promoted to other
tracks manually in the Play Console; iOS builds land with internal TestFlight testers.

Every push/PR to `main` also runs `.github/workflows/ci.yml` (version policy, format, analyze,
test with coverage) and `.github/workflows/build-check.yml` (compile-only builds for Windows,
Linux, macOS, Android, and iOS) before code reaches `main`; `.github/workflows/nightly.yml`
watches for Flutter SDK drift.

## Versioning

- **Version** is set in `pubspec.yaml` (`version: 1.1.3+6`). The optional `+6` is the build
  number. Bump before release; Flutter uses this for the app version shown on device and in
  stores. The release workflow rejects tags that don't match this version.
- The full policy (which part to bump, store mappings, tagging rules, and the release
  checklist) lives in [09-VERSIONING.md](09-VERSIONING.md). Use `dart run tool/version.dart`
  to inspect or bump the version instead of editing `pubspec.yaml` by hand.
