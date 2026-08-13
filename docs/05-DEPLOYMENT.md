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
- **Android**: Configure signing in `android/app/build.gradle` (keystore, key alias). For Play Store use the App Bundle and the Play Console.
- **iOS**: Configure signing in Xcode (team, provisioning profile). Archive and upload to App Store Connect or distribute via TestFlight/Ad Hoc.

## Automated Releases (GitHub Actions)

macOS, Windows, and Linux are built and published automatically by `.github/workflows/release.yml`
whenever a `v*.*.*` tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This builds a signed + notarized macOS app, a Windows executable (signed if a certificate
secret is configured), and a Linux tarball, then attaches all three to a GitHub Release with
auto-generated notes. See `.github/workflows/README.md` for the full list of required signing
secrets and one-time setup steps.

Android and iOS are **not** built by this pipeline — they're submitted to the Play Store and
App Store directly (see Code Signing and Store Submission below), so `flutter build apk`,
`appbundle`, and `ios` remain manual, local steps.

Every push/PR to `main` also runs `.github/workflows/ci.yml` (format, analyze, test) and
`.github/workflows/build-check.yml` (compile-only builds for macOS/Windows/Linux) before code
reaches `main`.

## Versioning

- **Version** is set in `pubspec.yaml` (`version: 1.0.0+1`). The optional `+1` is the build number. Bump before release; Flutter uses this for the app version shown on device and in stores.
