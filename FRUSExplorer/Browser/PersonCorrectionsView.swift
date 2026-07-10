// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - PersonMergePickerSheet

/// A searchable list of every other person, for the manual "Merge with another person…" flow
/// (#243). Picking a person hands it back through `onPick` and dismisses; the launching detail
/// sheet then shows a merge-confirmation alert.
///
/// The full rollup list (~18k identities) is loaded once and filtered in memory by name; the
/// `List` renders lazily, so only visible rows are built. The current person's own rollup is
/// excluded (a self-merge is a no-op).
///
/// Follows the codebase's sheet-chrome convention: `NavigationStack` + toolbar on iOS, a plain
/// `VStack` with a bottom-right Done on macOS (a `NavigationStack` renders sidebar-style artifacts
/// inside a macOS sheet — see `PersonIndexDetailSheet`).
///
/// Version history:
///   1.0 — Session 4 / #243: manual person-merge picker
///   1.1 — Session 4 review: current rollup excluded at load; case/diacritic-folded name
///          precompute + ~150 ms debounced off-keystroke filtering (plan item 1); row a11y
///          labels carry the role/era subtitle with the action phrasing as a hint
struct PersonMergePickerSheet: View {

    /// The current person's rollup id, excluded from the results.
    let excludingRollupId: Int?
    /// Invoked with the chosen person just before the sheet dismisses.
    let onPick: (PersonIndexEntry) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// One searchable candidate: the entry plus its precomputed case/diacritic-folded
    /// name, so the per-keystroke scan is a plain `contains` (no per-row folding).
    private struct Candidate: Sendable {
        let entry: PersonIndexEntry
        let foldedName: String
    }

    /// Every other rollup identity (the current one excluded at load), sorted by name,
    /// with folded names precomputed once.
    @State private var candidates: [Candidate] = []
    /// The rows currently shown — `candidates` filtered by the debounced search text.
    @State private var results: [PersonIndexEntry] = []
    @State private var isLoading = true
    @State private var searchText = ""

    /// Debounce for the search filter (plan item 1: ~18,600 rollups feed this list, so
    /// the scan runs at most once per pause, off the keystroke path, and stale runs are
    /// cancelled). Measured on-corpus: a folded `contains` scan over 18,641 names is
    /// ~5–10 ms — the debounce exists to keep even that off every keystroke.
    private static let searchDebounceNanos: UInt64 = 150_000_000

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "people.mergePicker.title", defaultValue: "Merge With…"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            searchField
            Divider()
            content
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 460)
        .task { await load() }
        #else
        NavigationStack {
            content
                .navigationTitle(String(localized: "people.mergePicker.title", defaultValue: "Merge With…"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText,
                            prompt: String(localized: "people.mergePicker.prompt",
                                           defaultValue: "Search people"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    }
                }
        }
        .task { await load() }
        #endif
    }

    #if os(macOS)
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(String(localized: "people.mergePicker.prompt", defaultValue: "Search people"),
                      text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    #endif

    @ViewBuilder
    private var content: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(results) { entry in
                    Button {
                        onPick(entry)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.entry.name).font(.body).foregroundStyle(.primary)
                            if let sub = entry.entry.roleEraSubtitle {
                                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Combined name + role/era label so VoiceOver can disambiguate the many
                    // same-named people; the action phrasing moves to the hint.
                    .accessibilityLabel([entry.entry.name, entry.entry.roleEraSubtitle]
                        .compactMap { $0 }.joined(separator: ", "))
                    .accessibilityHint(String(localized: "people.mergePicker.row.hint",
                                              defaultValue: "Merges this person into the current identity"))
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
            }
        }
        // Debounced search: recompute `results` off the keystroke path; stale runs cancel.
        .task(id: searchText) {
            if !searchText.isEmpty {
                try? await Task.sleep(nanoseconds: Self.searchDebounceNanos)
                guard !Task.isCancelled else { return }
            }
            results = Self.filter(candidates, by: searchText)
        }
    }

    /// Filters candidates by a case/diacritic-folded substring match on the precomputed
    /// folded names. Pure and `nonisolated` so it never contends with the main actor.
    private nonisolated static func filter(_ candidates: [Candidate], by query: String) -> [PersonIndexEntry] {
        guard !query.isEmpty else { return candidates.map(\.entry) }
        let folded = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return candidates.filter { $0.foldedName.contains(folded) }.map(\.entry)
    }

    private func load() async {
        guard let store = appState.personMentionStore else { isLoading = false; return }
        let all = (try? await store.allPersonsSortedByName()) ?? []
        candidates = all
            .filter { $0.rollupId != excludingRollupId }
            .map { Candidate(entry: $0,
                             foldedName: $0.entry.name.folding(
                                options: [.caseInsensitive, .diacriticInsensitive], locale: .current)) }
        results = candidates.map(\.entry)
        isLoading = false
    }
}

// MARK: - PersonCorrectionsSheet

/// The corrections/undo manager (#243): every person-cluster correction the user has made — merges
/// and separations — with a per-row Undo that deletes the override and re-consolidates so the
/// rollup reverts live. The People-browser toolbar opens it.
///
/// Each row resolves its stored `(volumeId, ref)` anchors to human-readable names; an anchor that
/// no longer resolves (its volume was removed from the index) falls back to the raw key. Merge
/// direction is rendered as prose ("A and B — merged"), never a bare arrow glyph.
///
/// Version history:
///   1.0 — Session 4 / #243: corrections/undo manager
///   1.1 — Session 4 review: rows hold value snapshots (not live CloudKit @Models) and
///          undo re-fetches by id, treating a miss as already-undone elsewhere; shared
///          `saveAndReconsolidate` tail; in-progress announcement; generation-counter bump
struct PersonCorrectionsSheet: View {

    /// Invoked after an undo re-consolidates, so the launching People list can refresh.
    let onChange: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// One resolved correction row — a VALUE snapshot, deliberately not the live
    /// CloudKit-synced `PersonClusterOverride` @Model (which another device could delete
    /// while this sheet is open, leaving a dangling managed object). `undo` re-fetches
    /// by `id` at action time and treats a miss as already-undone elsewhere.
    private struct CorrectionRow: Identifiable {
        /// The override's stable model `id`, for the undo-time re-fetch.
        let id: UUID
        /// Prose describing the correction (names resolved, direction textual).
        let title: String
        /// The correction date, formatted, or `nil`.
        let dateText: String?
    }

    @State private var rows: [CorrectionRow] = []
    @State private var isLoading = true
    @State private var isBusy = false

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "people.corrections.title", defaultValue: "Corrections"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            Divider()
            content
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 420)
        .task { await load() }
        #else
        NavigationStack {
            content
                .navigationTitle(String(localized: "people.corrections.title", defaultValue: "Corrections"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        .task { await load() }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if rows.isEmpty {
            ContentUnavailableView(
                String(localized: "people.corrections.empty.title", defaultValue: "No Corrections"),
                systemImage: "arrow.uturn.backward.circle",
                description: Text(String(localized: "people.corrections.empty.detail",
                    defaultValue: "Merges and separations you make in the People browser appear here, where you can undo them."))
            )
        } else {
            List {
                Section {
                    ForEach(rows) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.body)
                                if let dateText = row.dateText {
                                    Text(dateText).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await undo(id: row.id) }
                            } label: {
                                Text(String(localized: "people.corrections.undo", defaultValue: "Undo"))
                            }
                            .buttonStyle(.borderless)
                            .disabled(isBusy)
                            .accessibilityLabel(String(format: String(
                                localized: "people.corrections.undo.a11y %@",
                                defaultValue: "Undo: %@"), row.title))
                        }
                    }
                } footer: {
                    Text(String(localized: "people.corrections.footer",
                        defaultValue: "Undoing a correction rebuilds the affected identities and syncs across your devices."))
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #endif
        }
    }

    // MARK: - Data

    private func load() async {
        let overrides = PersonClusterOverrideStore.fetchAll(context: modelContext)
        let store = appState.personMentionStore
        var built: [CorrectionRow] = []
        for override in overrides {
            guard let kind = override.overrideKind else { continue }
            let nameA = await resolvedName(store, volumeId: override.volumeIdA, ref: override.refA)
            let title: String
            switch kind {
            case .merge:
                let nameB = await resolvedName(store, volumeId: override.volumeIdB ?? "", ref: override.refB ?? "")
                title = String(format: String(localized: "people.corrections.row.merge %1$@ %2$@",
                    defaultValue: "%1$@ and %2$@ — merged"), nameA, nameB)
            case .split:
                title = String(format: String(localized: "people.corrections.row.split %@",
                    defaultValue: "%@ — separated"), nameA)
            }
            built.append(CorrectionRow(id: override.id, title: title,
                                       dateText: override.createdAt.map { Self.dateFormatter.string(from: $0) }))
        }
        rows = built
        isLoading = false
    }

    /// The person's name for an anchor, or the raw `volumeId/ref` when it no longer resolves.
    private func resolvedName(_ store: PersonMentionStore?, volumeId: String, ref: String) async -> String {
        if let name = try? await store?.personName(volumeId: volumeId, ref: ref), !name.isEmpty {
            return name
        }
        return "\(volumeId)/\(ref)"
    }

    /// Undoes the correction with the given model `id`: re-fetches the live override at
    /// action time (it may have been deleted by a sync from another device — a miss is
    /// treated as already-undone), removes it, and re-consolidates via the shared tail.
    private func undo(id: UUID) async {
        guard let pipeline = appState.indexingPipeline else { return }
        isBusy = true
        defer { isBusy = false }
        let descriptor = FetchDescriptor<PersonClusterOverride>(predicate: #Predicate { $0.id == id })
        guard let override = (try? modelContext.fetch(descriptor))?.first else {
            // Already gone (undone/synced away elsewhere) — just refresh the list.
            await load()
            onChange()
            return
        }
        AccessibilityNotification.Announcement(
            String(localized: "people.corrections.undo.inProgress",
                   defaultValue: "Undoing correction…")).post()
        PersonClusterOverrideStore.remove(override, context: modelContext)
        await PersonClusterOverrideStore.saveAndReconsolidate(context: modelContext, pipeline: pipeline)
        AccessibilityNotification.Announcement(
            String(localized: "people.corrections.undo.done", defaultValue: "Correction undone")).post()
        appState.personCorrectionsGeneration += 1
        await load()
        onChange()
    }

    /// Shared medium-date formatter for the correction timestamps.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
