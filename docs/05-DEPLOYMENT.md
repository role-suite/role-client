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

## Versioning

- **Version** is set in `pubspec.yaml` (`version: 1.0.16+1`). The optional `+1` is the build number. Bump before release; Flutter uses this for the app version shown on device and in stores.
