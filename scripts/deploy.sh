#!/bin/bash
#
# Ship a build of Nomstamp to TestFlight.
#
# Everything docs/deployment/testflight.md §3.2 describes, in the order it has to happen, with the
# checks that catch a bad upload before Apple does. Safe to re-run: it refuses rather than
# half-finishes.
#
#   scripts/deploy.sh                 # test, archive, export, upload
#   scripts/deploy.sh --bump          # …after incrementing the build number
#   scripts/deploy.sh --skip-tests    # when the suites just ran
#   scripts/deploy.sh --no-upload     # archive and export only, then stop
#   scripts/deploy.sh --dry-run       # print what would happen, touch nothing
#
# Credentials, none of which belong in the repository:
#
#   ASC_TEAM_ID     ten characters, developer.apple.com/account → Membership details
#   ASC_KEY_ID      App Store Connect API key id
#   ASC_ISSUER_ID   the issuer UUID shown above the key list
#
# The key itself is read from ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8, which is
# where the uploader looks by default.

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="FoodMap"
PROJECT="FoodMap.xcodeproj"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Nomstamp.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

BUMP=0
SKIP_TESTS=0
UPLOAD=1
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --bump)       BUMP=1 ;;
        --skip-tests) SKIP_TESTS=1 ;;
        --no-upload)  UPLOAD=0 ;;
        --dry-run)    DRY_RUN=1 ;;
        -h|--help)    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        *)            echo "unknown option: $1 (try --help)" >&2 ; exit 2 ;;
    esac
    shift
done

# ── how this script talks ────────────────────────────────────────────────────────────────────────

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
note() { printf '  %s\n' "$1"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  \033[2m$ %s\033[0m\n' "$*"
    else
        "$@"
    fi
}

# ── preflight ────────────────────────────────────────────────────────────────────────────────────
# Every one of these has cost somebody an upload.

step "Preflight"

command -v xcodegen >/dev/null || die "xcodegen is not installed — brew install xcodegen"
command -v xcodebuild >/dev/null || die "xcodebuild is not on PATH — install the Xcode command line tools"

[ -n "${ASC_TEAM_ID:-}" ] || die "ASC_TEAM_ID is not set. See the header of this script."

ICON="FoodMap/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
[ -f "$ICON" ] || die "No app icon at $ICON — run: swift Tools/MakeAppIcon.swift $ICON"

# A build that cannot be traced back to a commit is a build you cannot fix.
if [ -n "$(git status --porcelain)" ]; then
    note "Working tree is dirty; this build will not be tagged."
    DIRTY=1
else
    DIRTY=0
fi

VERSION=$(grep -m1 'MARKETING_VERSION:' project.yml | sed 's/.*"\(.*\)".*/\1/')
BUILD_NUMBER=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/.*"\(.*\)".*/\1/')

if [ "$BUMP" -eq 1 ]; then
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
    note "Build number → $BUILD_NUMBER"
    run sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$BUILD_NUMBER\"/" project.yml
fi

note "Nomstamp $VERSION ($BUILD_NUMBER), team $ASC_TEAM_ID"
note "App Store Connect rejects a build number it has already seen — bump with --bump."

# ── generate ─────────────────────────────────────────────────────────────────────────────────────

step "Generating the project"
run xcodegen generate

# ── test ─────────────────────────────────────────────────────────────────────────────────────────
# All four suites, the same ones CLAUDE.md names. Full xcodebuild test, never
# test-without-building, which happily re-runs a stale bundle.

if [ "$SKIP_TESTS" -eq 1 ]; then
    step "Tests skipped (--skip-tests)"
else
    step "Testing"
    for package in FoodMapDomain FoodMapData FoodMapDesign; do
        note "$package"
        run swift test --package-path "Packages/$package"
    done
    note "XCUITest journeys"
    run xcodebuild test -project "$PROJECT" -scheme "$SCHEME" \
        -destination 'platform=iOS Simulator,name=iPhone 17' \
        -quiet
fi

# ── archive ──────────────────────────────────────────────────────────────────────────────────────
# A stale archive is indistinguishable from a fresh one in the Organizer, so it goes first.

step "Archiving"
run rm -rf "$ARCHIVE" "$EXPORT_DIR"
run xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$ASC_TEAM_ID" \
    -allowProvisioningUpdates \
    -quiet \
    archive

[ "$DRY_RUN" -eq 1 ] || [ -d "$ARCHIVE" ] || die "No archive was produced at $ARCHIVE"

# ── export ───────────────────────────────────────────────────────────────────────────────────────
# The options are written here rather than read from docs/deployment/ExportOptions.plist so the
# team id comes from the environment and no real credential is ever committed.

step "Exporting"
OPTIONS="$BUILD_DIR/ExportOptions.generated.plist"
if [ "$DRY_RUN" -eq 1 ]; then
    note "would write $OPTIONS"
else
    mkdir -p "$BUILD_DIR"
    cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>export</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>$ASC_TEAM_ID</string>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
fi

run xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates \
    -quiet

IPA="$EXPORT_DIR/$SCHEME.ipa"
if [ "$DRY_RUN" -eq 0 ]; then
    [ -f "$IPA" ] || IPA=$(find "$EXPORT_DIR" -name '*.ipa' -maxdepth 1 | head -1)
    [ -n "$IPA" ] && [ -f "$IPA" ] || die "No .ipa in $EXPORT_DIR"
    note "$IPA ($(du -h "$IPA" | cut -f1))"
fi

# ── upload ───────────────────────────────────────────────────────────────────────────────────────

if [ "$UPLOAD" -eq 0 ]; then
    step "Stopping before upload (--no-upload)"
    note "Upload by hand with: xcrun altool --upload-app -f $IPA -t ios --apiKey \$ASC_KEY_ID --apiIssuer \$ASC_ISSUER_ID"
    exit 0
fi

step "Uploading to App Store Connect"
[ -n "${ASC_KEY_ID:-}" ] || die "ASC_KEY_ID is not set"
[ -n "${ASC_ISSUER_ID:-}" ] || die "ASC_ISSUER_ID is not set"

KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[ "$DRY_RUN" -eq 1 ] || [ -f "$KEY_FILE" ] || die "No API key at $KEY_FILE — it can only be downloaded once, from App Store Connect → Users and Access → Integrations"

run xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

# ── after ────────────────────────────────────────────────────────────────────────────────────────

step "Uploaded"
note "Processing takes 5–30 minutes. If the build never appears in TestFlight, read the email"
note "Apple sends the account holder — invalid binaries are explained there and nowhere else."

if [ "$DIRTY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    TAG="v$VERSION-$BUILD_NUMBER"
    if git rev-parse "$TAG" >/dev/null 2>&1; then
        note "Tag $TAG already exists; leaving it alone."
    else
        git tag "$TAG"
        note "Tagged $TAG — push it with: git push origin $TAG"
    fi
fi
