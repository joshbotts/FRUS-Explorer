// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

/// Draw-cost accounting for the word-cloud renderer.
///
/// ## Why this is separate from frame intervals
/// The frame *interval* is a shared resource. During an indexing run it is dominated by
/// whatever else the main thread is doing, so "p95 75 ms" says the device was busy — it
/// does not say the animation was expensive. The first on-device reading of this probe
/// produced exactly that confusion.
///
/// This measures the one thing the animation is actually answerable for: wall-clock time
/// spent inside its own render closure. That number is unconfounded, comparable between
/// builds, and is what a go/no-go on the drift engine turns on.
///
/// Nothing observes this, deliberately — the probe samples it when it formats, roughly four
/// times a second. Publishing it would invalidate a view on every frame to display a number
/// about how long frames take.
///
/// Version history:
///   1.0 — P-1: split out so the renderer's own cost can be read separately from the
///         frame interval it shares with everything else on the main thread
@MainActor
enum DrawCostMeter {

    private static var totalMicroseconds: Double = 0
    private static var samples: Int = 0
    private static var worstMicroseconds: Double = 0

    /// Records one render-closure execution.
    ///
    /// Called from the renderer itself, which is why it must stay this cheap: two adds and
    /// a compare. It is a no-op when the probe is off, so the shipping path pays a single
    /// boolean test.
    static func record(microseconds: Double) {
        guard FrameTimeProbe.isEnabled else { return }
        totalMicroseconds += microseconds
        samples += 1
        worstMicroseconds = max(worstMicroseconds, microseconds)
    }

    /// Mean and worst draw cost in milliseconds since the last read, then resets the mean.
    ///
    /// The worst case is *not* reset: a single 4 ms draw is the finding, and a metric that
    /// forgets it four times a second cannot report one.
    static func drain() -> (mean: Double, worst: Double)? {
        guard samples > 0 else { return nil }
        let mean = totalMicroseconds / Double(samples) / 1000
        totalMicroseconds = 0
        samples = 0
        return (mean: mean, worst: worstMicroseconds / 1000)
    }

    /// Clears the retained worst case, so an A/B can start from a clean slate.
    static func resetWorst() { worstMicroseconds = 0 }
}

/// The rolling frame-interval statistics behind the readout.
///
/// A plain value with no SwiftUI in it, because every correction the first version needed
/// was an arithmetic mistake — a percentile off by one, a threshold taken from the wrong
/// number, a tail silently truncated — and none of them could be observed from inside a
/// `ViewModifier`. They shipped, and were caught by an owner squinting at a badge on an
/// iPad. `FrameProbeStatisticsTests` is the thing that should have caught them.
///
/// Version history:
///   1.0 — P-1: extracted from `FrameTimeProbe` so the statistics can be tested
struct FrameIntervalWindow {

    /// Intervals kept, in arrival order — one second at 120 Hz, two at 60 Hz.
    private(set) var samples: [Double] = []

    /// The worst interval seen since launch, stalls included. Never decays: a metric that
    /// forgets the worst frame within a second cannot report one, which is precisely how
    /// the first version behaved.
    private(set) var sessionHigh: Double = 0

    /// Gaps long enough to be a stall rather than a late frame.
    private(set) var stallCount: Int = 0

    /// Frames retained in the rolling window.
    var windowSize = 120

    /// Beyond this a gap is a stall: kept out of the percentiles, but counted and carried
    /// into ``sessionHigh``. The first version *discarded* these, which capped the largest
    /// value it could ever print at 29 vsyncs and censored the tail exactly where it
    /// mattered.
    var stallMilliseconds: Double = 250

    /// Beyond this the app was suspended, not slow. Genuinely not a frame.
    var backgroundGapMilliseconds: Double = 2000

    /// Folds in one interval. Returns `false` if it was discarded as a suspension.
    @discardableResult
    mutating func add(_ interval: Double) -> Bool {
        guard interval > 0, interval < backgroundGapMilliseconds else { return false }
        sessionHigh = max(sessionHigh, interval)
        if interval >= stallMilliseconds {
            stallCount += 1
        } else {
            samples.append(interval)
            if samples.count > windowSize { samples.removeFirst(samples.count - windowSize) }
        }
        return true
    }

    /// Percentiles and lateness over the current window, or `nil` before it is meaningful.
    func snapshot(minimumSamples: Int = 30) -> Snapshot? {
        guard samples.count >= minimumSamples else { return nil }
        let sorted = samples.sorted()
        let p50 = sorted[sorted.count / 2]
        // Nearest-rank: the smallest value at or above which 95% of samples fall. The first
        // version used `Int(count * 0.95)`, selecting the 115th of 120 — the 95.8th
        // percentile — which is wrong in the direction that flatters the result.
        let index = max(0, Int((Double(sorted.count) * 0.95).rounded(.up)) - 1)
        let p95 = sorted[min(sorted.count - 1, index)]
        // Lateness against the cadence the display actually settled on, not the panel's
        // maximum. A ProMotion iPad ramps to 60 Hz on its own; measured against a 120 Hz
        // budget every one of those genuine frames counted as dropped, which is most of
        // what the first on-device reading was reporting.
        let late = Double(sorted.filter { $0 > p50 * 1.5 }.count) / Double(sorted.count)
        return Snapshot(p50: p50, p95: p95, worst: sorted[sorted.count - 1],
                        sessionHigh: sessionHigh, lateFraction: late, stalls: stallCount)
    }

    /// One reading.
    struct Snapshot: Equatable {
        let p50: Double
        let p95: Double
        /// Worst interval in the current window.
        let worst: Double
        /// Worst interval since launch.
        let sessionHigh: Double
        let lateFraction: Double
        let stalls: Int

        /// The cadence the display is actually running at, inferred from the median.
        var observedHz: Double { 1000 / max(0.1, p50) }
    }
}

/// An on-screen frame-time readout, for answering "is this animation affordable?" without
/// Instruments.
///
/// ## Why this exists
/// The word-cloud backdrop's frame cost gates the drift work, and three attempts to capture
/// it with Instruments failed in three different ways — a Debug build with the debugger
/// attached, a hung "stopping the trace", and a trace lost to unplugging the device. The
/// measurement is simple enough that owning it removes the whole apparatus: the number is
/// read off the device, there is no cable, no symbolication, and no trace to lose.
///
/// ## Not `#if DEBUG`, deliberately
/// A Debug build's SwiftUI is unoptimised, so its frame times answer a question nobody
/// asked. This is gated on an environment variable instead, so it can run under the
/// **`AppStore` configuration** — which is what `Product ▸ Profile` builds — and report
/// numbers that describe the shipping app. That follows the existing `FRUS_UI_TEST_MODE`
/// and `FRUS_DEBUG_EDGE_TAP_ZONES` precedent: env-gated diagnostics living in shipping
/// code, inert unless asked for.
///
/// ## Reading it
/// ```
///  120Hz · 8.3/8.3/17 · hi 192 · late 0.4% · draw 0.31/0.92
/// ```
/// - **`8.3/8.3/17`** — p50 / p95 / max frame interval in ms over the last ~1 s.
/// - **`hi 192`** — the worst interval seen since launch. Does not decay.
/// - **`late 0.4%`** — share of intervals more than half again the *current* cadence.
/// - **`draw 0.31/0.92`** — mean / worst ms inside the cloud's own render closure.
///
/// ## Three corrections the first version needed
/// The first on-device run produced numbers that could not be interpreted, in three
/// specific ways, each fixed here:
///
/// 1. **It called ProMotion a dropped frame.** The budget came from
///    `maximumFramesPerSecond`, so on an iPad that deliberately ramps to 60 Hz every
///    genuine 16.7 ms frame counted as late. Lateness is now measured against the rolling
///    *median* interval, which tracks whatever cadence the display has actually chosen —
///    self-calibrating, and it still flags a real hitch, which by definition departs from
///    the median.
/// 2. **It threw away the worst frames.** Any interval ≥ 250 ms was discarded as
///    "backgrounded". The owner read a max of 192 ms; the largest value the probe could
///    ever have printed was 242. The tail was censored exactly where it mattered. Long
///    gaps are now counted as stalls and kept in the session high; only multi-second gaps,
///    which really are backgrounding, are dropped.
/// 3. **`max` decayed within a second.** The window is 120 samples — one second at 120 Hz,
///    not the "two seconds at 60 Hz" the comment claimed — so every spike aged out almost
///    immediately and the readout appeared to reset. Hence `hi`.
///
/// ## What it still cannot tell you
/// `record` is driven by `TimelineView(.animation)`, so every interval it can compute is a
/// difference of two vsync timestamps. It cannot distinguish "the display chose a slower
/// cadence" from "we missed the deadline" from first principles — the median comparison is
/// a good heuristic, not a proof. When the two must be told apart, `draw` is the honest
/// number: it measures work, not delivery.
///
/// Version history:
///   1.0 — P-0: initial implementation
///   1.1 — worst-frame reporting, after a during-indexing reading of "over 4%" turned out
///         to be unactionable without knowing the magnitude of the overs
///   2.0 — P-1: median-relative lateness, uncensored tail, session high, per-frame draw
///         cost, and a summary formatted 4×/s instead of 120×/s
struct FrameTimeProbe: ViewModifier {

    /// Set `FRUS_FRAME_PROBE=1` in the scheme's Run/Profile environment to show it.
    ///
    /// Resolved once. The first version re-read `ProcessInfo.processInfo.environment` —
    /// which materialises the whole environment dictionary — on every body evaluation.
    static let isEnabled: Bool =
        ProcessInfo.processInfo.environment["FRUS_FRAME_PROBE"] == "1"

    @State private var window = FrameIntervalWindow()
    @State private var lastTick: Date?
    @State private var summary = "measuring…"
    @State private var framesSinceFormat: Int = 0

    /// How often the readout is re-formatted, in frames.
    ///
    /// The first version formatted a string and wrote `@State` on *every* frame, which
    /// invalidated the readout 120 times a second to display a number about frame times.
    /// A quarter-second refresh is as fast as anyone can read it.
    private let formatEveryNFrames = 30

    func body(content: Content) -> some View {
        if Self.isEnabled {
            content.overlay(alignment: .top) { readout }
        } else {
            content
        }
    }

    private var readout: some View {
        TimelineView(.animation) { context in
            Text(summary)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.65)))
                // Clears the status bar and Dynamic Island by hand. The probe overlays the
                // backdrop, which its hosts render with `.ignoresSafeArea()` — so the safe
                // area insets are already consumed and cannot be asked for here.
                .padding(.top, statusBarClearance)
                .onChange(of: context.date) { _, now in record(now) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Folds one frame's interval into the rolling window.
    private func record(_ now: Date) {
        defer { lastTick = now }
        guard let lastTick else { return }
        window.add(now.timeIntervalSince(lastTick) * 1000)

        framesSinceFormat += 1
        guard framesSinceFormat >= formatEveryNFrames else { return }
        framesSinceFormat = 0
        if let snapshot = window.snapshot() { summary = Self.line(for: snapshot) }
    }

    /// Formats one reading. Static and pure, so the readout's wording is testable too.
    static func line(for s: FrameIntervalWindow.Snapshot) -> String {
        var line = String(format: "%.0fHz · %.1f/%.1f/%.0f · hi %.0f · late %.1f%%",
                          s.observedHz, s.p50, s.p95, s.worst, s.sessionHigh,
                          s.lateFraction * 100)
        if s.stalls > 0 { line += String(format: " · stalls %d", s.stalls) }
        if let draw = DrawCostMeter.drain() {
            line += String(format: " · draw %.2f/%.2f", draw.mean, draw.worst)
        }
        return line
    }

    /// Vertical offset that clears the status bar / Dynamic Island on a full-bleed host.
    private var statusBarClearance: CGFloat {
        #if os(macOS)
        8
        #else
        56
        #endif
    }

    /// Milliseconds per frame at the display's maximum refresh rate.
    ///
    /// No longer used for lateness — that is median-relative now — but kept because it is
    /// the honest answer to "what is this panel capable of", which is worth knowing when
    /// the observed cadence turns out to be half of it.
    static var frameBudgetMilliseconds: Double {
        #if os(iOS)
        let fps = UIScreen.main.maximumFramesPerSecond
        return fps > 0 ? 1000 / Double(fps) : 1000 / 60
        #else
        let fps = NSScreen.main?.maximumFramesPerSecond ?? 60
        return fps > 0 ? 1000 / Double(fps) : 1000 / 60
        #endif
    }
}

extension View {

    /// Overlays a frame-time readout when `FRUS_FRAME_PROBE=1`, otherwise does nothing.
    ///
    /// Applied to the word-cloud backdrop, whose animation cost is the thing being decided.
    func frameTimeProbe() -> some View {
        modifier(FrameTimeProbe())
    }
}
