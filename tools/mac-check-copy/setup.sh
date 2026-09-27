#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Step 1 of the isolated Mac check copy (tools/mac-check-copy/README.md): extract a committed tree
# of this repository into a scratch directory and seed a fake home with volumes, so build.sh can
# build and launch a copy of FRUS Explorer that never touches the installed app's data or iCloud.
#
# Usage: tools/mac-check-copy/setup.sh [--ref REF] [--prefix P[,P…]] [--scratch DIR] [--no-fetch]
#   --ref REF      the tree to extract (default origin/v2, fetched first; HEAD for this checkout's
#                  last commit — uncommitted edits are never extracted)
#   --prefix P     seed every manifest volume whose filename starts with P; comma-separated for
#                  several (default frus1961-63, 27 volumes, ~142 MB of APFS clones)
#   --scratch DIR  where src/, home/ and dd/ live (default $MAC_CHECK_SCRATCH, else
#                  ~/Library/Caches/frus-mac-check)
#   --no-fetch     do not `git fetch origin` before extracting an origin/ ref
# Env: FRUS_VOLUMES_DIR  the corpus to seed from (default ~/Development/frus/volumes)
set -euo pipefail

REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
REF=origin/v2
PREFIXES=frus1961-63
SCRATCH=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
FETCH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF=$2; shift 2 ;;
    --prefix) PREFIXES=$2; shift 2 ;;
    --scratch) SCRATCH=$2; shift 2 ;;
    --no-fetch) FETCH=0; shift ;;
    -h|--help) sed -n '10,22p' "$0"; exit 0 ;;
    *) echo "setup.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
VOLUMES=${FRUS_VOLUMES_DIR:-$HOME/Development/frus/volumes}
[ -d "$VOLUMES" ] || { echo "setup.sh: no corpus at $VOLUMES (set FRUS_VOLUMES_DIR)" >&2; exit 1; }

SRC=$SCRATCH/src
FAKE_HOME=$SCRATCH/home
VOLDIR="$FAKE_HOME/Library/Application Support/FRUSExplorer/Volumes"

if [ "$FETCH" = 1 ] && [ "${REF#origin/}" != "$REF" ]; then
  git -C "$REPO" fetch -q origin
fi
SHA=$(git -C "$REPO" rev-parse --short=8 "$REF^{commit}")

# src/ is replaced whole; dd/ (derived data) is kept, so a rebuild after a new extract is
# incremental; home/ is kept, so its index survives a rebuild (delete it for a clean library).
rm -rf "$SRC"
mkdir -p "$SRC" "$VOLDIR"
git -C "$REPO" archive "$REF" | tar -x -C "$SRC"
echo "$REF $SHA" > "$SCRATCH/ref.txt"
echo "extracted $REF ($SHA) into $SRC"

# The local-only store is a compile-time switch in the app's own source since #1512. A tree from
# before it would build a copy that traps in CloudKit at launch, so refuse it here.
if ! grep -q '^ *#if FRUS_MAC_CHECK$' "$SRC/FRUSExplorer/Models/ModelContainer+FRUS.swift"; then
  echo "setup.sh: $REF has no #if FRUS_MAC_CHECK store switch (it predates #1512); extract a later ref" >&2
  exit 1
fi

# Seed: every manifest volume whose filename starts with one of the prefixes, APFS-cloned (cp -c
# costs no space until either copy changes). manifest.json is a list; entries carry `filename`.
LIST=$SCRATCH/seed-list.txt
python3 - "$SRC/FRUSExplorer/Resources/manifest.json" "$PREFIXES" > "$LIST" <<'PY'
import json, sys
prefixes = tuple(p for p in sys.argv[2].split(',') if p)
for entry in json.load(open(sys.argv[1])):
    if entry['filename'].startswith(prefixes):
        print(entry['filename'])
PY
listed=0; seeded=0; missing=0
while IFS= read -r f || [ -n "$f" ]; do
  listed=$((listed + 1))
  if [ -f "$VOLUMES/$f" ]; then
    cp -c "$VOLUMES/$f" "$VOLDIR/" && seeded=$((seeded + 1))
  else
    missing=$((missing + 1)); echo "  not in the corpus: $f" >&2
  fi
done < "$LIST"
echo "seeded $seeded of $listed manifest volumes matching $PREFIXES ($missing missing); $(ls "$VOLDIR" | wc -l | tr -d ' ') in $VOLDIR"
[ "$seeded" -gt 0 ] || { echo "setup.sh: seeded nothing" >&2; exit 1; }
echo "next: tools/mac-check-copy/build.sh --scratch \"$SCRATCH\""
