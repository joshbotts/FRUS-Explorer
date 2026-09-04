// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - PersonIndexView

/// Alphabetical index of all persons mentioned across the indexed FRUS corpus.
///
/// Loads from `PersonMentionStore.allPersonsSortedByName()` and groups results by
/// the first letter of each person's name. Tapping a row opens `PersonIndexDetailSheet`
/// which shows the name, description, mention count, and a "Find all mentions" action.
///
/// ## Platform placement
/// - **iOS**: Navigation destination pushed from `CorpusView` ("People" row).
/// - **macOS**: Hosted by the "People" window (`frus.people`, via `PeopleWindowView`),
///   opened from the Corpus Browser toolbar "People" button.
///
/// Version history:
///   1.0 — Session 87
///   1.1 — Session 2026-07-04 (macOS UI audit B5): the macOS presentation moved from a
///          Corpus Browser sheet (which stacked the person-detail sheet on top of
///          itself) to the frus.people window — the detail sheet is now a single
///          window-level modal; this view is unchanged apart from placement
///   1.2 — Session 4 / #243: "Corrections" toolbar entry opening `PersonCorrectionsSheet`
///          (undo merges/separations); `PersonIndexRow` reads as one combined VoiceOver
///          element with a labeled mention count and a hidden decorative chevron
///   1.3 — Session 4 review: row context-menu "Merge with another person…" shortcut
///          (auto-opens the picker in the detail sheet); the list reloads reactively on
///          `AppState.personRollupGeneration` so corrections applied from surfaces
///          without an `onCorrection` closure (front-matter/compilation sheets) refresh it
struct PersonIndexView: View {

    @Environment(AppState.self) private var appState
    /// #338 step 4: this window's scene, threaded into PersonIndexDetailSheet → its nested cross-volume
    /// sheet, so a volume-open hand-off from a person's subject-affinity row targets THIS window.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    /// Opens the Search window directly for "Find all mentions" (the MainWindowView
    /// relay is retired — provenance PR 2).
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var sections: [PersonIndexSection] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @State private var selectedIndexEntry: PersonIndexEntry?
    /// Rollup ids with a pending "possibly the same" suggestion, loaded once for row hints.
    @State private var candidateRollupIds: Set<Int> = []
    /// Presents the corrections/undo manager (#243).
    @State private var showCorrections = false
    /// When `true`, the next presented detail sheet auto-opens the merge picker — set by
    /// the row context-menu "Merge with another person…" shortcut (#243 plan item 2).
    @State private var autoOpenMergePicker = false

    private var displaySections: [PersonIndexSection] {
        guard !searchText.isEmpty else { return sections }
        let q = searchText.lowercased()
        return sections.compactMap { s in
            let filtered = s.entries.filter { $0.entry.name.lowercased().contains(q) }
            return filtered.isEmpty ? nil : PersonIndexSection(letter: s.letter, entries: filtered)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(String(localized: "people.loading", defaultValue: "Loading people\u{2026}"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displaySections.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        String(localized: "people.empty.title", defaultValue: "No People Indexed"),
                        systemImage: "person.2",
                        description: Text(String(
                            localized: "people.empty.detail",
                            defaultValue: "Index some volumes to see people mentioned across the corpus."))
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List {
                    ForEach(displaySections) { section in
                        Section(section.letter) {
                            ForEach(section.entries) { indexEntry in
                                PersonIndexRow(
                                    indexEntry: indexEntry,
                                    hasCandidate: indexEntry.rollupId.map { candidateRollupIds.contains($0) } ?? false
                                ) {
                                    selectedIndexEntry = indexEntry
                                }
                                .contextMenu {
                                    mentionsButton(for: indexEntry)
                                    // #243 plan item 2: per-row shortcut into the manual-merge
                                    // flow — opens the detail sheet with the picker pre-opened.
                                    if indexEntry.rollupId != nil {
                                        Button {
                                            autoOpenMergePicker = true
                                            selectedIndexEntry = indexEntry
                                        } label: {
                                            Label(String(localized: "people.detail.mergeManual",
                                                         defaultValue: "Merge with another person…"),
                                                  systemImage: "person.2.badge.gearshape")
                                        }
                                    }
                                }
                                #if os(iOS)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    mentionsButton(for: indexEntry).tint(.accentColor)
                                }
                                #endif
                            }
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
        .navigationTitle(String(localized: "people.title", defaultValue: "People"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(
            text: $searchText,
            prompt: String(localized: "people.search.prompt", defaultValue: "Search people")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCorrections = true
                } label: {
                    Label(String(localized: "people.corrections.toolbar", defaultValue: "Corrections"),
                          systemImage: "arrow.uturn.backward.circle")
                }
                .help(String(localized: "people.corrections.toolbar.help",
                             defaultValue: "Review and undo your merge and separate corrections"))
            }
        }
        .task { await loadPeople() }
        // Live corrections signal: reload whenever ANY surface applies or undoes a
        // person correction (detail sheets launched from front-matter/compilation views
        // don't hold an onCorrection closure into this list — the app-wide generation
        // counter covers them, and any other open People surface, reactively).
        .onChange(of: appState.personRollupGeneration) { _, _ in
            Task { await loadPeople() }
        }
        .sheet(item: $selectedIndexEntry, onDismiss: { autoOpenMergePicker = false }) { indexEntry in
            PersonIndexDetailSheet(indexEntry: indexEntry,
                                   openMergePickerOnAppear: autoOpenMergePicker,
                                   onCorrection: {
                Task { await loadPeople() }
            })
            // #338 step 4: thread this window's scene into the detail sheet (and its nested sheets).
            .environment(\.sceneID, sceneID)
        }
        .sheet(isPresented: $showCorrections) {
            PersonCorrectionsSheet(onChange: { Task { await loadPeople() } })
        }
    }

    // MARK: - Data Loading

    private func loadPeople() async {
        guard let store = appState.personMentionStore else {
            isLoading = false
            return
        }
        let entries = (try? await store.allPersonsSortedByName()) ?? []
        sections = PersonIndexSection.makeSections(from: entries)
        candidateRollupIds = (try? await store.rollupIdsWithCandidates()) ?? []
        isLoading = false
    }

    /// A "Find all mentions" action for a cluster, used in the row context menu and iOS swipe.
    /// macOS opens the Search window directly, binding it to this People window's own
    /// provenance so result clicks land where the People browser's opens do.
    @ViewBuilder
    private func mentionsButton(for indexEntry: PersonIndexEntry) -> some View {
        Button {
            appState.openSearch(SearchParameters(personRollupId: indexEntry.rollupId,
                                                      personLabel: indexEntry.entry.name), from: sceneID)
            #if os(macOS)
            appState.bindTool(.search, to: appState.provenance(of: .people))
            openWindow.fronting(id: "frus.search")
            #else
            appState.openTab(.search, from: sceneID)
            #endif
        } label: {
            Label(String(localized: "people.row.findMentions", defaultValue: "Find all mentions"),
                  systemImage: "magnifyingglass")
        }
        .disabled(indexEntry.mentionCount == 0)
    }
}

// MARK: - PersonIndexSection

struct PersonIndexSection: Identifiable {
    let letter: String
    let entries: [PersonIndexEntry]
    var id: String { letter }

    static func makeSections(from entries: [PersonIndexEntry]) -> [PersonIndexSection] {
        var dict: [String: [PersonIndexEntry]] = [:]
        for e in entries {
            let letter = e.entry.name.isEmpty
                ? "#"
                : String(e.entry.name.prefix(1).uppercased())
            dict[letter, default: []].append(e)
        }
        return dict.keys.sorted().map { PersonIndexSection(letter: $0, entries: dict[$0]!) }
    }
}

// MARK: - PersonIndexRow

private struct PersonIndexRow: View {
    let indexEntry: PersonIndexEntry
    /// Whether this rollup has a pending "possibly the same" suggestion (Phase 4 hint).
    let hasCandidate: Bool
    let onTap: () -> Void

    /// `role · era · N volumes`, omitting whichever parts are absent.
    private var subtitle: String? {
        var parts: [String] = []
        if let roleEra = indexEntry.entry.roleEraSubtitle { parts.append(roleEra) }
        if indexEntry.volumeCount > 1 {
            parts.append(String(localized: "people.row.volumeCount",
                                defaultValue: "\(indexEntry.volumeCount) volumes"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// One combined VoiceOver label — name, subtitle, labeled mention count, and the
    /// possible-duplicate hint — so the row reads as a single stop instead of four elements.
    private var accessibilityLabelText: String {
        var parts: [String] = [indexEntry.entry.name]
        if let subtitle { parts.append(subtitle) }
        if indexEntry.mentionCount > 0 {
            parts.append(String(format: String(localized: "people.row.mentionCount.a11y %lld",
                                               defaultValue: "%lld mentions"),
                                Int64(indexEntry.mentionCount)))
        }
        if hasCandidate {
            parts.append(String(localized: "people.row.candidate.a11y", defaultValue: "Possible duplicate"))
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(indexEntry.entry.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if hasCandidate {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .help(String(localized: "people.row.candidate.help",
                                     defaultValue: "May be the same as another person — open to review"))
                }
                if indexEntry.mentionCount > 0 {
                    Text("\(indexEntry.mentionCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            // #312 follow-up: no frame needed — the Spacer already makes this HStack full width.
            // contentShape is what makes the gaps around the name, count capsule and chevron
            // tappable, since `.buttonStyle(.plain)` hit-tests only opaque content.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }
}

// MARK: - PersonIndexDetailSheet

/// Sheet shown when a person row is tapped in `PersonIndexView` or `FrontMatterPersonsView`.
///
/// Displays name, biographical description, and mention count. The mention count is loaded
/// asynchronously on appear so callers can pass any initial value (including 0) without a
/// blocking actor call at the tap site. The "Find all mentions" button triggers a
/// person-filtered search and dismisses the sheet.
///
/// ## Platform layout
/// iOS keeps `NavigationStack` + toolbar Done. The macOS body follows the codebase's
/// documented sheet pattern (UI audit gap 11): plain `VStack` with a header row, the
/// shared list, and a bottom-right Done button — no `NavigationStack` chrome, which
/// renders sidebar-style artifacts inside macOS sheets.
///
/// Version history:
///   1.0 — Person rollup program: initial implementation (merge/split corrections added
///          across Phases 2–5)
///   1.1 — Session 2026-07-04 (macOS UI audit gap 11): macOS body normalized to
///          VStack + bottom-right Done; shared `detailList` extracted
///   1.2 — Session 4 / #243: manual "Merge with another person…" (searchable picker +
///          confirmation with a differing-authority warning); the merge/split/manual
///          paths share one `applyCorrection` tail (persist → consolidate → announce →
///          refresh → dismiss); per-person Merge/Separate a11y labels
///   1.3 — Session 4 review: reentrancy guard raised before the representative-member
///          awaits; in-progress + completion VoiceOver announcements; the correction tail
///          delegates to `PersonClusterOverrideStore.saveAndReconsolidate` and bumps the
///          app-wide corrections generation; `openMergePickerOnAppear` context-menu entry
///   1.4 — #264: volume-level person↔subject affinity chips — the person's per-volume
///          mention counts (new `volumeMentionCounts(forRollupId:)`) joined against the
///          bundled volume subject profiles; chips reuse the Session-9 styling and pivot
///          to the shared `VolumeSubjectVolumesSheet`; the caption states the volume
///          grain explicitly (doc-level tags stay retired until #261 clears)
// MARK: - PersonSubjectAffinity

/// The pure person↔subject affinity ranking (#264), factored out of `PersonIndexDetailSheet`
/// so the join is unit-testable without a live `PersonMentionStore` or the subject-profiles
/// bundle.
///
/// Join: the person's per-volume distinct-document mention counts × each volume's bundled
/// subject profile. Affinity weight = Σ (person's doc count in a volume × the subject's score
/// in that volume), so a subject scores high when it characterizes the volumes where the person
/// appears MOST — not merely any volume they brush. Volume-grain by deliberate decision (#261):
/// the affinity never claims a per-document link.
enum PersonSubjectAffinity {

    /// One ranked affinity: a subject plus how broadly (`volumeCount`) and strongly (`weight`)
    /// it co-occurs with the person's mentions.
    struct Ranked: Identifiable, Equatable {
        /// The resolved subject (name, category, per-volume distinctiveness score).
        let subject: VolumeSubjectProfiles.ResolvedSubject
        /// How many of the person's mention volumes carry this subject in their profile.
        let volumeCount: Int
        /// Σ over those volumes of (person's distinct-document count × the subject's score).
        let weight: Double
        var id: String { subject.id }
    }

    /// Ranks a person's subject affinities. `topSubjectsByVolume` returns a volume's profile
    /// subjects (`nil` when the volume has no bundled profile — that volume is skipped). Ties on
    /// weight break by subject name for determinism; the result is capped to `limit`.
    ///
    /// **`topSubjectsByVolume` must be the PROFILE producer, not the document-subject index**, and
    /// the compiler cannot tell them apart: both vend `[ResolvedSubject]` per volume, and the app
    /// swaps one for the other at six other call sites to widen their reach. Here the swap would
    /// be wrong, because this is the one place that does arithmetic on
    /// ``VolumeSubjectProfiles/ResolvedSubject/score`` **through an injected producer** rather than
    /// sorting by it. (`ProjectFocusSuggestions` sums the same field, but takes a concrete
    /// `VolumeSubjectProfiles`, so the swap is not reachable there without a signature change.)
    /// The profile score
    /// varies per volume — how characteristic the subject is of that volume — so
    /// `Σ documentCount × score` is a genuine affinity. The document index's score is corpus IDF,
    /// a constant per subject, which factors out of the sum and leaves rarity × total mentions:
    /// the same type, plausible output, and a different question answered. See the field's own
    /// documentation (#1024).
    static func rank(
        mentionCounts: [(volumeId: String, documentCount: Int)],
        topSubjectsByVolume: (String) -> [VolumeSubjectProfiles.ResolvedSubject]?,
        limit: Int
    ) -> [Ranked] {
        var aggregate: [String: (subject: VolumeSubjectProfiles.ResolvedSubject, volumes: Int, weight: Double)] = [:]
        for (volumeId, documentCount) in mentionCounts {
            guard let subjects = topSubjectsByVolume(volumeId) else { continue }
            for subject in subjects {
                var entry = aggregate[subject.ref] ?? (subject, 0, 0)
                entry.volumes += 1
                entry.weight += Double(documentCount) * subject.score
                aggregate[subject.ref] = entry
            }
        }
        return aggregate.values
            .sorted { $0.weight != $1.weight ? $0.weight > $1.weight
                                             : $0.subject.name < $1.subject.name }
            .prefix(limit)
            .map { Ranked(subject: $0.subject, volumeCount: $0.volumes, weight: $0.weight) }
    }
}

struct PersonIndexDetailSheet: View {

    let indexEntry: PersonIndexEntry
    /// When `true`, the merge picker opens as soon as this sheet's rollup id is resolved —
    /// the row context-menu "Merge with another person…" shortcut (#243 plan item 2).
    var openMergePickerOnAppear: Bool = false
    /// Called after a correction (merge) changes the rollup, so the caller can reload its list.
    var onCorrection: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// #338 step 4: this window's scene (received from the presenter), re-injected into the nested
    /// cross-volume sheet so its volume-open hand-off targets THIS window.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    /// Opens the Search window directly for "Find all mentions" (the MainWindowView
    /// relay is retired — provenance PR 2).
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Cross-corpus mention count loaded asynchronously on appear.
    /// Already correct for rollup entries from `PersonIndexView`; resolved here for the per-volume
    /// front-matter case (`FrontMatterPersonsView` passes 0 + a `sourceVolumeId`).
    @State private var resolvedMentionCount: Int?
    /// Rollup id resolved for a per-volume front-matter entry, used by "Find all mentions".
    @State private var resolvedRollupId: Int?
    /// Authority id / VIAF id resolved for a per-volume front-matter entry (Phase 5).
    @State private var resolvedAuthorityId: Int?
    @State private var resolvedViafId: String?
    /// Presents the searchable person picker for a manual merge (#243).
    @State private var showMergePicker = false
    /// The person chosen in the picker, awaiting merge confirmation.
    @State private var pendingMergeTarget: PersonIndexEntry?

    /// "Possibly the same person" suggestions for this rollup (Phase 2 candidates).
    @State private var candidates: [PersonMergeCandidate] = []
    /// The per-volume records folded into this rollup (Phase 4 drill-in).
    @State private var members: [PersonRollupMember] = []
    /// True while a correction (merge or separate) is being applied + the rollup re-consolidated.
    @State private var isMerging = false

    /// Volume-level subject affinities (#264): subjects characteristic of the volumes where
    /// this person is mentioned, weighted by the person's footprint in each volume. Empty when
    /// the person has no indexed mentions or the bundled profiles are absent.
    @State private var subjectAffinities: [PersonSubjectAffinity.Ranked] = []
    /// The affinity chip whose cross-volume pivot sheet is open, or `nil`.
    @State private var selectedAffinitySubject: VolumeSubjectProfiles.ResolvedSubject?

    private var displayCount: Int { resolvedMentionCount ?? indexEntry.mentionCount }
    private var effectiveRollupId: Int? { indexEntry.rollupId ?? resolvedRollupId }
    private var effectiveAuthorityId: Int? { indexEntry.authorityId ?? resolvedAuthorityId }
    private var effectiveViafId: String? { indexEntry.viafId ?? resolvedViafId }

    /// The bundled authority entry for this person, when they are reconciled (#736).
    ///
    /// Read straight from the bundled index rather than the rollup row, because the rollup stores
    /// only `authority_id`/`viaf_id` — the schema-v2 additions (POCOM slug, Wikidata, role text)
    /// live in the JSON and adding three columns to the rollup would force a reindex to show a
    /// subtitle.
    private var authorityEntry: PersonAuthorityIndex.AuthorityEntry? {
        guard let id = effectiveAuthorityId else { return nil }
        return PersonAuthorityIndexStore.shared?.entry(for: id)
    }

    /// This person's POCOM career, when the authority entry names a slug and the register has
    /// appointments for it (#736).
    private var career: POCOMCareer? {
        guard let slug = authorityEntry?.s, !slug.isEmpty else { return nil }
        return POCOMIndexStore.shared?.career(forSlug: slug)
    }

    var body: some View {
        Group {
            #if os(macOS)
            macBody
            #else
            iOSBody
            #endif
        }
        .task {
            // Browser rollup entries already carry the correct count + rollup id. A per-volume
            // front-matter entry resolves its rollup here for the cross-corpus count and search.
            if indexEntry.rollupId == nil,
               let volumeId = indexEntry.sourceVolumeId,
               let store = appState.personMentionStore {
                if let resolved = try? await store.rollupEntry(forVolumeId: volumeId, ref: indexEntry.entry.ref) {
                    resolvedRollupId = resolved.rollupId
                    resolvedMentionCount = resolved.mentionCount
                    resolvedAuthorityId = resolved.authorityId
                    resolvedViafId = resolved.viafId
                } else {
                    resolvedMentionCount = 0
                }
            }
            await loadCorrectionContext()
            await loadSubjectAffinities()
            // Context-menu shortcut: jump straight into the merge picker once the rollup
            // id is known (immediate for People-browser rows; resolved above for
            // front-matter entries).
            if openMergePickerOnAppear && effectiveRollupId != nil {
                showMergePicker = true
            }
        }
    }

    // MARK: - Platform bodies

    #if os(macOS)
    /// macOS-native sheet layout (UI audit gap 11): header row + shared list +
    /// bottom-right Done — no `NavigationStack` chrome inside the sheet.
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(indexEntry.entry.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            detailList

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 360, minHeight: 320)
    }
    #else
    /// iOS sheet layout — `NavigationStack` with an inline title and toolbar Done.
    private var iOSBody: some View {
        NavigationStack {
            detailList
                .navigationTitle(indexEntry.entry.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
    }
    #endif

    // MARK: - Career (#736)

    /// The person's posts, from the Principal Officers and Chiefs of Mission register.
    ///
    /// ## A list of rows, not a drawn timeline
    /// A visual timeline would have to choose pixel positions for dates that are frequently
    /// partial — the register records "1935" with no month for a great many early appointments —
    /// and would need its own Dynamic Type and VoiceOver handling. Rows in document order get
    /// both for free and never imply a precision the source does not have.
    ///
    /// The dates are printed exactly as the register writes them for the same reason: a formatter
    /// would have to invent the missing month and day.
    @ViewBuilder
    private func careerSection(_ career: POCOMCareer) -> some View {
        Section {
            ForEach(career.a) { assignment in
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.titleText)
                        .font(.subheadline)
                    if let range = assignment.dateRangeText {
                        Text(range)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let note = assignment.nt, !note.isEmpty {
                        // Kept because it is often the only thing distinguishing an ordinary
                        // rotation from an incident — "Died at post", "Left Tehran on".
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 1)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(String(localized: "people.detail.career", defaultValue: "Career"))
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if let lifespan = career.lifespanText {
                    Text(lifespan)
                }
                // Named, because these are the Department's own appointment records and a reader
                // should know this is not something the app inferred from the documents.
                Text(String(localized: "people.detail.career.source",
                            defaultValue: "From the Department’s Principal Officers and Chiefs of Mission register."))
            }
            .font(.caption2)
        }
    }

    /// The sectioned person detail shared by both platform bodies.
    private var detailList: some View {
        List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(indexEntry.entry.name)
                            .font(.title2.bold())
                        if let desc = indexEntry.entry.description, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        // The overlay's role text (#736). Shown only when it says something the
                        // volume's own description does not already say — upstream frequently
                        // repeats the editors' wording, and printing it twice looks like a bug.
                        if let role = authorityEntry?.r, !role.isEmpty,
                           role.caseInsensitiveCompare(indexEntry.entry.description ?? "") != .orderedSame {
                            Text(role)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if effectiveAuthorityId != nil {
                            Label(
                                String(localized: "people.detail.reconciled",
                                       defaultValue: "Reconciled identity"),
                                systemImage: "checkmark.seal"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(String(localized: "people.detail.reconciled.help",
                                         defaultValue: "Matched to the bundled name-authority data"))
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LabeledContent(
                        String(localized: "people.detail.mentions", defaultValue: "Mentions")
                    ) {
                        if indexEntry.rollupId == nil && resolvedMentionCount == nil && indexEntry.mentionCount == 0 {
                            // Per-volume front-matter entry still resolving its cross-corpus count.
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text(String(localized: "people.detail.mentions.loading",
                                            defaultValue: "Loading…"))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("\(displayCount) document\(displayCount == 1 ? "" : "s")")
                        }
                    }
                    if let era = indexEntry.entry.eraText {
                        LabeledContent(
                            String(localized: "people.detail.active", defaultValue: "Active"),
                            value: era
                        )
                    }
                }

                // #264: person↔subject affinity chips — volume-level, mirroring the volume
                // detail's "Top subjects" chips (Session 9) including the cross-volume pivot.
                if !subjectAffinities.isEmpty {
                    Section {
                        #if os(macOS)
                        let showsIndicators = true
                        #else
                        let showsIndicators = false
                        #endif
                        ScrollView(.horizontal, showsIndicators: showsIndicators) {
                            HStack(spacing: 6) {
                                ForEach(subjectAffinities) { affinity in
                                    affinityChip(affinity)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                        Text(String(localized: "people.detail.subjects.note",
                                    defaultValue: "Volume-level: subjects characteristic of the volumes where this person is mentioned — not per-document tags."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(String(localized: "people.detail.subjects.header",
                                    defaultValue: "Subjects"))
                    }
                }

                Section {
                    Button {
                        appState.openSearch(SearchParameters(personRollupId: effectiveRollupId,
                                                                  personLabel: indexEntry.entry.name), from: sceneID)
                        #if os(macOS)
                        // Direct open (the MainWindowView relay is retired — provenance
                        // PR 2), bound to the People window's own provenance.
                        appState.bindTool(.search, to: appState.provenance(of: .people))
                        openWindow.fronting(id: "frus.search")
                        #else
                        appState.openTab(.search, from: sceneID)
                        #endif
                        dismiss()
                    } label: {
                        Label(
                            String(localized: "people.detail.findMentions",
                                   defaultValue: "Find all mentions"),
                            systemImage: "magnifyingglass"
                        )
                    }
                    .disabled(displayCount == 0)
                    .help(String(localized: "people.detail.findMentions.help",
                                 defaultValue: "Open Search filtered to documents that mention this person"))

                    if displayCount == 0
                        && !(indexEntry.rollupId == nil && resolvedMentionCount == nil && indexEntry.mentionCount == 0) {
                        Text(String(localized: "people.detail.findMentions.noMentions",
                                    defaultValue: "This person has no indexed document mentions to open — they appear only in a volume’s front-matter person list."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let viaf = effectiveViafId, !viaf.isEmpty,
                       let url = URL(string: "https://viaf.org/viaf/\(viaf)") {
                        Link(destination: url) {
                            Label(String(localized: "people.detail.viaf", defaultValue: "View on VIAF"),
                                  systemImage: "link")
                        }
                        .help(String(localized: "people.detail.viaf.help",
                                     defaultValue: "Open this person’s VIAF authority record"))
                        .accessibilityHint(String(localized: "people.detail.viaf.a11y",
                                                  defaultValue: "Opens in your browser"))
                    }
                    // Wikidata (#736). Coverage jumped from 142 VIAF ids to 3,198 VIAF and 3,825
                    // Wikidata when the overlay landed, so this is a link most reconciled people
                    // now have.
                    if let url = authorityEntry?.wikidataURL {
                        Link(destination: url) {
                            Label(String(localized: "people.detail.wikidata",
                                         defaultValue: "View on Wikidata"),
                                  systemImage: "link")
                        }
                        .help(String(localized: "people.detail.wikidata.help",
                                     defaultValue: "Open this person’s Wikidata item"))
                        .accessibilityHint(String(localized: "people.detail.wikidata.a11y",
                                                  defaultValue: "Opens in your browser"))
                    }
                }

                if let career, !career.a.isEmpty { careerSection(career) }

                if effectiveRollupId != nil {
                    Section {
                        Button {
                            showMergePicker = true
                        } label: {
                            Label(String(localized: "people.detail.mergeManual",
                                         defaultValue: "Merge with another person…"),
                                  systemImage: "person.2.badge.gearshape")
                        }
                        .disabled(isMerging)
                        .help(String(localized: "people.detail.mergeManual.help",
                                     defaultValue: "Combine this identity with another person you choose"))
                    } footer: {
                        Text(String(localized: "people.detail.mergeManual.footer",
                                    defaultValue: "Use this when one person appears under different names and the app kept them apart. The change syncs across your devices and can be undone from Corrections."))
                    }
                }

                if !candidates.isEmpty {
                    Section {
                        ForEach(candidates) { candidate in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(.body)
                                    if let reason = candidate.reason {
                                        Text(reason)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    Task { await merge(with: candidate) }
                                } label: {
                                    Text(String(localized: "people.detail.merge", defaultValue: "Merge"))
                                }
                                .buttonStyle(.borderless)
                                .disabled(isMerging)
                                .accessibilityLabel(String(format: String(
                                    localized: "people.detail.merge.a11y %@",
                                    defaultValue: "Merge %@ into this person"), candidate.name))
                            }
                        }
                    } header: {
                        Text(String(localized: "people.detail.possiblySame.header",
                                    defaultValue: "Possibly the Same Person"))
                    } footer: {
                        Text(String(localized: "people.detail.possiblySame.footer",
                                    defaultValue: "Merge if these records refer to the same person. The change syncs across your devices."))
                    }
                }

                if members.count > 1 {
                    Section {
                        ForEach(members) { member in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.entry.name)
                                        .font(.body)
                                    Text(member.volumeId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await separate(member) }
                                } label: {
                                    Text(String(localized: "people.detail.separate", defaultValue: "Separate"))
                                }
                                .buttonStyle(.borderless)
                                .disabled(isMerging)
                                .accessibilityLabel(String(format: String(
                                    localized: "people.detail.separate.a11y %@",
                                    defaultValue: "Separate %@ into its own identity"), member.entry.name))
                            }
                        }
                    } header: {
                        Text(String(localized: "people.detail.records.header",
                                    defaultValue: "Records in This Identity (\(members.count))"))
                    } footer: {
                        Text(String(localized: "people.detail.records.footer",
                                    defaultValue: "Separate a record if it refers to a different person."))
                    }
                }
        }
        .sheet(isPresented: $showMergePicker) {
            PersonMergePickerSheet(excludingRollupId: effectiveRollupId) { picked in
                pendingMergeTarget = picked
            }
        }
        // #264 chip pivot: the same cross-volume sheet the volume detail's subject chips
        // open. `excluding: ""` excludes nothing — every covering volume is relevant here.
        // `onNavigate` dismisses THIS detail sheet too: a row tap hands off to the browse
        // surface, and leaving the person sheet up would cover the navigation it triggered.
        .sheet(item: $selectedAffinitySubject) { subject in
            VolumeSubjectVolumesSheet(subject: subject, currentVolumeId: "",
                                      onNavigate: { dismiss() })
                .environment(\.sceneID, sceneID)
        }
        .alert(
            String(localized: "people.detail.mergeConfirm.title", defaultValue: "Merge these identities?"),
            isPresented: Binding(get: { pendingMergeTarget != nil },
                                 set: { if !$0 { pendingMergeTarget = nil } }),
            presenting: pendingMergeTarget
        ) { target in
            Button(String(localized: "people.detail.mergeConfirm.action", defaultValue: "Merge"),
                   role: .destructive) {
                Task { await manualMerge(with: target) }
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: { target in
            Text(mergeConfirmMessage(for: target))
        }
    }

    // MARK: - Corrections (Phase 3 merge / Phase 4 split)

    /// One affinity chip (#264) — the volume-detail chip styling (Session 9), pivoting to the
    /// shared cross-volume subject sheet on tap.
    @ViewBuilder
    private func affinityChip(_ affinity: PersonSubjectAffinity.Ranked) -> some View {
        Button {
            selectedAffinitySubject = affinity.subject
        } label: {
            Text(affinity.subject.name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(affinity.subject.name)
        .accessibilityValue(String(
            localized: "people.detail.subjectChip.a11yValue",
            defaultValue: "\(affinity.subject.category), in \(affinity.volumeCount) volume\(affinity.volumeCount == 1 ? "" : "s") mentioning this person"))
        .accessibilityHint(String(localized: "browser.volume.subjectChip.hint",
                                  defaultValue: "Shows other volumes covering this subject"))
        .help(String(localized: "people.detail.subjectChip.help",
                     defaultValue: "Subject of volumes where this person is mentioned — click to see all volumes covering it"))
    }

    /// Computes the volume-level person↔subject affinities (#264).
    ///
    /// Join: the person's per-volume distinct-document mention counts
    /// (`PersonMentionStore.volumeMentionCounts(forRollupId:)`, one GROUP-BY query) × the
    /// bundled volume subject profiles (`topSubjects(forVolumeId:)`, an in-memory dict hit per
    /// volume). Affinity weight = Σ (person's doc count in volume × subject's score in that
    /// volume), so a subject scores high when it characterizes the volumes where the person
    /// appears MOST — not merely any volume they brush. Top 8 by weight; name-tiebroken for
    /// determinism.
    private func loadSubjectAffinities() async {
        guard let rollupId = effectiveRollupId,
              let store = appState.personMentionStore,
              let profiles = VolumeSubjectProfilesStore.shared,
              let counts = try? await store.volumeMentionCounts(forRollupId: rollupId),
              !counts.isEmpty else { return }
        subjectAffinities = PersonSubjectAffinity.rank(
            mentionCounts: counts,
            topSubjectsByVolume: profiles.topSubjects(forVolumeId:),
            limit: 8)
    }

    private func loadCorrectionContext() async {
        guard let rollupId = effectiveRollupId, let store = appState.personMentionStore else { return }
        let raw = (try? await store.candidates(forRollupId: rollupId)) ?? []
        candidates = raw.map { PersonMergeCandidate(rollupId: $0.rollupId, name: $0.name, reason: $0.reason) }
        members = (try? await store.members(forRollupId: rollupId)) ?? []
    }

    /// The shared tail of every correction (merge, manual merge, separate): persist the override
    /// just inserted by `insert` and re-consolidate the rollup live (via the store's shared
    /// `saveAndReconsolidate`), announce progress and completion for VoiceOver (re-consolidation
    /// takes seconds on a large corpus), bump the app-wide corrections signal, refresh the
    /// launching list via `onCorrection`, and dismiss. `insert` performs the SwiftData mutation
    /// on the main-actor context and runs only once the pipeline is confirmed available.
    ///
    /// - Parameters:
    ///   - announcement: The localized VoiceOver completion announcement.
    ///   - insert: The override insertion (a `PersonClusterOverrideStore.merge`/`split` call).
    private func applyCorrection(announcement: String, _ insert: (ModelContext) -> Void) async {
        guard let pipeline = appState.indexingPipeline else { return }
        isMerging = true
        defer { isMerging = false }
        AccessibilityNotification.Announcement(
            String(localized: "people.detail.correction.inProgress",
                   defaultValue: "Applying correction…")).post()
        insert(modelContext)
        await PersonRollupRefresh.afterCorrection(context: modelContext, pipeline: pipeline,
                                                  appState: appState)
        AccessibilityNotification.Announcement(announcement).post()
        onCorrection?()
        dismiss()
    }

    /// Records a "split" correction detaching `member` into its own identity, re-consolidates so it
    /// takes effect immediately, then dismisses.
    private func separate(_ member: PersonRollupMember) async {
        guard !isMerging else { return }
        await applyCorrection(
            announcement: String(format: String(localized: "people.detail.separate.done %@",
                                                 defaultValue: "Separated %@"), member.entry.name)
        ) { context in
            PersonClusterOverrideStore.split((volumeId: member.volumeId, ref: member.entry.ref),
                                             context: context)
        }
    }

    /// Records a "merge" correction from a candidate suggestion.
    private func merge(with candidate: PersonMergeCandidate) async {
        await mergeRollup(candidate.rollupId, named: candidate.name)
    }

    /// Records a "merge" correction from an arbitrary person chosen in the merge picker (#243).
    private func manualMerge(with entry: PersonIndexEntry) async {
        guard let rollupId = entry.rollupId else { return }
        await mergeRollup(rollupId, named: entry.entry.name)
    }

    /// Resolves this rollup and `otherRollupId` to their stable `(volumeId, ref)` member anchors and
    /// records a must-link merge override between them. Shared by the candidate and manual paths.
    /// `isMerging` is raised BEFORE the representative-member lookups so a double-tap cannot enter
    /// twice during those awaits (the buttons disable on it).
    private func mergeRollup(_ otherRollupId: Int, named otherName: String) async {
        guard !isMerging else { return }
        isMerging = true
        defer { isMerging = false }
        guard let store = appState.personMentionStore,
              let myRollup = effectiveRollupId,
              let mine = try? await store.representativeMember(forRollupId: myRollup),
              let theirs = try? await store.representativeMember(forRollupId: otherRollupId) else { return }
        await applyCorrection(
            announcement: String(format: String(localized: "people.detail.merge.done %1$@ %2$@",
                                                 defaultValue: "Merged %1$@ into %2$@"),
                                 otherName, indexEntry.entry.name)
        ) { context in
            PersonClusterOverrideStore.merge((volumeId: mine.volumeId, ref: mine.ref),
                                             (volumeId: theirs.volumeId, ref: theirs.ref),
                                             context: context)
        }
    }

    /// The merge-confirmation body: names both identities, explains the transitive union, and warns
    /// when both are already matched to *different* Office-of-the-Historian authority records
    /// (advisory — the historian may know better, so the merge is allowed to proceed).
    private func mergeConfirmMessage(for target: PersonIndexEntry) -> String {
        var message = String(format: String(localized: "people.detail.mergeConfirm.message %1$@ %2$@",
            defaultValue: "“%1$@” and “%2$@” will become a single identity. Merging is transitive — if you later merge a third record with either one, all three become one identity. You can undo this from Corrections."),
            target.entry.name, indexEntry.entry.name)
        if let mine = effectiveAuthorityId, let theirs = target.authorityId, mine != theirs {
            message += "\n\n" + String(localized: "people.detail.mergeConfirm.authorityWarning",
                defaultValue: "These records match different entries in the bundled name-authority data, so they may be distinct. Merge only if you’re sure.")
        }
        return message
    }
}

// MARK: - PersonMergeCandidate

/// A "possibly the same person" suggestion shown in `PersonIndexDetailSheet`.
private struct PersonMergeCandidate: Identifiable {
    let rollupId: Int
    let name: String
    let reason: String?
    var id: Int { rollupId }
}

#if os(macOS)

// MARK: - PeopleWindowView

/// Root content for the "People" macOS window scene (`frus.people`, UI audit B5).
///
/// Wraps `PersonIndexView` in a `NavigationStack` so its title and search field
/// anchor to the window toolbar. Replaces the Corpus Browser's People *sheet*, which
/// stacked the person-detail sheet on top of itself — as a window, the index stays
/// browsable beside documents and `PersonIndexView`'s own detail presentation becomes
/// a single window-level modal (no sheet-on-sheet).
///
/// ## Boot guard (copied from the S6 Archival Neighbors pattern)
/// `PersonIndexView.loadPeople()` renders the definitive "No People Indexed" empty
/// state when `appState.personMentionStore` is nil — but the store is only assigned
/// once `bootDownloadManager()` finishes, and a window restored at app launch races
/// that boot. While the store is nil this view shows a "Preparing your index…"
/// placeholder instead; reading the `@Observable` property in `body` re-evaluates the
/// view (and creates `PersonIndexView`, firing its load) once the store appears.
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit B5)
struct PeopleWindowView: View {

    @Environment(AppState.self) private var appState

    /// Whether the person mention store exists to query; `false` while the app boots.
    private var storeReady: Bool { appState.personMentionStore != nil }

    var body: some View {
        Group {
            if storeReady {
                NavigationStack {
                    PersonIndexView()
                }
            } else {
                ProgressView(String(localized: "people.window.preparing",
                                    defaultValue: "Preparing your index…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
    }
}

#endif // os(macOS)
