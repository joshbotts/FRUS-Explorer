#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Rebuilds Vendor/llama.xcframework from source (V-5 s2; rebuilt for B4 on 2026-10-15).
#
# The committed xcframework is the product of upstream llama.cpp's OWN build script at the
# PINNED COMMIT, trimmed to the three slices this app ships (iOS device, iOS simulator,
# macOS) and with the embedded dSYMs stripped: the DWARF files are 63–126 MB each, two of the
# three past GitHub's 100 MB hard limit, and are archived instead as a release asset on
# frus-semantic-vectors (llama-xcframework-dSYMs-<commit7>.zip) for symbolication. The
# upstream script itself is run UNMODIFIED, so "what did we build" has a one-line answer.
#
# THE PIN is a0e6dc73 since 2026-10-15 (plan of record B4): past upstream PR 30054, which added
# EmbeddingGemma 2's `gemma-embedding2` architecture, and the commit that model's corpus store
# was embedded through, so the app's query encoder is the same engine as the document encoder.
# EmbeddingGemma 300m through it reproduces the shipped store at cosine >= 0.999982
# (EmbeddingGemma-2-Stage-1-2026-10-14.md §4). Until then the pin was 8663224, the commit the
# step-4 spike measured (parity min cosine 0.9999984, V5-Step4-Spike-2026-08-28.md).
#
# AFTER A REBUILD, PUBLISH BOTH HALVES TOGETHER: commit the new Vendor/llama.xcframework and
# upload the zip this writes to the release Scripts/fetch-llama-dsyms.sh reads from (its
# DSYM_RELEASE, `encoder-1` today). The archive-only "Embed llama dSYM" build phase refuses
# to archive without a cached dSYM whose UUIDs match the committed binary, so a rebuild that
# forgets the upload fails the next archive rather than shipping unsymbolicated.
#
# Needs: Xcode with iOS + macOS SDKs, cmake (brew install cmake), and the network; 2 min 47 s on
# the M5 MacBook Air with Xcode 27.0 (2026-10-15).

set -euo pipefail

LLAMA_COMMIT=a0e6dc7384edb8f5d927155e1d26c10b4a310e6d
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
DSYM_ZIP="$REPO_ROOT/llama-xcframework-dSYMs-${LLAMA_COMMIT:0:7}.zip"
rm -f "$DSYM_ZIP"
# Zipped from inside build-apple/, so every path starts at llama.xcframework/: the layout of
# the 8663224 asset on encoder-1 and the one fetch-llama-dsyms.sh unpacks. Zipped from the
# checkout's root, as until 2026-10-15, the paths start at build-apple/ and the fetch script
# refuses the zip (the first rebuild since the fetch script was written found it).
(cd build-apple && zip -rq "$DSYM_ZIP" llama.xcframework/*/dSYMs)
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

echo "Done. dSYM archive at $DSYM_ZIP (do not commit)."
echo "Next: upload it to the frus-semantic-vectors release, then refresh the local cache with"
echo "      DSYM_ZIP=$DSYM_ZIP ./Scripts/fetch-llama-dsyms.sh"
