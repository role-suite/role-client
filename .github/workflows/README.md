# CI/CD workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | push/PR to `main` | version-policy check, `dart format` check, `dart analyze --fatal-infos` (incl. `riverpod_lint`), `flutter test` with a coverage artifact |
| `build.yml` | called by `build-check.yml` / `release.yml` | Reusable build workflow: platform matrix, optional Windows signing, optional packaging + artifact upload |
| `build-check.yml` | push/PR to `main` | Calls `build.yml` with all five platforms to catch build breakage early |
| `pr-title.yml` | PR opened/edited | Enforces Conventional Commit-style PR titles (`feat:`, `fix:`, `chore:`, ...) |
| `release.yml` | push tag `v*.*.*` (or manual dispatch) | Verifies the tag matches `pubspec.yaml` and is an ancestor of `main`, calls `build.yml` for Windows/Linux/Android, attests provenance, creates a draft release, publishes it after approval, and uploads to Google Play (internal) and TestFlight when configured |
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

Third-party GitHub Actions are pinned to full commit SHAs with a `# vX.Y.Z` comment.
Renovate's `helpers:pinGitHubActionDigestsToSemver` preset keeps the pins and the version
comments up to date, so unpinned `@vN` references should not be reintroduced.

## Toolchain pinning

- The Flutter SDK is pinned in [`.fvmrc`](../../.fvmrc) and installed by
  `.github/actions/setup-flutter`; bump it deliberately rather than letting CI track `stable`.
- The composite action runs `flutter pub get --enforce-lockfile`, so `pubspec.lock` must match
  `pubspec.yaml` exactly. Run `flutter pub get` locally after changing dependencies.
- App versions are governed by `pubspec.yaml` and [docs/09-VERSIONING.md](../../docs/09-VERSIONING.md);
  `dart run tool/version.dart` bumps and validates them.

## Required secrets for `release.yml`

None of these are needed for `ci.yml`, `build-check.yml`, or `nightly.yml`. Add them under
**Settings → Secrets and variables → Actions** before pushing a release tag. Every secret below
is optional — with none set, `release.yml` still builds and publishes unsigned artifacts.

`release.yml` uses a GitHub Environment named `release` for its final publish job. Configure it
under **Settings → Environments** with required reviewers if you want a manual approval between
the draft release being prepared and it going live; without that, publishing happens
automatically once the draft is ready.

Android and iOS are distributed through their respective app stores, and macOS is not currently
distributed through this pipeline, so `release.yml` does not build them (the PR build check does
compile all five platforms).

### Windows (optional for the `windows` job)

If `WINDOWS_CERTIFICATE_BASE64` is not set, the workflow still builds and packages the app, just unsigned.

| Secret | Value |
|---|---|
| `WINDOWS_CERTIFICATE_BASE64` | base64-encoded `.pfx` code-signing certificate |
| `WINDOWS_CERTIFICATE_PASSWORD` | password for the `.pfx` |

### Linux

No signing secrets used — the `linux` job always builds and packages a `.tar.gz`.

### Android (optional for the `android-aab` build and Play upload)

The App Bundle is signed with the upload keystore when these are set. If
`ANDROID_KEYSTORE_BASE64` is missing, the AAB is built debug-signed (the same fallback the PR
build check uses) and the Play upload is skipped — unless `PLAY_SERVICE_ACCOUNT_JSON` is set,
in which case the workflow fails fast rather than uploading a wrong-key bundle.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64-encoded upload keystore (`.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | full JSON of a Play service account with release access |

Uploads go to the **internal** track; promote releases to other tracks manually in the Play
Console. The app (`com.devora.relay`) must already exist there and the service account must be
granted access. Keep an offline backup of the upload keystore — losing it means you can no
longer update the Play listing.

### iOS (optional for the TestFlight upload)

CI signs with [fastlane match](https://docs.fastlane.tools/actions/match/) in readonly mode
(`ios/fastlane/Matchfile`) and uploads to TestFlight for **internal** testers. If
`MATCH_GIT_URL` is not set, the iOS step is skipped with a notice instead of failing the
release — the same applies to the Android and Windows signing steps.

| Secret | Value |
|---|---|
| `MATCH_GIT_URL` | URL of the private certificates repo (created by `fastlane match`) |
| `MATCH_PASSWORD` | encryption password for the certificates repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 `username:token` for cloning the private repo (or use a deploy key) |
| `MATCH_USERNAME` | optional Apple ID email, used only when running match locally |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | App Store Connect API private key (`.p8` contents, newlines included) |

One-time setup (on a Mac with an Apple Developer account, from the repo root):

```bash
MATCH_GIT_URL=git@github.com:role-suite/role-certificates.git \
MATCH_PASSWORD=<password> \
bundle exec fastlane match appstore
```

This creates the App Store distribution certificate and profile and stores them encrypted in
the certificates repo. The App Store Connect app record (`com.devora.relay`) must already
exist.

## Cutting a release

See the release checklist in [docs/09-VERSIONING.md](../../docs/09-VERSIONING.md). In short:

```
dart run tool/version.dart bump patch   # or minor/major/build
# update CHANGELOG.md, merge to main, then:
git tag v1.1.0
git push origin v1.1.0
```

This triggers `release.yml`, which:

1. verifies the tag matches `pubspec.yaml` and is an ancestor of `main` (fails fast otherwise);
2. calls `build.yml` to build, sign (if configured), and package Windows, Linux, and Android artifacts;
3. creates build-provenance attestations and a `SHA256SUMS` file;
4. creates a **draft** GitHub Release with auto-generated notes;
5. publishes the draft after the `release` environment gate (if configured);
6. uploads `relay-android.aab` to the Google Play internal track when `PLAY_SERVICE_ACCOUNT_JSON` is configured;
7. builds and uploads the IPA to TestFlight (internal testers) when `MATCH_GIT_URL` is configured.

| Asset | Contents |
|---|---|
| `relay-<version>-windows-x64.zip` | `relay.exe` and runtime DLLs |
| `relay-<version>-linux-x64.tar.gz` | extracts to a `relay/` folder with the binary and libs |
| `SHA256SUMS` | checksums for all of the above |

Verify a downloaded artifact's provenance with:

```bash
gh attestation verify relay-<version>-windows-x64.zip --repo role-suite/role-client
```

You can also re-run a release from the **Actions → Release → Run workflow** dialog by entering
an existing tag; the workflow checks out that tag, rebuilds and re-attaches its assets, and the
draft goes through the same publish gate again.
