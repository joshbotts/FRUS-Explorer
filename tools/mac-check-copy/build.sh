#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Step 2 of the isolated Mac check copy (tools/mac-check-copy/README.md): build the tree setup.sh
# extracted as FRUSExplorerMac, AppStore configuration, under its own bundle id, ad-hoc signed with
# no sandbox and no iCloud entitlement, with FRUS_MAC_CHECK defined so it opens a local-only store;
# then launch it against the fake home, where it indexes the seeded volumes on first launch.
#
# Usage: tools/mac-check-copy/build.sh [--scratch DIR] [--wait-for-lanes N] [--no-launch]
#   --scratch DIR        as for setup.sh (default $MAC_CHECK_SCRATCH, else
#                        ~/Library/Caches/frus-mac-check)
#   --wait-for-lanes N   before building, wait while more than N xcodebuild processes run (a
#                        machine running parallel build lanes; the build-48 cap was 3)
#   --no-launch          build only
# Env: DEVELOPER_DIR (default /Applications/Xcode.app/Contents/Developer)
set -uo pipefail

SCRATCH=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
WAIT_FOR=""
LAUNCH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --scratch) SCRATCH=$2; shift 2 ;;
    --wait-for-lanes) WAIT_FOR=$2; shift 2 ;;
    --no-launch) LAUNCH=0; shift ;;
    -h|--help) sed -n '10,21p' "$0"; exit 0 ;;
    *) echo "build.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
BUNDLE_ID=bottsywattsy.FRUS-Explorer.maccheck
SRC=$SCRATCH/src
FAKE_HOME=$SCRATCH/home
LOG=$SCRATCH/build.log
[ -d "$SRC/FRUSExplorer.xcodeproj" ] || { echo "build.sh: no extracted tree at $SRC — run setup.sh first" >&2; exit 1; }

if [ -n "$WAIT_FOR" ]; then
  # Each xcodebuild invocation is one process of that exact name.
  while [ "$(pgrep -x xcodebuild | wc -l | tr -d ' ')" -gt "$WAIT_FOR" ]; do
    echo "$(date +%H:%M:%S) $(pgrep -x xcodebuild | wc -l | tr -d ' ') xcodebuild running; waiting for at most $WAIT_FOR"
    sleep 60
  done
fi

echo "building $(cat "$SCRATCH/ref.txt" 2>/dev/null || echo "$SRC") — log: $LOG"
cd "$SRC" || exit 1
# SWIFT_ACTIVE_COMPILATION_CONDITIONS is the ONLY place FRUS_MAC_CHECK is defined:
# CodingStandardsAuditTests.macCheckStoreSwitchNeverShips fails if project.yml or the project
# defines it, and fails if this line stops defining it.
nice -n 10 xcodebuild build -project FRUSExplorer.xcodeproj -scheme FRUSExplorerMac \
  -configuration AppStore -destination 'platform=macOS' -derivedDataPath "$SCRATCH/dd" \
  PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGN_ENTITLEMENTS= ENABLE_APP_SANDBOX=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) FRUS_MAC_CHECK' > "$LOG" 2>&1
grep -E '\*\* BUILD (SUCCEEDED|FAILED) \*\*' "$LOG" || { echo "build.sh: no build result"; tail -30 "$LOG"; exit 1; }
grep -q '\*\* BUILD SUCCEEDED \*\*' "$LOG" || { grep -E 'error:' "$LOG" | head -20; exit 1; }

APP=$(find "$SCRATCH/dd/Build/Products/AppStore" -maxdepth 1 -name '*.app' | head -1)
[ -n "$APP" ] || { echo "build.sh: no .app under $SCRATCH/dd/Build/Products/AppStore" >&2; exit 1; }
echo "$APP" > "$SCRATCH/app-path.txt"
echo "app: $APP"
echo "bundle id: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
echo "entitlements:"; codesign -d --entitlements - "$APP" 2>&1 | sed -n '1,15p'

if [ "$LAUNCH" = 1 ]; then
  mkdir -p "$FAKE_HOME"
  # open -n --env, never a direct exec: macOS App Nap throttles an app launched from a shell.
  # CFFIXED_USER_HOME moves Application Support (the volumes, frus.db, the SwiftData store) into
  # the fake home; preferences do NOT follow it (see the README's cleanup).
  open -n -a "$APP" --env CFFIXED_USER_HOME="$FAKE_HOME" --args -hasCompletedOnboarding 1
  echo "launched at $(date +%H:%M:%S) with home $FAKE_HOME"
fi
