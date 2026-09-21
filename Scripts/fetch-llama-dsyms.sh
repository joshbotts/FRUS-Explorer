#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Fetches the debug symbols for Vendor/llama.xcframework into a local, gitignored cache so an
# archive can carry them (Scripts/embed-llama-dsyms.sh, an archive-only build phase on both
# app targets).
#
# WHY A FETCH AND NOT A COMMIT: the dSYMs are 76–153 MB per slice, past GitHub's 100 MB hard
# limit, so Scripts/build-llama-xcframework.sh strips them from the committed xcframework and
# they are published instead as a release asset on frus-semantic-vectors. Without them every
# TestFlight / App Store upload warns that the archive "did not include a dSYM for
# llama.framework", and a crash inside the query encoder cannot be symbolicated.
#
# The asset is named by the pinned llama.cpp commit read from build-llama-xcframework.sh —
# one source of truth for "which build is this" — but the CACHE PATH carries no commit, on
# purpose: the archive phase runs under ENABLE_USER_SCRIPT_SANDBOXING, which grants a script
# only the exact files project.yml declares as inputs (a declared directory grants nothing
# beneath it — measured), so the paths must be stable across rebuilds. What makes the cache
# trustworthy is not its name but the check: every slice's dSYM is verified against the
# committed binary's UUIDs before it is accepted, because a dSYM whose UUID does not match
# is silently useless — App Store Connect matches symbols by UUID, never by name.
#
# Only Contents/Info.plist and Contents/Resources/DWARF/llama are kept per dSYM (upstream's
# Relocations/*.yml is dsymutil's relink input, not symbolication data) — the same two files
# the archive phase declares and copies.
#
# Idempotent: a cache that already verifies is left alone (no download). Run it once after
# cloning and once after every xcframework rebuild — or let Scripts/notarize.sh run it.
#
# Env:
#   DSYM_ZIP        — a local zip to install from instead of downloading (the one the build
#                     script just wrote, before it has been uploaded to the release)
#   DSYM_REPO       — GitHub repo holding the release asset (default joshbotts/frus-semantic-vectors)
#   DSYM_RELEASE    — release tag carrying llama-xcframework-dSYMs-<commit7>.zip (default encoder-1)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRIPT="$REPO_ROOT/Scripts/build-llama-xcframework.sh"
XCFRAMEWORK="$REPO_ROOT/Vendor/llama.xcframework"

LLAMA_COMMIT="$(sed -n 's/^LLAMA_COMMIT=\([0-9a-f]\{40\}\)$/\1/p' "$BUILD_SCRIPT")"
if [[ -z "$LLAMA_COMMIT" ]]; then
    echo "error: could not read LLAMA_COMMIT from $BUILD_SCRIPT" >&2
    exit 1
fi
SHORT="${LLAMA_COMMIT:0:7}"

DSYM_REPO="${DSYM_REPO:-joshbotts/frus-semantic-vectors}"
DSYM_RELEASE="${DSYM_RELEASE:-encoder-1}"
ASSET="llama-xcframework-dSYMs-${SHORT}.zip"
CACHE_DIR="$REPO_ROOT/.cache/llama-dSYMs"

# Slice identifier -> path of the committed binary inside its framework (macOS frameworks are
# versioned bundles; iOS ones are flat). Keep in step with Vendor/llama.xcframework/Info.plist.
slice_binary() {
    case "$1" in
        macos-arm64_x86_64)          echo "llama.framework/Versions/A/llama" ;;
        ios-arm64|ios-arm64_x86_64-simulator) echo "llama.framework/llama" ;;
        *) echo "error: unknown xcframework slice '$1'" >&2; return 1 ;;
    esac
}

# Sorted, newline-separated UUIDs of a Mach-O or dSYM (fat files print one per architecture).
uuids_of() {
    xcrun dwarfdump --uuid "$1" | awk '{print $2}' | sort
}

# Every slice in the committed xcframework must have a dSYM in the cache whose UUID set equals
# the committed binary's. Prints the mismatch and returns 1 otherwise.
verify_cache() {
    local ok=1 slice dsym bin
    for dir in "$XCFRAMEWORK"/*/; do
        slice="$(basename "$dir")"
        bin="$XCFRAMEWORK/$slice/$(slice_binary "$slice")"
        dsym="$CACHE_DIR/llama.xcframework/$slice/dSYMs/llama.dSYM"
        if [[ ! -f "$dsym/Contents/Resources/DWARF/llama" || ! -f "$dsym/Contents/Info.plist" ]]; then
            echo "  $slice: no dSYM at $dsym"
            ok=0
            continue
        fi
        if [[ "$(uuids_of "$bin")" != "$(uuids_of "$dsym")" ]]; then
            echo "  $slice: UUID MISMATCH — binary $(uuids_of "$bin" | tr '\n' ' ') vs dSYM $(uuids_of "$dsym" | tr '\n' ' ')"
            ok=0
            continue
        fi
        echo "  $slice: $(uuids_of "$dsym" | tr '\n' ' ')ok"
    done
    [[ $ok -eq 1 ]]
}

echo "llama.cpp $SHORT — checking cached dSYMs at $CACHE_DIR"
if [[ -d "$CACHE_DIR" ]] && [[ "$(cat "$CACHE_DIR/llama-commit" 2>/dev/null)" == "$LLAMA_COMMIT" ]] && verify_cache; then
    echo "Cached dSYMs verify against Vendor/llama.xcframework; nothing to fetch."
    exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/llama-dsyms.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [[ -n "${DSYM_ZIP:-}" ]]; then
    echo "Installing from local archive $DSYM_ZIP"
    cp "$DSYM_ZIP" "$WORK/$ASSET"
else
    URL="https://github.com/$DSYM_REPO/releases/download/$DSYM_RELEASE/$ASSET"
    echo "Downloading $URL"
    if ! curl -fL --progress-bar -o "$WORK/$ASSET" "$URL"; then
        echo "error: could not download $ASSET from release $DSYM_RELEASE of $DSYM_REPO." >&2
        echo "       If the xcframework was just rebuilt, upload the zip the build script wrote" >&2
        echo "       to that release, or install it directly: DSYM_ZIP=<path> $0" >&2
        exit 1
    fi
fi

# The zip holds llama.xcframework/<slice>/dSYMs/llama.dSYM — exactly what upstream's
# build-xcframework.sh lays out and what build-llama-xcframework.sh removes before committing.
unzip -q "$WORK/$ASSET" -d "$WORK/unpacked"
rm -rf "$CACHE_DIR"
for dir in "$WORK"/unpacked/llama.xcframework/*/; do
    slice="$(basename "$dir")"
    src="$dir/dSYMs/llama.dSYM"
    dst="$CACHE_DIR/llama.xcframework/$slice/dSYMs/llama.dSYM"
    mkdir -p "$dst/Contents/Resources/DWARF"
    cp "$src/Contents/Info.plist" "$dst/Contents/Info.plist"
    cp "$src/Contents/Resources/DWARF/llama" "$dst/Contents/Resources/DWARF/llama"
done
echo "$LLAMA_COMMIT" > "$CACHE_DIR/llama-commit"

echo "Verifying against the committed binaries:"
if ! verify_cache; then
    echo "error: the fetched dSYMs do not match Vendor/llama.xcframework — refusing to keep them." >&2
    echo "       The release asset and the committed xcframework must come from the SAME build" >&2
    echo "       (rebuild with Scripts/build-llama-xcframework.sh and publish both together)." >&2
    rm -rf "$CACHE_DIR"
    exit 1
fi
echo "Done. Archives will now carry llama.framework.dSYM (Scripts/embed-llama-dsyms.sh)."
