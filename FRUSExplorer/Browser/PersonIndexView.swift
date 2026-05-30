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
                                PersonIndexRow(indexEntry: indexEntry) {
                                    selectedIndexEntry = indexEntry
                                }
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
            PersonIndexDetailSheet(indexEntry: indexEntry)
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
        isLoading = false
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(indexEntry.entry.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let desc = indexEntry.entry.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
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

/// Sheet shown when a person row is tapped in `PersonIndexView`.
///
/// Displays name, biographical description, and mention count. The "Find all mentions"
/// button triggers a person-filtered search and dismisses the sheet.
private struct PersonIndexDetailSheet: View {

    let indexEntry: PersonIndexEntry
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

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
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LabeledContent(
                        String(localized: "people.detail.mentions", defaultValue: "Mentions"),
                        value: "\(indexEntry.mentionCount) document\(indexEntry.mentionCount == 1 ? "" : "s")"
                    )
                }

                Section {
                    Button {
                        appState.pendingSearch = SearchParameters(personRef: indexEntry.entry.ref)
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
                    .disabled(indexEntry.mentionCount == 0)
                    .help(String(localized: "people.detail.findMentions.help",
                                 defaultValue: "Open Search filtered to documents that mention this person"))
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
    }
}
