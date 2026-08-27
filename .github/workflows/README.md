# CI/CD workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | push/PR to `main` | `dart format` check, `flutter analyze` (incl. `riverpod_lint`), `flutter test` |
| `build-check.yml` | push/PR to `main` | Compile-only build of Windows, Linux to catch platform build breakage early |
| `pr-title.yml` | PR opened/edited | Enforces Conventional Commit-style PR titles (`feat:`, `fix:`, `chore:`, ...) |
| `release.yml` | push tag `v*.*.*` (or manual dispatch) | Verifies the tag matches `pubspec.yaml`, builds Windows (signed if cert provided) and Linux artifacts; publishes them to a GitHub Release with versioned filenames and a `SHA256SUMS` file |

## Required secrets for `release.yml`

None of these are needed for `ci.yml` or `build-check.yml`. Add them under **Settings → Secrets and variables → Actions** before pushing a release tag. Every secret below is optional — with none set, `release.yml` still builds and publishes unsigned artifacts for both platforms.

Android and iOS are distributed through their respective app stores, and macOS is not currently distributed through this pipeline, so `release.yml` does not build them.

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
| `relay-<version>-windows-x64.zip` | `relay.exe` and runtime DLLs |
| `relay-<version>-linux-x64.tar.gz` | extracts to a `relay/` folder with the binary and libs |
| `SHA256SUMS` | checksums for all of the above |

You can also re-run a release from the **Actions → Release → Run workflow** dialog by entering
an existing tag; the workflow checks out that tag and re-publishes its assets.
