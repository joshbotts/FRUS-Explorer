#!/usr/bin/env bash
# notarize.sh — FRUS Explorer Direct Distribution notarization workflow
#
# Usage:
#   ./Scripts/notarize.sh [--app-path PATH] [--profile NAME] [--dry-run]
#
# Prerequisites:
#   1. Xcode command-line tools installed (xcodebuild, xcrun, ditto)
#   2. A valid Developer ID Application signing certificate in your keychain
#   3. A notarytool credential profile stored via:
#        xcrun notarytool store-credentials "FRUS-Notary" \
#          --apple-id "your@email.com" \
#          --team-id "YOUR_TEAM_ID" \
#          --password "xxxx-xxxx-xxxx-xxxx"
#   4. stapler bundled with Xcode CLT (xcrun stapler)
#
# What this script does:
#   1. Archives the FRUSExplorerMac target using the DirectDistribution config
#   2. Exports the archive as a Developer ID–signed .app
#   3. Creates a zip for upload (ditto -c -k --keepParent)
#   4. Submits to Apple notarization service (xcrun notarytool submit --wait)
#   5. Staples the notarization ticket (xcrun stapler staple)
#   6. Creates the final distributable DMG via hdiutil
#
# Environment variables (override defaults):
#   TEAM_ID          — 10-character Apple Team ID (required for signing)
#   NOTARY_PROFILE   — Keychain credential profile name (default: FRUS-Notary)
#   ARCHIVE_PATH     — Path for .xcarchive output (default: build/FRUSExplorer.xcarchive)
#   EXPORT_PATH      — Path for exported .app (default: build/export)
#   DMG_PATH         — Final DMG destination (default: build/FRUSExplorer.dmg)
#   APP_VERSION      — Injected as MARKETING_VERSION during build (optional)

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"

NOTARY_PROFILE="${NOTARY_PROFILE:-FRUS-Notary}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/FRUSExplorer.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_DIR/export}"
DMG_PATH="${DMG_PATH:-$BUILD_DIR/FRUSExplorer.dmg}"
APP_BUNDLE="$EXPORT_PATH/FRUS Explorer.app"
ZIP_PATH="$BUILD_DIR/FRUSExplorer-notarize.zip"
SCHEME="FRUSExplorerMac"
CONFIGURATION="DirectDistribution"
DRY_RUN=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-path)   APP_BUNDLE="$2"; shift 2 ;;
        --profile)    NOTARY_PROFILE="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        *)            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------
if [[ -z "${TEAM_ID:-}" ]]; then
    echo "ERROR: TEAM_ID environment variable is required." >&2
    echo "       Export it before running: export TEAM_ID=XXXXXXXXXX" >&2
    exit 1
fi

command -v xcrun  >/dev/null 2>&1 || { echo "ERROR: xcrun not found. Install Xcode CLT."; exit 1; }
command -v ditto  >/dev/null 2>&1 || { echo "ERROR: ditto not found. Install Xcode CLT."; exit 1; }
command -v hdiutil >/dev/null 2>&1 || { echo "ERROR: hdiutil not found."; exit 1; }

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
log() { echo "==> $*"; }
run() {
    if $DRY_RUN; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Step 1: Archive
# ---------------------------------------------------------------------------
log "Archiving $SCHEME ($CONFIGURATION)..."
mkdir -p "$BUILD_DIR"

run xcodebuild archive \
    -project "$PROJECT_ROOT/FRUSExplorer.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    TEAM_ID="$TEAM_ID" \
    ${APP_VERSION:+MARKETING_VERSION="$APP_VERSION"} \
    | xcpretty 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 2: Export (Developer ID)
# ---------------------------------------------------------------------------
log "Exporting Developer ID–signed app..."

EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
PLIST

run xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

# ---------------------------------------------------------------------------
# Step 3: Create zip for notarization upload
# ---------------------------------------------------------------------------
log "Creating zip for notarization upload..."
rm -f "$ZIP_PATH"
run ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# ---------------------------------------------------------------------------
# Step 4: Submit to Apple Notarization
# ---------------------------------------------------------------------------
log "Submitting to Apple Notarization (this may take several minutes)..."
run xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# ---------------------------------------------------------------------------
# Step 5: Staple the notarization ticket
# ---------------------------------------------------------------------------
log "Stapling notarization ticket to app bundle..."
run xcrun stapler staple "$APP_BUNDLE"

# ---------------------------------------------------------------------------
# Step 6: Verify stapling
# ---------------------------------------------------------------------------
log "Verifying notarization..."
run xcrun stapler validate "$APP_BUNDLE"
run spctl --assess --type execute --verbose "$APP_BUNDLE"

# ---------------------------------------------------------------------------
# Step 7: Create distributable DMG
# ---------------------------------------------------------------------------
log "Creating DMG at $DMG_PATH..."
rm -f "$DMG_PATH"
run hdiutil create \
    -volname "FRUS Explorer" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

log "Done! Distributable DMG: $DMG_PATH"
