#!/usr/bin/env bash
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Runs one heavy job at a time on this Mac, across every worktree and every session: a command run
# through this script waits until no other command run through it is running. A heavy job is an
# xcodebuild build, test or archive, swift build, swift test, a swift run of a generator, or
# tools/mac-check-copy/build.sh.
#
# WHY: on 2026-10-18 two sessions ran three builds from empty and a UI run at once on the M5
# MacBook Air (fanless, 10 cores, 32 GB). The load average reached 785 under thermal pressure, the
# Claude app froze for up to 84 s at a time, the app tore one session down after 996 s with no
# output, and the Mac had to be restarted. One session had asked the other to hold its builds, and
# it did, but the session that asked went on to run two builds of its own at once. A lock holds
# where a request does not.
#
# HOW: /usr/bin/lockf takes an exclusive lock on one file outside every worktree
# ($HOME/Library/Caches/FRUS-Explorer/heavy-job.lock, or $FRUS_HEAVY_LOCK), runs the command, and
# drops the lock when the command exits. The kernel releases the lock with the process that holds
# it, so a crash or a kill cannot leave it held. The exit status is the command's, or 75 when
# FRUS_HEAVY_WAIT seconds pass without the lock. The file is kept (-k): removing it while another
# job waits on it would let a third take a second lock on a new file.
#
# A command already running under the lock runs at once (FRUS_HEAVY_LOCK_HELD is set inside it),
# so a script run through this one may itself call this one without waiting on itself.
#
# Usage:
#   Scripts/heavy.sh xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer …
#   Scripts/heavy.sh swift test
#   FRUS_HEAVY_WAIT=600 Scripts/heavy.sh swift build --target FRUSCoreKit
#
# Before it waits, it prints once who holds the lock, as that job recorded itself when it started.
# Run a long job in the background, as before: the wait is part of its run.
#
# Version history:
#   1.0 — 2026-10-18: initial implementation

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "usage: Scripts/heavy.sh <command> [arguments…]" >&2
    exit 64
fi

if [[ "${FRUS_HEAVY_LOCK_HELD:-}" == "1" ]]; then
    exec "$@"
fi

lock="${FRUS_HEAVY_LOCK:-$HOME/Library/Caches/FRUS-Explorer/heavy-job.lock}"
mkdir -p "$(dirname "$lock")"

# Who holds it, said once before the wait. The holder file is a note, not the lock: a job killed
# before it could clear it leaves a stale line, which the next job overwrites when it starts.
if ! /usr/bin/lockf -k -s -t 0 "$lock" /usr/bin/true; then
    echo "heavy.sh: another heavy job is running; waiting for it. It recorded: $(cat "$lock.holder" 2>/dev/null || echo "nothing")" >&2
fi

export FRUS_HEAVY_LOCK_HELD=1
export FRUS_HEAVY_HOLDER="pid $$, started $(date '+%Y-%m-%d %H:%M:%S'), in $PWD: $*"

# The job itself, run by a shell that holds no lock of its own: it records itself, runs the
# command, clears its record and exits with the command's status.
run='printf "%s\n" "$FRUS_HEAVY_HOLDER" > "$0.holder"; "$@"; status=$?; rm -f "$0.holder"; exit $status'

if [[ -n "${FRUS_HEAVY_WAIT:-}" ]]; then
    exec /usr/bin/lockf -k -t "$FRUS_HEAVY_WAIT" "$lock" /bin/bash -c "$run" "$lock" "$@"
else
    exec /usr/bin/lockf -k "$lock" /bin/bash -c "$run" "$lock" "$@"
fi
