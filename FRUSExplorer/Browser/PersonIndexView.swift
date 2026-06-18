// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - PersonIndexView

/// Alphabetical index of all persons mentioned across the indexed FRUS corpus.
///
/// Loads from `PersonMentionStore.allPersonsSortedByName()` and groups results by
/// the first letter of each person's name. Tapping a row opens `PersonIndexDetailSheet`
/// which shows the name, description, mention count, and a "Find all mentions" action.
///
/// ## Platform placement
/// - **iOS**: Navigation destination pushed from `CorpusView` ("People" row).
/// - **macOS**: Sheet presented from the Corpus Browser toolbar "People" button.
///
/// Version history:
///   1.0 — Session 87
struct PersonIndexView: View {

    @Environment(AppState.self) private var appState

    @State private var sections: [PersonIndexSection] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @State private var selectedIndexEntry: PersonIndexEntry?
    /// Rollup ids with a pending "possibly the same" suggestion, loaded once for row hints.
    @State private var candidateRollupIds: Set<Int> = []

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
                                .contextMenu { mentionsButton(for: indexEntry) }
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
        .task { await loadPeople() }
        .sheet(item: $selectedIndexEntry) { indexEntry in
            PersonIndexDetailSheet(indexEntry: indexEntry, onCorrection: {
                Task { await loadPeople() }
            })
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
    @ViewBuilder
    private func mentionsButton(for indexEntry: PersonIndexEntry) -> some View {
        Button {
            appState.pendingSearch = SearchParameters(personRollupId: indexEntry.rollupId)
            #if os(iOS)
            appState.activeTab = .search
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
                        .accessibilityLabel(String(localized: "people.row.candidate.a11y",
                                                   defaultValue: "Possible duplicate"))
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
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PersonIndexDetailSheet

/// Sheet shown when a person row is tapped in `PersonIndexView` or `FrontMatterPersonsView`.
///
/// Displays name, biographical description, and mention count. The mention count is loaded
/// asynchronously on appear so callers can pass any initial value (including 0) without a
/// blocking actor call at the tap site. The "Find all mentions" button triggers a
/// person-filtered search and dismisses the sheet.
struct PersonIndexDetailSheet: View {

    let indexEntry: PersonIndexEntry
    /// Called after a correction (merge) changes the rollup, so the caller can reload its list.
    var onCorrection: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Cross-corpus mention count loaded asynchronously on appear.
    /// Already correct for rollup entries from `PersonIndexView`; resolved here for the per-volume
    /// front-matter case (`FrontMatterPersonsView` passes 0 + a `sourceVolumeId`).
    @State private var resolvedMentionCount: Int?
    /// Rollup id resolved for a per-volume front-matter entry, used by "Find all mentions".
    @State private var resolvedRollupId: Int?
    /// Authority id / VIAF id resolved for a per-volume front-matter entry (Phase 5).
    @State private var resolvedAuthorityId: Int?
    @State private var resolvedViafId: String?
    /// "Possibly the same person" suggestions for this rollup (Phase 2 candidates).
    @State private var candidates: [PersonMergeCandidate] = []
    /// The per-volume records folded into this rollup (Phase 4 drill-in).
    @State private var members: [PersonRollupMember] = []
    /// True while a correction (merge or separate) is being applied + the rollup re-consolidated.
    @State private var isMerging = false

    private var displayCount: Int { resolvedMentionCount ?? indexEntry.mentionCount }
    private var effectiveRollupId: Int? { indexEntry.rollupId ?? resolvedRollupId }
    private var effectiveAuthorityId: Int? { indexEntry.authorityId ?? resolvedAuthorityId }
    private var effectiveViafId: String? { indexEntry.viafId ?? resolvedViafId }

    var body: some View {
        NavigationStack {
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
                        if effectiveAuthorityId != nil {
                            Label(
                                String(localized: "people.detail.reconciled",
                                       defaultValue: "Reconciled identity"),
                                systemImage: "checkmark.seal"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(String(localized: "people.detail.reconciled.help",
                                         defaultValue: "Matched to the Office of the Historian's person registry"))
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

                Section {
                    Button {
                        appState.pendingSearch = SearchParameters(personRollupId: effectiveRollupId)
                        #if os(iOS)
                        appState.activeTab = .search
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

                    if let viaf = effectiveViafId, !viaf.isEmpty,
                       let url = URL(string: "https://viaf.org/viaf/\(viaf)") {
                        Link(destination: url) {
                            Label(String(localized: "people.detail.viaf", defaultValue: "View on VIAF"),
                                  systemImage: "link")
                        }
                        .help(String(localized: "people.detail.viaf.help",
                                     defaultValue: "Open this person's VIAF authority record"))
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
            .navigationTitle(indexEntry.entry.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            #else
            .frame(minWidth: 360, minHeight: 260)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
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
        }
    }

    // MARK: - Corrections (Phase 3 merge / Phase 4 split)

    private func loadCorrectionContext() async {
        guard let rollupId = effectiveRollupId, let store = appState.personMentionStore else { return }
        let raw = (try? await store.candidates(forRollupId: rollupId)) ?? []
        candidates = raw.map { PersonMergeCandidate(rollupId: $0.rollupId, name: $0.name, reason: $0.reason) }
        members = (try? await store.members(forRollupId: rollupId)) ?? []
    }

    /// Records a "split" correction detaching `member` into its own identity, re-consolidates so it
    /// takes effect immediately, then dismisses.
    private func separate(_ member: PersonRollupMember) async {
        guard let pipeline = appState.indexingPipeline else { return }
        isMerging = true
        defer { isMerging = false }
        PersonClusterOverrideStore.split((volumeId: member.volumeId, ref: member.entry.ref),
                                         context: modelContext)
        try? modelContext.save()
        let snapshot = PersonClusterOverrideStore.snapshot(context: modelContext)
        try? await pipeline.consolidatePersonRollup(overrides: snapshot, forceReload: false)
        onCorrection?()
        dismiss()
    }

    /// Records a user "merge" correction (a must-link `PersonClusterOverride`) between this rollup and
    /// `candidate`, re-consolidates so the change takes effect immediately, then dismisses.
    private func merge(with candidate: PersonMergeCandidate) async {
        guard let store = appState.personMentionStore,
              let pipeline = appState.indexingPipeline,
              let myRollup = effectiveRollupId else { return }
        isMerging = true
        defer { isMerging = false }
        guard let mine = try? await store.representativeMember(forRollupId: myRollup),
              let theirs = try? await store.representativeMember(forRollupId: candidate.rollupId) else { return }
        PersonClusterOverrideStore.merge((volumeId: mine.volumeId, ref: mine.ref),
                                         (volumeId: theirs.volumeId, ref: theirs.ref),
                                         context: modelContext)
        try? modelContext.save()
        let snapshot = PersonClusterOverrideStore.snapshot(context: modelContext)
        try? await pipeline.consolidatePersonRollup(overrides: snapshot, forceReload: false)
        onCorrection?()
        dismiss()
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
