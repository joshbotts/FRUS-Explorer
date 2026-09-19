#!/usr/bin/env python3
"""Loop a UI test and, the moment XCTest stalls waiting for animations, capture why.

The iOS 27 idle stall (Planning/DEVELOPMENT-PLAN.md, sessions "the Corpus Analytics idle stall"
and "the idle stall, caught"; the CLAUDE.md note on `-test-timeouts-enabled`). XCTest's in-app side
logs each wait as a pair, under subsystem `com.apple.dt.xctest` in the APP's process: "Received
request to notify when animations are idle", then "Sending animations idle reply". A stall is a
request with no reply, and the app stays alive throughout, so a request unanswered for
STALL_SECONDS triggers, in order: the app's CPU time over 10 s, a 3 s `sample` (both BEFORE lldb
attaches, since a held process samples as frozen), a simulator screenshot, and `animdump.py`
through lldb. What XCTest is waiting on is a counter, not the layer tree - `animdump.py` explains
it and reads it - so the dump's first line (`XCTEST COUNTER`) is the one that matters. One dump per
app process: once stuck, a process stays stuck, and XCTest's next request is the same stall.

A BASELINE is the same capture at a named step of a passing run: BASELINE_AT is a substring of
xcodebuild's live activity log, dumped at once per run for the first BASELINES runs. The one used
on 2026-09-19 was `Waiting 5.0s for Popover (First Match) to exist`, which prints once the tap on
the year-range chip has been answered idle. lldb holds the app for the 40-120 s a dump takes, so
a baseline run usually FAILS afterwards (its 5 s wait expires); its dump is still the idle state.
Stall detection is paused while any dump holds the app, or the baseline would report itself.

Run it from the repo root with a build already in DERIVED_DATA (`xcodebuild build-for-testing ...
-derivedDataPath <dir>`), somewhere it can run unattended. Several can run at once on different
simulators with different OUT directories; nothing here is shared between them - but four or more
at once drove the load average past 250 on a 10-core machine, so compare arms run side by side.

    UDID=<simulator> DERIVED_DATA=<dir> OUT=<dir> python3 tools/ui-test-stall/watch_stall.py

Env: UDID (required; pin one, several runtimes share a device name), DERIVED_DATA (required),
OUT (default ./stall-watch), RUNS (default 200), STOP_AFTER (stalled processes to capture, default
2), STALL_SECONDS (default 20), TEST (default `FRUSExplorerUITests/YearRangeFieldWidthTests`,
the reproducer: 13 of 221 cases stalled on iOS 27, iPhones about twice as often at its
accessibility text sizes. It launches with view animations OFF since it opted out of the stall,
so to reproduce pass INJECT='(void)[UIView setAnimationsEnabled:YES]', which turns them back on
~2 s after launch - before the Analysis Tools menu and the keyboard, the two triggers; measured,
1 stall in 30 cases that way. `AnalyticsKeyboardTests`, at the default size, ran 28 cases without
one), BASELINE_AT (default the popover line above),
BASELINES (default 0), TRACK (=1 attaches `track_counter.py` to every app process for the whole
run, logging each move of XCTest's counter to track-run-N-pid-P.log, and routes dumps through it.
It slows the app - every counted start and stop is a debugger stop - so read its stall rate as its
own, not as the untracked suite's), INJECT (an Objective-C expression evaluated in each app
process shortly after launch, e.g. `(void)[UIView setAnimationsEnabled:NO]` - how a mitigation is
A/B-tested without a rebuild; it retries until UIKit has loaded, ~2-3 s), LATE_SAMPLES (comma-
separated seconds after a stall's detection at which to repeat the CPU + `sample` capture, e.g.
`180,300`, to see whether a stuck process is still animating once the test has moved on).

Writes to OUT: run-N.log (xcodebuild's live output, one per run), run-N.xcresult, xctest-log.txt
(the app's XCTest log), baseline-N.txt + sample-baseline-N.txt, dump-stall-N.txt + stall-N.png +
sample-stall-N.txt, and summary.txt (one line per run and per stall: the step each stall began at,
and the app's CPU seconds over the 10 s after it was detected).
"""

import os
import signal
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
TEST = os.environ.get("TEST", "FRUSExplorerUITests/YearRangeFieldWidthTests")
BASELINE_AT = os.environ.get("BASELINE_AT", "Waiting 5.0s for Popover (First Match) to exist")
BASELINES = int(os.environ.get("BASELINES", "0"))
TRACK = os.environ.get("TRACK") == "1"
INJECT = os.environ.get("INJECT", "")
LATE_SAMPLES = [int(s) for s in os.environ.get("LATE_SAMPLES", "").split(",") if s.strip()]
HERE = os.path.dirname(os.path.abspath(__file__))
XCODE_PYTHON = "/Applications/Xcode.app/Contents/Developer/usr/bin/python3"
os.makedirs(OUT, exist_ok=True)

state = {"since": None, "dumped": False, "step": "", "request_step": "", "holding": False,
         "run": 0, "baselines": 0, "baseline_run": 0}
stalls = []
trackers = {}  # app pid -> the tracker's log path (TRACK mode)
dumped_pids = set()
lock = threading.Lock()
summary = open(os.path.join(OUT, "summary.txt"), "a", buffering=1)


def say(message):
    line = time.strftime("%H:%M:%S ") + message
    print(line, flush=True)
    summary.write(line + "\n")


def app_pid():
    """The app process on this simulator - the NEWEST, since a killed run can leave an old one
    beside it for a while (seen twice), and the first match then measured the wrong process."""
    pids = subprocess.run(["pgrep", "-f", "%s.*FRUS Explorer.app/FRUS Explorer" % UDID],
                          capture_output=True, text=True).stdout.split()
    return max(pids, key=int) if pids else None


def cpu_seconds(pid, seconds=10.0):
    """CPU time (user + system) the app used over `seconds`, from `ps` - the battery question.

    A stalled app that is really animating spends CPU every frame; one whose only fault is
    XCTest's counter spends what an idle app does. Read against the same measure at a baseline."""
    def total():
        out = subprocess.run(["ps", "-o", "time=", "-p", pid],
                             capture_output=True, text=True).stdout
        parts = out.strip().replace("-", ":").split(":")
        try:
            return sum(float(v) * 60 ** i for i, v in enumerate(reversed(parts)))
        except ValueError:
            return None
    before = total()
    time.sleep(seconds)
    after = total()
    return None if before is None or after is None else after - before


def animdump(pid, path):
    """Dump the app's animations to `path`. Stall detection is paused for the duration: lldb holds
    the app, so every request made meanwhile goes unanswered for a reason that is ours.

    In TRACK mode the app already has a debugger - the tracker - and a second cannot attach, so
    the dump is requested from the tracker, which appends its per-state ledger."""
    with lock:
        state["holding"] = True
    try:
        if TRACK and pid in trackers:
            with open(trackers[pid] + ".dump-request", "w") as handle:
                handle.write(path)
            deadline = time.time() + 600
            while time.time() < deadline and os.path.exists(trackers[pid] + ".dump-request"):
                time.sleep(1)
            while time.time() < deadline and "TRACKER LEDGER" not in (
                    open(path).read() if os.path.exists(path) else ""):
                time.sleep(1)
            return
        result = subprocess.run(
            ["xcrun", "lldb", "--batch", "-p", pid,
             "-o", "command script import " + os.path.join(HERE, "animdump.py"),
             "-o", "script animdump.dump(lldb.debugger, '%s')" % path, "-o", "detach"],
            capture_output=True, text=True, timeout=600)
        if not os.path.exists(path):
            with open(path, "w") as handle:
                handle.write("NO DUMP WRITTEN; lldb said:\n" + result.stdout + result.stderr)
    finally:
        with lock:
            state["holding"] = False
            state["since"] = None


def track_launches(run, done):
    """Act on each app process the run launches (one per case): TRACK attaches
    `track_counter.py`; INJECT evaluates one Objective-C expression through a short lldb attach,
    which is how a candidate mitigation is A/B-tested without rebuilding the app."""
    lldb_path = subprocess.run(["xcrun", "lldb", "-P"],
                               capture_output=True, text=True).stdout.strip()
    env = dict(os.environ, PYTHONPATH=lldb_path)
    seen = set()
    while not done.is_set():
        pid = app_pid()
        if pid and pid not in seen:
            seen.add(pid)
            if INJECT:
                # The process appears before UIKit is loaded, and an expression naming a UIKit
                # class fails until it is, so retry for a few seconds rather than once.
                for attempt in range(10):
                    result = subprocess.run(["xcrun", "lldb", "--batch", "-p", pid,
                                             "-o", "expr -l objc -- " + INJECT, "-o", "detach"],
                                            capture_output=True, text=True, timeout=120)
                    if "error:" not in result.stdout + result.stderr:
                        break
                    time.sleep(0.5)
                failed = "error:" in result.stdout + result.stderr
                say("injected into pid %s: %s (attempt %d)" % (
                    pid, "FAILED" if failed else "ok", attempt + 1))
            if TRACK:
                path = os.path.join(OUT, "track-run-%d-pid-%s.log" % (run, pid))
                trackers[pid] = path
                subprocess.Popen([XCODE_PYTHON, os.path.join(HERE, "track_counter.py"), pid, path],
                                 env=env, stdout=subprocess.DEVNULL,
                                 stderr=open(path + ".err", "w"))
        time.sleep(0.3)


def stream_app_log(proc, log):
    for line in proc.stdout:
        log.write(line)
        with lock:
            if "Received request to notify when animations are idle" in line:
                if state["since"] is None and not state["holding"]:
                    state["since"], state["dumped"] = time.time(), False
                    state["request_step"] = state["step"]
            elif "Sending animations idle reply" in line:
                if state["since"] and time.time() - state["since"] > STALL_SECONDS:
                    say("stall ended after %.0fs" % (time.time() - state["since"]))
                state["since"] = None


def monitor():
    while True:
        time.sleep(2)
        with lock:
            since = state["since"]
            if (not since or state["dumped"] or state["holding"]
                    or time.time() - since <= STALL_SECONDS):
                continue
            state["dumped"] = True
            stalls.append(len(stalls) + 1)
            k, step, run = stalls[-1], state["request_step"], state["run"]
        pid = app_pid()
        if not pid:
            say("stall %d (run %d), but no app process found" % (k, run))
            continue
        # Once stuck, a case stays stuck: XCTest re-asks before every later action and each ask
        # runs its full 60 s. One dump per process; the rest are the same stall, not new ones.
        if pid in dumped_pids:
            stalls.pop()
            say("still stalled (pid %s), at [%s]" % (pid, step))
            continue
        dumped_pids.add(pid)
        say("STALL %d in run %d: unanswered for %.0fs, began at [%s]; pid %s"
            % (k, run, time.time() - since, step, pid))
        say("stall %d: app CPU %s s over the next 10 s" % (k, cpu_seconds(pid)))
        # What the main thread does while XCTest waits, sampled BEFORE lldb attaches: a sample of
        # a process a debugger holds shows every thread frozen mid-instruction and means nothing.
        subprocess.run(["sample", pid, "3", "-file", os.path.join(OUT, "sample-stall-%d.txt" % k)],
                       capture_output=True)
        path = os.path.join(OUT, "dump-stall-%d.txt" % k)
        subprocess.run(["xcrun", "simctl", "io", UDID, "screenshot",
                        os.path.join(OUT, "stall-%d.png" % k)], capture_output=True)
        animdump(pid, path)
        say("dumped -> " + path)
        if LATE_SAMPLES:
            threading.Thread(target=late_samples, args=(k, pid, since), daemon=True).start()


def late_samples(k, pid, since):
    """Is the stalled process still animating later, on whatever screen the test has reached?

    XCTest keeps idle-waiting 60 s before each action of a stuck case, so a sample taken during
    one of those waits shows the app's own activity, not the test's."""
    for offset in LATE_SAMPLES:
        time.sleep(max(0.0, since + offset - time.time()))
        if subprocess.run(["ps", "-p", pid], capture_output=True).returncode != 0:
            say("stall %d: process gone before +%ds" % (k, offset))
            return
        step = state["step"]
        cpu = cpu_seconds(pid)
        path = os.path.join(OUT, "sample-stall-%d-late-%d.txt" % (k, offset))
        subprocess.run(["sample", pid, "3", "-file", path], capture_output=True)
        say("stall %d at +%ds: app CPU %s s over 10 s, at [%s]" % (k, offset, cpu, step))


def run_once(i):
    bundle = os.path.join(OUT, "run-%d.xcresult" % i)
    subprocess.run(["rm", "-rf", bundle])
    with lock:
        state["run"], state["step"] = i, ""
    proc = subprocess.Popen(
        ["xcodebuild", "test-without-building", "-project", "FRUSExplorer.xcodeproj",
         "-scheme", "FRUSExplorer", "-destination", "id=" + UDID,
         "-derivedDataPath", DERIVED, "-only-testing", TEST, "-resultBundlePath", bundle,
         "-test-timeouts-enabled", "YES", "-maximum-test-execution-time-allowance", "300"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    state["xcodebuild"] = proc
    executed = ""
    done = threading.Event()
    if TRACK or INJECT:
        threading.Thread(target=track_launches, args=(i, done), daemon=True).start()
    with open(os.path.join(OUT, "run-%d.log" % i), "w", buffering=1) as log:
        for line in proc.stdout:
            log.write(time.strftime("%H:%M:%S ") + line)
            if " t = " in line:
                with lock:
                    state["step"] = line.strip()
            if line.lstrip().startswith("Executed "):
                executed = line.strip()
            if (BASELINE_AT and BASELINE_AT in line and state["baselines"] < BASELINES
                    and state["baseline_run"] != i):
                pid = app_pid()
                if pid:
                    state["baselines"] += 1
                    state["baseline_run"] = i
                    path = os.path.join(OUT, "baseline-%d.txt" % state["baselines"])
                    say("baseline %d in run %d at [%s]" % (state["baselines"], i, line.strip()))
                    say("baseline %d: app CPU %s s over the next 10 s" % (
                        state["baselines"], cpu_seconds(pid)))
                    subprocess.run(["sample", pid, "3", "-file", os.path.join(
                        OUT, "sample-baseline-%d.txt" % state["baselines"])], capture_output=True)
                    animdump(pid, path)
                    say("dumped -> " + path)
    proc.wait()
    done.set()
    return proc.returncode, executed


def main():
    log = open(os.path.join(OUT, "xctest-log.txt"), "a", buffering=1)
    proc = subprocess.Popen(
        ["xcrun", "simctl", "spawn", UDID, "log", "stream", "--level", "debug", "--style", "compact",
         "--predicate", 'process == "FRUS Explorer" AND subsystem == "com.apple.dt.xctest"'],
        stdout=subprocess.PIPE, text=True)
    threading.Thread(target=stream_app_log, args=(proc, log), daemon=True).start()
    threading.Thread(target=monitor, daemon=True).start()
    say("watching %s on %s, TEST=%s" % (OUT, UDID, TEST))
    try:
        for i in range(1, RUNS + 1):
            code, executed = run_once(i)
            say("run %d exit=%d [%s] stalls so far %d%s" % (
                i, code, executed or "no 'Executed' line", len(stalls),
                " (baseline run)" if state["baseline_run"] == i else ""))
            if len(stalls) >= STOP_AFTER:
                break
    finally:
        # The first versions of this left `log stream` orphaned under launchd; end it explicitly.
        # The same for xcodebuild: a watcher killed mid-run otherwise leaves its test run going,
        # and the next watcher on that simulator races it for the device.
        proc.terminate()
        if state.get("xcodebuild") and state["xcodebuild"].poll() is None:
            state["xcodebuild"].terminate()
        log.close()
    say("done: %d stall(s) captured in %s" % (len(stalls), OUT))


if __name__ == "__main__":
    # SIGTERM (a plain `kill`) must run main's `finally` too, or xcodebuild is orphaned.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    main()
