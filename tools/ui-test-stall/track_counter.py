#!/usr/bin/env python3
"""Log every change to XCTest's in-app animation counter in one app process, from lldb.

The Corpus Analytics UI-test stall (Planning/DEVELOPMENT-PLAN.md): XCTest answers "notify when
animations are idle" from ONE process-wide counter, +1 in its swizzle of
`-[UIViewAnimationState animationDidStart:]` and -1 in its swizzle of
`animationDidStop:finished:` (see `animdump.py`). Stall dumps showed that counter stuck at 1, 2 and
11 while a memory scan found NO unstopped `UIViewAnimationState` of any class: UIKit had finished
every animation, and XCTest's count had drifted. A snapshot cannot say which calls drifted; this
records them as they happen.

It attaches to PID, breaks on XCTest's own two replacement functions (`XCTAnimationDidStart`,
`XCTAnimationDidStop` in XCTAutomationSupport - the exact code that moves the counter), and on
UIKit's `sendDelegateAnimationDidStop:finished:`, the point where UIKit itself considers a state
finished. Each hit writes one line to LOG with the counter as XCTest holds it (read from memory,
not reconstructed), the state and its class, the CAAnimation and its class, and a backtrace for
the counter moves; then the process continues. Every stop is a real stop, so the app runs slower
while tracked - several ms per animation event.

Only one debugger can attach to a process, so this also serves `watch_stall.py`'s dumps in TRACK
mode: when the file LOG + ".dump-request" appears, holding an output path, the process is stopped,
`animdump.dump` writes there followed by this tracker's per-state ledger, and the process resumes.

    PYTHONPATH=$(xcrun lldb -P) /Applications/Xcode.app/Contents/Developer/usr/bin/python3 \\
        tools/ui-test-stall/track_counter.py <pid> <log>

Must run under Xcode's python3 (the lldb module is built for it), which `watch_stall.py` does.
"""

import os
import sys
import time

import lldb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import animdump  # noqa: E402  (after the path insert, on purpose)

ISA_MASK = 0x0000000FFFFFFFF8


def main():
    pid, log_path = int(sys.argv[1]), sys.argv[2]
    request = log_path + ".dump-request"
    log = open(log_path, "a", buffering=1)
    debugger = lldb.SBDebugger.Create()
    debugger.SetAsync(True)
    target = debugger.CreateTarget("")
    listener = debugger.GetListener()
    error = lldb.SBError()
    process = target.AttachToProcessWithID(listener, pid, error)
    if error.Fail():
        log.write("ATTACH FAILED %s\n" % error.GetCString())
        return
    wait_for(listener, process, lldb.eStateStopped)
    started = time.time()

    points = {}
    for name, kind in (("XCTAnimationDidStart", "+"), ("XCTAnimationDidStop", "-"),
                       ("-[UIViewAnimationState sendDelegateAnimationDidStop:finished:]",
                        "UIKIT-DONE")):
        bp = target.BreakpointCreateByName(name)
        points[bp.GetID()] = kind
        log.write("BREAKPOINT %s -> %d locations\n" % (name, bp.GetNumLocations()))

    names, counter_address = {}, [None]
    ledger = {}  # state -> {"class", "+", "-", "done", "first"}

    def frame0():
        return process.GetSelectedThread().GetFrameAtIndex(0)

    def class_name(obj):
        if not obj:
            return "nil"
        err = lldb.SBError()
        isa = process.ReadPointerFromMemory(obj, err) & ISA_MASK
        if err.Fail():
            return "?"
        if isa not in names:
            value = frame0().EvaluateExpression("(const char *)class_getName((Class)0x%x)" % isa)
            names[isa] = (value.GetSummary() or "?").strip('"')
        return names[isa]

    def counter():
        if counter_address[0] is None:
            value, where = animdump.xctest_counter(target, process)
            if value is None:
                return "?"
            counter_address[0] = int(where.split()[-1], 16)
        err = lldb.SBError()
        raw = process.ReadUnsignedFromMemory(counter_address[0], 4, err)
        return "?" if err.Fail() else str(raw - (1 << 32) if raw & (1 << 31) else raw)

    def backtrace(thread, depth):
        frames = []
        for i in range(1, min(depth + 1, thread.GetNumFrames())):
            f = thread.GetFrameAtIndex(i)
            frames.append(f.GetFunctionName() or f.GetSymbol().GetName() or hex(f.GetPC()))
        return " < ".join(frames)

    log.write("ATTACHED pid %d, XCTest counter %s\n" % (pid, counter()))

    def on_stop():
        for thread in process:
            if thread.GetStopReason() != lldb.eStopReasonBreakpoint:
                continue
            kind = points.get(thread.GetStopReasonDataAtIndex(0))
            if kind is None:
                continue
            frame = thread.GetFrameAtIndex(0)
            reg = lambda r: frame.FindRegister(r).GetValueAsUnsigned()  # noqa: E731
            state, anim = reg("x0"), reg("x2")
            entry = ledger.setdefault(state, {"class": class_name(state), "+": 0, "-": 0,
                                              "done": 0, "first": ""})
            stamp = "%.3f" % (time.time() - started)
            if kind == "UIKIT-DONE":
                entry["done"] += 1
                log.write("%s UIKIT-DONE state=0x%x %s finished=%d  xct+%d-%d  counter=%s\n" % (
                    stamp, state, entry["class"], reg("x3") & 1, entry["+"], entry["-"], counter()))
                continue
            entry[kind] += 1
            trace = backtrace(thread, 40 if kind == "+" else 8)
            if kind == "+" and not entry["first"]:
                entry["first"] = trace
            # The counter is read BEFORE XCTest's function runs (we stop on its first instruction).
            log.write("%s %s state=0x%x %s anim=0x%x %s%s counter-before=%s\n    %s\n" % (
                stamp, kind, state, entry["class"], anim, class_name(anim),
                " finished=%d" % (reg("x3") & 1) if kind == "-" else "", counter(), trace))

    def serve_dump():
        with open(request) as handle:
            out = handle.read().strip()
        os.remove(request)
        # Wait for the stop EVENT, not `process.GetState()`: in async mode the public state can
        # still read "stopped" from before the last Continue(), and a dump then fails with
        # "can't evaluate expressions when the process is running" (measured, twice). The stop
        # that arrives may be a breakpoint hit rather than the interrupt; log it like any other.
        process.Stop()
        stopped, deadline = lldb.SBEvent(), time.time() + 60
        while time.time() < deadline:
            if (listener.WaitForEvent(1, stopped) and lldb.SBProcess.EventIsProcessEvent(stopped)
                    and lldb.SBProcess.GetStateFromEvent(stopped) == lldb.eStateStopped
                    and not lldb.SBProcess.GetRestartedFromEvent(stopped)):
                on_stop()
                break
        animdump.dump(debugger, out)
        with open(out, "a") as handle:
            handle.write("\nTRACKER LEDGER (pid %d, tracked %.0fs): states whose XCTest starts "
                         "and stops differ\n" % (pid, time.time() - started))
            for state, e in sorted(ledger.items()):
                if e["+"] != e["-"]:
                    handle.write("  0x%x %s  xct+%d -%d  uikit-done %d\n    first start: %s\n" % (
                        state, e["class"], e["+"], e["-"], e["done"], e["first"]))
            handle.write("  (%d states seen)\n" % len(ledger))
        log.write("DUMP -> %s\n" % out)

    process.Continue()
    event = lldb.SBEvent()
    while True:
        if os.path.exists(request):
            serve_dump()
            process.Continue()
        if not listener.WaitForEvent(1, event):
            continue
        if not lldb.SBProcess.EventIsProcessEvent(event):
            continue
        state = lldb.SBProcess.GetStateFromEvent(event)
        if state == lldb.eStateStopped and not lldb.SBProcess.GetRestartedFromEvent(event):
            on_stop()
            process.Continue()
        elif state in (lldb.eStateExited, lldb.eStateDetached, lldb.eStateCrashed):
            log.write("PROCESS %s\n" % lldb.SBDebugger.StateAsCString(state))
            break
    log.close()


def wait_for(listener, process, wanted, seconds=60):
    """Block until `process` reports `wanted` (attach and Stop are asynchronous here)."""
    event = lldb.SBEvent()
    deadline = time.time() + seconds
    while time.time() < deadline:
        if process.GetState() == wanted:
            return
        listener.WaitForEvent(1, event)


if __name__ == "__main__":
    main()
