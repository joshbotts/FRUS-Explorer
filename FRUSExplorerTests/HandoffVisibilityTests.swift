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
    ///
    /// Callers pass the declaration up to the OPENING PAREN only — `"private func foo("` — never a
    /// frozen parameter list. #988 added a `footnoteAnchor:` parameter to `navigateToCrossRef` and
    /// the full-signature literals here stopped matching, so `#require` failed on the lookup rather
    /// than on the behaviour: the guard was unrunnable, and it shipped that way because the PR that
    /// changed the signature did not run this suite.
    private static func functionBody(_ name: String, in source: String, limit: Int = 1_200) throws -> String {
        _ = try #require(source.range(of: name), "\(name) not found — did it move or get renamed?")
        // Slice CODE, not raw text. The character window is meant to bound how much of a function
        // an assertion sees; measured against raw source it bounds how much PROSE precedes the
        // code instead, so a long explanatory comment silently pushes the statements out of range
        // and the assertion fails on something the author never changed. That is what happened to
        // both guards here after #988 documented its branch at length.
        let code = codeLines(source).map(\.text)
        guard let startLine = code.firstIndex(where: { $0.contains(name) }) else {
            Issue.record("\(name) not found among code lines — did it move or get renamed?")
            return ""
        }
        return code[startLine...].joined(separator: "\n").prefix(limit).description
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

    @Test("Cross-Reference Analytics dismisses the SHEET before handing off, and the window does not")
    func analyticsSheetDismissesFirst() throws {
        let source = try Self.source("Analytics/CrossReferenceAnalyticsView.swift")

        // The contract changed shape in CW-9e and got STRICTER, not looser. The view used to call
        // `dismiss()` itself. That is right for the sheet — BrowserView both presents it and
        // consumes the hand-off, so without dismissing first the document lands on the stack
        // underneath and the tap reads as dead (#750 / H-5) — and fatal for the window this
        // surface now also opens in, where `dismiss()` CLOSES THE SCENE. So the dismissal is
        // injected: the sheet passes one, the window passes nil.
        //
        // Both halves are checked. Losing either reintroduces a real defect: no callback at all
        // puts the document under the sheet again, and a callback in the window closes the
        // analysis on the reader's first citation tap.
        #expect(source.contains("var onNavigate: (() -> Void)?"), """
            CrossReferenceAnalyticsView lost its injected navigate callback. It is presented BOTH             as a sheet and as a window, and those need opposite behaviour on a row tap — the sheet             must dismiss, the window must not (#750 / H-5, CW-9e).
            """)

        for function in ["private func openDocument(volumeId: String, documentId: String, header: String)",
                         "private func openVolume(_ volumeId: String)"] {
            let body = try Self.functionBody(function, in: source)
            let notifyAt = try #require(body.range(of: "onNavigate?()"),
                                        "\(function) must invoke the navigate callback before handing off")
            let handoffAt = try #require(body.range(of: "appState.openBrowse"))
            #expect(notifyAt.lowerBound < handoffAt.lowerBound,
                    "\(function) must notify BEFORE the hand-off, or the sheet's dismissal races the push")
            #expect(!body.contains("dismiss()"), """
                \(function) calls dismiss() directly again. In the window presentation that closes \
                the scene on the first landmark tap — the whole reason the callback is injected.
                """)
        }

        // The sheet supplies the dismisser; the window's nil is pinned by
        // `AnalyticsWindowValueTests.crossRefWindowKeepsItsNavigateCallbackNil`.
        let browser = try Self.source("Browser/BrowserView.swift")
        #expect(browser.contains("CrossReferenceAnalyticsView(onNavigate:"),
                "the sheet presentation must pass a dismisser, or a row tap lands beneath it")
    }

    // MARK: - 2b. Sheet-hosted readers stay in their own stack (H-10, M-15)

    @Test("DocumentView routes jumps to its host when one is supplied")
    func documentViewHonoursItsHost() throws {
        let source = try Self.source("DocumentView/DocumentView.swift")
        #expect(source.contains("var onNavigateToDocument: ((DocumentBrowserEntry, DocumentJump) -> Void)?"),
                "DocumentView needs a host router; without one a sheet-hosted reader cannot override the Browse-tab routing (#750)")

        // Both jump paths must consult it, and must RETURN rather than falling through to the
        // Browse hand-off as well — a double navigation would be worse than the original bug.
        for function in ["private func navigateToCrossRef(",
                         "private func navigateToAdjacentDocument("] {
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
            "private func navigateToCrossRef(", in: source, limit: 2_000)
        #expect(crossRef.contains("onNavigateToDocument(crossEntry, .push)"),
                "a cross-reference must PUSH, so Back returns to the document it was in")

        let pageTurn = try Self.functionBody(
            "private func navigateToAdjacentDocument(", in: source, limit: 2_000)
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
        #expect(source.contains("private func consumePendingSemanticMap()"),
                "same for the semantic map handed off from another device (UI review F-28)")

        // The drain block must call all four. The two browse channels were already drained; the two
        // sheet channels were the only iOS hand-offs without an appear-time drain, and they are the
        // ones whose producers instantiate Browse as part of the same action.
        // The window is generous on purpose: it is a scan budget, not an assertion about how long
        // the drain may be, and a correct new consumer must not fail this test by pushing an
        // existing one past the edge — which is exactly what CW-7c's semantic-map channel did.
        // **The drain block is identified by its CONTENT, not by being the first `.onAppear`.**
        // It used to be the latter, which quietly assumed no other `.onAppear` could ever precede
        // it in the file — and F-2's two-pane added exactly that: a
        // `.onAppear { containerWidth = proxy.size.width }` inside the layout's geometry reader,
        // which sits earlier in `body` and captured the scan. The test then failed on a change
        // that had nothing to do with hand-offs, reporting a missing consumer that was present
        // twenty lines further down.
        //
        // Searching for the block that actually contains a consumer is strictly stronger: it
        // cannot be fooled by an unrelated `.onAppear` on either side of it, and it still fails if
        // the drain loses a consumer or disappears entirely.
        // Found by walking BACKWARD from the anchor to the nearest preceding `.onAppear {`. A
        // forward scan is not enough: a 2,400-character window opened at an unrelated earlier
        // `.onAppear` still *reaches* the drain, so "the window contains the anchor" is satisfied
        // by the wrong block. The nearest preceding opener is the block the anchor is actually in.
        // Each `.onAppear` block is bounded by the NEXT one (or the 2,400-character budget,
        // whichever comes first), and the drain is the block that contains a consumer. Both
        // bounds matter: without the next-opener bound an unrelated earlier `.onAppear` reaches
        // the drain and captures the scan; without the anchor the first block wins by position
        // alone. Searching backward from the anchor does not work either — its first occurrence
        // in the file is the consumer's own `private func` declaration.
        let anchor = "consumePendingBrowseDocument()"
        var openers: [Range<String.Index>] = []
        var cursor = source.startIndex
        while let hit = source.range(of: ".onAppear {", range: cursor..<source.endIndex) {
            openers.append(hit)
            cursor = hit.upperBound
        }
        let blocks: [String] = openers.enumerated().map { index, opener in
            let hardLimit = source.index(opener.lowerBound, offsetBy: 2_400,
                                         limitedBy: source.endIndex) ?? source.endIndex
            let end = index + 1 < openers.count
                ? min(openers[index + 1].lowerBound, hardLimit)
                : hardLimit
            return String(source[opener.lowerBound..<end])
        }
        let onAppear = try #require(blocks.first { $0.contains(anchor) }, """
            No `.onAppear` block in BrowserView calls \(anchor). The appear-time drain is the #750 \
            fix — without it a cold-launch hand-off is parked until a later one overwrites it — \
            and `.onChange` cannot substitute, because it never fires for a value set before the \
            view attached (H-8, H-11).
            """)
        for consumer in ["consumePendingBrowseDocument()", "consumePendingBrowseVolume()",
                         "consumePendingAnalytics()", "consumePendingChronology()",
                         "consumePendingSemanticMap()"] {
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

    // MARK: - A navigation the reader did not ask for

    /// The two sheets whose reading stack is `@State` on the **presenter**, and must therefore be
    /// cleared when the sheet goes away.
    ///
    /// Every other sheet in the app that owns a `NavigationStack(path:)` declares that path inside
    /// the PRESENTED view — Chronology, Citation Lookup, Related Documents, Archival Neighbours all
    /// do — so SwiftUI recreates it per presentation and it resets for free. These two are
    /// different: #553 gave Project Home a stack owned by the presenting view, so the path outlives
    /// the presentation. Closing the sheet two documents deep and reopening it put the reader back
    /// inside the second document, with nothing on screen to say why; reached through the project
    /// picker, which is how you SWITCH projects, it showed a document from the project just left.
    ///
    /// This is the same family as the rest of this suite — a navigation the reader cannot account
    /// for — arriving from the other direction: not a hand-off they could not see, but one they
    /// never asked for.
    ///
    /// `onDismiss` is the required hook, not the Done button: a swipe-down never runs that button's
    /// action, and swiping is how a sheet is usually closed.
    static let presenterOwnedSheetPaths = [
        ("Research/ResearchView.swift", "projectHomePath"),
        ("ProjectContext/ProjectPickerMenu.swift", "homeSheetPath"),
    ]

    @Test("A sheet whose stack lives on the presenter clears it on dismiss")
    func presenterOwnedSheetPathsResetOnDismiss() throws {
        for (file, path) in Self.presenterOwnedSheetPaths {
            let source = try Self.source(file)
            let code = Self.codeLines(source).map(\.text).joined(separator: "\n")
            // Fixture guard: if the path stopped being presenter-owned, this test is measuring
            // nothing and should be deleted rather than left passing.
            #expect(code.contains("@State private var \(path)"),
                    "\(file) no longer declares \(path) on the presenter — re-scope this test")
            #expect(code.contains("NavigationStack(path: $\(path))"),
                    "\(file) no longer binds \(path) to a NavigationStack")
            #expect(code.contains("onDismiss: { \(path) = [] }"), """
                \(file) presents a sheet over \(path) without clearing it on dismiss. The path is \
                @State on the PRESENTER, so it survives the presentation and the next open lands \
                inside the last document read — after a project switch, a document from the \
                previous project.
                """)
        }
    }
}
