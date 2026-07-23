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

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
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
        .task(id: projectId) {
            // Reset per-project state — this view can be reused for a different project (the iOS
            // sheet reuses identity when `activeProjectId` changes), so drop any in-flight recompute
            // and its spinner from the previous project before starting this one's.
            recomputeTask?.cancel()
            isRecomputing = false
            questionDraft = project?.researchQuestion ?? ""
            if let project { draftWeights = ProjectLeadsService.effectiveWeights(for: project) }
            scheduleRecompute(immediate: true)   // no chatter to debounce on open / project switch
        }
        // Recompute leads when the project's collections (or their documents) change — the
        // discovery feedback loop (#377 Phase 3). Debounced inside `scheduleRecompute`.
        .onChange(of: seedSignature) { _, _ in scheduleRecompute() }
        .onDisappear { recomputeTask?.cancel() }
        .sheet(isPresented: $showFocusEditor) {
            if let project {
                ProjectFocusSubjectsEditor(project: project)
            }
        }
        .sheet(isPresented: $showCollectionsEditor) {
            if let project {
                ProjectCollectionsEditor(projectId: project.id, projectName: project.name)
            }
        }
    }

    // MARK: - Collections (#377 Phase 5 polish)

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
        switch (year(project.defaultDateRangeStart), year(project.defaultDateRangeEnd)) {
        case let (start?, end?): return "\(start)–\(end)"
        case let (start?, nil):  return String(localized: "project.home.dateFrom", defaultValue: "From \(start)")
        case let (nil, end?):    return String(localized: "project.home.dateTo", defaultValue: "Through \(end)")
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
        }
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

    /// "Related to N of your documents" (+ an editorial-note marker).
    private func leadContext(_ lead: ProjectLeadEntry) -> String {
        let n = lead.contributingSeedKeys.count
        let related = n == 1
            ? String(localized: "project.home.leads.related.one",
                     defaultValue: "Related to 1 of your documents")
            : String(localized: "project.home.leads.related.other",
                     defaultValue: "Related to \(n) of your documents")
        guard lead.isEditorialNote else { return related }
        return related + " · " + String(localized: "project.home.leads.editorial", defaultValue: "Editorial note")
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
    /// second seed source — reacts when a note is added/removed/retagged to the project; note
    /// `volumeId`/`documentId` are scalars, so no relationship fault). This only decides *when* to
    /// recompute; the real seed is derived off-main inside `recompute`, and the open-time and
    /// Refresh recomputes backstop any coarse miss (e.g. an add + remove that leaves the count
    /// unchanged).
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
        return "\(allCollectionEntries.count)|\(collections)|n:\(notedDocs)"
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
                weightRow(axis, project)
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

    /// One axis's weight slider. The value updates live for feedback; the persist + re-rank happens
    /// only when the drag settles (`onEditingChanged` false), so a drag is one recompute, not one per
    /// tick. The shared-subjects axis stays disabled + annotated until its detected-topic data ships.
    @ViewBuilder
    private func weightRow(_ axis: SimilarityAxis, _ project: Project) -> some View {
        let subjectsInert = axis == .sharedSubjects && DocumentSubjectStore.shared == nil
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Label(axis.displayName, systemImage: axis.systemImage)
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text(draftWeights[axis], format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { draftWeights[axis] },
                    set: { draftWeights[axis] = $0 }),   // live @State only; persist + re-rank on release
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing { commitWeights(project) }
                })
            .disabled(subjectsInert)
            if subjectsInert {
                Text(String(localized: "project.home.leads.tune.subjects.gated",
                            defaultValue: "Available when detected-topic data ships (experimental)."))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
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
        performNavigation {
            #if os(iOS)
            // The document lands in the Browse tab's stack; bring that tab forward so the tap isn't a
            // silent no-op (Project Home is reached from the Settings tab). Mirrors the other callers.
            appState.openTab(.browse, from: nil)
            #endif
            appState.openBrowseDocument(entry, from: nil)
        }
    }

    private func openSurface(_ windowId: String) {
        performNavigation {
            #if os(macOS)
            openWindow(id: windowId)
            bringMacWindowToFront(id: windowId)
            #else
            // AppTab is iOS-only; map the shared window id to the matching tab.
            let tab: AppTab
            switch windowId {
            case "frus.collections": tab = .collections
            case "frus.research":    tab = .research
            case "frus.search":      tab = .search
            default:                 tab = .browse
            }
            appState.openTab(tab, from: nil)
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
