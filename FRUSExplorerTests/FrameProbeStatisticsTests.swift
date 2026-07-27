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

import Testing
import Foundation
@testable import FRUSExplorer

/// The frame probe's statistics.
///
/// ## Why these exist
/// The probe is an instrument, and its first version was wrong in three ways that all
/// pointed the same direction — toward numbers that could not be acted on:
///
/// 1. It compared every interval against the panel's *maximum* refresh rate, so an iPad
///    deliberately running ProMotion at 60 Hz reported a stream of dropped frames.
/// 2. It discarded any interval of 250 ms or more as "backgrounded", which censored the
///    tail exactly where a stall lives. The owner read a max of 192 ms; the largest number
///    the probe could ever have printed was 242.
/// 3. Its window is one second at 120 Hz, and nothing latched the worst case, so `max`
///    decayed within a second of every spike and the badge appeared to reset.
///
/// None of it was observable from inside a `ViewModifier`, so all three shipped and were
/// found by an owner reading a badge on a device. The statistics are a plain value now,
/// and this is the suite that should have caught them.
///
/// Version history:
///   1.0 — P-1, after the first on-device reading proved uninterpretable
@Suite("Frame probe — statistics")
struct FrameProbeStatisticsTests {

    /// A window filled with `count` intervals of `ms`.
    private func window(of ms: Double, count: Int) -> FrameIntervalWindow {
        var w = FrameIntervalWindow()
        for _ in 0..<count { w.add(ms) }
        return w
    }

    // MARK: - Correction 1: ProMotion is not a dropped frame

    @Test("A display running steadily at 60Hz reports no late frames")
    func steadySixtyHertzIsNotLate() throws {
        // Every interval is 16.7 ms. Against a 120 Hz budget the old code called all of
        // them late; against the observed cadence none of them are, which is correct — the
        // display chose this, nothing was missed.
        let snapshot = try #require(window(of: 1000.0 / 60, count: 120).snapshot())
        #expect(snapshot.lateFraction == 0,
                "measuring lateness against the panel maximum reported 100% here")
        #expect(abs(snapshot.observedHz - 60) < 1,
                "and the readout should say 60Hz, not the 120 the panel is capable of")
    }

    @Test("A real hitch inside a 60Hz stream is still late")
    func hitchAtSixtyHertzIsStillLate() throws {
        // The median-relative rule must not become a rule that flags nothing.
        var w = window(of: 1000.0 / 60, count: 119)
        w.add(120)
        let snapshot = try #require(w.snapshot())
        #expect(snapshot.lateFraction > 0, "a 120 ms frame in a 16.7 ms stream is late at any cadence")
        #expect(snapshot.worst == 120)
    }

    @Test("A display running at 120Hz still flags a 60Hz dip as late")
    func dipFromOneTwentyIsLate() throws {
        var w = window(of: 1000.0 / 120, count: 110)
        for _ in 0..<10 { w.add(1000.0 / 60) }
        let snapshot = try #require(w.snapshot())
        #expect(snapshot.lateFraction > 0.05,
                "when the median says 120Hz, 16.7 ms frames genuinely are misses")
    }

    // MARK: - Correction 2: the tail is not censored

    @Test("A 300ms stall is counted, not silently dropped")
    func stallIsCountedNotDiscarded() throws {
        var w = window(of: 8.3, count: 100)
        w.add(300)
        let snapshot = try #require(w.snapshot())
        #expect(snapshot.stalls == 1, "the old code discarded this entirely")
        #expect(snapshot.sessionHigh == 300,
                "and it must survive in the session high, which is the number that matters")
        #expect(snapshot.worst < 300,
                "but stay out of the percentiles — one stall must not redefine a 1-second window")
    }

    @Test("Only a multi-second gap is treated as the app having been suspended")
    func suspensionIsDiscarded() {
        var w = window(of: 8.3, count: 100)
        #expect(w.add(5000) == false, "five seconds is a suspension, not a frame")
        #expect(w.stallCount == 0)
        #expect(w.sessionHigh < 100, "and it must not poison the session high either")
    }

    @Test("The reported worst case is not bounded by the stall threshold")
    func sessionHighIsUnbounded() {
        var w = window(of: 8.3, count: 40)
        w.add(1800)
        // The old implementation's ceiling was one tick under 250 ms. Anything worse than
        // its own filter was invisible to it, which is the failure mode where a probe
        // reports "fine" precisely when it is not.
        #expect(w.sessionHigh == 1800)
    }

    // MARK: - Correction 3: the worst case does not decay

    @Test("The session high survives the spike ageing out of the window")
    func sessionHighDoesNotDecay() throws {
        var w = window(of: 8.3, count: 60)
        w.add(192)
        // Now push the spike out: the window is 120 samples, so 120 more clean frames
        // guarantee it is gone from the percentiles.
        for _ in 0..<130 { w.add(8.3) }

        let snapshot = try #require(w.snapshot())
        #expect(snapshot.worst < 20, "precondition: the spike has aged out of the window")
        #expect(snapshot.sessionHigh == 192,
                "this is the badge 'resetting' the owner reported — the number was simply gone")
    }

    // MARK: - The percentile itself

    @Test("p95 is the nearest-rank 95th percentile, not the 96th")
    func p95IsNearestRank() throws {
        // 100 samples: 95 fast, 5 slow. The 95th percentile is the last fast one.
        var w = FrameIntervalWindow()
        for _ in 0..<95 { w.add(8) }
        for _ in 0..<5 { w.add(50) }
        let snapshot = try #require(w.snapshot())
        #expect(snapshot.p95 == 8,
                "Int(count * 0.95) selects index 95 — the first SLOW sample — and reads 50")
    }

    @Test("Below the minimum sample count there is no reading at all")
    func noSnapshotUntilTheWindowIsMeaningful() {
        #expect(window(of: 8.3, count: 10).snapshot() == nil)
        #expect(window(of: 8.3, count: 30).snapshot() != nil)
    }

    // MARK: - The readout

    @Test("The line reports cadence, percentiles, session high and lateness")
    @MainActor
    func lineCarriesEveryNumber() throws {
        var w = window(of: 8.3, count: 100)
        w.add(400)
        let line = FrameTimeProbe.line(for: try #require(w.snapshot()))
        #expect(line.contains("120Hz"))
        #expect(line.contains("hi 400"), "the worst frame must be readable off the badge")
        #expect(line.contains("stalls 1"))
    }
}
