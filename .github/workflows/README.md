# CI/CD workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | push/PR to `main` | version-policy check, `dart format` check, `dart analyze --fatal-infos` (incl. `riverpod_lint`), `flutter test` with a coverage artifact |
| `build-check.yml` | push/PR to `main` | Compile-only release builds for Windows, Linux, macOS (unsigned), Android and iOS (no codesign) to catch platform build breakage early |
| `pr-title.yml` | PR opened/edited | Enforces Conventional Commit-style PR titles (`feat:`, `fix:`, `chore:`, ...) |
| `release.yml` | push tag `v*.*.*` (or manual dispatch) | Verifies the tag matches `pubspec.yaml` via `tool/version.dart`, builds Windows (signed if cert provided) and Linux artifacts; publishes them to a GitHub Release with versioned filenames and a `SHA256SUMS` file |
| `nightly.yml` | daily schedule (or manual dispatch) | Drift check: analyze + test against the latest stable Flutter SDK (ignoring the `.fvmrc` pin) and opens/updates a GitHub issue on failure |

## Coverage

`ci.yml` writes `coverage/lcov.info`, posts a line-coverage summary on the run's Summary tab,
and uploads the report as a `coverage-lcov` artifact (14 days). It is report-only — no coverage
threshold is enforced, and no third-party coverage service is wired up.

## Dependency updates

[Renovate](../../renovate.json) opens grouped PRs for `pub` dependencies, GitHub Actions, and
the `.fvmrc` Flutter pin (monthly). It needs the Renovate GitHub App installed on this
repository — that is a one-time manual step in the GitHub UI, not something these files do.
Renovate PRs run the same CI gates as any other PR, including `--enforce-lockfile`.

## Toolchain pinning

- The Flutter SDK is pinned in [`.fvmrc`](../../.fvmrc) and installed by
  `.github/actions/setup-flutter`; bump it deliberately rather than letting CI track `stable`.
- The composite action runs `flutter pub get --enforce-lockfile`, so `pubspec.lock` must match
  `pubspec.yaml` exactly. Run `flutter pub get` locally after changing dependencies.
- App versions are governed by `pubspec.yaml` and [docs/09-VERSIONING.md](../../docs/09-VERSIONING.md);
  `dart run tool/version.dart` bumps and validates them.

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

See the release checklist in [docs/09-VERSIONING.md](../../docs/09-VERSIONING.md). In short:

```
dart run tool/version.dart bump patch   # or minor/major/build
# update CHANGELOG.md, merge to main, then:
git tag v1.1.0
git push origin v1.1.0
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
