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

/// An on-screen frame-time readout, for answering "is this animation affordable?" without
/// Instruments.
///
/// ## Why this exists
/// The word-cloud backdrop's frame cost gates the O-P1 drift work, and three attempts to
/// capture it with Instruments failed in three different ways — a Debug build with the
/// debugger attached, a hung "stopping the trace", and a trace lost to unplugging the
/// device. The measurement is simple enough that owning it removes the whole apparatus:
/// the number is read off the device, there is no cable, no symbolication, and no trace to
/// lose.
///
/// It also gives a **directly comparable** before/after, which two separate Instruments
/// sessions never quite do — same code, same device, same units, one variable changed.
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
///  p50 8.1  p95 16.9  over 4%   120Hz
/// ```
/// `p50`/`p95` are frame *intervals* in milliseconds; `over` is the share of frames that
/// missed the display's budget. On a 120 Hz panel the budget is 8.3 ms, on 60 Hz it is
/// 16.7 ms — which is why the refresh rate is shown rather than assumed.
///
/// **The probe is not free.** It costs one `TimelineView` tick and a small array append per
/// frame, so treat its own numbers as a slight over-estimate of the cost it is measuring.
/// That bias is in the safe direction for a go/no-go decision.
///
/// Version history:
///   1.0 — P-0: initial implementation
struct FrameTimeProbe: ViewModifier {

    /// Set `FRUS_FRAME_PROBE=1` in the scheme's Run/Profile environment to show it.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FRUS_FRAME_PROBE"] == "1"
    }

    @State private var samples: [Double] = []
    @State private var lastTick: Date?
    @State private var summary = "measuring…"

    /// Frames kept in the rolling window — about two seconds at 60 Hz.
    private let windowSize = 120

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

    /// Folds one frame's interval into the rolling window and re-renders the summary.
    private func record(_ now: Date) {
        defer { lastTick = now }
        guard let lastTick else { return }
        let interval = now.timeIntervalSince(lastTick) * 1000
        // A backgrounded or stalled app produces a multi-second gap that is not a dropped
        // frame; folding it in would poison the percentiles for the rest of the window.
        guard interval > 0, interval < 250 else { return }

        samples.append(interval)
        if samples.count > windowSize { samples.removeFirst(samples.count - windowSize) }
        guard samples.count >= 30 else { return }

        let sorted = samples.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        let budget = Self.frameBudgetMilliseconds
        let over = Double(sorted.filter { $0 > budget * 1.5 }.count) / Double(sorted.count)
        summary = String(format: "p50 %.1f  p95 %.1f  over %.0f%%  %.0fHz",
                         p50, p95, over * 100, 1000 / budget)
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
    /// Read rather than assumed: a 120 Hz iPad has half the budget of a 60 Hz one, so the
    /// same `p95` means something different on each.
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
