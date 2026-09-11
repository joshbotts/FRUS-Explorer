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
import SwiftUI   // NavigationPath, for the tenth host's overload
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
                         "CrossReference/CrossReferenceGraphView.swift",
                         "DocumentView/InPlaceDocumentReader.swift"] {   // 2026-09-11: tab-scoped reads
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

    /// Every router host routes its jump through the ONE shared rule.
    ///
    /// ## This assertion replaces a vacuous one, and the vacuity was measured
    /// The previous guard asserted that the literal `jump == .replace` appeared in each host's
    /// file, scanning RAW source. It never referenced `removeLast()` — the line that does the
    /// work. Deleting `vm.navigationPath.removeLast()` from `BrowserView` left that literal in
    /// place, reinstating M-17a in full (twenty page-turns costing twenty Back taps), and this
    /// suite stayed GREEN. Verified by running the mutant on 2026-08-20.
    ///
    /// Two things changed so that cannot recur. The rule now lives in ONE function that a real
    /// test drives (`DocumentJumpPathTests` below, which observes the resulting depth). And this
    /// scan matches the CALL rather than a literal that a comment could satisfy — a host that
    /// stops calling `jump.apply` has stopped honouring the jump, which is exactly the claim.
    @Test("Every router host routes its jump through the one shared rule")
    func hostsImplementReplace() throws {
        // A host that ignores the jump kind silently reinstates M-17a for its own readers.
        for relative in ["Search/SearchView.swift", "Browser/BrowserView.swift",
                         "Chronology/ChronologyView.swift", "Citation/CitationLookupView.swift",
                         "CrossReference/CrossReferenceGraphView.swift",
                         "Research/ResearchView.swift", "ProjectContext/ProjectPickerMenu.swift",
                         "RelatedDocuments/RelatedDocumentsView.swift",
                         "SourceExplorer/ArchivalNeighborsSheet.swift",
                         "DocumentView/InPlaceDocumentReader.swift"] {
            // codeLines, NOT raw source: these files discuss the old behaviour in comments
            // constantly, which is precisely how the previous guard came to assert nothing.
            let code = Self.codeLines(try Self.source(relative))
            #expect(code.contains { $0.text.contains("jump.apply(to:") }, """
                \(relative) must route its DocumentJump through DocumentJump.apply(to:appending:) \
                — the one place the pop-before-append rule lives — or page-turns stack a level \
                each in that host (#751 / M-17a).
                """)
        }
    }

    /// A document opened inside a tab reads in that tab (the owner's 2026-09-11 decision, reopening
    /// O-3's point 2).
    ///
    /// Each producer named here used to call `openTab(.browse)` + `openBrowseDocument`, so the document
    /// opened in the Browse tab and Back unwound Browse's own history rather than returning to the
    /// list the reader came from. They now reach `InPlaceDocumentReader` in their own stack. Named
    /// per producer, because the invariant is per-route: a new list that forgets it reintroduces the
    /// bug for its own readers only. Scanned as CODE lines — these files discuss the old routing in
    /// comments, which is exactly how an earlier guard in this suite came to assert nothing.
    @Test("A document opened inside a tab reads in that tab, not in Browse")
    func tabHostedOpensReadInPlace() throws {
        // Producers that always have a stack to read in: no Browse hand-off may remain — neither the
        // document nor the tab switch, since a leftover `openTab(.browse)` beside an in-place read would
        // still take the reader out of the tab they are working in.
        for (relative, opener) in [("Research/ResearchView.swift", "readingChain = [browsEntry]"),
                                   ("Collections/CollectionEditorView.swift", "readingChain = [browseEntry]"),
                                   ("TripPacket/ArchiveVisitEditorView.swift", "readingChain = [entry]"),
                                   ("Settings/SettingsView.swift", "onOpenInSheet: { readingChain = [$0] }")] {
            let code = Self.codeLines(try Self.source(relative)).map(\.text)
            #expect(code.contains { $0.contains(opener) },
                    "\(relative) must open the document in its own stack (`\(opener)`)")
            #expect(code.contains { $0.contains(".inPlaceReader($readingChain)") },
                    "\(relative) must declare the in-place reader its opener drives, or nothing is pushed")
            #expect(!code.contains { $0.contains("appState.openBrowseDocument(") }, """
                \(relative) hands a document to the Browse tab again. The reader leaves the tab they \
                are working in, and Back unwinds Browse's history instead of returning to this list.
                """)
            #expect(!code.contains { $0.contains("openTab(.browse") }, """
                \(relative) switches to the Browse tab again. Even beside an in-place read, that takes \
                the reader out of the tab they are working in.
                """)
        }

        // History is hosted by Research, which passes the opener; the fallback stays for a host that
        // offers no stack. The branch must CALL the opener and then RETURN — without the call the tap
        // does nothing, and without the return it also hands the document to Browse.
        let history = Self.codeLines(try Self.source("History/HistoryView.swift")).map(\.text)
        #expect(history.contains("var onOpenDocument: ((DocumentBrowserEntry) -> Void)? = nil"))
        let research = Self.codeLines(try Self.source("Research/ResearchView.swift")).map(\.text)
        #expect(research.contains { $0.contains("HistoryView(onOpenDocument: { readingChain = [$0] })") },
                "Research must pass History its opener, or the trail still hands off to Browse")
        let historySource = try Self.source("History/HistoryView.swift")
        let body = try Self.functionBody("private func openDocument(", in: historySource, limit: 1_400)
        let branch = try #require(body.range(of: "if let onOpenDocument"))
        let arm = String(body[branch.lowerBound...].prefix(160))
        let call = try #require(arm.range(of: "onOpenDocument(entry)"),
                                "History must hand the tapped document to its opener")
        let exit = try #require(arm.range(of: "return"),
                                "History must RETURN after reading in place, or it also hands the document to Browse")
        #expect(call.lowerBound < exit.lowerBound, "History must read in place BEFORE it returns")

        // Project Home reached from Settings reads through its host, like its two sheet presenters.
        let settings = Self.codeLines(try Self.source("Settings/SettingsView.swift")).map(\.text)
        #expect(settings.contains { $0.contains("ProjectHomeReadingHost(projectId: pid)") },
                "Settings must push Project Home inside the host that gives it a stack")
    }

    /// Opening a seeded document pushes the reader over the Archives Visit editor, so the editor's
    /// appear-time seeding runs again on Back — and it must not overwrite a rename the reader typed but
    /// never submitted. Review found exactly that: while the open still switched tabs the editor never
    /// disappeared and the draft survived, so reading in place is what exposed the unconditional seed.
    @Test("Returning from a seeded document keeps an unsubmitted plan rename")
    func archiveVisitDraftSurvivesTheReader() throws {
        let code = Self.codeLines(try Self.source("TripPacket/ArchiveVisitEditorView.swift")).map(\.text)
        #expect(!code.contains(".task(id: plan.id) { nameDraft = plan.name }"), """
            The unconditional seed is back: every seeded document opened and closed discards the name \
            the reader was typing.
            """)
        let seed = try #require(code.firstIndex(of: ".task(id: plan.id) {"),
                                "the editor no longer seeds its name draft from a plan-keyed task")
        let task = code[seed...].prefix(6)
        #expect(task.contains { $0.contains("nameDraft == draftSeed?.name") },
                "re-seed only when the reader has not typed since the last seed")
        #expect(task.contains { $0.contains("draftSeed?.plan != AnyHashable(plan.id)") },
                "a different plan must still re-seed, or one plan's draft shows under another's name")
    }

    /// The in-place reader applies every jump to its HOST's chain — pinned on the view, not the helper.
    ///
    /// The first version of this suite accepted `jump.apply(to:` anywhere in the reader's file, and the
    /// helper enum satisfied it: review showed a reader whose closure pushed on every page-turn, ignored
    /// page-turns, or never presented a cross-reference would all have stayed green. So this reads the
    /// view's own body for the calls that do the work, and `InPlaceReadingTests` drives the rule they call.
    @Test("The in-place reader routes every jump into its host's reading chain")
    func inPlaceReaderUsesTheChain() throws {
        let source = try Self.source("DocumentView/InPlaceDocumentReader.swift")
        let view = try Self.functionBody("struct InPlaceDocumentReader: View", in: source, limit: 2_000)
        let bodyStart = try #require(view.range(of: "var body: some View"), "the reader lost its body")
        let bodyCode = String(view[bodyStart.lowerBound...])
        #expect(bodyCode.contains("InPlaceReading.apply(jump, to: &chain, at: level, target: target)"), """
            The reader must apply its document's jumps to the host's chain. Anything else loses page-turns \
            or cross-references — or keeps them in views a layout change rebuilds.
            """)
        #expect(bodyCode.contains(".navigationDestination(isPresented: InPlaceReading.presentation(above: level, in: $chain))"),
                "a cross-reference must present the next level of the chain, or the tap does nothing")
        #expect(bodyCode.contains("InPlaceDocumentReader(chain: $chain, level: level + 1)"),
                "the next level must be another in-place reader on the same chain")
        #expect(bodyCode.contains(".workingOnSubtitle()"),
                "Browse and Search keep the research question in the title on iPad; so must a document read in place")

        let host = try Self.functionBody("func inPlaceReader(", in: source, limit: 400)
        #expect(host.contains("navigationDestination(isPresented: InPlaceReading.presentation(above: -1, in: chain))"),
                "a host's reader must present while its chain holds a document")
        #expect(host.contains("InPlaceDocumentReader(chain: chain, level: 0)"),
                "a host's reader must start at the bottom of its chain")

        let rule = try Self.functionBody("static func apply(", in: source, limit: 500)
        #expect(rule.contains("jump.apply(to: &visible, appending: target)"),
                "the chain rule must be DocumentJump's — the one Browse and Search use")
    }

    /// A topic chip in the rail must reach the Topic index from a document read in ANY tab.
    ///
    /// The index is a Browse-tab level whose hand-off replaces Browse's path. Handed off from the
    /// rail, the tap was visible only from a document read in Browse — so once documents read in their
    /// own tabs, it changed nothing the reader could see from Research, Collections or Settings (and
    /// never had from Search), while wiping Browse's history. The rail now asks its host, and the host
    /// closes the iPhone rail sheet and brings Browse forward: the "Find all mentions" shape.
    @Test("A rail topic chip brings the Browse tab forward, from whichever tab the document is in")
    func railTopicChipSwitchesToBrowse() throws {
        let rail = try Self.functionBody("private func openTopic(",
                                         in: try Self.source("DocumentView/ResearchRailView.swift"))
        let railLines = rail.split(separator: "\n").map(String.init)
        let iOSStart = try #require(railLines.firstIndex(of: "#else"), "openTopic lost its iOS arm")
        let iOSEnd = try #require(railLines[iOSStart...].firstIndex(of: "#endif"))
        let iOSArm = railLines[(iOSStart + 1)..<iOSEnd]
        #expect(iOSArm.contains("onOpenTool(.topic(request))"), """
            The rail's topic chip must ask its host on iOS. Handed off from the rail, the Topic index \
            changes Browse out of sight, and nothing happens for a reader in any other tab.
            """)
        #expect(!iOSArm.contains { $0.contains("appState.openSubjectExplorer(") },
                "the rail must not hand off itself — only the host can close the rail sheet and switch tabs")

        let host = try Self.functionBody("private func openRailTool(",
                                         in: try Self.source("DocumentView/DocumentView.swift"),
                                         limit: 2_400)
        let hostLines = host.split(separator: "\n").map(String.init)
        let armStart = try #require(hostLines.firstIndex(of: "case .topic(let request):"),
                                    "DocumentView must handle the rail's topic request")
        let arm = hostLines[(armStart + 1)...].prefix { !$0.hasPrefix("case ") && $0 != "}" }
        #expect(arm.contains("activeSheet = nil"),
                "on iPhone the rail is a sheet — switching tabs beneath it leaves it covering the index")
        #expect(arm.contains("appState.openSubjectExplorer(request, from: sceneID)"))
        #expect(arm.contains("appState.openTab(.browse, from: sceneID)"), """
            The host must bring Browse forward. Without it the tap replaces Browse's path out of sight, \
            from every tab but Browse.
            """)
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

// MARK: - DocumentJumpPathTests

/// Drives `DocumentJump.apply(to:appending:)` — the one rule every reader host now routes through.
///
/// ## Why this suite exists
/// #751's M-17a fix (a page-turn *replaces* the current document rather than deepening the stack)
/// shipped across ten hosts as ten copies of the same three lines, each buried in a `private func`
/// inside a `View`. Nothing could observe it, so the only guard was a source scan — and that scan
/// asserted a literal (`jump == .replace`) which a surviving `if` statement satisfies with its body
/// deleted. **Measured 2026-08-20: removing `removeLast()` from `BrowserView` reinstated M-17a in
/// full and the whole suite stayed green.**
///
/// Extracting the rule is what makes it observable. These tests assert the resulting **depth**,
/// which is the property the reader actually experiences: how many Back taps it costs to leave.
///
/// Version history:
///   1.0 — Session 2026-08-20: #751, replacing the vacuous source-scan guard
@Suite("Document jump path arithmetic")
struct DocumentJumpPathTests {

    /// A cross-reference is a descent, so Back must return to the document that cited it (H-3).
    @Test("push deepens the stack")
    func pushAppends() {
        var path = ["volume", "d1"]
        DocumentJump.push.apply(to: &path, appending: "d2")
        #expect(path == ["volume", "d1", "d2"], "a cross-reference must remain reachable by Back")
    }

    /// **The M-17a scenario, at the size the audit complained about.** Twenty page-turns must cost
    /// ONE Back tap, not twenty. Deleting the `removeLast()` inside `apply` makes this 21.
    @Test("twenty page-turns leave the stack exactly as deep as one")
    func replaceKeepsDepthConstant() {
        var path = ["volume", "d1"]
        for n in 2...21 {
            DocumentJump.replace.apply(to: &path, appending: "d\(n)")
        }
        #expect(path.count == 2, """
            Paging through twenty documents left a stack \(path.count) deep, so leaving the volume \
            costs \(path.count - 1) Back taps. That is audit M-17a exactly, and there is no \
            breadcrumb escape at document level — none at all on regular-width iPad.
            """)
        #expect(path == ["volume", "d21"], "the reader's position must be the LAST document paged to")
    }

    /// The owner's 2026-08-20 device observation, pinned: after paging, Back lands on the volume.
    /// Everything beneath the replaced entry must survive — `.replace` pops one level, never more.
    @Test("replace pops exactly one level, so the entry beneath survives")
    func replacePreservesEverythingBeneath() {
        var path = ["corpus", "subseries", "volume", "d4"]
        DocumentJump.replace.apply(to: &path, appending: "d5")
        #expect(path == ["corpus", "subseries", "volume", "d5"], """
            A page-turn must replace only the document. Back after paging lands on the volume, \
            which is what a device check confirmed on 2026-08-20.
            """)
    }

    /// A host showing a document as its own root has an empty path — the macOS document window, and
    /// a sheet opened straight onto a document. Popping there would leave it with nothing to show.
    @Test("replace on an empty path appends rather than emptying the host")
    func replaceOnEmptyPathAppends() {
        var path: [String] = []
        DocumentJump.replace.apply(to: &path, appending: "d1")
        #expect(path == ["d1"], "a document-rooted host must still show the document it paged to")
    }

    /// The tenth host (CitationLookupView) keeps an opaque `NavigationPath`. Its contents cannot be
    /// read back, but its DEPTH can — which is the property under test.
    @Test("the NavigationPath overload keeps depth constant too")
    func navigationPathOverloadKeepsDepth() {
        var path = NavigationPath()
        path.append("d1")
        for n in 2...10 {
            DocumentJump.replace.apply(to: &path, appending: "d\(n)")
        }
        #expect(path.count == 1, """
            The citation-lookup sheet stacked \(path.count) levels over ten page-turns. It was the \
            one host still carrying a hand-written copy of this rule.
            """)
        DocumentJump.push.apply(to: &path, appending: "cross-ref")
        #expect(path.count == 2, "a cross-reference inside the sheet must still be a descent")
    }
}

// MARK: - InPlaceReadingTests

/// Drives `InPlaceReading` — the rule every in-place reader applies to its host's reading chain.
///
/// Each assertion is a resulting chain, not a source literal, and each fixture is chosen so a wrong rule
/// gives a different chain: pushing where a page-turn should replace, replacing the wrong level, ignoring
/// the level a jump came from, or popping more than Back asked for.
///
/// Version history:
///   1.0 — 2026-09-11: initial implementation
///   1.1 — 2026-09-11: the rule moved onto the host's chain (review: an iPad layout swap discarded a
///          reading position kept inside the reader)
@Suite("In-place reading")
struct InPlaceReadingTests {

    private static func entry(_ documentId: String,
                              _ volumeId: String = "frus1961-63v06") -> DocumentBrowserEntry {
        DocumentBrowserEntry(documentId: documentId, volumeId: volumeId, header: documentId)
    }

    private let listed = Self.entry("d1")
    private let cited = Self.entry("d9", "frus1961-63v07")
    private let deeper = Self.entry("d40", "frus1961-63v08")
    private let neighbour = Self.entry("d2")

    @Test("A cross-reference keeps the document and pushes its target")
    func crossReferencePushes() {
        var chain = [listed]
        InPlaceReading.apply(.push, to: &chain, at: 0, target: cited)
        #expect(chain == [listed, cited],
                "a push must keep the citing document beneath its target, or Back has nowhere to return")
    }

    @Test("A page-turn swaps the document at its own level and pushes nothing")
    func pageTurnReplaces() {
        var chain = [listed, cited]
        InPlaceReading.apply(.replace, to: &chain, at: 1, target: deeper)
        #expect(chain == [listed, deeper],
                "a page-turn must replace ITS level — not push, and not the level beneath")
    }

    @Test("Twenty page-turns still cost one Back")
    func pagingNeverDeepens() {
        var chain = [listed]
        for n in 2...21 {
            InPlaceReading.apply(.replace, to: &chain, at: 0, target: Self.entry("d\(n)"))
        }
        #expect(chain == [Self.entry("d21")],
                "paging must not deepen the chain — M-17a, twenty pages for twenty Back taps")
    }

    @Test("A jump from beneath the top drops what stood above it")
    func jumpFromBeneathTheTopTruncates() {
        var pushed = [listed, cited, deeper]
        InPlaceReading.apply(.push, to: &pushed, at: 0, target: neighbour)
        #expect(pushed == [listed, neighbour], "a push from level 0 lands directly above level 0")

        var paged = [listed, cited, deeper]
        InPlaceReading.apply(.replace, to: &paged, at: 1, target: neighbour)
        #expect(paged == [listed, neighbour], "a page-turn at level 1 replaces level 1 and drops level 2")
    }

    @Test("Back drops its reader and every one above, and nothing beneath")
    func backDismissesOnlyAbove() {
        var chain = [listed, cited, deeper]
        #expect(InPlaceReading.isPresenting(above: -1, in: chain),
                "the host presents while the chain holds a document")
        #expect(InPlaceReading.isPresenting(above: 1, in: chain))
        #expect(!InPlaceReading.isPresenting(above: 2, in: chain), "nothing stands above the top")

        InPlaceReading.dismiss(above: 0, in: &chain)
        #expect(chain == [listed], "Back from level 1 must leave level 0 open")
        InPlaceReading.dismiss(above: 3, in: &chain)
        #expect(chain == [listed], "dismissing above a level the chain never reached changes nothing")
        InPlaceReading.dismiss(above: -1, in: &chain)
        #expect(chain.isEmpty, "Back from level 0 closes the reader")
        #expect(!InPlaceReading.isPresenting(above: -1, in: chain))
    }

    #if os(iOS)
    /// A reference the binding under test can write through.
    private final class ChainBox: @unchecked Sendable {
        var chain: [DocumentBrowserEntry]
        init(_ chain: [DocumentBrowserEntry]) { self.chain = chain }
    }

    @Test("The presentation binding reads the chain, and only a dismissal writes it")
    @MainActor
    func presentationBinding() {
        let box = ChainBox([listed, cited, deeper])
        let chain = Binding(get: { box.chain }, set: { box.chain = $0 })
        let aboveListed = InPlaceReading.presentation(above: 0, in: chain)
        #expect(aboveListed.wrappedValue)
        aboveListed.wrappedValue = true
        #expect(box.chain == [listed, cited, deeper], "re-asserting a presentation must not edit the chain")
        aboveListed.wrappedValue = false
        #expect(box.chain == [listed], "Back through the binding drops exactly the levels above")
        #expect(!aboveListed.wrappedValue)
    }
    #endif
}
