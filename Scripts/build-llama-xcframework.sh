#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Rebuilds Vendor/llama.xcframework from source (V-5 s2).
#
# The committed xcframework is the product of upstream llama.cpp's OWN build script at the
# PINNED COMMIT — the same commit the step-4 spike measured (parity min cosine 0.9999984,
# V5-Step4-Spike-2026-08-28.md) — trimmed to the three slices this app ships (iOS device,
# iOS simulator, macOS) and with the embedded dSYMs stripped: the DWARF files are 78–156 MB
# each, past GitHub's 100 MB hard limit, and are archived instead as a release asset on
# frus-semantic-vectors (llama-xcframework-dSYMs-<commit>.zip) for symbolication. The
# upstream script itself is run UNMODIFIED, so "what did we build" has a one-line answer.
#
# Needs: Xcode with iOS + macOS SDKs, cmake (brew install cmake), ~15 minutes.

set -euo pipefail

LLAMA_COMMIT=86632248188c106d749fad34a1dcd237c95863d4
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$(mktemp -d /tmp/llama-xcframework.XXXXXX)}"

echo "Cloning llama.cpp at ${LLAMA_COMMIT} into ${WORK}..."
git -C "$WORK" init -q llama.cpp
cd "$WORK/llama.cpp"
git remote add origin https://github.com/ggml-org/llama.cpp.git 2>/dev/null || true
git fetch -q --depth 1 origin "$LLAMA_COMMIT"
git checkout -q FETCH_HEAD

echo "Building (ios-sim ios-device macos)..."
./build-xcframework.sh ios-sim ios-device macos

echo "Stripping dSYMs (archived separately, not committed)..."
zip -rq "$REPO_ROOT/llama-xcframework-dSYMs.zip" build-apple/llama.xcframework/*/dSYMs
rm -rf build-apple/llama.xcframework/*/dSYMs
for i in 0 1 2; do
    plutil -remove "AvailableLibraries.$i.DebugSymbolsPath" \
        build-apple/llama.xcframework/Info.plist
done
plutil -lint build-apple/llama.xcframework/Info.plist

echo "Installing into Vendor/..."
rm -rf "$REPO_ROOT/Vendor/llama.xcframework"
mkdir -p "$REPO_ROOT/Vendor"
cp -R build-apple/llama.xcframework "$REPO_ROOT/Vendor/"

echo "Done. dSYM archive at $REPO_ROOT/llama-xcframework-dSYMs.zip (do not commit)."
