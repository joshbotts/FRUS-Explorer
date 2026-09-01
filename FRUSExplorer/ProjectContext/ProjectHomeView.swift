// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ProjectHomeRequest

/// The window value for the macOS Project Home window group (#377 Phase 1).
///
/// Value-based (like `NoteComposerRequest` / `DocumentWindowID`) so the window keeps
/// off the macOS Window menu and identity is the project it shows: opening Project
/// Home for the same project focuses the existing window, while a different project
/// opens its own — a multi-project researcher can keep several project homes open.
/// A dedicated type (rather than a raw `UUID`) makes the `WindowGroup(for:)` target
/// unambiguous.
///
/// Version history:
///   1.0 — #377 Phase 1: initial implementation
struct ProjectHomeRequest: Codable, Hashable {
    /// The `Project.id` this window's dashboard shows.
    let projectId: UUID
}

// MARK: - ProjectCorpusCoverage

/// One coverage tile's content: a corpus this project searched inside, and how much of it has been
/// worked on (W-13 session 2).
///
/// A view-side type rather than a reuse of `QueryMethodAppendix.CorpusCoverage`, which is an export
/// record and carries an export's obligations. Both are built from the same
/// `DocumentEngagementService.partition` over the same gathered keys, so the tile and the appendix
/// state the same numbers by construction rather than by agreement.
///
/// Version history:
///   1.0 — W-13 session 2: initial implementation
struct ProjectCorpusCoverage: Identifiable, Equatable, Sendable {

    /// The corpus, and the tile's stable identity in the grid.
    let corpusId: UUID

    /// Its name, which is the tile's label.
    let corpusName: String

    /// Opened / annotated / collected against the corpus's own document count.
    let coverage: EngagementCoverage

    /// Whether the capture that built the corpus was complete — the denominator can itself be a
    /// floor, and a tile reading "43/267" must not imply 267 was every match.
    let truncation: WorkingCorpus.CaptureTruncation

    /// `ForEach` identity.
    var id: UUID { corpusId }
}

// MARK: - ProjectHomeView

/// The **Project Home** dashboard (#377 Phase 1) — a project's activity workspace.
///
/// Surfaces the project's research question (inline-editable) and date focus, a live
/// activity summary (collections / notes / documents visited / searches), a reserved
/// slot for the Phase-3 "Project Leads" discovery feed, recent activity, and quick jumps.
///
/// Data comes from reactive `@Query`s filtered to the active project in memory (the
/// same approach `GlobalContextViewModel` uses, since SwiftData `#Predicate` support
/// for "`[UUID]` contains" is unreliable), so counts refresh live while the window is
/// open. Presented as the `frus.projectHome` window on macOS (Research ▸ Project
/// Home, ⌘P) and as a screen on iOS/iPadOS.
///
/// Version history:
///   1.0 — #377 Phase 1: initial implementation
struct ProjectHomeView: View {

    /// The project this dashboard shows.
    let projectId: UUID

    /// Called just before this view hands off to another surface (opening a document, or a quick
    /// action to Collections/Research/Search). A **modal** presenter — the iOS Research-tab sheet —
    /// passes `{ dismiss the sheet }` so the hand-off isn't left invisibly behind the modal;
    /// the non-modal presenters (the macOS `frus.projectHome` window and the Settings-tab push)
    /// leave it `nil` and stay put. (#377 Phase 1 iOS follow-up.)
    var onNavigateAway: (() -> Void)? = nil

    /// Opens a document **inside the presenting sheet's own stack** instead of handing it to Browse
    /// (#553 / O-3). `nil` keeps the hand-off, which is what macOS and the Settings push use.
    ///
    /// Project Home was the last of the three sheet origins still dismissing to Browse; Related
    /// Documents and Archival Neighbours moved to in-sheet reading in #757, so a reader could not
    /// predict which sheets kept their place. Only `openDocument` is routed this way —
    /// `openSurface` still hands off through `onNavigateAway`, because switching to the Collections
    /// or Search tab genuinely is leaving.
    var onOpenInSheet: ((DocumentBrowserEntry) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// The presenting window's scene id (#377 follow-up / #338): document and tab hand-offs from
    /// Project Home target the window the researcher is looking at on iPad Stage-Manager multi-window
    /// rather than `.anyWindow` (first-wins). Injected by the iOS sheet presenters (the Settings push
    /// inherits it); macOS routes via fixed window ids and ignores it, so it stays nil there.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    // Reactive activity — fetched whole, filtered to the project in `summary`.
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]
    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse) private var allVisits: [ReadingHistoryEntry]
    @Query(sort: \SearchHistoryEntry.executedAt, order: .reverse) private var allSearches: [SearchHistoryEntry]
    @Query(sort: \ProjectLeadEntry.aggregateScore, order: .reverse) private var allLeads: [ProjectLeadEntry]
    // A count-only reactive signal for the leads recompute trigger (see `seedSignature`) — its
    // `.count` changes when any collection document is added/removed, without faulting relationships.
    @Query private var allCollectionEntries: [CollectionEntry]
    // The researcher's user tags (for the focus-tags chips + editor) and a count-only reactive
    // signal for direct tag assignments (so tagging a document recomputes the focus-tag seed).
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @Query private var allTagAssignments: [DocumentTagAssignment]
    /// #279 / W-4: the user's classification corrections. A `ProjectLeadEntry`'s
    /// `isEditorialNote` is a snapshot taken when the lead surfaced (dismissed leads never
    /// refresh), so the lead row consults these live before trusting it.
    @Query private var classificationOverrides: [DocumentClassificationOverride]
    /// W-13: the corpora, and the highlights the engagement partition needs. Both are read whole
    /// and filtered in memory like every other table on this screen.
    @Query(sort: \WorkingCorpus.name) private var allCorpora: [WorkingCorpus]
    @Query private var allHighlights: [DocumentHighlight]
    /// Coverage of the corpora this project searched inside, recomputed off the body path.
    @State private var corpusCoverage: [ProjectCorpusCoverage] = []
    // Archive Visits Phase 3: the project's plan, resolved by in-memory `projectIds` filter
    // (the file's standing rule — the contains-predicate is unreliable in SwiftData).
    @Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)
    private var allArchiveVisits: [ArchiveVisitPlan]

    /// Local draft of the research question, loaded from the model on appearance and
    /// saved live on every edit (like the collection editors) — so an in-progress edit
    /// is never lost if the window closes before the field would have "committed".
    @State private var questionDraft: String = ""

    /// Whether the focus-subjects editor sheet is presented (#377 Phase 2b).
    @State private var showFocusEditor = false

    /// The in-flight (debounced) leads recompute, and whether one is running (#377 Phase 3).
    @State private var recomputeTask: Task<Void, Never>?
    @State private var isRecomputing = false

    /// Live draft of this project's per-project lead axis weights (#377 Phase 3b), seeded from the
    /// effective weights (project override → global preference → default) on appearance. Editing a
    /// slider updates this immediately for live feedback; the value is persisted to
    /// `Project.leadAxisWeights` and re-ranked only when the drag settles.
    @State private var draftWeights = AxisWeights.default

    /// Whether the inline weight-tuning sliders are expanded (they appear above the leads list).
    @State private var showWeightTuning = false

    /// Whether the "manage collections" editor sheet is presented (#377 Phase 5 polish).
    @State private var showCollectionsEditor = false
    /// The Archive Visit plan being edited — set by Plan a Visit's create-or-open (Phase 3).
    @State private var editingPlan: ArchiveVisitPlan?
    /// The engaged set a NEW plan is seeded from — the leads-seed union, cached per project.
    @State private var engagedPacketDocuments: [(volumeId: String, documentId: String)] = []

    /// Whether the focus-tags editor sheet is presented (#377 Phase 3 — tag focus).
    @State private var showTagsEditor = false

    private var project: Project? { projects.first { $0.id == projectId } }

    private var summary: ProjectHomeSummary {
        ProjectHomeSummary(
            notes:       allNotes.filter { $0.projectIds.contains(projectId) },
            collections: allCollections.filter { $0.projectIds.contains(projectId) },
            visits:      allVisits.filter { $0.projectId == projectId },
            searches:    allSearches.filter { $0.projectId == projectId }
        )
    }

    var body: some View {
        ScrollView {
            if let project {
                VStack(alignment: .leading, spacing: 28) {
                    header(project)
                    summarySection
                    collectionsSection(project)
                    focusSubjectsSection(project)
                    focusTagsSection(project)
                    leadsSection
                    recentSection
                    quickActions
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView(
                    String(localized: "project.home.missing.title", defaultValue: "No Project Selected"),
                    systemImage: "folder",
                    description: Text(String(localized: "project.home.missing.detail",
                                             defaultValue: "Choose a project from the project picker to see its workspace."))
                )
                .padding(.top, 80)
            }
        }
        .navigationTitle(project?.name ?? String(localized: "project.home.title", defaultValue: "Project Home"))
        // Unguarded, unlike ProjectEditorView's `#if os(iOS)` — that guard is an artifact of THAT
        // file's platform-split body. This view has one shared body and is also the macOS
        // `frus.projectHome` window; the modifier compiles away on macOS itself.
        .keyboardDismissBar()
        .task(id: projectId) {
            // Reset per-project state — this view can be reused for a different project (the iOS
            // sheet reuses identity when `activeProjectId` changes), so drop any in-flight recompute
            // and its spinner from the previous project before starting this one's.
            recomputeTask?.cancel()
            isRecomputing = false
            questionDraft = project?.researchQuestion ?? ""
            if let project { draftWeights = ProjectLeadsService.effectiveWeights(for: project) }
            scheduleRecompute(immediate: true)   // no chatter to debounce on open / project switch
            await refreshEngagedPacketDocuments()   // the Plan-a-Visit gate's content test
        }
        // Keyed on the LEAD KEYS, not the project (#553). A recompute replaces the lead set without
        // changing `projectId`, so a project-keyed task would leave the old snippets on screen —
        // attached to rows that are gone, under headers they do not describe. Sorted so a reorder
        // of the same leads is not a refetch.
        .task(id: leadSnippetIdentity) {
            await loadLeadSnippets()
        }
        // Recompute leads when the project's collections (or their documents) change — the
        // discovery feedback loop (#377 Phase 3). Debounced inside `scheduleRecompute`.
        .onChange(of: seedSignature) { _, _ in scheduleRecompute() }
        // W-13 coverage tiles. Keyed on a cheap signature of the tables the partition reads, so it
        // recomputes when the answer can have changed and never on a bare re-render — the set
        // arithmetic is over every note, visit and collection on the device, which is work this
        // screen's body must not do.
        .task(id: coverageSignature) { refreshCoverage() }
        .onDisappear { recomputeTask?.cancel() }
        .sheet(isPresented: $showFocusEditor) {
            ProjectFocusSubjectsEditor(projectId: projectId)
        }
        .sheet(isPresented: $showCollectionsEditor) {
            if let project {
                ProjectCollectionsEditor(projectId: project.id, projectName: project.name)
            }
        }
        .sheet(isPresented: $showTagsEditor) {
            ProjectFocusTagsEditor(projectId: projectId)
        }
        .sheet(item: $editingPlan) { plan in
            // Phase 3: Plan a Visit is create-or-open over the PERSISTENT plan (§4a / 1h) —
            // a new plan seeds once from the SAME gatherSeed union the leads engine computes,
            // and thereafter the plan is the researcher's edit surface (an explicit
            // "Re-seed from Project" lives in the editor; never a live mirror).
            NavigationStack {
                ArchiveVisitEditorView(plan: plan)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "research.projectHome.done",
                                          defaultValue: "Done")) {
                                editingPlan = nil
                            }
                        }
                    }
            }
            .environment(appState)
        }
    }

    // MARK: - Coverage (W-13)

    /// The signature the coverage recompute is keyed on.
    ///
    /// Counts only. It moves when a visit, note, highlight, collection or corpus is added or
    /// removed, and when the corpora this project has searched changes — which is every way the
    /// tiles' numbers can move except editing an existing record's project membership, the same
    /// bound `EngagementObserver` accepts in `CorpusDocumentsView`.
    private var coverageSignature: String {
        let searched = Set(summary.searches.compactMap(\.appliedCorpusId)).count
        return "\(projectId)-\(allVisits.count)-\(allNotes.count)-\(allHighlights.count)" +
               "-\(allCollections.count)-\(allCollectionEntries.count)-\(allCorpora.count)-\(searched)"
    }

    /// Recomputes the coverage tiles from the arrays already on screen.
    ///
    /// **The corpora are the ones this project searched inside**, resolved through
    /// `SearchHistoryEntry.appliedCorpusId` — the only record in the app carrying a corpus id and a
    /// project id together. A `WorkingCorpus` has no project of its own, so any other choice of
    /// universe would either invent a relationship or show the researcher corpora from an unrelated
    /// line of work. Same rule as the exported appendix, which is why both read it from the log.
    ///
    /// No fetch: every table it needs is already a `@Query` on this view, and
    /// `DocumentEngagementService`'s pure overloads take the arrays directly, so the tiles and the
    /// export cannot come to disagree about what counts.
    private func refreshCoverage() {
        let searched = Set(summary.searches.compactMap(\.appliedCorpusId))
        let measurable = allCorpora.filter { searched.contains($0.id) }
        guard !measurable.isEmpty else {
            corpusCoverage = []
            return
        }
        let keys = DocumentEngagementService.gather(collections: allCollections,
                                                    notes: allNotes,
                                                    highlights: allHighlights,
                                                    visits: allVisits,
                                                    forProject: projectId)
        let isOpenedComplete = AppState.isResearchLoggingEnabled
        corpusCoverage = measurable.map { corpus in
            ProjectCorpusCoverage(
                corpusId: corpus.id,
                corpusName: corpus.name,
                coverage: DocumentEngagementService.partition(corpusKeys: corpus.documentKeys,
                                                              keys: keys,
                                                              isOpenedComplete: isOpenedComplete),
                truncation: corpus.truncationAtCapture)
        }
    }

    // MARK: - Focus tags (#377 Phase 3 — tag focus)

    /// The project's user-tag focus: the tags whose documents anchor this project's suggestions, plus
    /// an editor entry. Distinct from the *subject* focus above (which scopes Mode A search to
    /// volumes) — these are the researcher's own tags feeding the leads seed. Shown only once the
    /// researcher has created tags.
    @ViewBuilder
    private func focusTagsSection(_ project: Project) -> some View {
        if !allTags.isEmpty {
            let chosen = project.defaultUserTagIds
            let chosenTags = allTags.filter { chosen.contains($0.id) }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(localized: "project.home.focusTags.title", defaultValue: "Focus tags"))
                        .font(.headline)
                    Spacer()
                    Button {
                        showTagsEditor = true
                    } label: {
                        Label(chosenTags.isEmpty
                              ? String(localized: "project.home.focusTags.add", defaultValue: "Add")
                              : String(localized: "project.home.focusTags.edit", defaultValue: "Edit"),
                              systemImage: "tag")
                    }
                    .buttonStyle(.borderless)
                }
                if chosenTags.isEmpty {
                    Text(String(localized: "project.home.focusTags.empty",
                                defaultValue: "Choose tags whose documents should anchor this project's suggestions."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                              alignment: .leading, spacing: 8) {
                        ForEach(chosenTags) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Collections (#377 Phase 5 polish)


    /// The project's engaged documents, for the trip packet (Archive Visits Phase 0).
    ///
    /// Parity with Suggested Next **by construction**: this calls the same
    /// `ProjectLeadsService.gatherSeed` the leads engine runs — collections ∪ noted documents
    /// ∪ focus-tagged documents — rather than re-implementing one of its three sources. The
    /// previous version walked `summary.collections` only, while claiming parity in its doc
    /// comment: a researcher who works by annotating rather than filing got a packet that
    /// omitted every document they had engaged with, three sections below the leads that
    /// ranked over all of them.
    private func refreshEngagedPacketDocuments() async {
        let keys = await ProjectLeadsService.gatherSeed(
            forProject: projectId, container: modelContext.container).seedKeys
        engagedPacketDocuments = keys.compactMap { DocumentKey(compositeString: $0)?.tuple }
    }

    /// This project's Archive Visit, when one exists.
    private var projectPlan: ArchiveVisitPlan? {
        allArchiveVisits.first { $0.projectIds.contains(projectId) }
    }

    /// Create-or-open (Phase 3, §4a/1h): open the project's existing plan, or create one —
    /// auto-named from the project, inquiry seeded from its research question, seeds from
    /// the leads union with both contributions on.
    private func planVisit(_ project: Project) async {
        if let existing = projectPlan {
            editingPlan = existing
            return
        }
        await refreshEngagedPacketDocuments()
        let plan = ArchiveVisitPlan(name: project.name,
                                    inquiryText: project.researchQuestion,
                                    projectIds: [projectId])
        modelContext.insert(plan)
        plan.addSeeds(engagedPacketDocuments, includeSource: true,
                      includeExternalRefs: true, in: modelContext)
        try? modelContext.save()
        editingPlan = plan
    }

    /// The project's collections: which ones are attached, plus a "Manage" entry to attach or detach
    /// existing collections. A collection belongs to a project via `Collection.projectIds`, which was
    /// previously set only implicitly (when a collection was created while the project was active);
    /// this gives an explicit control.
    @ViewBuilder
    private func collectionsSection(_ project: Project) -> some View {
        let members = summary.collections
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "project.home.collections.title", defaultValue: "Collections"))
                    .font(.headline)
                Spacer()
                // Archive Visits Phase 0: the packet is built over the ENGAGED set — the same
                // collections ∪ notes ∪ focus-tags union that seeds the leads engine — and the
                // gate tests that CONTENT, not whether a collection happens to be attached. An
                // attached-but-empty collection used to enable this button onto an empty packet.
                Button {
                    Task { await planVisit(project) }
                } label: {
                    Label(String(localized: "project.home.planVisit",
                                 defaultValue: "Plan a Visit"),
                          systemImage: "building.columns")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                // Enabled by engaged CONTENT — or by an existing plan, which can always be
                // opened (its seeds are its own; the project's current state no longer gates it).
                .disabled(engagedPacketDocuments.isEmpty && projectPlan == nil)
                Button {
                    showCollectionsEditor = true
                } label: {
                    Label(String(localized: "project.home.collections.manage", defaultValue: "Manage"),
                          systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.borderless)
            }
            if members.isEmpty {
                Text(String(localized: "project.home.collections.empty",
                            defaultValue: "Attach collections to fold their documents into this project's activity and suggestions."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(members) { collection in
                    Label {
                        Text(collection.name.isEmpty
                             ? String(localized: "project.home.collections.untitled", defaultValue: "Untitled collection")
                             : collection.name)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "tray.2").foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Focus subjects (#377 Phase 2b)

    /// The project's discovery-focus subjects: a chip list plus an editor entry. The focus
    /// resolves (in Mode A search) to the volumes those subjects are characteristic of, so a
    /// project's subjects become a discovery lens over the corpus. Hidden when the subject
    /// index is unavailable.
    @ViewBuilder
    private func focusSubjectsSection(_ project: Project) -> some View {
        if let profiles = VolumeSubjectProfilesStore.shared {
            let chosen = project.defaultSubjectTagIds
            let subjects = profiles.allSubjects.filter { chosen.contains($0.ref) }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(localized: "project.home.focus.title", defaultValue: "Focus subjects"))
                        .font(.headline)
                    Spacer()
                    Button {
                        showFocusEditor = true
                    } label: {
                        Label(subjects.isEmpty
                              ? String(localized: "project.home.focus.add", defaultValue: "Add")
                              : String(localized: "project.home.focus.edit", defaultValue: "Edit"),
                              systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderless)
                }
                if subjects.isEmpty {
                    Text(String(localized: "project.home.focus.empty",
                                defaultValue: "Choose subjects to focus discovery on the volumes they define."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                              alignment: .leading, spacing: 8) {
                        ForEach(subjects) { subject in
                            Text(subject.name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
            }
        }
    }


    // MARK: - Header (name + research question + focus)

    @ViewBuilder
    private func header(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(project.name)
                .font(.largeTitle.weight(.semibold))

            TextField(
                String(localized: "project.home.question.placeholder",
                       defaultValue: "What is this project's research question?"),
                text: $questionDraft,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .foregroundStyle(.secondary)
            .lineLimit(1...4)
            // Save live — `commitQuestion` no-ops when unchanged, so the initial `.task` load
            // (which sets `questionDraft` to the model's value) never writes a spurious edit.
            .onChange(of: questionDraft) { _, _ in commitQuestion(project) }

            if let range = dateFocusText(project) {
                Label(range, systemImage: "calendar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    /// A readable date-focus chip from the project's default date range, or `nil` if unset.
    private func dateFocusText(_ project: Project) -> String? {
        let cal = Calendar.current
        func year(_ date: Date?) -> Int? { date.map { cal.component(.year, from: $0) } }
        // Grouping off: `String(localized:)` runs an interpolated `Int` through a number
        // formatter, so an open-ended range read "From 1,969". The two-sided case uses plain
        // interpolation and was always correct, which is what hid this.
        let plain = IntegerFormatStyle<Int>.number.grouping(.never)
        switch (year(project.defaultDateRangeStart), year(project.defaultDateRangeEnd)) {
        case let (start?, end?): return "\(start)–\(end)"
        case let (start?, nil):  return String(localized: "project.home.dateFrom",
                                               defaultValue: "From \(start, format: plain)")
        case let (nil, end?):    return String(localized: "project.home.dateTo",
                                               defaultValue: "Through \(end, format: plain)")
        case (nil, nil):         return nil
        }
    }

    /// Writes the draft back to the model only when it actually changed.
    private func commitQuestion(_ project: Project) {
        let trimmed = questionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = trimmed.isEmpty ? nil : trimmed
        if project.researchQuestion != newValue {
            project.researchQuestion = newValue
        }
    }

    // MARK: - Activity summary

    private var summarySection: some View {
        let s = summary
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            statTile(s.collectionCount,
                     String(localized: "project.home.stat.collections", defaultValue: "Collections"),
                     "tray.2")
            statTile(s.noteCount,
                     String(localized: "project.home.stat.notes", defaultValue: "Notes"),
                     "note.text")
            statTile(s.documentsVisitedCount,
                     String(localized: "project.home.stat.visited", defaultValue: "Documents Visited"),
                     "book")
            statTile(s.searchCount,
                     String(localized: "project.home.stat.searches", defaultValue: "Searches Run"),
                     "magnifyingglass")
            // W-13: one tile per corpus this project searched inside. Not a fifth fixed tile,
            // because the number of corpora is a property of the research and not of the layout —
            // and none at all is the common case, where the grid is exactly as it was.
            ForEach(corpusCoverage) { entry in
                coverageTile(entry)
            }
        }
    }

    /// A coverage tile: how much of one searched corpus this project has worked on.
    ///
    /// A fraction where the others show a count, because the number alone answers nothing — "43"
    /// is progress against 60 and a standing start against 6,000. The corpus name is the label,
    /// so several tiles are told apart by the thing that distinguishes them.
    private func coverageTile(_ entry: ProjectCorpusCoverage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(entry.corpusName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            } icon: {
                Image(systemName: "checklist").foregroundStyle(.secondary)
            }
            Text(verbatim: "\(entry.coverage.engagedCount)/\(entry.coverage.totalCount)")
                .font(.title.weight(.semibold))
                .contentTransition(.numericText())
            Text(entry.coverage.untouchedDescription)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let note = CorporaAxis.truncationLine(entry.truncation,
                                                     documentCount: entry.coverage.totalCount) {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.corpusName): \(entry.coverage.coverageDescription)")
    }

    private func statTile(_ count: Int, _ label: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(label).font(.caption).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            }
            Text("\(count)")
                .font(.title.weight(.semibold))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Project Leads slot (Phase 3 placeholder)

    /// The project's non-dismissed leads, ranked by aggregate relatedness (#377 Phase 3).
    private var projectLeads: [ProjectLeadEntry] {
        allLeads.filter { $0.projectId == projectId && !$0.dismissed }
    }

    /// Leading document text for the leads on screen, keyed by `"volumeId/documentId"` (#553).
    ///
    /// `ProjectLeadEntry` stores no body text, and `ProjectLeadsService` deliberately ranks with
    /// `includeSnippets: false` because that extraction would run up to `seedCap` times per
    /// recompute over candidates that are mostly never shown. So the text is fetched here instead —
    /// once, for the ≤ `leadLimit` leads actually rendered.
    ///
    /// Missing keys are normal, not an error: a lead whose volume is not indexed on this device has
    /// no `document_cache` row, and its row simply renders as it did before.
    @State private var leadSnippets: [String: String] = [:]

    @ViewBuilder
    private var leadsSection: some View {
        let leads = projectLeads
        let canTune = !summary.collections.isEmpty
        VStack(alignment: .leading, spacing: 10) {
            // Title line with the inline "Adjust weighting" toggle (only when there's a seed to tune).
            HStack(spacing: 8) {
                Text(String(localized: "project.home.leads.title", defaultValue: "Suggested Next"))
                    .font(.headline)
                Spacer()
                if canTune {
                    Button {
                        withAnimation(.snappy) { showWeightTuning.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text(String(localized: "project.home.leads.tune", defaultValue: "Adjust weighting"))
                            Image(systemName: showWeightTuning ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            // Sliders expand ABOVE the list.
            if showWeightTuning, canTune, let project {
                weightTuningPanel(project)
            }
            if leads.isEmpty {
                Label {
                    Text(String(localized: "project.home.leads.placeholder",
                                defaultValue: "As you add documents to this project's collections, related documents you haven't gathered yet will surface here."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "sparkles").foregroundStyle(.secondary)
                }
            } else {
                ForEach(leads) { leadRow($0) }
            }
            leadsFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The refresh control / recompute status under the leads.
    @ViewBuilder
    private var leadsFooter: some View {
        HStack(spacing: 8) {
            if isRecomputing {
                ProgressView().controlSize(.small)
                Text(String(localized: "project.home.leads.computing", defaultValue: "Finding leads…"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button {
                    scheduleRecompute(immediate: true)
                } label: {
                    Label(String(localized: "project.home.leads.refresh", defaultValue: "Refresh"),
                          systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private func leadRow(_ lead: ProjectLeadEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                openDocument(volumeId: lead.volumeId, documentId: lead.documentId,
                             title: lead.header.isEmpty ? nil : lead.header)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(lead.header.isEmpty ? lead.documentKey : lead.header)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        if isNewLead(lead) {
                            Text(String(localized: "project.home.leads.new", defaultValue: "NEW"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(leadContext(lead))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // #553: the reported complaint is that a lead row carries too little to judge
                    // the document by. `documentSnippets` prefers the stored summary over the body,
                    // so this is "the summary if there is one, otherwise the opening text" — which
                    // is what the copy below the row has to allow for.
                    if let snippet = leadSnippets[lead.documentKey], !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                dismissLead(lead)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "project.home.leads.dismiss.help", defaultValue: "Dismiss this lead"))
        }
        .padding(.vertical, 3)
    }

    /// The identity of the currently-displayed lead set, for the snippet fetch's `.task(id:)`.
    ///
    /// Sorted rather than in display order: re-ranking the same leads changes nothing about which
    /// text is needed, and refetching on every weight-slider drag would be pure churn.
    private var leadSnippetIdentity: [String] {
        projectLeads.map(\.documentKey).sorted()
    }

    /// Fetches the leading text for the displayed leads — one chunked point-lookup by primary key,
    /// never a scan (#553).
    ///
    /// Bounded by `ProjectLeadsService.leadLimit` (24), so this is a single chunk in practice. It
    /// is the same call `RelatedDocumentsEngine` already makes for its shown rows, and deliberately
    /// NOT `includeSnippets: true` on the ranking pass, which would extract for up to 40 seeds'
    /// worth of candidates that are never rendered.
    private func loadLeadSnippets() async {
        let keys = projectLeads.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        guard !keys.isEmpty, let pipeline = appState.indexingPipeline else {
            leadSnippets = [:]
            return
        }
        // A read failure degrades to no snippets, which is the same as an unindexed volume and
        // renders as the pre-#553 row. There is nothing here worth surfacing an error for.
        leadSnippets = (try? await pipeline.documentSnippets(forKeys: keys)) ?? [:]
    }

    /// "Related to N of your documents" (+ an editorial-note marker).
    private func leadContext(_ lead: ProjectLeadEntry) -> String {
        let n = lead.contributingSeedKeys.count
        let related = n == 1
            ? String(localized: "project.home.leads.related.one",
                     defaultValue: "Related to 1 of your documents")
            : String(localized: "project.home.leads.related.other",
                     defaultValue: "Related to \(n) of your documents")
        guard effectiveIsEditorialNote(for: lead) else { return related }
        return related + " · " + String(localized: "project.home.leads.editorial", defaultValue: "Editorial note")
    }

    /// The lead's editorial-note flag with the user's classification corrections applied
    /// (#279 / W-4): an override for the lead's document wins over the lead's own snapshot,
    /// which was taken when the lead surfaced and can be stale.
    private func effectiveIsEditorialNote(for lead: ProjectLeadEntry) -> Bool {
        if let override = classificationOverrides.first(where: {
            $0.volumeId == lead.volumeId && $0.documentId == lead.documentId
        }) {
            return override.isEditorialNote
        }
        return lead.isEditorialNote
    }

    /// A lead surfaced within the last week reads as new.
    private func isNewLead(_ lead: ProjectLeadEntry) -> Bool {
        lead.firstSurfacedAt > Date.now.addingTimeInterval(-7 * 24 * 3600)
    }

    /// Marks a lead dismissed so it stops surfacing (the reactive `@Query` removes it).
    private func dismissLead(_ lead: ProjectLeadEntry) {
        lead.dismissed = true
    }

    // MARK: - Leads recompute (debounced)

    /// A signature that changes when the project's collections or their documents change, so
    /// the leads recompute as the seed grows — the discovery feedback loop.
    ///
    /// Reads only scalars, so it can be re-evaluated on every `body` render (including every
    /// keystroke in the research-question field) without faulting any relationship: the project
    /// collections' ids + `lastModified` (which bumps on rename / retag and the
    /// `documentEntries.append` add path), plus the app-wide `CollectionEntry` count as a coarse
    /// reactive signal for the `entry.collection =` inverse-add path (which doesn't bump the
    /// parent's `lastModified`), plus the distinct set of the project's **noted document keys** (the
    /// second seed source), plus the distinct set of the documents the project's **focus tags**
    /// resolve to (the third seed source — from direct + note-applied tags). All scalar reads, so no
    /// relationship fault. This only decides *when* to recompute; the real seed is derived off-main
    /// inside `recompute`, and the open-time and Refresh recomputes backstop any coarse miss (e.g. an
    /// add + remove that leaves the collection-entry count unchanged).
    private var seedSignature: String {
        let collections = summary.collections
            .map { "\($0.id.uuidString):\($0.lastModified?.timeIntervalSince1970 ?? 0)" }
            .sorted()
            .joined(separator: ",")
        let notedDocs = Set(summary.notes
            .filter { !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .map { "\($0.volumeId)/\($0.documentId)" })
            .sorted()
            .joined(separator: ",")
        // The exact set of documents the project's focus tags resolve to — from direct tag
        // assignments AND note-applied tags, all scalar reads (tagId / userTagIds / volumeId /
        // documentId), no relationship fault. This reacts to editing the focus set AND to
        // (re)tagging a document, including a same-count tag swap (which a bare assignment count
        // would miss). Empty when the project has no focus tags.
        let focusTagSet = Set(project?.defaultUserTagIds ?? [])
        let taggedDocs = focusTagSet.isEmpty ? "" : Set(
            allTagAssignments
                .filter { focusTagSet.contains($0.tagId) && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
                .map { "\($0.volumeId)/\($0.documentId)" }
            + allNotes
                .filter { !Set($0.userTagIds).isDisjoint(with: focusTagSet)
                          && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
                .map { "\($0.volumeId)/\($0.documentId)" })
            .sorted()
            .joined(separator: ",")
        return "\(allCollectionEntries.count)|\(collections)|n:\(notedDocs)|tg:\(taggedDocs)"
    }

    /// Schedules a debounced leads recompute. `immediate` skips the debounce (the Refresh button
    /// and the open-time / project-switch recompute, which have no chatter to debounce against).
    /// The engine work is bounded and `async`, so it never blocks the UI.
    private func scheduleRecompute(immediate: Bool = false) {
        recomputeTask?.cancel()
        recomputeTask = Task { @MainActor in
            if !immediate { try? await Task.sleep(for: .milliseconds(800)) }
            guard !Task.isCancelled else { return }
            isRecomputing = true
            await ProjectLeadsService.recompute(forProject: projectId, appState: appState, in: modelContext)
            // A superseding schedule (or view teardown) cancelled us while `recompute` ran — leave
            // the flag for the live task to own, so its spinner state isn't stomped by our exit.
            guard !Task.isCancelled else { return }
            isRecomputing = false
        }
    }

    // MARK: - Lead weight tuning (#377 Phase 3b)

    /// The inline weight-tuning panel that expands above the leads list — the per-project override of
    /// the global related-documents weighting. Mirrors the document-view Related panel's weight
    /// sliders (same axes, same `0…1` range, same persist-on-release behaviour), but writes to
    /// `Project.leadAxisWeights` and re-ranks the leads instead of the panel.
    @ViewBuilder
    private func weightTuningPanel(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "project.home.leads.tune.detail",
                        defaultValue: "Set how much each kind of connection shapes this project's suggestions."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(SimilarityAxis.allCases) { axis in
                // No caption here: the semantic axis's explanation belongs where the reader meets
                // the axis itself, in the Related panel (#1029).
                AxisWeightRow(
                    axis: axis,
                    value: Binding(get: { draftWeights[axis] }, set: { draftWeights[axis] = $0 }),
                    onCommit: { commitWeights(project) })
            }
            HStack {
                Spacer()
                Button(String(localized: "project.home.leads.tune.reset", defaultValue: "Reset to global default")) {
                    resetWeights(project)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(project.leadAxisWeights == nil)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Persists the drafted weights to the project (its per-project override) and re-ranks the leads.
    /// No-ops when the released value matches what's stored (a tap, or a drag back to the start), and
    /// uses the *debounced* recompute so tuning several axes in a row coalesces into one re-rank
    /// (matching the `seedSignature` path — an immediate recompute per release would cancel-and-restart
    /// the up-to-`seedCap` ranking pass on every axis).
    private func commitWeights(_ project: Project) {
        let raw = draftWeights.rawValue
        guard raw != project.leadAxisWeights else { return }
        project.leadAxisWeights = raw
        scheduleRecompute()
    }

    /// Clears the per-project override (falling back to the global preference / default), re-seeds the
    /// sliders from the now-effective weights, and re-ranks.
    private func resetWeights(_ project: Project) {
        project.leadAxisWeights = nil
        draftWeights = ProjectLeadsService.effectiveWeights(for: project)
        scheduleRecompute(immediate: true)
    }

    // MARK: - Recent activity

    @ViewBuilder
    private var recentSection: some View {
        let s = summary
        if s.isEmpty {
            sectionCard(String(localized: "project.home.recent.title", defaultValue: "Recent Activity")) {
                Text(String(localized: "project.home.recent.empty",
                            defaultValue: "No activity in this project yet. Read documents, take notes, or build a collection while this project is active and it will appear here."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            if !s.recentVisits.isEmpty {
                sectionCard(String(localized: "project.home.recent.documents", defaultValue: "Recently Read")) {
                    ForEach(s.recentVisits) { visit in
                        recentRow(title: visit.displayTitle ?? "\(visit.volumeId) · \(visit.documentId)",
                                  systemImage: "book") {
                            openDocument(volumeId: visit.volumeId, documentId: visit.documentId,
                                         title: visit.displayTitle)
                        }
                    }
                }
            }
            if !s.recentNotes.isEmpty {
                sectionCard(String(localized: "project.home.recent.notes", defaultValue: "Recent Notes")) {
                    ForEach(s.recentNotes) { note in
                        recentRow(title: noteTitle(note), systemImage: "note.text") {
                            openDocument(volumeId: note.volumeId, documentId: note.documentId, title: nil)
                        }
                    }
                }
            }
            if !s.recentSearches.isEmpty {
                sectionCard(String(localized: "project.home.recent.searches", defaultValue: "Recent Searches")) {
                    ForEach(s.recentSearches) { search in
                        // Display-only in Phase 1; re-run arrives with project-scoped search (Phase 2).
                        Label {
                            HStack {
                                Text(search.queryText.isEmpty
                                     ? String(localized: "project.home.search.untitled", defaultValue: "(no query text)")
                                     : search.queryText)
                                Spacer()
                                Text(String(localized: "project.home.search.results",
                                            defaultValue: "\(search.resultCount) results"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func noteTitle(_ note: ResearchNote) -> String {
        "\(note.volumeId) · \(note.documentId)"
    }

    private func recentRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickButton(String(localized: "project.home.action.collections", defaultValue: "Collections"),
                        "tray.2") { openSurface("frus.collections") }
            quickButton(String(localized: "project.home.action.research", defaultValue: "Research"),
                        "note.text") { openSurface("frus.research") }
            quickButton(String(localized: "project.home.action.search", defaultValue: "Search"),
                        "magnifyingglass") { openSurface("frus.search") }
        }
    }

    private func quickButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Section card

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Navigation actions

    private func openDocument(volumeId: String, documentId: String, title: String?) {
        let entry = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            header: title ?? "\(volumeId) · \(documentId)"
        )
        // #553: read inside the sheet when the presenter offers a stack. Dropping the dismiss
        // WITHOUT pushing here would be #750's H-5 defect — the document lands invisibly beneath a
        // still-presented sheet — which is why this is an explicit push rather than a removal.
        if let onOpenInSheet {
            onOpenInSheet(entry)
            return
        }
        performNavigation {
            #if os(macOS)
            // Route through the provenance model, which MINTS a standalone window when no document
            // host is live (#748 / audit H-0). Project Home is its own window and the main window
            // can be closed (⌘W) while the app keeps running — before this, the click wrote
            // `pendingBrowseDocument`, whose only macOS consumers are the document hosts' drains.
            // With zero hosts mounted nothing observed the write, so the click did nothing at all
            // *and was not discarded*: the next window the user opened, minutes or days later,
            // immediately navigated itself to the long-forgotten document.
            //
            // `.global` rather than `.tool(…)` because Project Home has no `ToolWindowID` — it is a
            // dashboard, not a document-derived tool, so there is no launching host to bind to.
            // `.global` resolves to the most-recently-key live host, else mints.
            appState.openDocument(entry, from: .global, using: openWindow)
            #else
            // The document lands in the Browse tab's stack; bring that tab forward so the tap isn't a
            // silent no-op (Project Home is reached from the Settings tab). Mirrors the other callers.
            appState.openTab(.browse, from: sceneID)
            appState.openBrowseDocument(entry, from: sceneID)
            #endif
        }
    }

    private func openSurface(_ windowId: String) {
        performNavigation {
            #if os(macOS)
            openWindow.fronting(id: windowId)
            #else
            // AppTab is iOS-only; map the shared window id to the matching tab.
            let tab: AppTab
            switch windowId {
            case "frus.collections": tab = .collections
            case "frus.research":    tab = .research
            case "frus.search":      tab = .search
            default:                 tab = .browse
            }
            appState.openTab(tab, from: sceneID)
            #endif
        }
    }

    /// Runs a navigation hand-off, dismissing a modal presenter first (if any).
    ///
    /// When there IS a modal presenter (the iOS Research-tab sheet passes `onNavigateAway`), the
    /// hand-off is deferred one main-actor tick so the sheet's dismissal and the tab-switch/document
    /// push don't land in a single SwiftUI update — doing both in one frame trips
    /// "NavigationRequestObserver tried to update multiple times per frame" and the push is dropped
    /// (#431 on-device). The non-modal presenters (macOS window, Settings push) have no dismissal to
    /// collide with, so they run the hand-off synchronously as before.
    private func performNavigation(_ handoff: @escaping @MainActor () -> Void) {
        guard let onNavigateAway else {
            handoff()
            return
        }
        onNavigateAway()
        Task { @MainActor in handoff() }
    }
}

// MARK: - ProjectCollectionsEditor

/// Attaches existing collections to a project (or detaches them) — #377 Phase 5 polish.
///
/// A collection belongs to a project through `Collection.projectIds` (an array — a collection can
/// belong to several projects at once). Previously that was set only implicitly, when a collection
/// was *created* while the project was active; this sheet makes it explicit. Toggling membership
/// writes straight to the model (its `projectIds` `didSet` bumps `lastModified`), so the project's
/// activity summary, engaged set, and leads seed all update reactively.
///
/// Presented as a sheet from Project Home; shared by both platforms.
///
/// Version history:
///   1.0 — #377 Phase 5: initial implementation
struct ProjectCollectionsEditor: View {

    /// The project whose collection membership is being edited.
    let projectId: UUID

    /// The project's name, shown in the sheet title so concurrent Project Home windows (macOS) each
    /// have a distinguishable "Manage collections" sheet.
    let projectName: String

    @Environment(\.dismiss) private var dismiss

    /// Every collection, so the researcher can attach any of them (member or not).
    @Query(sort: \Collection.name) private var allCollections: [Collection]

    var body: some View {
        NavigationStack {
            Group {
                if allCollections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "project.collections.manage.empty.title", defaultValue: "No Collections"),
                        systemImage: "tray",
                        description: Text(String(localized: "project.collections.manage.empty.detail",
                                                 defaultValue: "Create a collection first, then attach it to this project here."))
                    )
                } else {
                    List {
                        let members = allCollections.filter { $0.projectIds.contains(projectId) }
                        let others = allCollections.filter { !$0.projectIds.contains(projectId) }
                        if !members.isEmpty {
                            Section(String(localized: "project.collections.manage.attached", defaultValue: "In this project")) {
                                ForEach(members) { collection in
                                    memberRow(collection)
                                }
                            }
                        }
                        Section {
                            if others.isEmpty {
                                Text(String(localized: "project.collections.manage.allAttached",
                                            defaultValue: "Every collection is already in this project."))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(others) { collection in
                                    addRow(collection)
                                }
                            }
                        } header: {
                            Text(String(localized: "project.collections.manage.add", defaultValue: "Add collections"))
                        } footer: {
                            Text(String(localized: "project.collections.manage.footer",
                                        defaultValue: "A collection can belong to more than one project. Attaching it here doesn't remove it from any others."))
                        }
                    }
                }
            }
            .navigationTitle(projectName.isEmpty
                             ? String(localized: "project.collections.manage.title", defaultValue: "Project Collections")
                             : String(localized: "project.collections.manage.titleNamed",
                                      defaultValue: "Collections · \(projectName)"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.collections.manage.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    /// A row for a collection already in this project: its name + document count, with a destructive
    /// **minus** button and a trailing swipe-to-remove — both detach it from the project.
    @ViewBuilder
    private func memberRow(_ collection: Collection) -> some View {
        HStack(spacing: 10) {
            collectionInfo(collection)
            Spacer()
            Button {
                detach(collection)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "project.collections.manage.remove.help", defaultValue: "Remove from this project"))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                detach(collection)
            } label: {
                Label(String(localized: "project.collections.manage.remove", defaultValue: "Remove"),
                      systemImage: "minus.circle")
            }
        }
    }

    /// A row for a collection not yet in this project: tapping it (or its leading plus) attaches it.
    private func addRow(_ collection: Collection) -> some View {
        Button {
            attach(collection)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                collectionInfo(collection)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The shared name + document-count label for a collection row. The count matches what actually
    /// seeds the leads engine (`ProjectLeadsService.collectionSeedKeys`): distinct document-kind
    /// entries with non-empty ids, so malformed or duplicate entries don't inflate it.
    @ViewBuilder
    private func collectionInfo(_ collection: Collection) -> some View {
        let docCount = Set(
            (collection.documentEntries ?? [])
                .filter { $0.entryKind == .document && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
                .map { "\($0.volumeId)/\($0.documentId)" }
        ).count
        VStack(alignment: .leading, spacing: 2) {
            Text(collection.name.isEmpty
                 ? String(localized: "project.collections.manage.untitled", defaultValue: "Untitled collection")
                 : collection.name)
                .foregroundStyle(.primary)
            Text(docCount == 1
                 ? String(localized: "project.collections.manage.docCount.one", defaultValue: "1 document")
                 : String(localized: "project.collections.manage.docCount.other", defaultValue: "\(docCount) documents"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Attaches the collection to this project (idempotent).
    private func attach(_ collection: Collection) {
        guard !collection.projectIds.contains(projectId) else { return }
        collection.projectIds = Self.toggledMembership(projectId, in: collection.projectIds)
    }

    /// Detaches the collection from this project (idempotent), preserving its other projects.
    private func detach(_ collection: Collection) {
        guard collection.projectIds.contains(projectId) else { return }
        collection.projectIds = Self.toggledMembership(projectId, in: collection.projectIds)
    }

    /// Returns `ids` with `projectId` toggled — removed if present, appended if absent. Pure so the
    /// add/remove (and its preservation of the collection's other projects) is unit-testable.
    static func toggledMembership(_ projectId: UUID, in ids: [UUID]) -> [UUID] {
        if let index = ids.firstIndex(of: projectId) {
            var updated = ids
            updated.remove(at: index)
            return updated
        }
        return ids + [projectId]
    }
}

// MARK: - ProjectFocusTagsEditor

/// Chooses which of the researcher's user tags focus a project's suggestions (#377 Phase 3).
///
/// The chosen tags are stored in `Project.defaultUserTagIds`; documents carrying any of them (via a
/// direct tag or a note tag) join the project's Project Leads seed. User tags are otherwise global,
/// so this is the project's deliberate lens over them. Selection saves live (toggling writes
/// straight to the model). Presented as a sheet from Project Home; shared by both platforms.
///
/// Version history:
///   1.0 — #377 Phase 3: initial implementation
struct ProjectFocusTagsEditor: View {

    /// The project whose tag focus is being edited; `defaultUserTagIds` is written live. Held by id
    /// and re-resolved through `@Query` (not a live `@Bindable` reference), so a deletion from
    /// another window/scene can't leave this sheet holding a deleted model to trap on.
    let projectId: UUID

    @Environment(\.dismiss) private var dismiss

    /// The researcher's user tags (a small, free-form set — no search needed).
    @Query(sort: \UserTag.name) private var allTags: [UserTag]

    /// All projects, filtered to `projectId` in `project`. Reactive: the row drops out on deletion.
    @Query private var projects: [Project]

    /// The project being edited, or `nil` if it was deleted while the sheet was open.
    private var project: Project? { projects.first { $0.id == projectId } }

    var body: some View {
        NavigationStack {
            Group {
                if let project {
                    if allTags.isEmpty {
                        ContentUnavailableView(
                            String(localized: "project.focusTags.empty.title", defaultValue: "No Tags"),
                            systemImage: "tag.slash",
                            description: Text(String(localized: "project.focusTags.empty.detail",
                                                     defaultValue: "Tag documents while you research, then choose which tags focus this project's suggestions here."))
                        )
                    } else {
                        List {
                            Section {
                                ForEach(allTags) { tag in
                                    row(tag, project: project)
                                }
                            } footer: {
                                Text(String(localized: "project.focusTags.footer",
                                            defaultValue: "Documents you've tagged with the chosen tags anchor this project's Suggested Next."))
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "project.focusTags.missing.title", defaultValue: "Project Unavailable"),
                        systemImage: "folder",
                        description: Text(String(localized: "project.focusTags.missing.detail",
                                                 defaultValue: "This project is no longer available."))
                    )
                }
            }
            .navigationTitle(String(localized: "project.focusTags.title", defaultValue: "Focus Tags"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.focusTags.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
        // Dismiss if the project is deleted from another window while this sheet is open.
        .onChange(of: project?.id) { _, id in if id == nil { dismiss() } }
    }

    @ViewBuilder
    private func row(_ tag: UserTag, project: Project) -> some View {
        let isChosen = project.defaultUserTagIds.contains(tag.id)
        Button {
            toggle(tag.id, in: project)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChosen ? Color.accentColor : Color.secondary)
                Text(tag.name.isEmpty
                     ? String(localized: "project.focusTags.untitled", defaultValue: "Untitled tag")
                     : tag.name)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Adds or removes a tag id from the project's focus (live save).
    private func toggle(_ tagId: UUID, in project: Project) {
        // Reassign the whole array — Project's array `didSet` (and thus `lastModified` / CloudKit
        // last-write-wins) does NOT fire on an in-place `remove`/`append` (see Project.swift).
        var ids = project.defaultUserTagIds
        if let index = ids.firstIndex(of: tagId) {
            ids.remove(at: index)
        } else {
            ids.append(tagId)
        }
        project.defaultUserTagIds = ids
    }
}
