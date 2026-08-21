#!/bin/bash
#
# Put a Debug build of Nomstamp on a real iPhone, which is the only place the friends ceremony
# can be tested — a simulator has no Bluetooth radio behind it at all
# (docs/testing/radio-check.md).
#
#   scripts/install-device.sh              # first connected device
#   scripts/install-device.sh <device-id>  # a particular one, from `xcrun devicectl list devices`
#
# Signing uses the same App Store Connect key as scripts/deploy.sh, read from .env, so no Apple ID
# has to be signed in to Xcode. Unlike deploy.sh this touches nothing remote: it builds, installs
# and launches, and that is all.

set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
note() { printf '  %s\n' "$1"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi
[ -n "${ASC_TEAM_ID:-}" ] || die "ASC_TEAM_ID is not set — copy .env.example to .env and fill it in."
[ -n "${ASC_KEY_ID:-}" ] || die "ASC_KEY_ID is not set."
[ -n "${ASC_ISSUER_ID:-}" ] || die "ASC_ISSUER_ID is not set."

KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[ -f "$KEY_FILE" ] || die "No signing key at $KEY_FILE"

# ── which phone ──────────────────────────────────────────────────────────────────────────────────

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
    step "Finding a phone"
    DEVICE=$(xcrun devicectl list devices 2>/dev/null \
        | awk '$0 ~ /connected/ && $0 ~ /iPhone/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-/) { print $i; exit } }')
    [ -n "$DEVICE" ] || die "No connected iPhone. Plug one in, unlock it, and trust this Mac.
  \`xcrun devicectl list devices\` shows what the Mac can see; 'unavailable' means locked or unplugged."
fi
note "device $DEVICE"

# ── build ────────────────────────────────────────────────────────────────────────────────────────

step "Generating the project"
xcodegen generate >/dev/null

DERIVED="build/device"
step "Building for the device"
xcodebuild -project FoodMap.xcodeproj \
    -scheme FoodMap \
    -configuration Debug \
    -destination "id=$DEVICE" \
    -derivedDataPath "$DERIVED" \
    DEVELOPMENT_TEAM="$ASC_TEAM_ID" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$KEY_FILE" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    -quiet \
    build

APP="$DERIVED/Build/Products/Debug-iphoneos/FoodMap.app"
[ -d "$APP" ] || die "No app was produced at $APP"

# The check that would have caught the original bug before anyone walked to a restaurant: a build
# without this key cannot use Bluetooth, and iOS kills the app when it goes to ask.
/usr/libexec/PlistBuddy -c "Print :NSBluetoothAlwaysUsageDescription" "$APP/Info.plist" >/dev/null 2>&1 \
    || die "This build has no NSBluetoothAlwaysUsageDescription — the friends screen cannot work."

step "Installing"
xcrun devicectl device install app --device "$DEVICE" "$APP"

step "Launching"
xcrun devicectl device process launch --device "$DEVICE" com.longnv.foodmap.app

printf '\n\033[32m✓ Nomstamp is on the phone.\033[0m\n'
note "Next: on the Mac, run  swift Tools/PeerProbe.swift listen"
note "then open Add friend on the phone. See docs/testing/radio-check.md."
