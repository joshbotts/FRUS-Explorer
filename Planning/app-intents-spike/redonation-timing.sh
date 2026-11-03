#!/bin/bash
# A6 spike (kept in the repository for #1723): times FRUS Explorer's own full Spotlight re-donation on the clone
# C3F1EFE9 of A4's full-library simulator. The memory note's rule: install first, so the clone gets a
# container of its own; launch nothing before that.
# As committed on 2026-11-03 it does not run: A4's simulator (8BE32D39) and the clone (C3F1EFE9) are both gone.
# To rerun it, clone a simulator that holds a full library, set SRC and CLONE, and look up SRCDATA's and the
# app bundle's container UUIDs on that source with `xcrun simctl get_app_container`.
set -uo pipefail
CLONE=C3F1EFE9-61C1-4613-84AB-A9068D3E465A
SRC=8BE32D39-405A-428A-B9CD-9EFCC043A62F
OUT="$(cd "$(dirname "$0")" && pwd)/redonation"
SRCDATA="$HOME/Library/Developer/CoreSimulator/Devices/$SRC/data/Containers/Data/Application/35D1B259-50ED-4D79-BBB8-ED5FDEF2A4BD"
APP="$OUT/FRUS Explorer.app"

echo "source frus.db before: $(stat -f '%z %Sm' "$SRCDATA/Library/Application Support/FRUSExplorer/frus.db")"
[ -d "$APP" ] || cp -c -R "$HOME/Library/Developer/CoreSimulator/Devices/$SRC/data/Containers/Bundle/Application/BE981F87-69AB-47F8-8567-1DD53CA2DC92/FRUS Explorer.app" "$APP"
xcrun simctl install "$CLONE" "$APP" || exit 1
NEW=$(xcrun simctl get_app_container "$CLONE" bottsywattsy.FRUS-Explorer data)
echo "clone container: $NEW"
case "$NEW" in *"$CLONE"*) ;; *) echo "container is not the clone's; stopping"; exit 2 ;; esac
echo "source frus.db after install: $(stat -f '%z %Sm' "$SRCDATA/Library/Application Support/FRUSExplorer/frus.db")"
[ -f "$SRCDATA/Library/Application Support/FRUSExplorer/frus.db" ] || { echo "source library missing; stopping"; exit 3; }
[ -f "$NEW/Library/Application Support/FRUSExplorer/frus.db" ] || { echo "clone container has no library; stopping"; exit 4; }
ls -la "$NEW/Library/Application Support/FRUSExplorer/" | grep frus.db

xcrun simctl shutdown "$CLONE"
PLIST="$NEW/Library/Preferences/bottsywattsy.FRUS-Explorer.plist"
plutil -replace spotlightSchemaVersionApplied -integer 3 "$PLIST"
plutil -p "$PLIST" | grep -E 'spotlightSchemaVersionApplied|dateIndexVersion|personRollupVersion'
xcrun simctl boot "$CLONE"
xcrun simctl bootstatus "$CLONE" -b > /dev/null
sleep 30

xcrun simctl spawn "$CLONE" log stream --level info --style compact \
    --predicate 'subsystem == "bottsywattsy.FRUS-Explorer" AND category == "IndexingPipeline"' > "$OUT/stream.txt" 2>&1 &
STREAM=$!
sleep 3
date -u +%Y-%m-%dT%H:%M:%S.000Z > "$OUT/launch3-utc.txt"
xcrun simctl launch "$CLONE" bottsywattsy.FRUS-Explorer -hasCompletedOnboarding YES | tee "$OUT/launch3.txt"
for i in $(seq 1 240); do
    sleep 5
    grep -q 'resubmitted' "$OUT/stream.txt" && break
done
date -u +%Y-%m-%dT%H:%M:%S.000Z > "$OUT/found3-utc.txt"
for i in $(seq 1 10); do
    ps -ax -o pid,pcpu,etime,command | grep -E 'RuntimeRoot.*(corespotlightd|searchd)|FRUS Explorer.app/FRUS Explorer' | grep -v grep \
        | awk -v t="$(date -u +%H:%M:%S)" '{n=split($0,a,"/"); print t, $1, $2, $3, a[n]}' >> "$OUT/cpu3.txt"
    sleep 30
done
kill "$STREAM" 2>/dev/null
xcrun simctl terminate "$CLONE" bottsywattsy.FRUS-Explorer
echo "source frus.db at end: $(stat -f '%z %Sm' "$SRCDATA/Library/Application Support/FRUSExplorer/frus.db")"
echo done
