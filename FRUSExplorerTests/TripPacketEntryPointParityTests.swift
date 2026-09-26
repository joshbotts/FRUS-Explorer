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

/// Pins the Archives Visit entry-point wiring, on every platform (#830; Phase 3).
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
///   2.0 — Archives Visits Phase 3: the collection surfaces' verb becomes Add to Archive
///          Visit (§7.3 — the ephemeral verb was kept only through Phases 1–2), Project
///          Home becomes create-or-open over the persistent plan, and the new surfaces —
///          the Research-tab list, the macOS window + menus, the Source Explorer three-way
///          add on both platforms, and the Neighbors control in the SHARED content core —
///          are pinned with the same discipline
///   2.1 — #1366: one creation path (every construction outside the factory fails), the packet
///          sheet's caption wiring, and Re-seed from Project's confirmation
///   2.2 — #1366 review: each creation site's PROJECT ARGUMENT is pinned, not just its call;
///          Re-seed is offered only while the plan's project exists; the replace question is
///          an alert whose cancel claims no authorship; the filled-topic toast is pinned; and
///          the comment stripper cuts at whichever of `//` and `/*` comes first, and reports a
///          file it leaves inside a block comment (it had blanked CrossReferenceStore.swift's
///          last 338 lines from `//… (`*://*`)`)
///   2.3 — #1366 review, round 2: the packet sheet opens a plan's topic from the plan alone and
///          names the project's question in exactly three places; the replace question's quoted
///          texts each end a paragraph; the Re-seed messages say "alert", as the code now is
///   2.4 — #1456: the editor's derivation task is keyed on `inputSignature` beside its counter
///          (``editorDerivationIsKeyedOnItsInputs()``), read through `callsWithTrailingClosures`
///   2.5 — #1456 review, round 1: the key's `revision` argument must BE `revision` (the label alone
///          passed `revision: 0`); the Archives Visits list's row is keyed and cached on the same
///          signature (``listRowSummaryIsKeyedOnItsInputs()``); and Plan a Visit creates no plan from
///          an empty fresh read, and a superseded read writes nothing (``planVisitKeepsTheGatesPromise()``)
@Suite("Archives Visit entry-point parity (#830 / Phase 3)")
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
    @Test("Both iOS add-menus offer Add to Archives Visit")
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
                \(menu) does not offer Add to Archives Visit. Every collection add-menu must, or \
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

    /// **Plan a Visit keeps its gate's promise where the plan is made** (#1457 review, round 1). The
    /// gate is enabled by the engaged set, and the set is re-read on a task keyed on the seed
    /// signature; so the button can be enabled by a read taken before a detach, and the read of an
    /// attach can land after the detach's. Two guards: the create branch returns on an empty fresh
    /// read before it makes a plan, and a read whose task was cancelled writes nothing.
    ///
    /// A source scan, comments stripped: the same answer on every test destination. Neither guard
    /// can be driven at runtime here — the one takes a detach racing the button, the other a detached
    /// read finishing after its successor.
    @Test("Plan a Visit creates no plan from an empty fresh read, and a superseded read writes nothing (#1457)")
    func planVisitKeepsTheGatesPromise() throws {
        let home = Self.strippingComments(try Self.source("FRUSExplorer/ProjectContext/ProjectHomeView.swift"))
        func collapsed(_ range: Range<String.Index>) -> String {
            home[range].split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let planVisit = collapsed(try #require(
            Self.body(after: "private func planVisit(_ project: Project) async", in: home),
            "ProjectHomeView no longer declares planVisit(_:) — re-derive this test"))
        let read = try #require(planVisit.range(of: "await refreshEngagedPacketDocuments()"),
                                "planVisit no longer reads the engaged set before it creates a plan")
        let guarded = try #require(planVisit.range(of: "guard !engagedPacketDocuments.isEmpty else { return }"), """
            planVisit creates a plan whatever its fresh read returns, so a button enabled by a stale \
            read seeds an empty plan — the case the gate exists to prevent. \(planVisit)
            """)
        let make = try #require(planVisit.range(of: "ArchiveVisitPlan.make("), "planVisit no longer creates a plan")
        #expect(read.upperBound <= guarded.lowerBound && guarded.upperBound <= make.lowerBound,
                "the empty-read guard must sit between the read and the plan's creation: \(planVisit)")

        let refresh = collapsed(try #require(
            Self.body(after: "private func refreshEngagedPacketDocuments() async", in: home),
            "ProjectHomeView no longer declares refreshEngagedPacketDocuments() — re-derive this test"))
        let writes = refresh.components(separatedBy: "engagedPacketDocuments = ").count - 1
        try #require(writes == 1, "refreshEngagedPacketDocuments assigns the set \(writes) times: \(refresh)")
        let cancelled = try #require(refresh.range(of: "guard !Task.isCancelled else { return }"), """
            A read whose task was cancelled still writes the engaged set, so an attach's read can land \
            after a detach's and leave Plan a Visit enabled: \(refresh)
            """)
        let write = try #require(refresh.range(of: "engagedPacketDocuments = "))
        #expect(cancelled.upperBound <= write.lowerBound,
                "the cancellation guard must come before the write: \(refresh)")
    }

    // MARK: - The Phase 3 surfaces

    /// The iOS Research tab carries the plan list, pinned beside Project Home, presented as a
    /// sheet with its own stack (the typed path is a one-deep projection no editor push could
    /// enter — the Project Home precedent).
    @Test("The Research tab offers the Archives Visits list")
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
    @Test("macOS carries the Archives Visits window and both its doors")
    func macCarriesWindowAndDoors() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        #expect(app.contains("id: \"frus.archiveVisits\""), "the window scene is missing")
        #expect(app.contains("menu.research.archiveVisits"),
                "the Research command menu has no Archives Visits item")
        let main = try Self.source("FRUSExplorer/App/MainWindowView.swift")
        #expect(main.contains("mainwindow.tools.archiveVisits"),
                "the My Research toolbar menu has no Archives Visits item")
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

    /// The macOS Archives Visits window is the Collections window's shape — a flat pane with
    /// a toolbar plan picker and a Manage sheet — NOT the iOS push-navigation shell (which
    /// put a back chevron and an iOS header inside a Mac singleton window, the owner-reported
    /// defect the UI pass fixed).
    @Test("The macOS window hosts the Mac manager, not the iOS push shell")
    func macWindowHostsTheManager() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        // Scope to the Archives Visits Window block: from its scene id to the next Window/MARK.
        let sceneRange = try #require(app.range(of: "id: \"frus.archiveVisits\""))
        let after = app[sceneRange.upperBound...]
        let blockEnd = after.range(of: ".defaultSize")?.lowerBound ?? after.endIndex
        let block = after[..<blockEnd]
        #expect(block.contains("MacArchiveVisitManagerView()"),
                "the window scene no longer hosts the Mac manager root")
        #expect(!block.contains("NavigationStack"), """
            The Archives Visits window wraps its content in a NavigationStack again. That is \
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

    // MARK: - #1366: one creation path, and the topic's explicit refresh

    /// The four places the app creates a plan (#1366 counted them), each with the argument its
    /// one `ArchiveVisitPlan.make(` call must pass for the project: the three that hold `AppState`
    /// pass the active project's id, and Project Home passes the project it shows (`planVisit`'s
    /// parameter, which its one caller fills with the Home's own project).
    private static let creationSites: [(path: String, label: String, argument: String)] = [
        ("FRUSExplorer/TripPacket/ArchiveVisitListView.swift",
         "activeProjectId", "appState.activeProjectId"),
        ("FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift",
         "activeProjectId", "appState.activeProjectId"),
        ("FRUSExplorer/TripPacket/PlanPickerSheet.swift",
         "activeProjectId", "appState.activeProjectId"),
        ("FRUSExplorer/ProjectContext/ProjectHomeView.swift",
         "activeProject", "project"),
    ]

    /// **No creation site bypasses the factory.** Three of #1366's four sites built a plan with a
    /// bare `ArchiveVisitPlan(name:)`, which attached no project and copied no research question,
    /// so every inquiry draft they led to printed the placeholder. `ArchiveVisitTopicSeedingTests`
    /// pins what the factory does; this pins that nothing else creates a plan.
    ///
    /// It walks every Swift file under `FRUSExplorer/`, comments removed, and fails on any
    /// `ArchiveVisitPlan(` / `ArchiveVisitPlan.init(` / `: ArchiveVisitPlan = .init(` outside the
    /// two bodies allowed one: the factory itself and `duplicate(in:)`, which copies a plan's
    /// topic and projects rather than seeding them. A construction spelled any other way — a
    /// `Self(…)` inside the model, say — is out of its reach; none exists. It also fails on a file
    /// the comment stripper leaves INSIDE a block comment: Swift cannot compile one, so it can
    /// only mean the stripper mistook something for `/*` and blanked the rest of the file from
    /// this scan (the #1366 review found that it had, for CrossReferenceStore.swift's last 338
    /// lines). What each creation site passes is `everyCreationSitePassesItsProject`'s.
    @Test("Every Archives Visit is created through ArchiveVisitPlan.make (#1366)")
    func everyPlanIsCreatedThroughTheFactory() throws {
        let appRoot = Self.repoRoot.appending(path: "FRUSExplorer")
        let paths = try FileManager.default.subpathsOfDirectory(atPath: appRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        #expect(paths.count > 100,
                "Only \(paths.count) Swift files under FRUSExplorer/ — the scan path is wrong.")

        let construction = try NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9_])ArchiveVisitPlan(\.init)?\(|:\s*ArchiveVisitPlan\s*=\s*\.init\("#)
        let model = "FRUSExplorer/Models/ArchiveVisitPlan.swift"
        var permitted: [String] = []
        var bypasses: [String] = []
        var unterminated: [String] = []
        for path in paths {
            let relative = "FRUSExplorer/\(path)"
            let stripped = Self.stripComments(try Self.source(relative))
            if stripped.endsInBlockComment { unterminated.append(relative) }
            let code = stripped.code
            var allowed: [(name: String, body: Range<String.Index>)] = []
            if relative == model {
                for (name, signature) in [
                    ("make", "static func make(name: String, activeProject: Project?) -> ArchiveVisitPlan"),
                    ("duplicate", "func duplicate(in context: ModelContext) -> ArchiveVisitPlan"),
                ] {
                    guard let body = Self.body(after: signature, in: code) else {
                        Issue.record("\(model) no longer declares `\(signature)` — the one construction it may hold is gone or renamed")
                        continue
                    }
                    allowed.append((name, body))
                }
            }
            for match in construction.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                guard let range = Range(match.range, in: code) else {
                    Issue.record("\(relative): a match did not map back to the source")
                    continue
                }
                let line = code[..<range.lowerBound].components(separatedBy: "\n").count
                if let owner = allowed.first(where: { $0.body.contains(range.lowerBound) }) {
                    permitted.append("\(owner.name) (\(relative):\(line))")
                } else {
                    bypasses.append("\(relative):\(line) — \(code[range])…")
                }
            }
        }

        #expect(bypasses.isEmpty, """
            \(bypasses.count) place(s) construct an ArchiveVisitPlan without the factory:
            \(bypasses.joined(separator: "\n"))
            Create through `ArchiveVisitPlan.make(name:activeProjectId:in:)` (or \
            `make(name:activeProject:)` when you hold the Project), or the plan is born with no \
            project and exports the topic placeholder (#1366).
            """)
        #expect(permitted.count == 2, """
            Expected exactly one construction in the factory and one in duplicate(in:), found \
            \(permitted.count): \(permitted). Zero means the scan stopped reading the model — the \
            regex or the comment stripping broke — and the bypass check above is vacuous.
            """)
        #expect(unterminated.isEmpty, """
            The comment stripper ended \(unterminated.count) file(s) inside a block comment, so \
            everything after the phantom `/*` was hidden from this scan: \(unterminated). \
            Swift cannot compile an unterminated block comment — the `/*` is in a line comment \
            or a string literal.
            """)
    }

    /// **Each creation site passes the project it creates under** (#1366 review). The factory scan
    /// proves every site calls `ArchiveVisitPlan.make(`, but both of its parameters are optional,
    /// so `activeProjectId: nil` compiles — and brings back #1366's exact failure (a plan with no
    /// project and a placeholder topic) on the picker path it was found on, with every runtime test
    /// green, since those drive the factory rather than the views. So each site's one call is read
    /// by balanced parentheses and the argument itself is compared: not `nil`, not a literal, not
    /// some other id — the active project's, or Project Home's own.
    @Test("Each creation site passes the active project, or Project Home's own (#1366)")
    func everyCreationSitePassesItsProject() throws {
        for site in Self.creationSites {
            let code = Self.strippingComments(try Self.source(site.path))
            let calls = Self.calls(of: "ArchiveVisitPlan.make", in: code)
            #expect(calls.count == 1, """
                \(site.path) should create its plan with exactly one `ArchiveVisitPlan.make(` \
                call, found \(calls.count). It is one of the four creation sites #1366 routed \
                through the factory.
                """)
            for call in calls {
                let passed = Self.argument(site.label, in: call)
                #expect(passed == site.argument, """
                    \(site.path) passes `\(site.label): \(passed ?? "<absent>")`; it must pass \
                    `\(site.argument)`, or the plan is born with no project and exports the topic \
                    placeholder (#1366). The call: \(call)
                    """)
            }
        }
    }

    /// **The comment stripper reads past a glob in a line comment** (#1366 review). It looked for
    /// `/*` before it cut at `//`, so a doc comment mentioning `*://*` opened a block comment that
    /// nothing closed, and the rest of the file vanished from the factory scan. The fixture's first
    /// line is CrossReferenceStore.swift's own, the one that hid its last 338 lines.
    @Test("The comment stripper cuts at whichever of // and /* comes first")
    func commentStripperReadsPastAGlobInALineComment() {
        let fixture = """
            ///   - bare volume ids (`frus…`) and URLs (`*://*`).
            let plan = ArchiveVisitPlan(name: "")
            /* a block */ let kept = 1 // trailing
            let url = base // see Resources/*.json
            /* opens
            closes */ let after = 2
            """
        let stripped = Self.stripComments(fixture)
        let lines = stripped.code.components(separatedBy: "\n")
        #expect(lines.count == 6, "the stripper must keep the line count, so a reported line is the line an editor opens")
        #expect(stripped.code.contains("let plan = ArchiveVisitPlan(name: \"\")"), """
            The code after a `//` comment containing `/*` was stripped — the scan would miss a \
            construction there: \(stripped.code)
            """)
        #expect(stripped.code.contains("let url = base"))
        #expect(stripped.code.contains("let kept = 1"))
        #expect(stripped.code.contains("let after = 2"))
        for comment in ["bare volume ids", "a block", "trailing", "Resources", "opens", "closes"] {
            #expect(!stripped.code.contains(comment), "comment text `\(comment)` survived")
        }
        #expect(!stripped.endsInBlockComment)
        #expect(Self.stripComments("let a = 1 /* never closed").endsInBlockComment,
                "an unterminated block comment must be reported, or the factory scan's guard is vacuous")
    }

    /// **The sheet is told the plan's question, and captions by the field.** The editor built the
    /// packet sheet with `researchQuestion: nil`, so its "Seeded from your project's research
    /// question" caption could never appear (#1366). The rule itself is pinned at runtime by
    /// `ArchiveVisitTopicSeedingTests.seededCaptionFollowsTheField`; this pins that the two
    /// views reach it.
    @Test("The packet sheet gets the plan's project question and captions by the field (#1366)")
    func packetSheetCaptionIsWired() throws {
        let editor = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift"))
        let presentations = Self.calls(of: "TripPacketSheet", in: editor)
        #expect(presentations.count == 1,
                "expected the editor's one packet-sheet construction, found \(presentations.count)")
        for call in presentations {
            #expect(call.contains("researchQuestion: plan.owningProject(in: modelContext)?.researchQuestion"),
                    "the editor must pass the plan's project question, found: \(call)")
        }

        let sheet = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/TripPacketSheet.swift"))
        let captions = Self.calls(of: "Text", in: sheet)
            .filter { $0.contains("packet.topic.caption.seeded") }
        #expect(captions.count == 1, "expected one caption Text, found \(captions.count)")
        for caption in captions {
            #expect(caption.contains(
                "TripPacketTopicSentence.showsSeededCaption(draft: topicDraft,"), """
                The caption must branch on the field as it stands, not on the question alone — \
                found: \(caption)
                """)
        }
    }

    /// **The packet sheet opens a plan's topic from the plan alone** (#1366 review, round 2). The
    /// editor hands the sheet the project's question for its caption, so only this scan stops the
    /// `.plan` rebuild from filling an empty field with it: the round-1 check's mutant, reading
    /// `plan.inquiryText ?? researchQuestion`, passed every test. The rule is
    /// `TripPacketTopicSentence.openPlanDraft`, driven at runtime by
    /// `ArchiveVisitTopicSeedingTests.packetSheetOpensThePlansOwnTopic`. This pins that the rebuild
    /// calls it with the plan's stored topic and sets the field only from what it returns, and that
    /// the sheet names `researchQuestion` in exactly three places — its declaration, the caption's
    /// comparison and the ephemeral builder's seed — so no other path can read the question.
    @Test("The packet sheet opens a plan's topic from the plan alone (#1366)")
    func packetSheetOpensThePlansOwnTopic() throws {
        let sheet = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/TripPacketSheet.swift"))
        let rebuild = try #require(Self.body(after: "private func rebuild() async", in: sheet),
                                   "the sheet's rebuild() is gone — re-derive this test")
        let header = try #require(sheet.range(of: "if let plan = seededPlan", range: rebuild),
                                  "rebuild() no longer branches on a plan seed")
        let planBranch = String(sheet[try #require(Self.body(from: header.upperBound, in: sheet))])
        #expect(!planBranch.contains("researchQuestion"), """
            The `.plan` branch of rebuild() names the project's question — it must open the topic \
            from the plan alone (#1366, §4 item 1): \(planBranch)
            """)
        let opens = Self.calls(of: "planModel.topicSentence.openPlanDraft", in: planBranch)
        #expect(opens.count == 1, "expected the plan branch's one openPlanDraft call, found \(opens.count)")
        for call in opens {
            #expect(Self.argument("draft", in: call) == "topicDraft")
            #expect(Self.argument("stored", in: call) == "plan.inquiryText", """
                The field must open from the plan's stored topic and nothing else — found \
                `stored: \(Self.argument("stored", in: call) ?? "<absent>")`.
                """)
        }
        #expect(planBranch.contains("let opened = planModel.topicSentence.openPlanDraft("))
        let assignment = try NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9_])topicDraft\s*=(?!=)\s*([A-Za-z0-9_.]*)"#)
        let sources = assignment.matches(in: planBranch,
                                         range: NSRange(planBranch.startIndex..., in: planBranch))
            .compactMap { Range($0.range(at: 1), in: planBranch).map { String(planBranch[$0]) } }
        #expect(sources == ["opened"], """
            The plan branch must set the topic field once, from openPlanDraft's result — it set \
            it from \(sources).
            """)

        var rest = sheet
        let captions = Self.calls(of: "TripPacketTopicSentence.showsSeededCaption", in: sheet)
        let builds = Self.calls(of: "TripPacketBuilder.build", in: sheet)
        #expect(captions.count == 1 && builds.count == 1, """
            Expected one caption comparison and one ephemeral build, found \(captions.count) and \
            \(builds.count).
            """)
        for call in captions + builds {
            #expect(Self.argument("researchQuestion", in: call) == "researchQuestion")
        }
        for permitted in ["let researchQuestion: String?"] + captions + builds {
            guard let range = rest.range(of: permitted) else {
                Issue.record("`\(permitted)` is not in the sheet — re-derive this test")
                continue
            }
            rest.replaceSubrange(range, with: String(rest[range].map { $0 == "\n" ? "\n" : " " }))
        }
        let token = try NSRegularExpression(pattern: #"(?<![A-Za-z0-9_])researchQuestion(?![A-Za-z0-9_])"#)
        let stray = token.matches(in: rest, range: NSRange(rest.startIndex..., in: rest))
            .compactMap { Range($0.range, in: rest) }
            .map { rest[..<$0.lowerBound].components(separatedBy: "\n").count }
        #expect(stray.isEmpty, """
            TripPacketSheet.swift names `researchQuestion` outside its declaration, the caption and \
            the ephemeral build, at line(s) \(stray) — a path that could seed a plan's topic from \
            the project's question at render time (#1366).
            """)
    }

    /// **The replace question puts no punctuation after a quoted text** (#1366 review, round 2).
    /// It quotes the project's research question, which almost always ends in "?", and the
    /// one-line form went on after each quotation with a full stop — `…winter target?”. This
    /// plan’s…` — the class of error #1392 fixed in "Document 41., footnote 3". The app ships no
    /// localization, so the `defaultValue:` read here is the text the alert shows.
    @Test("The replace question's quoted texts each end a paragraph (#1366)")
    func replaceQuestionPutsNoPunctuationAfterAQuotation() throws {
        let editor = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift"))
        let key = try #require(editor.range(of: "\"archiveVisit.reseed.topic.message\""),
                               "the replace question's message is gone — re-derive this test")
        let start = try #require(editor.range(of: "defaultValue: \"",
                                              range: key.upperBound..<editor.endIndex))
        var template = ""
        var escaped = false
        for character in editor[start.upperBound...] {
            if character == "\"" && !escaped { break }
            escaped = character == "\\" && !escaped
            template.append(character)
        }
        for placeholder in ["\\(pending.question)", "\\(pending.current)"] {
            #expect(template.contains("“\(placeholder)”"),
                    "the message must quote \(placeholder) — found: \(template)")
        }
        let closings = template.indices.filter { template[$0] == "”" }
        #expect(closings.count == 2, "expected the two quotations' closing marks, found \(closings.count)")
        for closing in closings {
            let after = template[template.index(after: closing)...]
            #expect(after.isEmpty || after.hasPrefix("\\n"), """
                A quotation in the message is followed by `\(after.prefix(3))`: a question ending \
                in "?" would print `?”\(after.prefix(1))`. End its paragraph there instead — \
                found: \(template)
                """)
        }
    }

    /// **Re-seed from Project reaches the topic, and asks before it replaces one.** The decision is
    /// pinned at runtime by `ArchiveVisitTopicSeedingTests`; this pins the editor's two halves of
    /// it — the menu action runs the plan's own re-seed and turns a `.needsConfirmation` into the
    /// alert, and only the alert's Replace writes the question.
    @Test("Re-seed from Project runs through the plan and confirms before replacing (#1366)")
    func reseedIsWiredThroughThePlan() throws {
        let editor = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift"))
        let reseed = try #require(
            Self.body(after: "private func reseed(fromProject projectId: UUID) async", in: editor),
            "the editor's reseed(fromProject:) is gone — re-derive this test")
        let reseedBody = editor[reseed]
        #expect(reseedBody.contains("plan.reseed(fromProject: projectId, in: modelContext)"),
                "Re-seed must run the plan's own reseed — a view-side copy is untested")
        #expect(reseedBody.contains("pendingTopicReplacement = (question: question, current: current)"),
                "a .needsConfirmation outcome must raise the alert")
        #expect(!reseedBody.contains("replaceInquiryTopic"),
                "Re-seed itself must never replace the topic — only the alert's Replace may")
        // #1366 review: the fill is announced. The topic lives in the packet sheet, not on the
        // editor's screen, so a silent fill would change what the drafts send with nothing to say so.
        let filled = try #require(reseedBody.range(of: "case .filled"),
                                  "the .filled outcome is no longer handled")
        let filledEnd = reseedBody.range(of: "case ", range: filled.upperBound..<reseedBody.endIndex)?
            .lowerBound ?? reseedBody.endIndex
        #expect(reseedBody[filled.upperBound..<filledEnd]
                    .contains("toast = String(localized: \"archiveVisit.reseed.topic.filled\""), """
            A Re-seed that fills an empty topic must say so with the filled-topic toast — found: \
            \(reseedBody[filled.upperBound..<filledEnd])
            """)

        let replaceKey = try #require(editor.range(of: "\"archiveVisit.reseed.topic.replace\""),
                                      "the alert's Replace button is gone")
        let action = try #require(Self.body(from: replaceKey.upperBound, in: editor),
                                  "the Replace button has no action")
        #expect(editor[action].contains("plan.replaceInquiryTopic(with: pending.question)"),
                "the Replace button must write the offered question through the model")
        #expect(editor.components(separatedBy: "replaceInquiryTopic(").count - 1 == 1,
                "the topic must be replaced in exactly one place — the alert's Replace")
    }

    /// **Re-seed from Project is offered only while the plan's project exists** (#1366 review). The
    /// item used to test `plan.projectIds.first`, which a deleted project leaves in place (as it
    /// leaves notes' and collections' ids), so the menu offered a Re-seed with no question behind
    /// it that did nothing and said nothing. It now resolves the id against a `@Query` of projects —
    /// a query, so the item goes the moment the project does. The resolution itself is pinned at
    /// runtime by `ArchiveVisitTopicSeedingTests.deletedProjectsPlansOfferNoReseed`.
    @Test("Re-seed from Project is gated on the plan's project resolving (#1366)")
    func reseedIsOfferedOnlyWhileTheProjectExists() throws {
        let editor = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift"))
        #expect(editor.contains("@Query private var projects: [Project]"),
                "the gate must read a @Query of projects, which a delete updates")
        let menu = try #require(Self.body(after: "private var moreMenuItems: some View", in: editor),
                                "the editor's overflow menu is gone — re-derive this test")
        #expect(!editor[menu].contains("plan.projectIds.first"),
                "the menu must not gate on a raw id — a deleted project leaves it in place")
        let gate = try #require(
            editor.range(of: "if let project = plan.owningProject(among: projects)", range: menu),
            "Re-seed from Project must be gated on the plan's project resolving")
        let gated = try #require(Self.body(from: gate.upperBound, in: editor))
        #expect(editor[gated].contains("\"archiveVisit.editor.reseed\""),
                "the Re-seed item must sit inside the gate")
        #expect(editor[gated].contains("let projectId = project.id")
                    && editor[gated].contains("await reseed(fromProject: projectId)"),
                "the item must re-seed from the project the gate resolved")
        #expect(editor.components(separatedBy: "\"archiveVisit.editor.reseed\"").count - 1 == 1,
                "one Re-seed from Project item, the gated one")
    }

    /// **The replace question is an alert, and does not say the topic is the reader's** (#1366
    /// review). It is asked from the ⋯ menu, which is gone by the time it presents, so as a
    /// confirmation dialog iPad drew it as a popover pointing at the whole editor — #1357's class;
    /// an alert is centred and anchored to nothing. And it also appears when the topic is only the
    /// project's old question, which the plan cannot tell from the reader's edit, so its cancel
    /// button must not read "Keep My Topic".
    @Test("The replace-the-topic question is an alert whose cancel claims no authorship (#1366)")
    func replaceQuestionIsAnAlertThatClaimsNoAuthorship() throws {
        let editor = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift"))
        let title = "\"archiveVisit.reseed.topic.title\""
        #expect(Self.calls(of: "alert", in: editor).filter { $0.contains(title) }.count == 1,
                "the replace-the-topic question must be presented by one `.alert`")
        #expect(Self.calls(of: "confirmationDialog", in: editor).filter { $0.contains(title) }.isEmpty,
                "as a confirmation dialog it floats over the whole editor on iPad (#1357's class)")
        let keep = Self.calls(of: "Button", in: editor)
            .filter { $0.contains("\"archiveVisit.reseed.topic.keep\"") }
        #expect(keep.count == 1, "expected the question's one cancel button, found \(keep.count)")
        for button in keep {
            #expect(button.contains("role: .cancel"))
            #expect(!button.contains("My Topic"), """
                The cancel button claims the topic is the reader's, but the question also appears \
                when it is only the project's old question: \(button)
                """)
        }
    }

    // MARK: - The editor's derivation key (#1456)

    /// **The open editor re-derives when its plan changes from outside.** Its derivation task was
    /// keyed on `revision`, a counter only the editor's own writes moved, so seeds added from the
    /// Collections window left it reading "No targets derive from these documents" over a plan that
    /// derived six. The key is now the counter together with
    /// `ArchiveVisitDerivation.inputSignature(plan:indexedVolumeIds:)`, which
    /// `ArchiveVisitInputSignatureTests` drives; this pins that the task really is keyed on it, over
    /// the SAME indexed set the derivation is handed, so the key cannot quietly revert to the
    /// counter alone. Matched on the `.task(` call whose trailing closure runs `derive()`, with its
    /// balanced parentheses, never on a window of lines.
    ///
    /// A source scan: the same answer on every test destination.
    @Test("The editor's derivation is keyed on its inputs, not only on its own writes (#1456)")
    func editorDerivationIsKeyedOnItsInputs() throws {
        let editor = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift"))
        let tasks = Self.callsWithTrailingClosures(of: ".task", in: editor)
        #expect(tasks.count >= 2, "read \(tasks.count) .task( calls in the editor; the scan has stopped matching")
        let deriving = tasks.filter { $0.closure?.contains("derive()") == true }
        try #require(deriving.count == 1, """
            Expected exactly one `.task(` in ArchiveVisitEditorView whose closure runs derive(), \
            found \(deriving.count): \(deriving.map(\.arguments))
            """)
        let id = try #require(Self.argument("id", in: deriving[0].arguments),
                              "the derivation task has no id: argument: \(deriving[0].arguments)")
        let keys = Self.calls(of: "DerivationKey", in: id)
        try #require(keys.count == 1, "the derivation task's id is not one DerivationKey(…): \(id)")
        // The argument's VALUE, not its label: `id.contains("revision")` passed `revision: 0`.
        #expect(Self.argument("revision", in: keys[0]) == "revision", """
            The derivation key does not carry `revision`. The editor's own writes, the tier sheet's \
            dismiss and the index-boot recovery move only that counter, so an editor opened before the \
            index booted, on a plan none of whose volumes then joins the indexed set, stays on the \
            placeholder. Key: \(id)
            """)
        let inputs = try #require(Self.argument("inputs", in: keys[0]), "the derivation key has no inputs: \(id)")
        let signatures = Self.calls(of: "ArchiveVisitDerivation.inputSignature", in: inputs)
        try #require(signatures.count == 1, """
            The derivation task's key is not built from ArchiveVisitDerivation.inputSignature, so a \
            write the editor did not make — another window's Add to Archives Visit, an iCloud merge, \
            a seed's volume finishing indexing — leaves the screen on the old derivation (#1456). \
            Key: \(id)
            """)
        #expect(Self.argument("plan", in: signatures[0]) == "plan")
        #expect(Self.argument("indexedVolumeIds", in: signatures[0]) == "appState.indexedVolumeIds")

        // The key must read the set the derivation is handed, or the two can disagree about what
        // is indexed.
        let deriveBody = try #require(Self.body(after: "private func derive() async", in: editor),
                                      "the editor no longer declares derive()")
        let derives = Self.calls(of: "ArchiveVisitDerivation.derive", in: String(editor[deriveBody]))
        try #require(derives.count == 1, "derive() makes \(derives.count) ArchiveVisitDerivation.derive calls")
        #expect(Self.argument("plan", in: derives[0]) == "plan")
        #expect(Self.argument("indexedVolumeIds", in: derives[0]) == "appState.indexedVolumeIds", """
            derive() hands the derivation a different indexed set from the one its key reads.
            """)
    }

    /// **The Archives Visits list's row re-derives its summary when its plan's inputs change**
    /// (#1456 review, round 1). The row's "N targets · M repositories" comes from the same
    /// derivation as the editor, and was derived and cached under the plan's id and `lastModified`,
    /// which a seed's flag and a seed's volume finishing indexing never move: the row said "0 targets"
    /// beside a coverage line that had already gone. This pins that the row's task and its cache are
    /// keyed on ``ArchiveVisitDerivation/inputSignature(plan:indexedVolumeIds:)`` over the set the
    /// derivation is handed, and not on `lastModified`. `ArchiveVisitInputSignatureTests` drives the
    /// signature.
    ///
    /// A source scan, comments stripped: the same answer on every test destination.
    @Test("The Archives Visits list's row summary is keyed on its plan's inputs, not its lastModified (#1456)")
    func listRowSummaryIsKeyedOnItsInputs() throws {
        let list = Self.strippingComments(
            try Self.source("FRUSExplorer/TripPacket/ArchiveVisitListView.swift"))
        func collapsed(_ range: Range<String.Index>) -> String {
            list[range].split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }

        // The key: the plan's id and its signature over the device's indexed set.
        let keyBody = collapsed(try #require(
            Self.body(after: "private func summaryKey(for plan: ArchiveVisitPlan) -> SummaryKey", in: list), """
            ArchiveVisitListView declares no summaryKey(for:), so its row's summary is not keyed on the \
            plan's derivation inputs (#1456)
            """))
        let keys = Self.calls(of: "SummaryKey", in: keyBody)
        try #require(keys.count == 1, "summaryKey(for:) makes \(keys.count) SummaryKey(…) values: \(keyBody)")
        #expect(Self.argument("planId", in: keys[0]) == "plan.id")
        let signatures = Self.calls(of: "ArchiveVisitDerivation.inputSignature",
                                    in: Self.argument("inputs", in: keys[0]) ?? "")
        try #require(signatures.count == 1, "the row's key is not built from inputSignature: \(keyBody)")
        #expect(Self.argument("plan", in: signatures[0]) == "plan")
        #expect(Self.argument("indexedVolumeIds", in: signatures[0]) == "appState.indexedVolumeIds")
        #expect(!keyBody.contains("lastModified"), """
            The row's key reads lastModified, which a seed's flag and a seed's volume finishing indexing \
            never move, and which a rename moves for nothing: \(keyBody)
            """)

        // The row's task, and the line it draws, read that key.
        let row = collapsed(try #require(
            Self.body(after: "private func row(_ plan: ArchiveVisitPlan) -> some View", in: list),
            "ArchiveVisitListView no longer declares row(_:) — re-derive this test"))
        let tasks = Self.callsWithTrailingClosures(of: ".task", in: row)
            .filter { $0.closure?.contains("loadSummary(") == true }
        try #require(tasks.count == 1, "expected one .task( in the row that loads its summary, found \(tasks.count)")
        let id = try #require(Self.argument("id", in: tasks[0].arguments),
                              "the summary task has no id: argument: \(tasks[0].arguments)")
        #expect(row.contains("let \(id) = summaryKey(for: plan)"), """
            The row's summary task is keyed on «\(id)», which is not the row's summaryKey(for: plan): \(row)
            """)
        let loads = Self.calls(of: "loadSummary", in: tasks[0].closure ?? "")
        try #require(loads.count == 1)
        #expect(Self.argument("cachingUnder", in: loads[0]) == id,
                "the summary is cached under a different key from the one its task runs on: \(loads[0])")
        let lines = Self.calls(of: "summaryLine", in: row)
        try #require(lines.count == 1, "the row draws \(lines.count) summary lines")
        #expect(Self.argument("cachedUnder", in: lines[0]) == id,
                "the row reads its summary under a different key from the one it caches it under: \(lines[0])")

        // The loader and the line use the key they are handed, and the loader derives over the
        // indexed set the key reads.
        let load = collapsed(try #require(
            Self.body(after: "private func loadSummary(_ plan: ArchiveVisitPlan, cachingUnder key: SummaryKey) async", in: list),
            "ArchiveVisitListView no longer declares loadSummary(_:cachingUnder:)"))
        #expect(load.contains("summaries[key] == nil") && load.contains("summaries[key] = "),
                "loadSummary does not read and write its cache under the key it is handed: \(load)")
        let derives = Self.calls(of: "ArchiveVisitDerivation.derive", in: load)
        try #require(derives.count == 1, "loadSummary makes \(derives.count) ArchiveVisitDerivation.derive calls")
        #expect(Self.argument("indexedVolumeIds", in: derives[0]) == "appState.indexedVolumeIds",
                "loadSummary hands the derivation a different indexed set from the one its key reads")
        let line = collapsed(try #require(
            Self.body(after: "private func summaryLine(_ plan: ArchiveVisitPlan, cachedUnder key: SummaryKey) -> String", in: list),
            "ArchiveVisitListView no longer declares summaryLine(_:cachedUnder:)"))
        #expect(line.contains("summaries[key]"), "summaryLine does not read the key it is handed: \(line)")
    }

    // MARK: - Scan helpers

    /// `text` with `//` and `/* */` comments removed — ``stripComments(_:)``'s code alone.
    private static func strippingComments(_ text: String) -> String {
        stripComments(text).code
    }

    /// `text` with `//` and `/* */` comments removed, line count preserved so a reported line is
    /// the line an editor opens, and whether the text ENDED inside a block comment.
    ///
    /// Each line is cut at whichever of `//` and `/*` comes FIRST — the #1366 review's fix: looking
    /// for `/*` before `//` let a line comment mentioning `*://*` open a block that nothing closed,
    /// blanking CrossReferenceStore.swift from line 1006 to its end. String literals are not
    /// parsed: nothing these scans match sits in one, and a comment-aware scanner that also tracked
    /// quoting would be a second parser. A `/*` inside a literal would still open a phantom block —
    /// which is what `endsInBlockComment` reports, since Swift cannot compile a real one.
    private static func stripComments(_ text: String) -> (code: String, endsInBlockComment: Bool) {
        var out: [String] = []
        var inBlock = false
        for var line in text.components(separatedBy: "\n") {
            if inBlock {
                guard let end = line.range(of: "*/") else { out.append(""); continue }
                line = String(line[end.upperBound...])
                inBlock = false
            }
            var kept = ""
            while !line.isEmpty {
                let slashes = line.range(of: "//")
                let block = line.range(of: "/*")
                if let slashes, block.map({ slashes.lowerBound <= $0.lowerBound }) ?? true {
                    kept += line[..<slashes.lowerBound]
                    line = ""
                } else if let block {
                    kept += line[..<block.lowerBound]
                    if let end = line.range(of: "*/", range: block.upperBound..<line.endIndex) {
                        line = String(line[end.upperBound...])
                    } else {
                        line = ""
                        inBlock = true
                    }
                } else {
                    kept += line
                    line = ""
                }
            }
            out.append(kept)
        }
        return (out.joined(separator: "\n"), inBlock)
    }

    /// The expression `call` passes for the argument labelled `label`, whitespace collapsed — read
    /// at the argument list's own depth, so a nested call's label cannot answer; `nil` when the
    /// call has no such argument. `call` is an argument list as ``calls(of:in:)`` returns it.
    private static func argument(_ label: String, in call: String) -> String? {
        var arguments: [String] = []
        var current = ""
        var depth = 0
        for character in call.dropFirst().dropLast() {
            if "([{".contains(character) { depth += 1 }
            if ")]}".contains(character) { depth -= 1 }
            if character == ",", depth == 0 {
                arguments.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        arguments.append(current)
        for argument in arguments {
            let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix(label + ":") else { continue }
            return trimmed.dropFirst(label.count + 1)
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        return nil
    }

    /// The braces-inclusive body of the first declaration or block that `header` opens.
    private static func body(after header: String, in code: String) -> Range<String.Index>? {
        guard let range = code.range(of: header) else { return nil }
        return body(from: range.upperBound, in: code)
    }

    /// From the first `{` at or after `index` to the `}` that closes it.
    private static func body(from index: String.Index, in code: String) -> Range<String.Index>? {
        guard let open = code[index...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var cursor = open
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return open..<code.index(after: cursor) }
            }
            cursor = code.index(after: cursor)
        }
        return nil
    }

    /// Every call of `name` in `code` with its argument list — from its `(` to the `)` that closes
    /// it — and the trailing closure that follows it, braces included, or `nil` when none does. The
    /// same identifier rule as ``calls(of:in:)``.
    private static func callsWithTrailingClosures(of name: String, in code: String)
        -> [(arguments: String, closure: String?)] {
        var found: [(arguments: String, closure: String?)] = []
        var searchStart = code.startIndex
        while let range = code.range(of: name + "(", range: searchStart..<code.endIndex) {
            searchStart = range.upperBound
            if range.lowerBound > code.startIndex {
                let before = code[code.index(before: range.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }
            var depth = 0
            var cursor = code.index(before: range.upperBound)
            var close: String.Index?
            while cursor < code.endIndex {
                if code[cursor] == "(" { depth += 1 }
                if code[cursor] == ")" {
                    depth -= 1
                    if depth == 0 { close = cursor; break }
                }
                cursor = code.index(after: cursor)
            }
            guard let close else { continue }
            let arguments = String(code[code.index(before: range.upperBound)...close])
            var next = code.index(after: close)
            while next < code.endIndex, code[next].isWhitespace { next = code.index(after: next) }
            let closure = next < code.endIndex && code[next] == "{"
                ? Self.body(from: next, in: code).map { String(code[$0]) } : nil
            found.append((arguments, closure))
        }
        return found
    }

    /// The argument list of every call of `name` in `code` — from its `(` to the `)` that closes
    /// it. `name` must not be the tail of a longer identifier, so `RichText(` is not a `Text(`.
    private static func calls(of name: String, in code: String) -> [String] {
        var found: [String] = []
        var searchStart = code.startIndex
        while let range = code.range(of: name + "(", range: searchStart..<code.endIndex) {
            searchStart = range.upperBound
            if range.lowerBound > code.startIndex {
                let before = code[code.index(before: range.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }
            var depth = 0
            var cursor = code.index(before: range.upperBound)
            while cursor < code.endIndex {
                if code[cursor] == "(" { depth += 1 }
                if code[cursor] == ")" {
                    depth -= 1
                    if depth == 0 {
                        found.append(String(code[code.index(before: range.upperBound)...cursor]))
                        break
                    }
                }
                cursor = code.index(after: cursor)
            }
        }
        return found
    }
}
