# 9. Versioning

`pubspec.yaml`'s `version:` field is the single source of truth for the app version. Everything
else — Android `versionName`/`versionCode`, iOS `CFBundleShortVersionString`/`CFBundleVersion`,
Git tags, and release assets — derives from it.

## Format

```
version: MAJOR.MINOR.PATCH+BUILD
```

- **MAJOR.MINOR.PATCH** (`release`) follows [Semantic Versioning](https://semver.org/).
- **BUILD** (the `+N` suffix) is a positive integer that must strictly increase with every
  artifact ever uploaded to a store. It is never reset when the release version changes.
- Every version must include `+BUILD`. Prerelease suffixes (`-beta.1`) are **not** allowed:
  Android tolerates them but iOS `CFBundleShortVersionString` must be numeric, and stores reject
  malformed bundles. Use build-number bumps for internal TestFlight/Play testing instead.

### When to bump what

| Part | Use when |
|---|---|
| **MAJOR** | Breaking change to how users work with the app (removed features, incompatible data migration with no recovery path). |
| **MINOR** | New user-facing features, backward compatible (online mode, assertions, file uploads). |
| **PATCH** | Bug fixes and maintenance with no new features. |
| **BUILD** | Every store upload, including re-submissions of the same release version and CI-only fixes. |

## Store mapping

| Store field | Source | Example (`1.1.0+3`) |
|---|---|---|
| Android `versionName` | `release` | `1.1.0` |
| Android `versionCode` | `build` | `3` |
| iOS `CFBundleShortVersionString` | `release` | `1.1.0` |
| iOS `CFBundleVersion` | `build` | `3` |
| Git tag | `v` + `release` | `v1.1.0` |
| Release asset filenames | `release` | `relay-1.1.0-windows-x64.zip` |

The build number only ever moves forward; when in doubt, bump **build** instead of reusing a
version. Store submissions are effectively irreversible.

## Git tags

- Annotated tags named `vMAJOR.MINOR.PATCH` are created **only on `main`**, only after the
  release commit is merged, and must match `pubspec.yaml`'s release version exactly (the release
  workflow verifies this and fails otherwise).
- Tags never include the build number.
- A tag is the release trigger; the workflow can also be re-run from the Actions tab against an
  existing tag.

## Tooling

`tool/version.dart` reads and writes the version without third-party dependencies:

```bash
dart run tool/version.dart show                 # current version, tag, store mapping
dart run tool/version.dart tag                  # prints e.g. v1.1.0
dart run tool/version.dart bump patch           # patch|minor|major|build
dart run tool/version.dart validate --tag v1.1.0
```

- `bump` rewrites `pubspec.yaml`, always increments the build number, and warns when the result
  is not higher than the highest existing `v*.*.*` tag.
- `validate` is the check the release workflow runs against the pushed tag.

## Release checklist

1. Make sure `main` is green (CI + build check).
2. Decide the bump (see the table above) and run `dart run tool/version.dart bump <part>`.
3. Update `CHANGELOG.md`: move the `Unreleased` entries under a new `## [X.Y.Z] - <date>`
   section using [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) categories.
4. Open a PR with the version bump and changelog (title: `chore(release): vX.Y.Z`), get it
   merged to `main`.
5. Tag and push:

   ```bash
   git checkout main && git pull
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

6. Watch the `release.yml` workflow; verify the GitHub Release artifacts, checksums, and store
   uploads (where configured).

## History and the 1.1.0 baseline

The local-workbench rebuild reset the in-repo version to `1.0.0+N` while old releases had
already shipped from an earlier line. Those historical tags are inconsistent with the pubspec
they point at (for example, tag `v1.0.34` contains `version: 1.0.32+1`), so they are **not** a
reliable source of previous versions. The known maximums across released artifacts were
versionName `1.0.32` and versionCode/build `2`.

`1.1.0+3` was chosen as the first release of the current line because it is greater than every
historical tag name **and** every previously shipped store version, which keeps Git tag
ordering, App Store Connect's monotonic version requirement, and Android's monotonic
`versionCode` requirement all satisfied. Do not reuse `v1.0.0` or any other existing tag.

## Flutter SDK pinning

The Flutter SDK is pinned separately in [`.fvmrc`](../.fvmrc) (currently `3.47.2`). CI installs
exactly that version; devs should match it (`fvm use`, or install that SDK directly). Keeping the
formatter (`dart format`) version-identical between local and CI prevents spurious formatting
failures, since formatter output can change between SDK releases. Bumping the SDK is a deliberate
change to `.fvmrc` plus a green CI run — not something CI tracks automatically.
