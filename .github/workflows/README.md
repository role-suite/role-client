# CI/CD workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | push/PR to `main` | `dart format` check, `flutter analyze` (incl. `riverpod_lint`), `flutter test` |
| `build-check.yml` | push/PR to `main` | Compile-only build of macOS, Windows, Linux to catch platform build breakage early |
| `pr-title.yml` | PR opened/edited | Enforces Conventional Commit-style PR titles (`feat:`, `fix:`, `chore:`, ...) |
| `release.yml` | push tag `v*.*.*` (or manual dispatch) | Verifies the tag matches `pubspec.yaml`, builds macOS (universal, signed+notarized if cert provided), Windows (signed if cert provided), and Linux artifacts; publishes them to a GitHub Release with versioned filenames and a `SHA256SUMS` file |

## Required secrets for `release.yml`

None of these are needed for `ci.yml` or `build-check.yml`. Add them under **Settings → Secrets and variables → Actions** before pushing a release tag. Every secret below is optional — with none set, `release.yml` still builds and publishes unsigned artifacts for all three platforms.

Android and iOS are distributed through their respective app stores, not through this pipeline, so `release.yml` does not build them.

### macOS (optional for the `macos` job)

If `MACOS_CERTIFICATE_BASE64` is not set, the workflow still builds and packages the app, just unsigned and unnotarized. To sign and notarize, you need an Apple Developer account, a **Developer ID Application** certificate, and an app-specific password for notarization.

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE_BASE64` | base64-encoded `.p12` export of your Developer ID Application certificate |
| `MACOS_CERTIFICATE_PASSWORD` | password used when exporting the `.p12` |
| `MACOS_CERTIFICATE_IDENTITY` | signing identity string, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `KEYCHAIN_PASSWORD` | any password — used only for the temporary CI keychain |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_ID_PASSWORD` | [app-specific password](https://support.apple.com/en-us/102654) for that Apple ID |
| `APPLE_TEAM_ID` | your 10-character Apple Developer Team ID |

### Windows (optional for the `windows` job)

If `WINDOWS_CERTIFICATE_BASE64` is not set, the workflow still builds and packages the app, just unsigned.

| Secret | Value |
|---|---|
| `WINDOWS_CERTIFICATE_BASE64` | base64-encoded `.pfx` code-signing certificate |
| `WINDOWS_CERTIFICATE_PASSWORD` | password for the `.pfx` |

### Linux

No signing secrets used — the `linux` job always builds and packages a `.tar.gz`.

## Cutting a release

```
git tag v1.0.0
git push origin v1.0.0
```

This triggers `release.yml`, which first checks that the tag matches the `version:` in
`pubspec.yaml` (the workflow fails fast otherwise), then builds all platforms in parallel and
publishes a GitHub Release with auto-generated notes and these assets:

| Asset | Contents |
|---|---|
| `relay-<version>-macos.zip` | universal (arm64 + x86_64) `relay.app`, stapled if signed |
| `relay-<version>-windows-x64.zip` | `relay.exe` and runtime DLLs |
| `relay-<version>-linux-x64.tar.gz` | extracts to a `relay/` folder with the binary and libs |
| `SHA256SUMS` | checksums for all of the above |

You can also re-run a release from the **Actions → Release → Run workflow** dialog by entering
an existing tag; the workflow checks out that tag and re-publishes its assets.
