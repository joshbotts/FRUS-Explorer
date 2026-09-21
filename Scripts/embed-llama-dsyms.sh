#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Archive-only build phase ("Embed llama dSYM", both app targets in project.yml): copies the
# debug symbols for the embedded llama.framework slice into the archive's dSYM folder, so the
# TestFlight / App Store upload stops warning that the archive "did not include a dSYM for
# llama.framework" and a crash inside the query encoder symbolicates.
#
# The committed xcframework carries no dSYMs (76–153 MB each, past GitHub's limit); they are
# cached locally by Scripts/fetch-llama-dsyms.sh under .cache/llama-dSYMs/. Xcode collects
# every *.dSYM in $DWARF_DSYM_FOLDER_PATH into the .xcarchive, which is the same mechanism it
# uses for the app's own symbols — nothing here is archive-format-specific.
#
# THIS RUNS UNDER ENABLE_USER_SCRIPT_SANDBOXING, and the sandbox grants exactly the files the
# phase declares in project.yml — a declared directory grants nothing beneath it (measured:
# the first archive read the declared binary and was refused the dSYM's DWARF). So every file
# read here is declared there, the copy is file by file rather than `cp -R` (no directory
# listing), and a read failure is reported as a read failure, not as a UUID mismatch.
#
# Four refusals, each deliberate:
#   - a file this needs cannot be read: FAIL naming the path — if the cache exists but the
#     sandbox refused it, the fix is the declaration, not the fetch.
#   - not archiving (ACTION != install): exit 0 silently. The phase is also marked "run only
#     when installing", so this is belt and braces for a hand-run.
#   - the cache is missing: FAIL the archive with the command to run. Shipping without the
#     symbols is exactly the state this phase exists to end, so it must not happen quietly.
#   - the cached dSYM's UUIDs differ from the embedded binary's: FAIL. A dSYM is matched by
#     UUID, so a stale one would upload cleanly and symbolicate nothing.

set -euo pipefail

if [[ "${ACTION:-build}" != "install" ]]; then
    exit 0
fi

: "${SRCROOT:?run from an Xcode build phase}"
: "${PLATFORM_NAME:?run from an Xcode build phase}"
: "${DWARF_DSYM_FOLDER_PATH:?run from an Xcode build phase}"

case "$PLATFORM_NAME" in
    iphoneos)        SLICE="ios-arm64";                  BIN="llama.framework/llama" ;;
    iphonesimulator) SLICE="ios-arm64_x86_64-simulator"; BIN="llama.framework/llama" ;;
    macosx)          SLICE="macos-arm64_x86_64";         BIN="llama.framework/Versions/A/llama" ;;
    *) echo "error: no llama.xcframework slice for PLATFORM_NAME=$PLATFORM_NAME" >&2; exit 1 ;;
esac

BUILD_SCRIPT="$SRCROOT/Scripts/build-llama-xcframework.sh"
LLAMA_COMMIT="$(sed -n 's/^LLAMA_COMMIT=\([0-9a-f]\{40\}\)$/\1/p' "$BUILD_SCRIPT")"
SHORT="${LLAMA_COMMIT:0:7}"
DSYM="$SRCROOT/.cache/llama-dSYMs/llama.xcframework/$SLICE/dSYMs/llama.dSYM"
BINARY="$SRCROOT/Vendor/llama.xcframework/$SLICE/$BIN"

DWARF="$DSYM/Contents/Resources/DWARF/llama"
PLIST="$DSYM/Contents/Info.plist"

if [[ ! -e "$DWARF" ]]; then
    echo "error: no cached dSYM for llama.framework ($SLICE, llama.cpp $SHORT) at $DSYM" >&2
    echo "error: run  ./Scripts/fetch-llama-dsyms.sh  once, then archive again." >&2
    exit 1
fi
for f in "$BINARY" "$DWARF" "$PLIST"; do
    if ! cat "$f" > /dev/null 2>&1; then
        echo "error: cannot read $f" >&2
        echo "error: it exists, so this is the script sandbox — declare it under the phase's inputFiles in project.yml." >&2
        exit 1
    fi
done

uuids_of() {
    local out
    out="$(xcrun dwarfdump --uuid "$1" | awk '{print $2}' | sort)"
    if [[ -z "$out" ]]; then
        echo "error: dwarfdump found no UUID in $1" >&2
        exit 1
    fi
    echo "$out"
}
BIN_UUIDS="$(uuids_of "$BINARY")"
DSYM_UUIDS="$(uuids_of "$DWARF")"
if [[ "$BIN_UUIDS" != "$DSYM_UUIDS" ]]; then
    echo "error: cached llama dSYM does not match the embedded binary ($SLICE)." >&2
    echo "error:   binary: $(echo "$BIN_UUIDS" | tr '\n' ' ')" >&2
    echo "error:   dSYM:   $(echo "$DSYM_UUIDS" | tr '\n' ' ')" >&2
    echo "error: run  ./Scripts/fetch-llama-dsyms.sh  to refresh the cache." >&2
    exit 1
fi

DEST="$DWARF_DSYM_FOLDER_PATH/llama.framework.dSYM"
rm -rf "$DEST"
mkdir -p "$DEST/Contents/Resources/DWARF"
cp "$PLIST" "$DEST/Contents/Info.plist"
cp "$DWARF" "$DEST/Contents/Resources/DWARF/llama"
echo "Embedded llama.framework.dSYM ($SLICE: $(echo "$DSYM_UUIDS" | tr '\n' ' ')) into $DWARF_DSYM_FOLDER_PATH"
