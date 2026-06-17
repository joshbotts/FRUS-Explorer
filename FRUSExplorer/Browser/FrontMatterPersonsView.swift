// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - FrontMatterPersonsView

/// Shows the persons list from a volume's front-matter `<div type="persons">` section.
///
/// Persons are loaded from `PersonMentionStore.allPersons(forVolumeId:)`, which queries the
/// `persons` SQLite table populated during indexing. Each row shows the person's name and
/// optional biographical description. Tapping a row opens `PersonIndexDetailSheet` with the
/// full-corpus mention count and a "Find all mentions" action.
///
/// The view is embedded inside `CompilationView` when the browser navigates to a
/// `<div type="persons">` structural section.
///
/// ## Indexing Dependency
/// The persons table is populated during indexing — volumes that have not been indexed yet
/// will show an empty list with a prompt to index the volume.
///
/// Version history:
///   1.0 — Session 2026-06-08: initial implementation
struct FrontMatterPersonsView: View {

    /// The volume whose persons list is being shown.
    let volumeId: String

    @Environment(AppState.self) private var appState

    @State private var persons: [PersonEntry] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @State private var selectedPerson: PersonIndexEntry?

    /// Persons filtered by `searchText` (case-insensitive name or description match).
    private var displayPersons: [PersonEntry] {
        guard !searchText.isEmpty else { return persons }
        let q = searchText.lowercased()
        return persons.filter {
            $0.name.lowercased().contains(q)
            || ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(String(localized: "browser.persons.loading",
                                    defaultValue: "Loading persons…"))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .padding(.vertical, 4)
                }
            } else if displayPersons.isEmpty {
                Section {
                    if persons.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "browser.persons.empty.title",
                                        defaultValue: "No Persons Listed"))
                                .font(.headline)
                            Text(String(localized: "browser.persons.empty.detail",
                                        defaultValue: "Index this volume to load its persons list."))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        Text(String(localized: "browser.persons.noResults",
                                    defaultValue: "No persons match your search."))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            } else {
                Section(header: Text(String(
                    localized: "browser.persons.count.header",
                    defaultValue: "Persons (\(displayPersons.count))"
                ))) {
                    ForEach(displayPersons, id: \.ref) { person in
                        PersonVolumeRow(person: person) {
                            // Per-volume entry: the detail sheet resolves the cross-corpus rollup
                            // (count + identity) from this volume + the person's ref.
                            selectedPerson = PersonIndexEntry(
                                entry: person, mentionCount: 0, sourceVolumeId: volumeId
                            )
                        }
                    }
                }
            }
        }
        .task { await loadPersons() }
        .sheet(item: $selectedPerson) { entry in
            PersonIndexDetailSheet(indexEntry: entry)
        }
    }

    // MARK: - Data Loading

    private func loadPersons() async {
        guard let store = appState.personMentionStore else {
            isLoading = false
            return
        }
        let entries = (try? await store.allPersons(forVolumeId: volumeId)) ?? []
        persons = entries
        isLoading = false
        #if DEBUG
        print("[FrontMatterPersonsView] Loaded \(entries.count) persons for \(volumeId)")
        #endif
    }
}

// MARK: - PersonVolumeRow

/// A single row in the volume persons list.
///
/// Shows name (primary) and optional description (secondary). No mention count badge —
/// those are cross-corpus counts loaded in the detail sheet after tap.
private struct PersonVolumeRow: View {
    let person: PersonEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let desc = person.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
