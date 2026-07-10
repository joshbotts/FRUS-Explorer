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
struct PersonMergePickerSheet: View {

    /// The current person's rollup id, excluded from the results.
    let excludingRollupId: Int?
    /// Invoked with the chosen person just before the sheet dismisses.
    let onPick: (PersonIndexEntry) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Every rollup identity, loaded once, sorted by name.
    @State private var allPeople: [PersonIndexEntry] = []
    @State private var isLoading = true
    @State private var searchText = ""

    /// The current person excluded, then filtered by the search text (case-insensitive).
    private var filtered: [PersonIndexEntry] {
        let base = allPeople.filter { $0.rollupId != excludingRollupId }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.entry.name.localizedCaseInsensitiveContains(searchText) }
    }

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
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(filtered) { entry in
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
                .accessibilityLabel(String(format: String(localized: "people.mergePicker.row.a11y %@",
                                                          defaultValue: "Merge with %@"), entry.entry.name))
            }
            #if os(macOS)
            .listStyle(.inset)
            #endif
        }
    }

    private func load() async {
        guard let store = appState.personMentionStore else { isLoading = false; return }
        allPeople = (try? await store.allPersonsSortedByName()) ?? []
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
struct PersonCorrectionsSheet: View {

    /// Invoked after an undo re-consolidates, so the launching People list can refresh.
    let onChange: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// One resolved correction row.
    private struct CorrectionRow: Identifiable {
        let override: PersonClusterOverride
        /// Prose describing the correction (names resolved, direction textual).
        let title: String
        /// The correction date, formatted, or `nil`.
        let dateText: String?
        var id: UUID { override.id }
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
                                Task { await undo(row.override) }
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
                title = String(format: String(localized: "people.corrections.row.merge %@ %@",
                    defaultValue: "%@ and %@ — merged"), nameA, nameB)
            case .split:
                title = String(format: String(localized: "people.corrections.row.split %@",
                    defaultValue: "%@ — separated"), nameA)
            }
            built.append(CorrectionRow(override: override, title: title,
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

    private func undo(_ override: PersonClusterOverride) async {
        guard let pipeline = appState.indexingPipeline else { return }
        isBusy = true
        defer { isBusy = false }
        PersonClusterOverrideStore.remove(override, context: modelContext)
        try? modelContext.save()
        let snapshot = PersonClusterOverrideStore.snapshot(context: modelContext)
        try? await pipeline.consolidatePersonRollup(overrides: snapshot, forceReload: false)
        AccessibilityNotification.Announcement(
            String(localized: "people.corrections.undo.done", defaultValue: "Correction undone")).post()
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
