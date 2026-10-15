#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Compiles mac_parity_harness.swift beside the app's own query encoder source, against the macOS
# slice of the llama.xcframework given, and runs it RUNS times, one JSON line a run (plan of
# record B4, 2026-10-15). Each run is a fresh process, so each pays its own load.
#
# Usage: run_mac_harness.sh <llama.xcframework> <gguf> <fixture.json> [runs]
#   The committed framework is Vendor/llama.xcframework; the one before B4 can be read out of git
#   with `git archive <commit> Vendor/llama.xcframework/macos-arm64_x86_64 | tar -x -C <dir>`.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCFRAMEWORK="$(cd "$1" && pwd)"
GGUF="$2"
FIXTURE="$3"
RUNS="${4:-1}"
SLICE="$XCFRAMEWORK/macos-arm64_x86_64"

BUILD="$(mktemp -d "${TMPDIR:-/tmp}/mac-parity-harness.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
# swiftc runs top-level code only from a file named main.swift.
cp "$HERE/mac_parity_harness.swift" "$BUILD/main.swift"
xcrun swiftc -O -swift-version 6 \
    -F "$SLICE" -framework llama -Xlinker -rpath -Xlinker "$SLICE" \
    "$REPO/FRUSExplorer/Semantic/SemanticQueryEncoder.swift" \
    "$REPO/SemanticVectorsKit/SemanticQueryPrompt.swift" \
    "$BUILD/main.swift" -o "$BUILD/mac-parity-harness"

for _ in $(seq 1 "$RUNS"); do
    "$BUILD/mac-parity-harness" "$GGUF" "$FIXTURE" 2>/dev/null
done
