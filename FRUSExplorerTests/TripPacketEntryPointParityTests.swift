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

// MARK: - TripPacketEntryPointParityTests

/// Pins the Archive Visit entry-point wiring, on every platform (#830; Phase 3).
///
/// ## The defect class this exists for, and why the obvious test would have missed it
/// The original collection entry point shipped in T-2 and **never worked on any platform**: the
/// control that set the presenting flag lived in `iPhoneAddMenu` while the `.sheet` that observed
/// it lived inside `macBody` — same file, separated by a platform branch, so no same-file check
/// could catch it, and each platform had only half the wiring. This suite asserts the property
/// that actually failed: **the presenter must sit in the shared `body`**, above the per-platform
/// split, so no `#if` can strand it away from its control.
///
/// A UI test would catch these too, but only on whichever platform and size class it runs at,
/// and the original defect was specifically one of a *size class* (regular width had no item at
/// all). A source scan covers every surface/size combination at once, which is the shape of the
/// bug. Each assertion is scoped to a CONTROL, not a file (the source-scan rule).
///
/// Version history:
///   1.0 — Session 2026-08-23: #830, the dead collection entry point
///   2.0 — Archive Visits Phase 3: the collection surfaces' verb becomes Add to Archive
///          Visit (§7.3 — the ephemeral verb was kept only through Phases 1–2), Project
///          Home becomes create-or-open over the persistent plan, and the new surfaces —
///          the Research-tab list, the macOS window + menus, the Source Explorer three-way
///          add on both platforms, and the Neighbors control in the SHARED content core —
///          are pinned with the same discipline
@Suite("Archive Visit entry-point parity (#830 / Phase 3)")
struct TripPacketEntryPointParityTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    private static let editor = "FRUSExplorer/Collections/CollectionEditorView.swift"
    private static let macManager = "FRUSExplorer/Collections/MacCollectionManagerView.swift"

    /// Every collection surface offers the action under the SHARED localization key — a menu
    /// that spelled its own label would be a different bug; this suite is about wiring.
    private static let addToVisitKey = "collection.addToVisit"

    // MARK: - The collection surfaces (the verb swap)

    /// **The exact failure shape, re-pinned for the successor.** The picker presenter must
    /// appear in the shared `body`, not inside `macBody` or `iOSBody`.
    @Test("The collection picker presenter lives in the shared body, not a per-platform one")
    func presenterIsPlatformIndependent() throws {
        let text = try Self.source(Self.editor)

        guard let bodyStart = text.range(of: "\n    var body: some View {"),
              let macBody = text.range(of: "\n    private var macBody: some View {"),
              let iOSBody = text.range(of: "\n    private var iOSBody: some View {"),
              let presenter = text.range(of: ".sheet(item: $planPickerRequest)")
        else {
            Issue.record("CollectionEditorView no longer declares body / macBody / iOSBody / the presenter — re-derive this test against the new shape rather than deleting it")
            return
        }

        let firstPlatformBody = min(macBody.lowerBound, iOSBody.lowerBound)
        #expect(presenter.lowerBound > bodyStart.lowerBound, """
            The plan-picker sheet is declared before `var body`. Expected it inside the shared body.
            """)
        #expect(presenter.lowerBound < firstPlatformBody, """
            The plan-picker sheet sits inside a PER-PLATFORM body. That is exactly how the
            original packet entry point shipped dead on every platform — attach it to the
            shared `body`.
            """)
    }

    /// The action must be reachable at BOTH size classes on iOS — the original defect was
    /// specifically that `iPadAddMenu` had no item at regular width.
    @Test("Both iOS add-menus offer Add to Archive Visit")
    func bothIOSMenusOfferTheAction() throws {
        let text = try Self.source(Self.editor)
        for menu in ["iPhoneAddMenu", "iPadAddMenu"] {
            guard let start = text.range(of: "\n    private var \(menu): some View {") else {
                Issue.record("\(menu) no longer exists — re-derive this test")
                continue
            }
            // Scope to THIS menu: from its declaration to the next one, so a match cannot be
            // borrowed from a sibling menu that happens to sit nearby.
            let rest = text[start.upperBound...]
            let end = rest.range(of: "\n    private var ")?.lowerBound ?? rest.endIndex
            let menuBody = rest[..<end]
            #expect(menuBody.contains(Self.addToVisitKey), """
                \(menu) does not offer Add to Archive Visit. Every collection add-menu must, or \
                the route disappears at one size class.
                """)
            #expect(menuBody.contains("TripPacketSeed.resolve("), """
                \(menu)'s action must resolve membership through the ONE shared rule — smart \
                collections through `smartRefs`, static through `staticSeedDocuments` — or this \
                surface and the plan describe different sets.
                """)
        }
    }

    /// macOS edits collections in `MacCollectionManagerView`, so the macOS route needs its own
    /// control AND its own presenter, both in that file.
    @Test("The macOS manager carries both halves of the route")
    func macManagerHasControlAndPresenter() throws {
        let text = try Self.source(Self.macManager)
        #expect(text.contains(Self.addToVisitKey), """
            MacCollectionManagerView offers no Add-to-Archive-Visit control. This is the pane \
            where macOS actually edits a collection, so without an item here macOS has no \
            collection route to a plan.
            """)
        #expect(text.contains("TripPacketSeed.resolve("),
                "the macOS action must resolve membership through the shared rule")
        #expect(text.contains(".sheet(item: $planPickerRequest)"), """
            MacCollectionManagerView sets `planPickerRequest` but never presents it — the same \
            half-wired shape that made the original entry point dead on every platform.
            """)
        #expect(text.contains("PlanPickerSheet(request:"), "the macOS presenter builds no picker")
    }

    /// All three surfaces use one localization key — three hand-written labels would be three
    /// places for the menus to disagree about what the action is called. The RETIRED ephemeral
    /// verb's key must be gone (§7.3: replaced in Phase 3, not doubled).
    @Test("All three surfaces share one key, and the retired verb is gone")
    func surfacesShareOneKey() throws {
        let editor = try Self.source(Self.editor)
        let mac = try Self.source(Self.macManager)
        let occurrences = editor.components(separatedBy: Self.addToVisitKey).count - 1
        #expect(occurrences == 2, """
            Expected the key exactly twice in CollectionEditorView (iPhone and iPad menus), \
            found \(occurrences).
            """)
        #expect(mac.components(separatedBy: Self.addToVisitKey).count - 1 == 1,
                "Expected the key exactly once in MacCollectionManagerView")
        for (name, text) in [("editor", editor), ("mac", mac)] {
            #expect(!text.contains("collection.planVisit"), """
                The \(name) still carries the retired ephemeral verb. §7.3 kept it only through \
                Phases 1–2; two verbs for one destination is the drift this suite exists to stop.
                """)
        }
    }

    /// The three collection gates keep admitting a saved-search collection and an excerpt-only
    /// collection — the two membership shapes Phase 0 un-orphaned.
    @Test("All three gates admit smart and excerpt-only collections")
    func gatesAdmitSmartAndExcerpts() throws {
        let editor = try Self.source(Self.editor)
        #expect(editor.components(separatedBy: "linkedSavedSearchId == nil").count - 1 >= 2, """
            Both size-class gates must test the saved search — a smart collection's membership \
            resolves at build time, and a gate that only counts static entries re-orphans it.
            """)
        let mac = try Self.source(Self.macManager)
        #expect(mac.contains("collection.savedSearchId == nil"),
                "the macOS gate must test the saved search like the iOS pair")
        for (name, text) in [("editor", editor), ("mac", mac)] {
            #expect(text.contains(".entryKind == .excerpt"), """
                The \(name) gate must count excerpt entries — they carry real document \
                provenance, and a collection built from highlighted passages is exactly what a \
                reader accumulates while reading.
                """)
        }
    }

    // MARK: - Project Home (create-or-open)

    /// Project Home's Plan a Visit is create-or-open over the PERSISTENT plan (§4a/1h): a new
    /// plan seeds once from the leads union; an existing plan opens regardless of the current
    /// engaged set. Never a live mirror — re-seeding is the editor's explicit button.
    @Test("Project Home's Plan a Visit is create-or-open over the persistent plan")
    func projectHomeIsCreateOrOpen() throws {
        let home = try Self.source("FRUSExplorer/ProjectContext/ProjectHomeView.swift")
        #expect(home.contains("ProjectLeadsService.gatherSeed("), """
            A NEW plan's seed must come from the leads engine's own gatherSeed — a \
            re-implementation of one of its three sources is how the seed silently narrowed \
            to collections-only once before.
            """)
        #expect(home.contains("projectPlan == nil"),
                "the gate must admit an existing plan even when the engaged set is empty")
        #expect(home.contains("ArchiveVisitEditorView(plan:"),
                "the flow must open the persistent plan's editor, not an ephemeral sheet")
        #expect(home.contains("addSeeds("),
                "creation must write seeds through the one shared write path")
        #expect(!home.contains("TripPacketSheet("), """
            Project Home still presents the ephemeral packet sheet. Phase 3 made the plan the \
            route; the packet is exported from the plan's editor.
            """)
    }

    // MARK: - The Phase 3 surfaces

    /// The iOS Research tab carries the plan list, pinned beside Project Home, presented as a
    /// sheet with its own stack (the typed path is a one-deep projection no editor push could
    /// enter — the Project Home precedent).
    @Test("The Research tab offers the Archive Visits list")
    func researchTabOffersTheList() throws {
        let research = try Self.source("FRUSExplorer/Research/ResearchView.swift")
        #expect(research.contains("research.sidebar.archiveVisits"),
                "the sidebar row is missing")
        #expect(research.contains("showArchiveVisits = true"),
                "the row names the action but sets no state")
        #expect(research.contains(".sheet(isPresented: $showArchiveVisits)"),
                "the flag has no presenter — the half-wired shape again")
        #expect(research.contains("ArchiveVisitListView()"),
                "the presenter builds no list")
    }

    /// The macOS window and both its doors: the scene, the Research command menu, and the
    /// main-window My Research toolbar menu (whose fronting is separately pinned by
    /// `MacWindowFrontingTests`).
    @Test("macOS carries the Archive Visits window and both its doors")
    func macCarriesWindowAndDoors() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        #expect(app.contains("id: \"frus.archiveVisits\""), "the window scene is missing")
        #expect(app.contains("menu.research.archiveVisits"),
                "the Research command menu has no Archive Visits item")
        let main = try Self.source("FRUSExplorer/App/MainWindowView.swift")
        #expect(main.contains("mainwindow.tools.archiveVisits"),
                "the My Research toolbar menu has no Archive Visits item")
    }

    /// Source Explorer's three-way add exists on BOTH platforms — the Mac twin is
    /// hand-maintained, which is this repo's standing drift hazard.
    @Test("Source Explorer offers the three-way add on both platforms")
    func sourceExplorerOffersThreeWayAdd() throws {
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let text = try Self.source(path)
            for key in ["source.explorer.addVisit.source",
                        "source.explorer.addVisit.refs %lld",
                        "source.explorer.addVisit.both"] {
                #expect(text.contains(key), "\(path) is missing the \(key) option")
            }
            #expect(text.contains("PlanPickerSheet(request:"),
                    "\(path) offers the menu but presents no picker")
        }
    }

    /// The unit-grain entry (Phase 4): the shared collection detail — the surface every
    /// unit-shaped view routes to — offers the citing-documents add, count on the control,
    /// fetching through the SAME `collectionNeighbors` clause the Neighbors list runs (a
    /// second clause would let the control and the list describe different sets), with the
    /// ceiling above the corpus's per-unit maximum and a shortfall basis rather than a
    /// silent cap.
    @Test("The collection detail offers the unit-grain add")
    func collectionDetailOffersUnitGrainAdd() throws {
        let text = try Self.source("FRUSExplorer/SourceExplorer/CollectionDetailView.swift")
        #expect(text.contains("collection.detail.addToVisit %lld"),
                "the count-disclosing control is missing")
        #expect(text.contains("collectionNeighbors("),
                "the citing set must come from the Neighbors list's own clause")
        #expect(text.contains("planSeedFetchCeiling = 20_000"), """
            The fetch ceiling must clear the measured per-unit maximum (17,606) — a lower \
            ceiling silently truncates the unit.
            """)
        #expect(text.contains("archiveVisit.basis.unit.partial %lld %lld %@"),
                "a capped fetch must disclose itself in the basis, never present as whole")
        #expect(text.contains("PlanPickerSheet(request:"),
                "the control offers the add but presents no picker")
    }

    /// The Neighbors add control lives in the SHARED content core — before the window host's
    /// declaration — so all three hosts (iOS sheet, macOS window, Stage Manager) carry it.
    /// It is ONE honest option over the documents shown (§7.7's resolution): the full cohort
    /// is never in memory, and its count already reads in the overflow line.
    @Test("The Neighbors add control is in the shared content core")
    func neighborsControlIsInTheCore() throws {
        let text = try Self.source("FRUSExplorer/SourceExplorer/ArchivalNeighborsSheet.swift")
        guard let control = text.range(of: "archivalNeighbors.addToVisit %lld"),
              let windowHost = text.range(of: "struct ArchivalNeighborsWindowView") else {
            Issue.record("the control or the window host is gone — re-derive this test")
            return
        }
        #expect(control.lowerBound < windowHost.lowerBound, """
            The add control sits in a HOST rather than in `ArchivalNeighborsContent`. A control \
            outside the core is missing from the macOS and Stage-Manager windows — the exact \
            reason the design put it in the core.
            """)
        #expect(!text.contains("Add all"), """
            A full-cohort add appeared. The cohort documents are never in memory (the loaders \
            cap at 30), so an "Add all N" control would either lie or silently re-query — §7.7 \
            resolved this to one honest option over the documents shown.
            """)
    }

    // MARK: - The macOS window shape (UI pass)

    /// The macOS Archive Visits window is the Collections window's shape — a flat pane with
    /// a toolbar plan picker and a Manage sheet — NOT the iOS push-navigation shell (which
    /// put a back chevron and an iOS header inside a Mac singleton window, the owner-reported
    /// defect the UI pass fixed).
    @Test("The macOS window hosts the Mac manager, not the iOS push shell")
    func macWindowHostsTheManager() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        // Scope to the Archive Visits Window block: from its scene id to the next Window/MARK.
        let sceneRange = try #require(app.range(of: "id: \"frus.archiveVisits\""))
        let after = app[sceneRange.upperBound...]
        let blockEnd = after.range(of: ".defaultSize")?.lowerBound ?? after.endIndex
        let block = after[..<blockEnd]
        #expect(block.contains("MacArchiveVisitManagerView()"),
                "the window scene no longer hosts the Mac manager root")
        #expect(!block.contains("NavigationStack"), """
            The Archive Visits window wraps its content in a NavigationStack again. That is \
            the iOS push shell — a back chevron in a Mac singleton window — which the UI pass \
            replaced with the Collections window's flat-pane + toolbar-picker shape.
            """)

        let manager = try Self.source("FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift")
        #expect(manager.contains("ToolbarItem(placement: .navigation) { planPickerMenu }"),
                "the manager lost its toolbar plan picker — the window's only switcher")
        #expect(manager.contains("MacManageArchiveVisitsSheet("),
                "the manager presents no Manage sheet — rename/delete become unreachable")
        #expect(manager.contains("deleteWithChildren(in:"), """
            The Manage sheet's delete must run the explicit cascade — the `.nullify` \
            relationships orphan every child row under a bare delete (§4a).
            """)
    }

    /// The editor's citation surfaces parse the formatter's Markdown instead of printing
    /// literal underscores — `CitationFormatter` wraps series titles in `_…_` BY DESIGN for
    /// copy/export, so any raw `Text(citation)` renders the markers.
    @Test("Editor citations render Markdown, never literal underscores")
    func editorCitationsRenderMarkdown() throws {
        let editor = try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift")
        #expect(editor.contains("AttributedString(markdownBody: doc.citation)"),
                "the drawn-from seeding row renders the raw citation string again")
        #expect(!editor.contains("Text(doc.citation)"), """
            A raw Text(citation) reappeared in the editor. A plain String in Text does not \
            parse Markdown, so the series title prints with literal underscores — route it \
            through AttributedString(markdownBody:).
            """)
        // The Documents-tab row label is the header + volume title, never the publication
        // citation (export-grade verbosity, and the Markdown trap again).
        #expect(editor.contains("facts?.header ?? seed.documentKey"),
                "the Documents-tab row lost its header-first label anatomy")
    }

    /// The measured-sparsity counts go through `.formatted()` — the shipped build printed
    /// "13750 of 316839" beside a static sentence that grouped its own digits.
    @Test("Sparsity counts are grouped")
    func sparsityCountsAreGrouped() throws {
        let editor = try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift")
        #expect(editor.contains("sparsity.withReferences.formatted()"),
                "the measured-sparsity line stopped formatting its counts")
        #expect(!editor.contains("archiveVisit.info.sparsity.measured %lld"),
                "the old ungrouped %lld sparsity key came back")
    }
}
