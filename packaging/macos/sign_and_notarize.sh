#!/usr/bin/env bash
#
# Signs a macOS .app with a Developer ID Application identity, embeds the
# Developer ID provisioning profile, notarizes it with Apple, staples the
# ticket, and writes the final distribution zip.
#
# Used by the release workflow when MACOS_CERTIFICATE_P12_BASE64 is configured.
# See docs/10-CODE-SIGNING.md for the one-time certificate/profile/API-key
# setup and the required secrets.
#
# Usage: sign_and_notarize.sh <path-to-app> <entitlements> <output-zip>
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <path-to-app> <entitlements> <output-zip>" >&2
  exit 64
fi

APP="$1"
ENTITLEMENTS="$2"
OUT_ZIP="$3"

: "${MACOS_CERTIFICATE_P12_BASE64:?MACOS_CERTIFICATE_P12_BASE64 is required}"
: "${MACOS_CERTIFICATE_PASSWORD:?MACOS_CERTIFICATE_PASSWORD is required}"
: "${MACOS_PROVISIONING_PROFILE_BASE64:?MACOS_PROVISIONING_PROFILE_BASE64 is required}"
: "${APP_STORE_CONNECT_API_KEY_KEY_ID:?APP_STORE_CONNECT_API_KEY_KEY_ID is required}"
: "${APP_STORE_CONNECT_API_KEY_ISSUER_ID:?APP_STORE_CONNECT_API_KEY_ISSUER_ID is required}"
: "${APP_STORE_CONNECT_API_KEY_KEY:?APP_STORE_CONNECT_API_KEY_KEY is required}"

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  exit 1
fi

WORK="$(mktemp -d)"
KEYCHAIN="$WORK/build.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"

cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== Importing Developer ID certificate =="
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | tr -d '\n' | openssl base64 -d -A > "$WORK/certificate.p12"
security import "$WORK/certificate.p12" -k "$KEYCHAIN" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN"

IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
if [[ -z "$IDENTITY" ]]; then
  echo "No 'Developer ID Application' identity found in the imported certificate." >&2
  exit 1
fi
echo "Signing identity: $IDENTITY"

echo "== Embedding Developer ID provisioning profile =="
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILE_DIR"
PROFILE_PATH="$PROFILE_DIR/relay-developer-id.provisionprofile"
printf '%s' "$MACOS_PROVISIONING_PROFILE_BASE64" | tr -d '\n' | openssl base64 -d -A > "$PROFILE_PATH"
cp "$PROFILE_PATH" "$APP/Contents/embedded.provisionprofile"

echo "== Signing nested frameworks and dylibs =="
while IFS= read -r -d '' framework; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$framework"
done < <(find "$APP/Contents/Frameworks" -depth -type d -name "*.framework" -print0 2>/dev/null || true)
while IFS= read -r -d '' dylib; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$dylib"
done < <(find "$APP" -type f -name "*.dylib" -print0 2>/dev/null || true)

echo "== Signing app bundle =="
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "== Zipping for notarization =="
NOTARIZE_ZIP="$WORK/notarize.zip"
ditto -c -k --keepParent "$APP" "$NOTARIZE_ZIP"

echo "== Submitting to Apple notary service (this can take a few minutes) =="
printf '%s' "$APP_STORE_CONNECT_API_KEY_KEY" > "$WORK/AuthKey.p8"
NOTARY_OUTPUT="$(xcrun notarytool submit "$NOTARIZE_ZIP" \
  --key "$WORK/AuthKey.p8" \
  --key-id "$APP_STORE_CONNECT_API_KEY_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" \
  --wait 2>&1)" || {
  echo "$NOTARY_OUTPUT"
  echo "Notarization request failed." >&2
  exit 1
}
echo "$NOTARY_OUTPUT"
if ! grep -q "status: Accepted" <<< "$NOTARY_OUTPUT"; then
  echo "Notarization was not accepted." >&2
  exit 1
fi

echo "== Stapling and verifying =="
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

echo "== Writing distribution zip =="
rm -f "$OUT_ZIP"
ditto -c -k --keepParent "$APP" "$OUT_ZIP"
echo "Signed, notarized, and stapled: $OUT_ZIP"
