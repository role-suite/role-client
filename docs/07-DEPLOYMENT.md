# 7. Deployment

This document covers building and distributing the Röle (role-client) app. The app is a standard Flutter application; there is no separate backend deployed with it (the backend is role-server).

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

- **relay_server_client**: The app depends on `relay_server_client` via a pinned public source (git ref or package version), so builds work from a clean clone without a local `role-server` checkout.
- **Contributor override (optional)**: When developing client+server together, use a local `pubspec_overrides.yaml` to point `relay_server_client` to `../role-server/relay_server_client`.

## Code Signing and Store Submission

- **Windows**: No code signing required for local distribution. For store (e.g. Microsoft Store), follow Flutter and store guidelines.
- **macOS**: Sign and notarize the app for distribution outside the App Store; use Xcode or `codesign`/`notarytool`. For App Store, use Xcode archive and submit.
- **Android**: Configure signing in `android/app/build.gradle` (keystore, key alias). For Play Store use the App Bundle and the Play Console.
- **iOS**: Configure signing in Xcode (team, provisioning profile). Archive and upload to App Store Connect or distribute via TestFlight/Ad Hoc.

## Environment and Backend URL

The app does not bake in a default backend URL. Users set the base URL (and optional API key / Serverpod) in the app after install. For enterprise or controlled environments, you could ship a build that pre-fills a base URL (e.g. by changing default in `DataSourcePreferencesService` or a config screen); that would be a custom fork or build variant.

## Versioning

- **Version** is set in `pubspec.yaml` (`version: 1.0.16+1`). The optional `+1` is the build number. Bump before release; Flutter uses this for the app version shown on device and in stores.
