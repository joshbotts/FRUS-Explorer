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
#if canImport(UIKit)
import UIKit
#endif
@testable import FRUSExplorer

/// The Q-wave re-glyph of the search actions bar (`examineMenu`).
///
/// Two things are pinned here: that ``ResultReading`` really is a single-selection projection over
/// the three flags the view body still reads, and that every symbol the control names actually
/// exists. The second matters more than it looks — a `systemImage` naming a symbol that is not in
/// the catalog renders as a blank, and nothing in the compiler, the test suite or a code review
/// catches it. The app is currently shipping exactly that bug elsewhere (`cloud.slash`).
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Result reading projection")
struct ResultReadingTests {

    // MARK: - The projection

    @Test("Every reading round-trips through its own flags")
    func roundTrip() {
        for reading in ResultReading.allCases {
            let flags = reading.flags
            let recovered = ResultReading.active(timeline: flags.timeline,
                                                 concordance: flags.concordance,
                                                 collocates: flags.collocates)
            #expect(recovered == reading, "\(reading) did not survive the round trip")
        }
    }

    @Test("No reading ever sets more than one flag")
    func exclusivity() {
        for reading in ResultReading.allCases {
            let flags = reading.flags
            let on = [flags.timeline, flags.concordance, flags.collocates].filter { $0 }.count
            #expect(on <= 1, "\(reading) set \(on) flags")
            // `.list` is the ABSENCE of a reading, not a fourth one — it must set none.
            #expect(on == (reading == .list ? 0 : 1))
        }
    }

    @Test("All flags off is the list, not a reading")
    func noFlagsIsList() {
        #expect(ResultReading.active(timeline: false, concordance: false, collocates: false) == .list)
    }

    /// The flags are three independent `@State` bools, so an inconsistent triple is representable
    /// even though nothing should now produce one. The precedence must match `resultsList`'s
    /// `else if` chain — collocates, then concordance, then timeline — or the control would name
    /// one reading while the screen showed another.
    @Test("Precedence on an inconsistent triple matches the view body's chain")
    func precedenceMatchesResultsList() {
        #expect(ResultReading.active(timeline: true, concordance: true, collocates: true) == .collocates)
        #expect(ResultReading.active(timeline: true, concordance: true, collocates: false) == .concordance)
        #expect(ResultReading.active(timeline: true, concordance: false, collocates: true) == .collocates)
        #expect(ResultReading.active(timeline: false, concordance: true, collocates: true) == .collocates)
    }

    @Test("List is offered first, so the menu's default reads as the plain result list")
    func listIsFirst() {
        #expect(ResultReading.allCases.first == .list)
        #expect(ResultReading.allCases.count == 4)
    }

    @Test("Every reading has a distinct, non-empty title")
    func titles() {
        let titles = ResultReading.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count, "two readings share a title: \(titles)")
    }

    // MARK: - The glyphs

    #if canImport(UIKit)
    /// Every symbol the readings name must resolve. A `systemImage` that does not exist renders as
    /// nothing at all and is invisible to the compiler.
    @Test("Every reading's glyph exists in the SF Symbols catalog")
    func readingGlyphsResolve() {
        for reading in ResultReading.allCases {
            #expect(UIImage(systemName: reading.systemImage) != nil,
                    "\(reading) names a symbol that does not exist: \(reading.systemImage)")
        }
    }

    /// The control's own mark, in both states. `binoculars.fill` is what makes an active reading
    /// visible on the control — the previous glyph filled only for Timeline, so turning on
    /// Concordance or Collocates replaced the entire results region while the control looked
    /// untouched.
    @Test("The examine control's own glyphs exist, in both states")
    func examineGlyphsResolve() {
        #expect(UIImage(systemName: "binoculars") != nil)
        #expect(UIImage(systemName: "binoculars.fill") != nil)
    }

    /// Guards the test above against passing vacuously: `UIImage(systemName:)` must actually
    /// return nil for a name that is not in the catalog, or the two tests above prove nothing.
    @Test("The glyph check can fail")
    func glyphCheckIsNotVacuous() {
        #expect(UIImage(systemName: "binoculars.not.a.real.variant") == nil)
        // The real bug this shape of test is meant to catch, shipped elsewhere in the app today.
        #expect(UIImage(systemName: "cloud.slash") == nil)
    }
    #endif
}

// MARK: - ExamineMenuAuditTests

/// Source audits for the Q-wave restructure of the search actions bar.
///
/// These pin claims that no runtime test can reach: which items are in which menu, and which
/// literal drives the Large Content Viewer. Each assertion is scoped to a single brace-matched
/// declaration rather than a fixed-size window, because a window that overruns into the next
/// member passes for the wrong reason.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Examine menu structure")
struct ExamineMenuAuditTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// The body of a declaration, from its opening brace to the brace that matches it.
    ///
    /// Brace matching rather than a line count: `examineMenu` and `moreMenu` are adjacent, so a
    /// fixed window over one of them reaches into the other and every "is X absent from this
    /// menu?" assertion would pass vacuously.
    private static func declaration(_ signature: String, in source: String) throws -> String {
        let start = try #require(source.range(of: signature), "no declaration: \(signature)")
        var depth = 0
        var index = start.lowerBound
        var opened = false
        while index < source.endIndex {
            let character = source[index]
            if character == "{" { depth += 1; opened = true }
            if character == "}" {
                depth -= 1
                if opened, depth == 0 { return String(source[start.lowerBound...index]) }
            }
            index = source.index(after: index)
        }
        Issue.record("unbalanced braces after \(signature)")
        return ""
    }

    // MARK: - The slicer itself

    /// Without this, every absence assertion below could pass because the slicer returned "".
    @Test("The declaration slicer returns a bounded, non-empty body")
    func slicerIsSound() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let examine = try Self.declaration("private var examineMenu: some View {", in: source)
        let more = try Self.declaration("private var moreMenu: some View {", in: source)

        #expect(!examine.isEmpty)
        #expect(!more.isEmpty)
        // Bounded: neither slice may swallow the other, or the absence checks prove nothing.
        #expect(!examine.contains("private var moreMenu"))
        #expect(!more.contains("private var examineMenu"))
        // Each is a real body, not just the signature line.
        #expect(examine.contains("Menu {"))
        #expect(more.contains("Menu {"))
    }

    // MARK: - Membership

    @Test("Save as Working Corpus is not among the readings")
    func saveIsNotAReading() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let examine = try Self.declaration("private var examineMenu: some View {", in: source)
        #expect(!examine.contains("showSaveCorpusSheet"),
                "the capture action is back inside the examine menu")
        #expect(!examine.contains("search.corpus.save"))
    }

    @Test("Save as Working Corpus sits in the overflow menu beside Save this search")
    func saveLivesInMoreMenu() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let more = try Self.declaration("private var moreMenu: some View {", in: source)
        #expect(more.contains("showSaveCorpusSheet"))
        #expect(more.contains("search.corpus.save"))
        // Adjacency is the point: saving the results is the sibling of saving the query.
        let query = try #require(more.range(of: "search.saveSearch.a11y"))
        let results = try #require(more.range(of: "search.corpus.save"))
        let between = String(more[query.upperBound..<results.lowerBound])
        // Naming the actual siblings, not counting `Label(` — the corpus row's own `Label` opens
        // before its key, so it always falls in this span and a `Label(` check can never pass.
        #expect(!between.contains("search.savedSearches.a11y"))
        #expect(!between.contains("search.citationLookup.a11y"))
    }

    @Test("The capture action keeps its own enablement rule after the move")
    func saveKeepsItsGate() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let more = try Self.declaration("private var moreMenu: some View {", in: source)
        #expect(more.contains(".disabled(vm.displayedResults.isEmpty)"),
                "Save must gate on displayedResults, not results — it captures what is retained")
    }

    // MARK: - The glyph

    @Test("The examine control is a binoculars, in both states, and no longer a chart")
    func controlGlyph() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let examine = try Self.declaration("private var examineMenu: some View {", in: source)
        #expect(examine.contains(#"Image(systemName: activeReading == .list ? "binoculars" : "binoculars.fill")"#))
        #expect(!examine.contains(#""chart.bar.fill""#), "the control still fills as a chart")
    }

    /// `.controlHelp`'s `systemImage:` is a separate literal driving the Large Content Viewer HUD.
    /// Left behind, a low-vision user keeps seeing the old glyph after the visible one has moved.
    @Test("The Large Content Viewer literal moved with the visible glyph")
    func largeContentViewerGlyph() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let examine = try Self.declaration("private var examineMenu: some View {", in: source)
        let help = try #require(examine.range(of: ".controlHelp("))
        let tail = String(examine[help.lowerBound...])
        #expect(tail.contains(#"systemImage: "binoculars""#))
        #expect(!tail.contains(#"systemImage: "chart.bar""#))
    }

    @Test("The control announces which reading is active")
    func announcesItsValue() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let examine = try Self.declaration("private var examineMenu: some View {", in: source)
        #expect(examine.contains(".accessibilityValue(activeReading.title)"))
    }

    /// The readings must be a `Picker`, not four `Button`s: `Label(_:systemImage:)` contributes no
    /// accessible text, so a checkmark swapped into the icon slot is silent to VoiceOver.
    @Test("The readings are a single-selection Picker")
    func readingsArePicker() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let examine = try Self.declaration("private var examineMenu: some View {", in: source)
        #expect(examine.contains("Picker("))
        #expect(examine.contains("selection: readingSelection"))
        #expect(!examine.contains(#""checkmark""#), "state is back to a hand-swapped checkmark")
    }

    // MARK: - macOS

    /// On macOS the capture action sat physically between Concordance and Collocates — an action
    /// in the middle of three mutually exclusive readings.
    @Test("macOS orders the three readings together, then the capture action")
    func macOSGrouping() throws {
        let source = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        let collocates = try #require(source.range(of: "search.collocates.show.a11y"))
        let save = try #require(source.range(of: #"Image(systemName: "tray.full")"#))
        #expect(save.lowerBound > collocates.upperBound,
                "the capture action is back between two readings")
    }

    /// macOS showed `text.alignright` for the INACTIVE concordance — the symbol iOS uses for the
    /// ACTIVE one, so the same state read as two different glyphs across platforms.
    @Test("macOS concordance keeps one glyph and lets tint carry the state")
    func macOSConcordanceGlyph() throws {
        let source = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        #expect(!source.contains(#""text.alignright""#))
        #expect(source.contains(#"Image(systemName: "text.alignleft")"#))
    }
}

// MARK: - ReadingDenominatorTests

/// Which reading states its own denominator, and which deliberately does not.
///
/// The five surfaces behind the examine control span three sets — the concordance covers one
/// page, the list/timeline/collocates the whole retained set, the facets the whole match before
/// narrowing — and each produces a quotable number. "214 occurrences" reads as a fact about the
/// search rather than about twenty-five rows.
///
/// Only the two OUTLIERS are labelled. That restraint is the design, not an omission, so it is
/// pinned: annotate all five and the distinction disappears into the annotation.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Reading denominators")
struct ReadingDenominatorTests {

    @Test("Only the concordance names its own set among the readings")
    func onlyTheOutlierIsLabelled() {
        #expect(ResultReading.concordance.denominatorDescription != nil)
        #expect(ResultReading.list.denominatorDescription == nil)
        #expect(ResultReading.timeline.denominatorDescription == nil)
        #expect(ResultReading.collocates.denominatorDescription == nil)
    }

    /// The restraint, stated as a count so that labelling a second reading fails here and has to
    /// be a decision rather than a drift.
    @Test("Exactly one reading carries a denominator")
    func exactlyOneLabelled() {
        let labelled = ResultReading.allCases.filter { $0.denominatorDescription != nil }
        #expect(labelled == [.concordance],
                "labelled: \(labelled.map(\.rawValue)) — annotating more dissolves the contrast")
    }

    @Test("The concordance says it is the page, and the facets the whole match")
    func theTwoOutliersSayWhatTheyAre() throws {
        let concordance = try #require(ResultReading.concordance.denominatorDescription)
        #expect(concordance.localizedCaseInsensitiveContains("page"))
        #expect(ResultReading.facetsDenominatorDescription
            .localizedCaseInsensitiveContains("whole match"))
        #expect(ResultReading.facetsDenominatorDescription
            .localizedCaseInsensitiveContains("narrowing"))
    }

    /// The two must not say the same thing — they exist to contrast.
    @Test("The two denominators are distinct")
    func theyContrast() throws {
        let concordance = try #require(ResultReading.concordance.denominatorDescription)
        #expect(concordance != ResultReading.facetsDenominatorDescription)
    }
}
