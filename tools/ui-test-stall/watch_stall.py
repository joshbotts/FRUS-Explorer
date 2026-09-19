#!/usr/bin/env python3
"""Loop a UI test and, the moment XCTest stalls waiting for animations, dump them.

The Corpus Analytics stall (Planning/DEVELOPMENT-PLAN.md, session "the Corpus Analytics idle
stall") has never been caught live. XCTest's in-app side logs each wait as a pair, under subsystem
`com.apple.dt.xctest` in the APP's process: "Received request to notify when animations are idle",
then "Sending animations idle reply". A stall is a request with no reply, and the app stays alive
throughout, so a request unanswered for STALL_SECONDS triggers `animdump.py` through lldb plus a
simulator screenshot. Diff the dump against a baseline taken on a passing run.

Run it from the repo root with a build already in DERIVED_DATA (`xcodebuild build-for-testing ...
-derivedDataPath <dir>`), somewhere it can run unattended: it may need many hours, having measured
4 stalls in 19 runs on 2026-09-18 and 0 in 22 on 2026-09-19.

    UDID=<simulator> DERIVED_DATA=<dir> OUT=<dir> python3 tools/ui-test-stall/watch_stall.py

Env: UDID (required; pin one, several runtimes share a device name), DERIVED_DATA (required),
OUT (default ./stall-watch), RUNS (default 200), STOP_AFTER (stalls to capture, default 2),
STALL_SECONDS (default 20), TEST (default the year-range popover test, where 3 of the 4 stalls hit).
"""

import os
import subprocess
import sys
import threading
import time

UDID = os.environ.get("UDID") or sys.exit("UDID is required")
DERIVED = os.environ.get("DERIVED_DATA") or sys.exit("DERIVED_DATA is required")
OUT = os.path.abspath(os.environ.get("OUT", "stall-watch"))
RUNS = int(os.environ.get("RUNS", "200"))
STOP_AFTER = int(os.environ.get("STOP_AFTER", "2"))
STALL_SECONDS = float(os.environ.get("STALL_SECONDS", "20"))
TEST = os.environ.get("TEST", "FRUSExplorerUITests/KeyboardDismissBarReachTests/"
                              "testDismissBarRendersInTheYearRangePopover")
HERE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)

pending = {"since": None, "dumped": False}
stalls = []


def say(message):
    print(time.strftime("%H:%M:%S"), message, flush=True)


def stream(proc, log):
    for line in proc.stdout:
        log.write(line)
        if "Received request to notify when animations are idle" in line:
            if pending["since"] is None:
                pending["since"], pending["dumped"] = time.time(), False
        elif "Sending animations idle reply" in line:
            if pending["since"] and time.time() - pending["since"] > STALL_SECONDS:
                say("stall ended after %.0fs" % (time.time() - pending["since"]))
            pending["since"] = None


def monitor():
    while True:
        time.sleep(2)
        since = pending["since"]
        if not since or pending["dumped"] or time.time() - since <= STALL_SECONDS:
            continue
        pending["dumped"] = True
        stalls.append(len(stalls) + 1)
        k = stalls[-1]
        pids = subprocess.run(["pgrep", "-f", "%s.*FRUS Explorer.app/FRUS Explorer" % UDID],
                              capture_output=True, text=True).stdout.split()
        if not pids:
            say("stall %d, but no app process found" % k)
            continue
        path = os.path.join(OUT, "dump-stall-%d.txt" % k)
        say("STALL %d: unanswered for %.0fs, dumping pid %s" % (k, time.time() - since, pids[0]))
        subprocess.run(["xcrun", "lldb", "--batch", "-p", pids[0],
                        "-o", "command script import " + os.path.join(HERE, "animdump.py"),
                        "-o", "script animdump.dump(lldb.debugger, '%s')" % path, "-o", "detach"],
                       capture_output=True, text=True, timeout=600)
        subprocess.run(["xcrun", "simctl", "io", UDID, "screenshot",
                        os.path.join(OUT, "stall-%d.png" % k)], capture_output=True)
        say("dumped -> " + path)


def main():
    log = open(os.path.join(OUT, "xctest-log.txt"), "w", buffering=1)
    proc = subprocess.Popen(
        ["xcrun", "simctl", "spawn", UDID, "log", "stream", "--level", "debug", "--style", "compact",
         "--predicate", 'process == "FRUS Explorer" AND subsystem == "com.apple.dt.xctest"'],
        stdout=subprocess.PIPE, text=True)
    threading.Thread(target=stream, args=(proc, log), daemon=True).start()
    threading.Thread(target=monitor, daemon=True).start()
    try:
        for i in range(1, RUNS + 1):
            bundle = os.path.join(OUT, "run-%d.xcresult" % i)
            subprocess.run(["rm", "-rf", bundle])
            result = subprocess.run(
                ["xcodebuild", "test-without-building", "-project", "FRUSExplorer.xcodeproj",
                 "-scheme", "FRUSExplorer", "-destination", "id=" + UDID,
                 "-derivedDataPath", DERIVED, "-only-testing", TEST, "-resultBundlePath", bundle,
                 "-test-timeouts-enabled", "YES", "-maximum-test-execution-time-allowance", "300"],
                capture_output=True, text=True)
            say("run %d exit=%d, stalls so far %d" % (i, result.returncode, len(stalls)))
            if len(stalls) >= STOP_AFTER:
                break
    finally:
        # The first versions of this left `log stream` orphaned under launchd; end it explicitly.
        proc.terminate()
        log.close()
    say("done: %d stall(s) captured in %s" % (len(stalls), OUT))


if __name__ == "__main__":
    main()
