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

@testable import FRUSExplorer

// MARK: - KeynessWiringAuditTests

/// Source-text audit of how the keyness mode is *wired into the view*.
///
/// `KeynessCloudTests` calls `KeynessCloud.rank` directly, which is the right way to test the
/// measure — and it means those tests cannot see the call site at all. Every defect below was
/// confirmed to survive the whole unit suite: inverting `includeDiplomatic` in `WordCloudView`
/// changes nothing any of the 14 cases can observe.
///
/// A SwiftUI view of this size is not unit-testable without a host, and these are one-line,
/// silently-plausible slips in exactly the argument that decides whether the number on screen is
/// meaningful. Reading the source is a weak tool — it cannot see behaviour, only text — so every
/// check below carries an anti-vacuity floor: if the file is renamed or the code restructured, the
/// audit fails loudly rather than passing by matching nothing.
///
/// Version history:
///   1.0 — S-1: initial implementation
@Suite("Keyness wiring audit")
struct KeynessWiringAuditTests {

    /// Reads a source file out of the repository next to this test file.
    private func source(_ relativePath: String) throws -> String {
        // #filePath is this file inside FRUSExplorerTests/, so the repo root is one level up.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: relativePath)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.count > 1_000, "\(relativePath) is implausibly small — did it move?")
        return text
    }

    /// The text of one declaration, from its header to the closing brace at the same indent.
    ///
    /// A character-count window is not a substitute: the first version of this file used
    /// `prefix(700)` from `private struct KeynessKey`, which ran into `TaskKey` — whose members
    /// have the same names — so the assertions passed on the wrong type.
    private func declaration(named header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "\(header) not found")
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "\n    }"), "no closing brace for \(header)")
        return String(source[start.lowerBound..<end.upperBound])
    }

    @Test("The keyness call site passes excludeBoilerplate VERBATIM, never negated")
    func includeDiplomaticIsNotInverted() throws {
        let view = try source("FRUSExplorer/Analytics/WordCloud/WordCloudView.swift")
        // The two names sound like opposites and are not: WordCloudLoader passes
        // `includeDiplomaticStopwords: excludeBoilerplate` straight through. Negating it here
        // compiles, reads plausibly, and inverts the one guard that stops department / telegram /
        // washington — reference count zero — from ranking as the corpus's most distinctive words.
        #expect(view.contains("includeDiplomatic: excludeBoilerplate"),
                "the keyness availability check must be given the live boilerplate setting verbatim")
        #expect(!view.contains("includeDiplomatic: !excludeBoilerplate"),
                "includeDiplomatic is NOT the inverse of excludeBoilerplate in this codebase — see WordCloudLoader.load")
    }

    @Test("The loader's own polarity is the one the audit above depends on")
    func loaderPolarityIsUnchanged() throws {
        let loader = try source("FRUSExplorer/Analytics/WordCloud/WordCloudLoader.swift")
        // If this ever flips, the check above becomes wrong rather than protective — so it is
        // pinned here rather than assumed.
        #expect(loader.contains("includeDiplomaticStopwords: excludeBoilerplate"),
                "the scope side's polarity changed; the keyness call site must change with it")
        #expect(!loader.contains("includeDiplomaticStopwords: !excludeBoilerplate"))
    }

    @Test("Availability is checked against the CLAMPED live tuning, not the raw mirrors")
    func usesClampedLiveTuning() throws {
        let view = try source("FRUSExplorer/Analytics/WordCloud/WordCloudView.swift")
        #expect(view.contains("tuning: WordCloudSettings.tuning"),
                "WordCloudSettings.tuning clamps (max(2, minLength) / max(1, minCount)) and is what WordCloudLoader counted the scope with; the view's raw @AppStorage mirrors do not clamp")
        #expect(!view.contains("tuning: .standard"),
                "checking availability against the defaults would defeat the guard entirely — the whole point is that the app follows live settings while the reference is fixed")
    }

    @Test("The measure is persisted, because the macOS host destroys view state on retarget")
    func measureIsPersisted() throws {
        let view = try source("FRUSExplorer/Analytics/WordCloud/WordCloudView.swift")
        #expect(view.contains("@AppStorage(WordCloudSettings.Keys.measure)"),
                "WordCloudWindowContent applies .id(scope.signature) to WordCloudView, so a @State measure would silently revert to frequency on the Mac while surviving the same action on iOS")
        #expect(!view.contains("@State private var measure"))
    }

    @Test("The measure participates in the layout key, or the spiral never re-lays out")
    func measureIsInTheLayoutKey() throws {
        let view = try source("FRUSExplorer/Analytics/WordCloud/WordCloudView.swift")
        // LayoutKey is keyed on termCount, which a RE-RANKING leaves untouched: without the measure
        // the canvas would keep the frequency arrangement while the list re-ordered underneath it.
        let body = try declaration(named: "private struct LayoutKey", in: view)
        #expect(body.contains("let measure: String"),
                "LayoutKey must carry the measure")
        #expect(view.contains("LayoutKey(measure: measureRaw"),
                "…and the call site must actually pass it")
    }

    @Test("The keyness recompute is keyed on the live settings it reads")
    func recomputeKeyIsComplete() throws {
        let view = try source("FRUSExplorer/Analytics/WordCloud/WordCloudView.swift")
        // Bounded at the NEXT declaration, not by a character count. A fixed 700-character window
        // ran past the end of KeynessKey into TaskKey — which declares `exclude`, `settings` and
        // `lens` of its own — so every check below passed on the neighbour's members and the test
        // was vacuous.
        let body = try declaration(named: "private struct KeynessKey", in: view)
        #expect(!body.dropFirst("private struct KeynessKey".count).contains("private struct"),
                "the extracted window ran into the following declaration — the checks below would pass on ITS members")
        // `exclude` is the case the guard exists for and it is one tap away in this view's own
        // Options menu; `settings` covers the tuning. A verdict keyed on the lens alone goes stale.
        for member in ["let exclude: Bool", "let settings: String", "let lens: WordCloudLens"] {
            #expect(body.contains(member), "KeynessKey is missing \(member) — a stale verdict would survive the change it exists to catch")
        }
    }

    @Test("The bundled reference is actually prepared at launch")
    func referenceIsPrepared() throws {
        let app = try source("FRUSExplorer/App/FRUSExplorerApp.swift")
        // Without this every read returns .unavailable(.noArtifact) — indistinguishable from a
        // missing bundle resource, so the whole feature would look wired and be permanently dark.
        #expect(app.contains("await BundledKeynessBaseline.prepare()"),
                "nothing else in the app loads keyness-baseline.json")
    }

    @Test("Export cannot assert frequency ranking over a keyness list")
    func exportNamesTheMeasure() throws {
        let view = try source("FRUSExplorer/Analytics/WordCloud/WordCloudView.swift")
        // A CSV or a plate outlives the screen that explains it, so the measure has to travel in the
        // file itself — the axis label, the value mode, and the figure caption.
        #expect(view.contains("wordcloud.export.axis.keyness"))
        #expect(view.contains("wordcloud.export.caption.keyness"))
        // The method statement must follow the DATA, not the picker. Gated on `measure` instead,
        // an export taken while keyness is selected but unavailable emits frequency rows under a
        // preamble asserting log-likelihood keyness.
        #expect(view.contains("axisLabel: ranking != nil"),
                "the export's axis label must be driven by whether a ranking EXISTS")
        #expect(!view.contains("axisLabel: measure == .keyness"))
        #expect(view.contains("measure == .keyness && ranking == nil"),
                "export must be disabled when Distinctive is selected but no ranking exists")
        let tables = try source("FRUSExplorer/Analytics/Export/AnalyticsChartTables.swift")
        #expect(tables.contains("wordCloudKeynessTable"),
                "the frequency table's Occurrences / Share columns would present a keyness ordering as frequency data")
    }
}
