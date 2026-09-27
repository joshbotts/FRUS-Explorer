// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// HoverRegionProbe — which region a graph hit area's pointer modifiers answer on macOS, and what a
// click, a double-click and a drag on empty canvas reach (#1471).
//
// Four graph hit areas were `Button { … }.buttonStyle(.plain).position(pos)` followed by their
// `.onHover`. #1471 asked whether that makes the hover region the whole canvas — `.position`
// returns a view that fills its parent — which would explain the Volume Connections panel showing
// the last-sorted partner after every Explore connections and Back. The Mac check that found the
// symptom could not produce hover by moving the pointer, so this answers it in-process instead: it
// hosts each hit-area shape in an `NSHostingView` and feeds the view the events AppKit would.
//
// Build and run (no Xcode project, no signing; it opens and closes a few small windows):
//
//     DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//         swiftc -O tools/hover-region-probe/HoverRegionProbe.swift -o /tmp/HoverRegionProbe
//     /tmp/HoverRegionProbe
//
// HOW THE POINTER IS FAKED, and what each fake is for — each was measured by removing it:
// - Hover. SwiftUI reads hover from the hosting view's own tracking area and reports nothing until
//   the pointer has ENTERED that area: `mouseMoved` alone, sent to the hosting view or posted
//   through the app, printed no hover in any run. So the probe sends `mouseEntered` naming that
//   area — the one whose options are 643 (entered/exited, moved, active-always, in-visible-rect); a
//   `.help` adds a second (options 4225), and entering that one reports no hover — and then
//   `mouseMoved` straight to the hosting view. Faking `NSEvent.mouseLocation` and
//   `mouseLocationOutsideOfEventStream` as well changed nothing, so neither is here.
// - Gestures. Clicks and drags go through `NSWindow.sendEvent(_:)`. SwiftUI recognised a tap or a
//   drag from them only while the window was key and the app active: without those two fakes a
//   click on empty canvas and a drag printed nothing and a double-click read as one click, though a
//   `Button` still took its click. A process started from a shell is refused activation, so the
//   panel reports itself key and `NSApplication.isActive` is swapped to answer `true`. The hover
//   lines were the same with and without them.
// - The first click a fresh process sends can be swallowed, so a warm-up variant runs first and its
//   lines are discarded.
//
// The two orders are ONE variable: both write the same `.onHover` and `.help`, and they differ only
// in where `.position(pos)` sits — before both, as `v2` wrote three of its four hit areas, or after
// both, as they are written now. (Until review round 1 the `v2` variant carried no `.help`, so a
// difference could have been the `.help`'s second tracking area rather than the order.)
//
// Measured on macOS 27 (Darwin 27.0.0), Xcode 27.0, 2026-09-26 — the lines this prints:
// - `v2 order` (`.position(pos)` then `.onHover` and `.help`): entering the canvas over EMPTY space
//   reports `hover c true` — the LAST hit area, the topmost — and moving onto disc a reports nothing.
// - `pointer modifiers first` (`.onHover` and `.help`, then `.position(pos)`): nothing over empty
//   canvas, `hover a true` over disc a, `hover a false` off it.
// - Neither order puts a context menu on empty canvas: the hosting view's `menu(for:)` at an empty
//   point is empty in both, since a menu is found by hit-testing.
// - Without a hit-testable background, a click, a double-click and a drag on empty canvas reach
//   nothing, in both orders; with the shipped `emptyCanvas` background (after `.offset`, before
//   the gestures) a click clears, a double-click resets without clearing, a drag pans, and a click
//   on a disc still reaches the disc.
// - Panned 150 pt right and zoomed to 0.8, the discs have left the probe's points (disc a and
//   disc c are drawn off the 400-pt canvas, so neither is hovered or clicked), and empty canvas
//   OUTSIDE the transformed content still takes the click, the double-click and the drag: the
//   background sits after `.offset`, so it does not move with the graph. Of eight runs made while
//   this file was written, one read the panned variant's double-click as a single click (a clear,
//   no reset); the last three, of the file as first committed, gave the lines above exactly, and
//   so did three more of the file as it is now, with the `.help` in both orders (review round 1).
//   The `v2` variant's lines did not change when it gained its `.help`.

import AppKit
import SwiftUI

/// The probe's event log.
@MainActor final class Log { static var lines: [String] = [] }

/// The three discs, placed well away from the canvas's top-left corner, where the pointer rests
/// after Explore connections or Back.
let discs = ["a", "b", "c"]
let positions: [String: CGPoint] = [
    "a": CGPoint(x: 300, y: 80), "b": CGPoint(x: 320, y: 200), "c": CGPoint(x: 330, y: 250),
]

/// Each hit-area shape the probe hosts.
enum Variant: String, CaseIterable {
    case warmUp = "warm-up (discarded)"
    case v2Order = "v2 order: .position(pos) then .onHover and .help"
    case pointerModifiersFirst = "pointer modifiers first: .onHover and .help, then .position(pos)"
    case shipped = "shipped: emptyCanvas background after .offset, before the gestures"
    case shippedPanned = "shipped, panned 150 pt right and zoomed to 0.8"
}

/// One disc's hit area, in the order `variant` writes its modifiers: the same `.onHover`, `.help` and
/// `.contextMenu` in every variant, with `.position` after the first two or before them.
struct Disc: View {
    let id: String
    let variant: Variant
    var body: some View {
        let button = Button { Log.lines.append("click \(id)") } label: {
            Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
        }
        .buttonStyle(.plain)
        if variant == .v2Order {
            button
                .position(positions[id]!)
                .onHover { h in Log.lines.append("hover \(id) \(h)") }
                .help("help \(id)")
                .contextMenu { Button("menu \(id)") {} }
        } else {
            button
                .onHover { h in Log.lines.append("hover \(id) \(h)") }
                .help("help \(id)")
                .position(positions[id]!)
                .contextMenu { Button("menu \(id)") {} }
        }
    }
}

/// The canvas: a non-hit-testing `Canvas` under the discs, with two of the graph's three gestures —
/// the drag that pans and the double-click that resets. The pinch is not here: nothing this probe
/// sends would drive it, so what a pinch on empty canvas reaches is not measured.
struct Probe: View {
    let variant: Variant
    var body: some View {
        GeometryReader { _ in
            let stack = ZStack(alignment: .topLeading) {
                Canvas { _, _ in }.allowsHitTesting(false)
                ForEach(discs, id: \.self) { Disc(id: $0, variant: variant) }
            }
            .scaleEffect(variant == .shippedPanned ? 0.8 : 1, anchor: .center)
            .offset(variant == .shippedPanned ? CGSize(width: 150, height: 0) : .zero)
            Group {
                switch variant {
                case .shipped, .shippedPanned, .warmUp:
                    stack.background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { Log.lines.append("canvas single (clear)") }
                    }
                case .v2Order, .pointerModifiersFirst:
                    stack
                }
            }
            .gesture(DragGesture(minimumDistance: 5)
                .onChanged { _ in if Log.lines.last != "pan changed" { Log.lines.append("pan changed") } }
                .onEnded { _ in Log.lines.append("pan ended") })
            .gesture(TapGesture(count: 2).onEnded { Log.lines.append("double (reset)") })
        }
        .frame(width: 400, height: 300)
    }
}

/// A panel that reports itself key, since a shell-started process is refused activation and SwiftUI
/// recognises gestures only in a key window.
final class ProbeWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

extension NSApplication { @objc var probeIsActive: Bool { true } }

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.finishLaunching()
method_exchangeImplementations(
    class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.isActive))!,
    class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.probeIsActive))!)

/// Runs the app's event loop for `seconds`.
func pump(_ seconds: Double = 0.3) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end {
        if let event = app.nextEvent(matching: .any, until: Date().addingTimeInterval(0.02),
                                     inMode: .default, dequeue: true) {
            app.sendEvent(event)
        }
    }
}

/// Hosts `variant`, drives the pointer, and returns what was logged.
@MainActor func run(_ variant: Variant) -> [String] {
    Log.lines = []
    let host = NSHostingView(rootView: Probe(variant: variant))
    host.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
    let window = ProbeWindow(contentRect: NSRect(x: 200, y: 200, width: 400, height: 300),
                             styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
    window.contentView = host
    window.acceptsMouseMovedEvents = true
    window.makeKeyAndOrderFront(nil)
    pump(1.0)
    defer { window.orderOut(nil) }

    /// The window point for a canvas point (the canvas's origin is its top-left).
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x, y: 300 - y)
    }
    func mouse(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat, clicks: Int = 1) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point(x, y), modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                           clickCount: clicks, pressure: type == .leftMouseDown ? 1 : 0)!
    }
    func click(_ x: CGFloat, _ y: CGFloat, clicks: Int = 1) {
        window.sendEvent(mouse(.leftMouseDown, x, y, clicks: clicks))
        window.sendEvent(mouse(.leftMouseUp, x, y, clicks: clicks))
    }

    guard let hoverArea = host.trackingAreas.first(where: { $0.options.rawValue == 643 }) else {
        return ["no hover tracking area: \(host.trackingAreas.map(\.options.rawValue))"]
    }
    Log.lines.append("-- the pointer enters the canvas over EMPTY space (40, 40)")
    host.mouseEntered(with: NSEvent.enterExitEvent(
        with: .mouseEntered, location: point(40, 40), modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
        context: nil, eventNumber: 0, trackingNumber: unsafeBitCast(hoverArea, to: Int.self),
        userData: nil)!)
    pump()
    Log.lines.append("-- it moves onto disc a (300, 80)")
    host.mouseMoved(with: mouse(.mouseMoved, 300, 80)); pump()
    Log.lines.append("-- it moves off onto EMPTY canvas (60, 250)")
    host.mouseMoved(with: mouse(.mouseMoved, 60, 250)); pump()
    Log.lines.append("-- context menu at EMPTY (60, 250): \(host.menu(for: mouse(.rightMouseDown, 60, 250))?.items.map(\.title) ?? [])")
    Log.lines.append("-- context menu at disc a (300, 80): \(host.menu(for: mouse(.rightMouseDown, 300, 80))?.items.map(\.title) ?? [])")
    Log.lines.append("-- a click on EMPTY canvas (60, 250)")
    click(60, 250); pump(1.0)
    Log.lines.append("-- a double-click on EMPTY canvas (60, 250)")
    click(60, 250); click(60, 250, clicks: 2); pump(1.0)
    Log.lines.append("-- a click on disc c (330, 250)")
    click(330, 250); pump(1.0)
    Log.lines.append("-- a drag on EMPTY canvas, (60, 250) to (160, 200)")
    window.sendEvent(mouse(.leftMouseDown, 60, 250))
    for step in 1...10 {
        window.sendEvent(mouse(.leftMouseDragged, 60 + CGFloat(step) * 10, 250 - CGFloat(step) * 5))
        pump(0.02)
    }
    window.sendEvent(mouse(.leftMouseUp, 160, 200)); pump(1.0)
    return Log.lines
}

MainActor.assumeIsolated {
    for variant in Variant.allCases {
        let lines = run(variant)
        guard variant != .warmUp else { continue }
        print("\(variant.rawValue):\n  " + lines.joined(separator: "\n  "))
    }
}
