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

/// An iOS hand-off must land somewhere the user can see (#750).
///
/// ## The family
/// The 2026-08 navigation audit filed seven findings here; they are three defects, each of which
/// delivered a navigation the user could not see:
///
/// 1. **Buried under a stale document** (H-4, M-29) — a search hand-off replaced the query, filters
///    and results, but never popped the Search tab's stack, so a document pushed from an *earlier*
///    search stayed on top while the new search ran beneath it. "Find all mentions" looked like it
///    had opened the wrong document.
/// 2. **Buried under the sheet that sent it** (H-5, H-10, M-15) — Cross-Reference Analytics is
///    presented *by* the Browse tab and hands off *to* the Browse tab, so its taps appended
///    underneath itself; and three reader sheets (Chronology, Citation Lookup, the cross-reference
///    graph) routed every cross-ref and page-turn to the Browse tab rather than their own stack.
/// 3. **Dropped before the tab existed** (H-8, H-11) — `pendingAnalytics` / `pendingChronology` were
///    consumed by `.onChange` only, while their producers write the slot and *then* switch to
///    Browse. On a cold launch or a fresh iPad window the tab switch is what creates the consumer,
///    and `.onChange` never fires for a value already set.
///
/// ## Why these are source-reading tests
/// Every one of these is about what a view does *not* do — pop, dismiss, or drain. Absence has no
/// runtime signature to assert against without a UI harness, and the audit's own verification was
/// static tracing for the same reason. So this reads the source, in the style of
/// `CodingStandardsAuditTests`, `ResetInventoryTests` and `MacWindowFrontingTests`.
///
/// Version history:
///   1.0 — Session 2026-08-08: #750
@Suite("iOS hand-off visibility")
struct HandoffVisibilityTests {

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: appSourceRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Code lines only — these files discuss the old behaviour in comments constantly.
    private static func codeLines(_ source: String) -> [(line: Int, text: String)] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.hasPrefix("//") && !$0.text.hasPrefix("///") && !$0.text.hasPrefix("*") }
    }

    /// The body of `name`, up to `limit` characters — enough to assert what a function does.
    private static func functionBody(_ name: String, in source: String, limit: Int = 1_200) throws -> String {
        let start = try #require(source.range(of: name), "\(name) not found — did it move or get renamed?")
        return String(source[start.lowerBound...].prefix(limit))
    }

    // MARK: - The helper earns its trust

    @Test("codeLines ignores comments but keeps code")
    func codeLinesFilters() {
        let sample = """
            // dismiss() is what the old version was missing
            /// dismiss() again, in a doc comment
            dismiss()
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1, "only the real call is code")
        #expect(kept.first?.text == "dismiss()")
    }

    // MARK: - 1. The search hand-off pops the stack (H-4, M-29)

    @Test("consumePendingSearch pops the Search tab's stack before applying parameters")
    func searchHandoffPopsFirst() throws {
        let source = try Self.source("Search/SearchView.swift")
        let body = try Self.functionBody("private func consumePendingSearch()", in: source)

        #expect(body.contains("vm.navigationPath.removeAll()"), """
            consumePendingSearch must clear the navigation stack. It replaces the query, every \
            filter and the results — but a document pushed from an EARLIER search stayed on top, \
            so the new search ran invisibly beneath it and "Find all mentions" looked like it had \
            opened the wrong document (#750 / H-4, M-29).
            """)

        // Order matters: popping after applying would still render the stale document for a frame,
        // and popping after `runSearch()` would race the results in.
        let popIndex = try #require(body.range(of: "vm.navigationPath.removeAll()"))
        let applyIndex = try #require(body.range(of: "vm.applyParameters(params)"))
        #expect(popIndex.lowerBound < applyIndex.lowerBound,
                "pop before applying the parameters, not after")
    }

    // MARK: - 2a. The analytics sheet dismisses itself (H-5)

    @Test("Cross-Reference Analytics dismisses before handing off on iOS")
    func analyticsSheetDismissesFirst() throws {
        let source = try Self.source("Analytics/CrossReferenceAnalyticsView.swift")
        #expect(source.contains("@Environment(\\.dismiss) private var dismiss"), """
            CrossReferenceAnalyticsView had NO dismiss at all. It is presented by BrowserView and \
            hands off to BrowserView, so its taps appended to the stack directly underneath itself \
            (#750 / H-5).
            """)

        for function in ["private func openDocument(volumeId: String, documentId: String, header: String)",
                         "private func openVolume(_ volumeId: String)"] {
            let body = try Self.functionBody(function, in: source)
            let dismissAt = try #require(body.range(of: "dismiss()"),
                                         "\(function) must dismiss the sheet before handing off")
            let handoffAt = try #require(body.range(of: "appState.openBrowse"))
            #expect(dismissAt.lowerBound < handoffAt.lowerBound,
                    "\(function) must dismiss BEFORE the hand-off, or it lands beneath the sheet")
        }
    }

    // MARK: - 2b. Sheet-hosted readers stay in their own stack (H-10, M-15)

    @Test("DocumentView routes jumps to its host when one is supplied")
    func documentViewHonoursItsHost() throws {
        let source = try Self.source("DocumentView/DocumentView.swift")
        #expect(source.contains("var onNavigateToDocument: ((DocumentBrowserEntry, DocumentJump) -> Void)?"),
                "DocumentView needs a host router; without one a sheet-hosted reader cannot override the Browse-tab routing (#750)")

        // Both jump paths must consult it, and must RETURN rather than falling through to the
        // Browse hand-off as well — a double navigation would be worse than the original bug.
        for function in ["private func navigateToCrossRef(documentId: String, volumeId: String)",
                         "private func navigateToAdjacentDocument(_ adjacent: DocumentBrowserEntry)"] {
            let body = try Self.functionBody(function, in: source, limit: 2_000)
            #expect(body.contains("if let onNavigateToDocument"),
                    "\(function) must route through the host when one is supplied (#750 / H-10)")
            let branch = try #require(body.range(of: "if let onNavigateToDocument"))
            let afterBranch = String(body[branch.lowerBound...].prefix(400))
            #expect(afterBranch.contains("return"),
                    "\(function) must RETURN after the host call, or it also appends to the Browse tab — two navigations")
        }
    }

    @Test("All three reader sheets pass their own stack to DocumentView")
    func readerSheetsSupplyAHost() throws {
        // Named individually: the invariant is per-host, and a new sheet that forgets this
        // reintroduces the bug for its own readers only.
        for relative in ["Chronology/ChronologyView.swift",
                         "Citation/CitationLookupView.swift",
                         "CrossReference/CrossReferenceGraphView.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("onNavigateToDocument:"), """
                \(relative) pushes DocumentView on its own stack, so it must pass \
                onNavigateToDocument — otherwise cross-refs and page-turns inside that reader go to \
                the Browse tab beneath the sheet, the tap reads as dead, and the user's context is \
                lost when they finally close it (#750 / H-10, M-15).
                """)
        }
    }

    @Test("Every iOS host that owns a reader stack routes jumps into it")
    func everyReaderHostSuppliesARouter() throws {
        // SUPERSEDED #750's `browseHostsAreUnchanged`, which asserted the opposite for these two.
        // That test's stated reason — "a cross-ref would push onto the browse stack twice over" —
        // was WRONG: `DocumentView` returns after calling the router, so there is no second
        // navigation. It was really encoding #750's decision to keep the change opt-in. #751 is the
        // owner decision that changed it, so the guard now records the new rule instead.
        for relative in ["Search/SearchView.swift",        // #751: journeys stay in the Search tab
                         "Browser/BrowserView.swift",      // #751 / M-17a: page-turns replace
                         "Chronology/ChronologyView.swift",
                         "Citation/CitationLookupView.swift",
                         "CrossReference/CrossReferenceGraphView.swift"] {
            let source = try Self.source(relative)
            let passes = Self.codeLines(source).filter { $0.text.contains("onNavigateToDocument:") }
            #expect(!passes.isEmpty, """
                \(relative) hosts a DocumentView on its own stack, so it must pass \
                onNavigateToDocument — otherwise cross-references and page-turns leave the reader's \
                context (#751).
                """)
        }
    }

    @Test("A page-turn replaces the reading position; a cross-reference descends")
    func pageTurnsReplaceAndCrossRefsPush() throws {
        // The whole point of DocumentJump. If both jumps pushed, M-17a is unfixed; if both
        // replaced, Back would no longer return to the document a cross-reference came from.
        let source = try Self.source("DocumentView/DocumentView.swift")
        let crossRef = try Self.functionBody(
            "private func navigateToCrossRef(documentId: String, volumeId: String)", in: source, limit: 2_000)
        #expect(crossRef.contains("onNavigateToDocument(crossEntry, .push)"),
                "a cross-reference must PUSH, so Back returns to the document it was in")

        let pageTurn = try Self.functionBody(
            "private func navigateToAdjacentDocument(_ adjacent: DocumentBrowserEntry)", in: source, limit: 2_000)
        #expect(pageTurn.contains("onNavigateToDocument(adjacent, .replace)"),
                "a page-turn must REPLACE — appending is what made 20 pages cost 20 Back taps (M-17a)")
    }

    @Test("Every router host honours .replace rather than always appending")
    func hostsImplementReplace() throws {
        // A host that ignores the jump kind silently reinstates M-17a for its own readers.
        for relative in ["Search/SearchView.swift", "Browser/BrowserView.swift",
                         "Chronology/ChronologyView.swift", "Citation/CitationLookupView.swift",
                         "CrossReference/CrossReferenceGraphView.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("jump == .replace"), """
                \(relative) must act on DocumentJump.replace — removing the current entry before \
                appending — or page-turns stack a level each in that host (#751 / M-17a).
                """)
        }
    }

    // MARK: - 3. The sheet channels drain on appear (H-8, H-11)

    @Test("Analytics and Chronology hand-offs are drained on appear, not just observed")
    func sheetChannelsDrainOnAppear() throws {
        let source = try Self.source("Browser/BrowserView.swift")

        #expect(source.contains("private func consumePendingAnalytics()"),
                "the analytics consumer must be extractable so .onAppear can run it too (#750)")
        #expect(source.contains("private func consumePendingChronology()"),
                "same for chronology (#750)")

        // The drain block must call all four. The two browse channels were already drained; the two
        // sheet channels were the only iOS hand-offs without an appear-time drain, and they are the
        // ones whose producers instantiate Browse as part of the same action.
        let onAppear = try Self.functionBody(".onAppear {", in: source, limit: 1_400)
        for consumer in ["consumePendingBrowseDocument()", "consumePendingBrowseVolume()",
                         "consumePendingAnalytics()", "consumePendingChronology()"] {
            #expect(onAppear.contains(consumer), """
                BrowserView's .onAppear drain must call \(consumer). `.onChange` never fires for a \
                value set before the view attached, and the producers write the slot and THEN call \
                openTab(.browse) — so on a cold launch the hand-off was parked until a later one \
                overwrote it (#750 / H-8, H-11).
                """)
        }
    }

    @Test("Both entry points share one implementation")
    func observersDelegateToTheConsumers() throws {
        // If .onChange kept its own inlined copy, the two paths could drift — which is how the
        // browse channels stayed correct while their siblings did not.
        let source = try Self.source("Browser/BrowserView.swift")
        #expect(source.contains(".onChange(of: appState.pendingAnalytics) { _, _ in consumePendingAnalytics() }"),
                "the analytics observer must delegate to the same consumer .onAppear uses")
        #expect(source.contains(".onChange(of: appState.pendingChronology) { _, _ in consumePendingChronology() }"),
                "the chronology observer must delegate to the same consumer .onAppear uses")
    }
}
