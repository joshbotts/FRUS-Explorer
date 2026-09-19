"""List every Core Animation animation live in a running app, from lldb.

Written for the Corpus Analytics UI-test stall (Planning/DEVELOPMENT-PLAN.md, session "the Corpus
Analytics idle stall"): XCTest waits for the app's animations to finish before every action, and in
a stall that wait runs its full 60 s while the app's main thread is idle. The question is WHICH
animation XCTest is waiting on, and only the live layer tree can answer it.

    xcrun lldb --batch -p <pid> \
        -o "command script import tools/ui-test-stall/animdump.py" \
        -o "script animdump.dump(lldb.debugger, '/tmp/anims.txt')" \
        -o detach

One small expression per layer, through the SB API, on purpose. A single recursive Objective-C
block expression is the obvious shape and does not work here: lldb cannot call variadic methods
(`appendFormat:`) without their signatures, resolves `delegate`/`sublayers` ambiguously across
UIKit and QuartzCore, and a failed compile in `--batch` prints only notes and no error. Properties
are read through `valueForKey:` for the same reason. A walk of ~260 layers takes ~13 s.

READ THE BASELINE BEFORE THE STALL. An idle Browse screen on iOS 27 already carries
infinite-duration `CAMatchMoveAnimation` / `CAMatchPropertyAnimation` entries on the Liquid Glass
tab bar (`_UILiquidLensView`, `UISDFElementView`), and XCTest treats that screen as idle, so those
are not the answer. The answer is whatever a stall dump has that a baseline dump does not.
"""

import time

import lldb


def dump(debugger, out_path):
    """Walk every window's layer tree and write each animating layer and its animations."""
    frame = debugger.GetSelectedTarget().GetProcess().GetThreadAtIndex(0).GetFrameAtIndex(0)
    opts = lldb.SBExpressionOptions()
    opts.SetLanguage(lldb.eLanguageTypeObjC_plus_plus)
    opts.SetIgnoreBreakpoints(True)
    opts.SetTimeoutInMicroSeconds(5_000_000)
    opts.SetTryAllThreads(True)

    def ev(expr):
        value = frame.EvaluateExpression(expr, opts)
        if value.GetError().Fail():
            raise RuntimeError(expr + " -> " + value.GetError().GetCString())
        return value

    def u(expr):
        return ev(expr).GetValueAsUnsigned()

    def s(expr):
        return ev("(NSString *)(" + expr + ")").GetObjectDescription() or ""

    lines, count = [], [0]

    def walk(addr, path, depth):
        if depth > 80:
            return
        count[0] += 1
        delegate = u('(id)[(id)0x%x valueForKey:@"delegate"]' % addr)
        name = s("NSStringFromClass((Class)[(id)0x%x class])" % (delegate or addr))
        here = path + "/" + name
        keys = u("(id)[(id)0x%x animationKeys]" % addr)
        if keys:
            for i in range(u("(unsigned long)[(id)0x%x count]" % keys)):
                key = u("(id)[(id)0x%x objectAtIndex:%d]" % (keys, i))
                anim = u("(id)[(id)0x%x animationForKey:(id)0x%x]" % (addr, key))
                lines.append("ANIM %s\n    key=%s class=%s dur=%s repeat=%s beginTime=%s\n" % (
                    "/".join(here.split("/")[-4:]),
                    s("(id)0x%x" % key),
                    s("NSStringFromClass((Class)[(id)0x%x class])" % anim),
                    s('[[(id)0x%x valueForKey:@"duration"] description]' % anim),
                    s('[[(id)0x%x valueForKey:@"repeatCount"] description]' % anim),
                    s('[[(id)0x%x valueForKey:@"beginTime"] description]' % anim)))
        subs = u('(id)[(id)0x%x valueForKey:@"sublayers"]' % addr)
        if subs:
            for i in range(u("(unsigned long)[(id)0x%x count]" % subs)):
                walk(u("(id)[(id)0x%x objectAtIndex:%d]" % (subs, i)), here, depth + 1)

    started = time.time()
    # `connectedScenes` is an NSSet, so the union is too: `allObjects` before `objectAtIndex:`.
    windows = u('(id)[(id)[(id)[UIApplication sharedApplication] '
                'valueForKeyPath:@"connectedScenes.@distinctUnionOfArrays.windows"] allObjects]')
    for i in range(u("(unsigned long)[(id)0x%x count]" % windows)):
        window = u("(id)[(id)0x%x objectAtIndex:%d]" % (windows, i))
        lines.append("WINDOW %s\n" % s("NSStringFromClass((Class)[(id)0x%x class])" % window))
        walk(u('(id)[(id)0x%x valueForKey:@"layer"]' % window), "", 0)
    lines.append("layers walked: %d in %.1fs\n" % (count[0], time.time() - started))
    with open(out_path, "w") as handle:
        handle.write("".join(lines))


def __lldb_init_module(debugger, internal_dict):
    """lldb entry point; `dump` is called explicitly through `script`."""
