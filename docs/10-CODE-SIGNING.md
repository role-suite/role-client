# 10. Code Signing & Notarization

Release artifacts are checksummed (`SHA256SUMS`) and have build provenance attestations, but that
does not stop Windows SmartScreen or macOS Gatekeeper from warning about an unsigned download.
This document covers the signing setup wired into the release pipeline and the remaining choices.

## What the pipeline does today

| Platform | When secrets are configured | When they are not |
|---|---|---|
| **Windows** | `relay.exe` and the Inno Setup installer are signed with the configured PFX, then verified with `Get-AuthenticodeSignature` (the release fails if either signature is invalid). | Artifacts are shipped unsigned; SmartScreen shows "Unknown publisher". |
| **macOS** | The `.app` is signed with a Developer ID Application identity (hardened runtime + App Sandbox entitlements + embedded Developer ID profile), notarized by Apple, stapled, and checked with `codesign`, `stapler`, and `spctl`. | An unsigned zip is shipped; users need right-click → Open. |
| **Linux / Android / iOS** | Linux/Android do not use OS-level signing on GitHub; Android store uploads use the upload keystore (see the workflows README). iOS is not signed in this pipeline — TestFlight signing is a separate path. | — |

GitHub Actions secrets are read by `.github/workflows/build.yml`. Nothing is required: without
secrets, releases keep working exactly as before.

## Windows

### Options (2026)

| Option | Cost | Eligibility | SmartScreen | Notes |
|---|---|---|---|---|
| **Microsoft Store** | Free (Store re-signs) | Worldwide | **No warnings** | Also gives distribution/discovery. Needs an MSIX package and a Store listing. |
| **SignPath Foundation** | Free for OSS | OSI license, no proprietary parts | Improves; reputation still builds | Certificate is issued to SignPath Foundation (publisher shows as SignPath Foundation). GitHub Actions integration. |
| **Azure Artifact Signing** (formerly Trusted Signing) | ~$10/month | Organizations in US/CA/EU/UK; **individuals only US/Canada** | Reputation builds over weeks | Not available to individuals in Turkey. No hardware token. |
| **OV certificate** | $150–500/year | Identity validation by a CA | Reputation builds over weeks | Since 2023 the private key must live on certified hardware or a cloud signing service. |
| **EV certificate** | $250–700/year | Registered businesses | Reputation builds over weeks (EV no longer skips SmartScreen since 2024) | Only worth it for drivers/some enterprise requirements. |

For an individual maintainer outside the US/Canada, the practical choices are **Microsoft Store**
(best trust + discovery, free), **SignPath Foundation** (free signing for direct downloads), or a
paid OV certificate if you want your own publisher name.

### Wiring a PFX certificate (already implemented)

The workflow signs `relay.exe` and the installer, then verifies both. Add:

| Secret | Value |
|---|---|
| `WINDOWS_CERTIFICATE_BASE64` | base64-encoded `.pfx` (single line) |
| `WINDOWS_CERTIFICATE_PASSWORD` | password for the `.pfx` |

```bash
# macOS/Linux
base64 -i certificate.pfx | tr -d '\n' | pbcopy   # macOS
openssl base64 -A -in certificate.pfx             # Linux

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.pfx"))
```

The signing step only runs when `WINDOWS_CERTIFICATE_BASE64` is set; the release fails if the
resulting signatures are not valid.

### SignPath Foundation (recommended free path for OSS)

SignPath signs artifacts through their service using a certificate issued to SignPath Foundation.
The integration uses `signpath/github-action-submit-signing-request` with a token and project
IDs. It is not wired here yet because it needs a SignPath account, an artifact configuration, and
project slugs created there. Apply at <https://signpath.org/> and follow
<https://docs.signpath.io/trusted-build-systems/github>; once the project exists, wiring it into
`build.yml` is a small follow-up (upload the installer, submit a signing request, download the
signed file, then package).

### Microsoft Store (free trust + discovery)

The Store re-signs submitted packages, so users never see SmartScreen warnings, and MSIX supports
built-in updates. Submitting requires an MSIX package (`msix` Flutter package) and a Partner
Center account. This is a distribution workstream on its own; the Windows installer in this repo
remains the direct-download path.

## macOS

### One-time setup

1. **Developer ID Application certificate** — in the Apple Developer portal create a *Developer ID
   Application* certificate for the team (`4VKLWUPBMR`), install it in Keychain, then export it as
   a `.p12` (certificate + private key) with a password.
2. **Developer ID provisioning profile** — create a *Developer ID* provisioning profile for
   `com.devora.relay` (required because the app uses App Sandbox), download the
   `.mobileprovision`.
3. **App Store Connect API key** — *Users and Access → Integrations → Team Keys*, role *App
   Manager*. Download the `.p8` once; note the Key ID and Issuer ID.
4. Add repository secrets (single-line base64 for the binary files, raw text for the `.p8`):

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | base64 of the `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12` password |
| `MACOS_PROVISIONING_PROFILE_BASE64` | base64 of the `.mobileprovision` |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | API issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | full `.p8` contents (newlines preserved) |

On the next tagged release, `packaging/macos/sign_and_notarize.sh` signs the app inside-out,
embeds the profile, notarizes with `notarytool --wait`, staples the ticket, and rewrites
`relay-<version>-macos.zip`. The job fails if notarization is not `Accepted` or Gatekeeper
assessment fails.

### App Store builds

Mac App Store builds are signed and notarized by Apple and updated by the App Store. The in-app
updater detects App Store builds (`_MASReceipt`) and stays out of the way; self-updates are only
offered for direct-download builds. See the macOS strategy note in the roadmap.

### SmartScreen/Gatekeeper reality

Signing removes "Unknown publisher" and enables notarization, but **SmartScreen reputation builds
over time** (often weeks) even with a valid signature. The only way to avoid SmartScreen warnings
on day one is Store distribution. Communicate this in release notes instead of treating every
warning as a regression.

## Verifying a release locally

```powershell
# Windows
Get-AuthenticodeSignature .\relay-<version>-windows-x64-setup.exe | Format-List Status, SignerCertificate
```

```bash
# macOS
unzip relay-<version>-macos.zip
codesign --verify --deep --strict --verbose=2 Runner.app
spctl --assess --type execute --verbose=2 Runner.app
xcrun stapler validate Runner.app
```

## Security rules

- Never commit certificates, keys, or profiles; keep them in GitHub Actions secrets.
- Prefer short-lived credentials and revoke/rotate certificates when a maintainer leaves.
- The pipeline verifies signatures before publishing; do not disable those checks to get a release out.
