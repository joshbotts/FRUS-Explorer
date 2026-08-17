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

import Foundation
import Testing

/// The developer instrumentation must not reach a reader, and the gates that ensure it must not be
/// removable in silence.
///
/// ## Why this suite exists
/// The semantic map's frame-rate HUD — `314483 documents · 0.05 ms mean · 18,849 fps equivalent` —
/// was `#if DEBUG`-gated at its single mount and **nothing asserted that**. Deleting two lines would
/// have shipped a rendering spike's readout onto an analytics window with the whole suite green.
/// Measured against the AppStore products before this suite existed: the map's strings were absent,
/// and `FRUS_FRAME_PROBE` was *present*, because that probe's only gate was a runtime environment
/// check. This pins both.
///
/// ## Why a source scan, when this repo distrusts them
/// A compile-time gate cannot be observed from a test binary — the tests build with `DEBUG` defined,
/// so the gated code is exactly what *is* present here. Running the assertion at runtime would test
/// the opposite of the claim. The honest instrument is therefore the source, and the risk that comes
/// with it is the one this repo has been bitten by: a `contains` that matches a doc comment quoting
/// the code it is meant to check, which is how a mutation survived `CollocationWiringAuditTests`.
///
/// Two defences. Comments are **stripped** before anything is matched, so prose describing a gate
/// cannot stand in for the gate. And the assertion is **regional**, not textual: the directives are
/// parsed into nesting depth and the guarded line is required to sit inside a `#if DEBUG` region —
/// so moving the mount out of the block fails even if every word in the file is unchanged.
///
/// Version history:
///   1.0 — build 42 release prep: pin the map HUD's gate, the stats machinery behind it, and the
///         word-cloud probe's move from a runtime environment variable to `#if DEBUG`
@Suite("Developer instrumentation is compiled out of release builds")
struct DeveloperInstrumentationGateTests {

    // MARK: - Reading the source

    private static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: sourceRoot.appending(path: relative), encoding: .utf8)
    }

    /// Removes `//` and `/* */` comments, preserving line count so reported numbers stay usable.
    ///
    /// Line-count preservation is the point: an assertion that reports "line 832" has to mean the
    /// line an editor would open. String literals are not parsed — this file's assertions never
    /// match text that appears inside one, and a comment-aware scanner that also tracked quoting
    /// would be a second parser to keep honest.
    private static func strippingComments(_ text: String) -> String {
        var out: [String] = []
        var inBlock = false
        for var line in text.components(separatedBy: .newlines) {
            if inBlock {
                if let end = line.range(of: "*/") {
                    line = String(line[end.upperBound...]); inBlock = false
                } else {
                    out.append(""); continue
                }
            }
            while let start = line.range(of: "/*") {
                if let end = line.range(of: "*/", range: start.upperBound..<line.endIndex) {
                    line = String(line[..<start.lowerBound]) + String(line[end.upperBound...])
                } else {
                    line = String(line[..<start.lowerBound]); inBlock = true; break
                }
            }
            if let slashes = line.range(of: "//") { line = String(line[..<slashes.lowerBound]) }
            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    /// The 1-based lines of `source` that sit inside at least one `#if DEBUG` region.
    ///
    /// Tracks nesting so a `#if DEBUG` containing an `#if os(macOS)` still reports its inner lines
    /// as guarded, and so an `#else` **leaves** the guarded region — a mount moved into the `#else`
    /// arm of a DEBUG gate ships, and must fail.
    private static func debugGuardedLines(_ source: String) -> Set<Int> {
        var guarded: Set<Int> = []
        var stack: [Bool] = []          // one entry per open #if; true when it is a DEBUG arm
        for (index, raw) in source.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                stack.append(line == "#if DEBUG")
            } else if line.hasPrefix("#elseif") {
                if !stack.isEmpty { stack[stack.count - 1] = false }
            } else if line == "#else" {
                // The other arm of any `#if` is not a DEBUG arm. This is deliberately blunt: for
                // `#if !DEBUG … #else` it is a false negative, which fails loudly rather than
                // passing something that ships, and no gate in this repo is written that way.
                if !stack.isEmpty { stack[stack.count - 1] = false }
            } else if line.hasPrefix("#endif") {
                if !stack.isEmpty { stack.removeLast() }
            } else if stack.contains(true) {
                guarded.insert(index + 1)
            }
        }
        return guarded
    }

    /// Asserts every occurrence of `needle` in `file` sits inside a `#if DEBUG` region.
    private static func expectGuarded(_ needle: String, in file: String,
                                      _ why: Comment) throws {
        let text = strippingComments(try source(file))
        let guarded = debugGuardedLines(text)
        var found = 0
        for (index, line) in text.components(separatedBy: .newlines).enumerated()
        where line.contains(needle) {
            found += 1
            #expect(guarded.contains(index + 1), why)
        }
        #expect(found > 0, """
            No line in \(file) contains "\(needle)" once comments are stripped. The code this test \
            guards was renamed or removed, so the assertion is now vacuous — retarget it or delete \
            it, but do not leave it passing over nothing.
            """)
    }

    // MARK: - The semantic map's HUD

    @Test("The map's frame-rate overlay is mounted only inside #if DEBUG")
    func mapStatsOverlayIsGated() throws {
        try Self.expectGuarded("statsOverlay }", in: "Semantic/Map/SemanticMapSpikeView.swift", """
            The semantic map's stats overlay is mounted outside #if DEBUG. It reads \
            "0.05 ms mean · 18,849 fps equivalent · N frames presented" — the language of a \
            rendering spike, over an analytics window a reader can open from the Analysis Tools \
            menu. It was acceptable only while the screen was unreachable.
            """)
    }

    @Test("The per-frame measurement behind the overlay is gated too, not just the readout")
    func mapStatsCollectionIsGated() throws {
        // The defect this pins is subtler than a visible overlay and is what release prep found:
        // the HUD was stripped while everything that fed it kept running, so a shipping build paid
        // a GPU completion handler, a lock, an array append and a main-actor `Task` hop per
        // presented frame — during pan and zoom — to publish a number no release view could read.
        try Self.expectGuarded("buffer.addCompletedHandler", in: "Semantic/Map/SemanticMapRenderer.swift", """
            The renderer registers its frame-timing completion handler outside #if DEBUG. That is \
            per-frame work in a shipping build for a readout that is compiled out.
            """)
        try Self.expectGuarded("final class StatsSink", in: "Semantic/Map/SemanticMapRenderer.swift",
                               "StatsSink ships in release, where nothing can read what it collects.")
        try Self.expectGuarded("made.onStats =", in: "Semantic/Map/SemanticMapSpikeView.swift", """
            The model assigns the renderer's stats callback outside #if DEBUG, so every presented \
            frame hops to the main actor to store a value no release view reads.
            """)
    }

    // MARK: - The word-cloud backdrop probe

    @Test("The word-cloud frame probe is gated by compilation, not only by an environment variable")
    func wordCloudProbeIsGated() throws {
        // Measured before this changed: `FRUS_FRAME_PROBE` was present in BOTH AppStore binaries.
        // A launched App Store build cannot carry a custom environment, so it could not switch on —
        // but the guarantee was a runtime string compare where a compilation condition belongs.
        try Self.expectGuarded("ProcessInfo.processInfo.environment[\"FRUS_FRAME_PROBE\"]",
                               in: "Analytics/WordCloud/FrameTimeProbe.swift", """
            The frame probe's only gate is the runtime environment again. Keep the variable — it is \
            what stops the readout appearing on every debug run — but inside #if DEBUG.
            """)
        try Self.expectGuarded("struct FrameTimeProbe", in: "Analytics/WordCloud/FrameTimeProbe.swift",
                               "The probe's ViewModifier is compiled into release builds.")
        try Self.expectGuarded("DrawCostMeter.record", in: "Analytics/WordCloud/WordCloudDriftCanvas.swift", """
            The draw-cost meter is fed on every production draw. It accumulates into scalars that \
            only the probe drains, and the probe does not exist in a release build.
            """)
    }

    // MARK: - The scanner itself

    /// The assertions above are only worth their runtime if the region parser is right, and two of
    /// its rules are easy to get wrong in a way that would silently pass everything.
    @Test("The #if DEBUG region parser handles nesting, #else and #elseif")
    func regionParserIsCorrect() {
        let sample = """
            line1
            #if DEBUG
            line3
            #if os(macOS)
            line5
            #endif
            line7
            #else
            line9
            #endif
            line11
            #if os(iOS)
            line13
            #endif
            """
        let guarded = Self.debugGuardedLines(sample)
        #expect(guarded == [3, 5, 7], """
            Expected exactly the lines inside the #if DEBUG arm — including those nested one level \
            deeper — and nothing in its #else arm or in an unrelated platform check. Got \
            \(guarded.sorted()). A parser that treats #else as still-guarded would pass a mount \
            that ships in release; one that loses nesting would fail a legitimate inner #if.
            """)
    }

    /// Comment stripping is the other load-bearing half, and the reason is a real prior defect:
    /// a doc comment quoting the very code an audit checked let a mutation survive.
    @Test("Comment stripping defeats prose that quotes the code")
    func commentStrippingWorks() {
        let sample = """
            // .overlay { statsOverlay } is gated below
            /// buffer.addCompletedHandler is DEBUG-only
            let real = 1 /* buffer.addCompletedHandler */
            """
        let stripped = Self.strippingComments(sample)
        #expect(!stripped.contains("statsOverlay"))
        #expect(!stripped.contains("addCompletedHandler"), """
            A comment mentioning the guarded call survived stripping, so any assertion about that \
            call could be satisfied by prose alone — exactly the shape that let a mutation survive \
            CollocationWiringAuditTests.
            """)
        #expect(stripped.contains("let real = 1"), "stripping removed real code")
        #expect(stripped.components(separatedBy: .newlines).count == 3,
                "line numbering must survive stripping or reported line numbers are wrong")
    }
}
