# 11. Package Managers

Every release attaches generated package-manager manifests alongside the binaries, so they always
match the published version and checksums:

| File | Manager | Installs from |
|---|---|---|
| `role.rb` | Homebrew Cask (macOS) | `relay-<version>-macos.zip` |
| `role.json` | Scoop (Windows) | `relay-<version>-windows-x64.zip` |
| `relay-winget-manifests.zip` | winget (Windows) | `relay-<version>-windows-x64-setup.exe` |

They are generated in `.github/workflows/release.yml` from `SHA256SUMS`; nothing is versioned in
the repository, so there is no second source of truth to keep in sync.

## Install from the release assets

```bash
# macOS (Homebrew)
brew install --cask ./role.rb
```

```powershell
# Windows (Scoop) — download role.json from the release first
scoop install .\role.json
```

```powershell
# Windows (winget) — download and unzip relay-winget-manifests.zip first
winget install --manifest .\winget
```

These local-install paths work, but users will not find them by searching package managers. For
discovery, publish the manifests to a tap/bucket and to winget-pkgs.

## Publishing (one-time setup + per-release updates)

### Homebrew tap

1. Create a public repo `role-suite/homebrew-tap`.
2. Add `Casks/role.rb` (copy the `role.rb` attached to any release).
3. Users install with:

   ```bash
   brew tap role-suite/tap
   brew install --cask role
   ```

4. Each release: update `version` and `sha256` in the tap (the attached `role.rb` is already
   correct — copy it over). A follow-up workflow can push the file automatically.

### Scoop bucket

1. Create a public repo `role-suite/scoop-bucket`.
2. Add `bucket/role.json` from the release (Scoop expects manifests under `bucket/`).
3. Users install with:

   ```powershell
   scoop bucket add role-suite https://github.com/role-suite/scoop-bucket
   scoop install role
   ```

4. Each release: replace `bucket/role.json`. The generated manifest already has `checkver` and
   `autoupdate` for `scoop update`.

### winget (official community repo)

1. Install `wingetcreate` and submit the generated manifests:

   ```powershell
   wingetcreate submit --token <PAT> .\winget\RoleSuite.Role.installer.yaml
   ```

2. This opens a PR against `microsoft/winget-pkgs`; Microsoft validates the manifest (and the
   installer URL). Once merged, users install with `winget install RoleSuite.Role`.

The package identifier used by the generated manifests is `RoleSuite.Role`; keep it stable across
releases.

### Flathub (Linux)

Flathub needs its own repository and Flatpak manifest (runtime, finish-args, sources pinned to the
release tarball). It is a separate submission process at <https://docs.flathub.org/docs/for-app-authors/submission>;
the AppImage remains the primary Linux artifact until then.

## Signing caveat

Package-manager installs bypass the browser but not the OS checks: SmartScreen and Gatekeeper will
still warn about unsigned builds. Configure signing first (see
[10-CODE-SIGNING.md](10-CODE-SIGNING.md)) so downloads from taps/buckets are trusted. Homebrew may
also warn about an unsigned app on first launch; that disappears once the macOS build is
notarized.

## Verifying a manifest

```bash
brew audit --cask ./role.rb          # Homebrew
scoop checkver role -d .\role.json   # Scoop (optional)
winget validate --manifest .\winget  # winget
```
