"""List what XCTest's animation-idle wait is counting in a running app, from lldb.

Written for the Corpus Analytics UI-test stall (Planning/DEVELOPMENT-PLAN.md, session "the Corpus
Analytics idle stall"): XCTest waits for the app's animations to finish before every action, and in
a stall that wait runs its full 60 s while the app's main thread is idle.

    xcrun lldb --batch -p <pid> \
        -o "command script import tools/ui-test-stall/animdump.py" \
        -o "script animdump.dump(lldb.debugger, '/tmp/anims.txt')" \
        -o detach

WHAT XCTEST ACTUALLY WAITS ON (read from XCTAutomationSupport, Xcode 27.0): not the layer tree.
`XCTAnimationsIdleNotifier` swizzles `-[UIViewAnimationState animationDidStart:]` and
`-[UIViewAnimationState animationDidStop:finished:]` and keeps ONE process-wide counter, +1 and -1;
a "notify when idle" request is answered when that counter falls to zero. So only animations whose
Core Animation delegate is a `UIViewAnimationState` (UIKit's `+[UIView animate…]` family) can hold
XCTest up, and a stall is a counter left above zero: an animation that reported starting and never
reported stopping. That is why the infinite Liquid Glass `CAMatchMoveAnimation` entries on an idle
iOS 27 screen do not stall anything - their delegate is not a `UIViewAnimationState`.

What the stalls turned out to be (2026-09-19, `track_counter.py`): not a running animation but a
drifted count. On iOS 27 the in-process animation engine (AnimationKit) reports starts it never
stops, and Core Animation reports one interrupted spring's start twice; UIKit finishes every
animation, XCTest's counter keeps the difference, and every later wait in that launch runs 60 s.

So the dump has three parts, each answering a narrower question than the one before:
  1. XCTEST COUNTER - the counter itself, decoded from `+[XCTAnimationsIdleNotifier
     isAnimationInProgress]` (`adrp; add; ldar`). Zero on a passing run's idle screen; the number
     of unbalanced starts in a stall.
  2. ANIM lines - every animation on every layer of every window, with its delegate class. Any
     line whose delegate is in `COUNTED_DELEGATES` is one the counter includes.
  3. STATE - every `UIViewAnimationState` that has not sent its stop, found by scanning memory
     rather than the layer tree (`unstopped_states`), with its ivars, its block delegate's, and the
     symbol behind each block, which names the code that started the animation. The layer walk
     alone is not enough: the first stall caught (2026-09-19) had a counter of 1 and NO counted
     animation on any layer, identical to the baseline everywhere else.

One small expression per layer, through the SB API, on purpose. A single recursive Objective-C
block expression is the obvious shape and does not work here: lldb cannot call variadic methods
(`appendFormat:`) without their signatures, resolves `delegate`/`sublayers` ambiguously across
UIKit and QuartzCore, and a failed compile in `--batch` prints only notes and no error. Properties
are read through `valueForKey:` for the same reason. A walk takes time: 336-545 layers in
37-121 s on 2026-09-19 (a Corpus Analytics screen, several simulators running), so a dump holds the
app long enough for the test step it interrupts to fail.

READ THE BASELINE BEFORE THE STALL. Take one on a passing run at the same step (`watch_stall.py`'s
BASELINE_AT) and diff: the answer is whatever the stall dump has that the baseline does not.
"""

import re
import struct
import time

import lldb

# The classes whose `animationDidStart:` / `animationDidStop:finished:` XCTest counts: the base
# class it swizzles and, on iOS 27, the three subclasses that inherit both methods unchanged.
COUNTED_DELEGATES = {"UIViewAnimationState", "UIViewSpringAnimationState",
                     "UIViewKeyframeAnimationState", "UIKit.UIViewInProcessAnimationState"}


def xctest_counter(target, process):
    """XCTest's in-app animation counter, or None with a reason when it cannot be located.

    `+[XCTAnimationsIdleNotifier isAnimationInProgress]` is `adrp x8, page; add x8, x8, #off;
    ldar w8, [x8]; cmp w8, #0; cset w0, gt; ret`, so the counter's address is decoded from its first
    two instructions rather than from a hard-coded offset that the next Xcode would move."""
    symbols = target.FindSymbols("+[XCTAnimationsIdleNotifier isAnimationInProgress]")
    if symbols.GetSize() != 1:
        return None, "isAnimationInProgress found %d times" % symbols.GetSize()
    start = symbols.GetContextAtIndex(0).GetSymbol().GetStartAddress().GetLoadAddress(target)
    error = lldb.SBError()
    raw = process.ReadMemory(start, 8, error)
    if error.Fail():
        return None, "could not read isAnimationInProgress: %s" % error.GetCString()
    adrp, add = struct.unpack("<II", raw)
    if adrp & 0x9F000000 != 0x90000000 or add & 0xFFC00000 != 0x91000000:
        return None, ("isAnimationInProgress no longer opens with adrp/add (0x%08x 0x%08x)"
                      % (adrp, add))
    imm = (((adrp >> 5) & 0x7FFFF) << 2) | ((adrp >> 29) & 3)
    if imm & (1 << 20):
        imm -= 1 << 21
    address = (start & ~0xFFF) + (imm << 12) + ((add >> 10) & 0xFFF)
    value = process.ReadMemory(address, 4, error)
    if error.Fail():
        return None, "could not read the counter at 0x%x: %s" % (address, error.GetCString())
    return struct.unpack("<i", value)[0], "at 0x%x" % address



def unstopped_states(process, u):
    """Every `UIViewAnimationState` (or subclass) that has not sent its stop, by scanning memory.

    A state retains ITSELF (`_retainedSelf`) from the moment its animation starts until it sends
    `animationDidStop`, so an unstopped one stays allocated even when no layer holds its animation
    any more - which is exactly the case the layer walk cannot see. The heap cannot be enumerated
    here (lldb's `objc_refs` finds nothing in this process, not even `UIWindow`, and `heap(1)`
    aborts on the AttributeGraph malloc zone), so this reads every writable region and keeps each
    8-byte-aligned word whose isa bits name the class or one of its subclasses - on iOS 27
    `UIViewSpringAnimationState`, `UIViewKeyframeAnimationState` and the Swift
    `UIKit.UIViewInProcessAnimationState`, which a base-class-only scan misses and which carry most
    presentation animations. Liveness comes from the candidate's own ivars, read as memory rather
    than messaged: `_retainedSelf == self` and `_animationDidStopSent == NO`. That test, not
    `malloc_size`, is the one that holds: a finished state's memory still reports a size and still
    reads as its class, but its `_retainedSelf` is nil and its stop flag YES (measured).

    Verified on a live base-class and a live spring state (both found, both gone once stopped).
    NOT verified for `UIViewInProcessAnimationState`: in every tracked stall its leaked states read
    as stopped here, which fits the tracker's finding that UIKit had finished them while XCTest's
    count had not - but no live in-process state was ever caught to prove the test sees one."""
    base = u('(unsigned long)NSClassFromString(@"UIViewAnimationState")')
    if not base:
        return [], "UIViewAnimationState is not a class in this process"
    classes = [base] + [u('(unsigned long)NSClassFromString(@"%s")' % name) for name in (
        "UIViewSpringAnimationState", "UIViewKeyframeAnimationState",
        "UIKit.UIViewInProcessAnimationState")]
    classes = [c for c in classes if c]

    def offset(ivar):
        return u('(long)((long (*)(void *))ivar_getOffset)(((void * (*)(void *, const char *))'
                 'class_getInstanceVariable)((void *)0x%x, "%s"))' % (base, ivar))

    own, sent = offset("_retainedSelf"), offset("_animationDidStopSent")
    if not own or not sent:
        return [], "UIViewAnimationState has no _retainedSelf/_animationDidStopSent ivar any more"
    # Non-pointer isa: bits 3..35 are the class address, the low three bits flags. So bytes 1..3
    # match the class exactly, and byte 0 and the low nibble of byte 4 match under a mask.
    keys = {struct.pack("<Q", c)[1:4]: c for c in classes}
    pattern = re.compile(b"(?=(" + b"|".join(re.escape(k) for k in keys) + b"))", re.DOTALL)
    matches, unstopped, scanned, started = 0, [], 0, time.time()
    regions, info = process.GetMemoryRegions(), lldb.SBMemoryRegionInfo()
    for index in range(regions.GetSize()):
        regions.GetMemoryRegionAtIndex(index, info)
        if not (info.IsReadable() and info.IsWritable() and info.IsMapped()) or info.IsExecutable():
            continue
        base_address, end = info.GetRegionBase(), info.GetRegionEnd()
        if end - base_address > (1 << 30):
            continue
        for chunk in range(base_address, end, 1 << 22):
            error = lldb.SBError()
            data = process.ReadMemory(chunk, min(1 << 22, end - chunk), error)
            if error.Fail() or not data:
                continue
            scanned += len(data)
            for found in pattern.finditer(data):
                word = found.start() - 1
                cls = keys[found.group(1)]
                if (word < 0 or word % 8 or word + 8 > len(data)
                        or data[word] & 0xF8 != cls & 0xF8
                        or data[word + 4] & 0x0F != (cls >> 32) & 0x0F):
                    continue
                matches += 1
                address = chunk + word
                error = lldb.SBError()
                retained = process.ReadPointerFromMemory(address + own, error)
                flag = process.ReadUnsignedFromMemory(address + sent, 1, error)
                if error.Success() and retained == address and flag == 0:
                    unstopped.append(address)
    return unstopped, "%d unstopped of %d isa matches over %d classes, %.0f MB scanned in %.1fs" % (
        len(unstopped), matches, len(classes), scanned / 1e6, time.time() - started)

def dump(debugger, out_path):
    """Write the XCTest counter, every live animation, and every unstopped UIViewAnimationState."""
    target = debugger.GetSelectedTarget()
    process = target.GetProcess()
    frame = process.GetThreadAtIndex(0).GetFrameAtIndex(0)
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

    def cls(addr):
        return s("NSStringFromClass((Class)[(id)0x%x class])" % addr) if addr else "nil"

    def symbol_at(pointer):
        address = target.ResolveLoadAddress(pointer)
        name = address.GetSymbol().GetName()
        module = address.GetModule().GetFileSpec().GetFilename()
        return "%s (%s)" % (name, module) if name else "0x%x" % pointer

    lines, count, states = [], [0], {}
    started = time.time()

    counter, where = xctest_counter(target, process)
    lines.append("XCTEST COUNTER %s  (%s)\n" % ("unknown" if counter is None else counter, where))
    # Cross-check through XCTest's own accessor. Messaging a nil class answers 0, which would read
    # as "idle" in an app XCTest never loaded into, so the class is looked up first.
    notifier = u('(Class)NSClassFromString(@"XCTAnimationsIdleNotifier")')
    if notifier:
        busy = u("(BOOL)[(Class)0x%x isAnimationInProgress]" % notifier)
        lines.append("XCTEST isAnimationInProgress %d\n" % busy)
    else:
        lines.append("XCTEST not loaded (no XCTAnimationsIdleNotifier): not a UI-test launch\n")
    lines.append("CACurrentMediaTime %.3f\n" % float(ev("(double)CACurrentMediaTime()").GetValue()))

    def walk(addr, path, depth):
        if depth > 80:
            return
        count[0] += 1
        delegate = u('(id)[(id)0x%x valueForKey:@"delegate"]' % addr)
        here = path + "/" + cls(delegate or addr)
        keys = u("(id)[(id)0x%x animationKeys]" % addr)
        if keys:
            for i in range(u("(unsigned long)[(id)0x%x count]" % keys)):
                key = u("(id)[(id)0x%x objectAtIndex:%d]" % (keys, i))
                anim = u("(id)[(id)0x%x animationForKey:(id)0x%x]" % (addr, key))
                anim_delegate = u('(id)[(id)0x%x valueForKey:@"delegate"]' % anim)
                delegate_class = cls(anim_delegate)
                timing = ""
                if delegate_class in COUNTED_DELEGATES:
                    states.setdefault(anim_delegate, []).append("/".join(here.split("/")[-4:]))
                    # A counted animation is either still inside its active time (a layer or an
                    # ancestor with `speed` 0 freezes it there), or past it and never reported
                    # stopped. The layer's LOCAL time - every ancestor's speed and offset applied -
                    # against beginTime + duration says which.
                    local = float(ev("((double (*)(id, SEL, double, id))objc_msgSend)((id)0x%x, "
                                     "@selector(convertTime:fromLayer:), "
                                     "(double)CACurrentMediaTime(), (id)0)" % addr).GetValue())
                    timing = (" layerLocalTime=%.3f layerSpeed=%s removedOnCompletion=%s"
                              " fillMode=%s") % (
                        local,
                        s('[[(id)0x%x valueForKey:@"speed"] description]' % addr),
                        s('[[(id)0x%x valueForKey:@"removedOnCompletion"] description]' % anim),
                        s('(id)[(id)0x%x valueForKey:@"fillMode"]' % anim))
                lines.append("ANIM %s\n    key=%s class=%s delegate=%s%s dur=%s repeat=%s "
                             "beginTime=%s%s\n" % (
                                 "/".join(here.split("/")[-4:]),
                                 s("(id)0x%x" % key),
                                 cls(anim),
                                 delegate_class,
                                 "@0x%x" % anim_delegate if anim_delegate else "",
                                 s('[[(id)0x%x valueForKey:@"duration"] description]' % anim),
                                 s('[[(id)0x%x valueForKey:@"repeatCount"] description]' % anim),
                                 s('[[(id)0x%x valueForKey:@"beginTime"] description]' % anim),
                                 timing))
        subs = u('(id)[(id)0x%x valueForKey:@"sublayers"]' % addr)
        if subs:
            for i in range(u("(unsigned long)[(id)0x%x count]" % subs)):
                walk(u("(id)[(id)0x%x objectAtIndex:%d]" % (subs, i)), here, depth + 1)

    # `connectedScenes` is an NSSet, so the union is too: `allObjects` before `objectAtIndex:`.
    windows = u('(id)[(id)[(id)[UIApplication sharedApplication] '
                'valueForKeyPath:@"connectedScenes.@distinctUnionOfArrays.windows"] allObjects]')
    for i in range(u("(unsigned long)[(id)0x%x count]" % windows)):
        window = u("(id)[(id)0x%x objectAtIndex:%d]" % (windows, i))
        lines.append("WINDOW %s\n" % cls(window))
        walk(u('(id)[(id)0x%x valueForKey:@"layer"]' % window), "", 0)
    lines.append("layers walked: %d in %.1fs\n" % (count[0], time.time() - started))

    # Part 3: every unstopped UIViewAnimationState, on a layer or not (see `unstopped_states`).
    unstopped, note = unstopped_states(process, u)
    lines.append("UNSTOPPED UIViewAnimationState: %s; %d seen as a delegate on a layer\n" % (
        note, len(states)))

    def describe(address, indent):
        """`_ivarDescription` of one object, plus the symbol behind every block it holds."""
        try:
            ivars = s("[(id)0x%x _ivarDescription]" % address)
        except RuntimeError as error:
            ivars = "_ivarDescription failed: %s" % error
        text = "".join(indent + line + "\n" for line in ivars.splitlines())
        for block in sorted(set(re.findall(r"<__NS\w*Block__: (0x[0-9a-f]+)>", ivars))):
            error = lldb.SBError()
            invoke = process.ReadPointerFromMemory(int(block, 16) + 16, error)
            text += "%sblock %s -> %s\n" % (
                indent, block, symbol_at(invoke) if error.Success() else "?")
        return text

    for address in sorted(set(unstopped) | set(states)):
        where = ", ".join(states[address]) if address in states else "NO LAYER (off the tree)"
        lines.append("STATE 0x%x %s on %s\n" % (
            address, "UNSTOPPED" if address in unstopped else "stopped", where))
        lines.append(describe(address, "    "))
        # A block-based animation keeps its start and completion blocks on a delegate object, and
        # the completion's symbol is the most direct name for the code that began the animation.
        delegate = u('(id)[(id)0x%x valueForKey:@"_delegate"]' % address)
        if delegate:
            lines.append("    DELEGATE %s 0x%x\n" % (cls(delegate), delegate))
            lines.append(describe(delegate, "        "))
        completions = u('(id)[(id)0x%x valueForKey:@"_addedCompletions"]' % address)
        if completions:
            for i in range(u("(unsigned long)[(id)0x%x count]" % completions)):
                block = u("(id)[(id)0x%x objectAtIndex:%d]" % (completions, i))
                error = lldb.SBError()
                invoke = process.ReadPointerFromMemory(block + 16, error)
                lines.append("    added completion 0x%x -> %s\n" % (
                    block, symbol_at(invoke) if error.Success() else "?"))
    lines.append("total %.1fs\n" % (time.time() - started))
    with open(out_path, "w") as handle:
        handle.write("".join(lines))


def __lldb_init_module(debugger, internal_dict):
    """lldb entry point; `dump` is called explicitly through `script`."""
