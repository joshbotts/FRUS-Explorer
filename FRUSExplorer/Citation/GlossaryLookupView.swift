// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - GlossaryLookupView

/// Corpus-wide abbreviation lookup (#265).
///
/// FRUS glossaries are per-volume, so until now the only way to learn what `S/S-S` meant was to
/// open a volume that happened to define it. This searches all of them at once — measured on the
/// owner's index, 10,632 distinct terms across 312 volumes.
///
/// **The editors did not standardise.** `EUR` carries 30 distinct definitions and `S/S` 25, so a
/// single answer per abbreviation would be picking one volume's wording and hiding the rest. Each
/// result shows its variants, most widely used first, with the count of volumes behind each.
///
/// Version history:
///   1.0 — Session 2026-08-10: #265 (F-11)
struct GlossaryLookupView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var entries: [GlossaryEntry] = []
    @State private var isSearching = false
    @State private var unavailable = false
    /// Terms the user has expanded to see every wording.
    @State private var expanded: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                if unavailable {
                    ContentUnavailableView(
                        String(localized: "glossary.unavailable.title",
                               defaultValue: "Glossary Not Available"),
                        systemImage: "character.book.closed",
                        description: Text(String(localized: "glossary.unavailable.detail",
                                                 defaultValue: "Download a volume to build the glossary index."))
                    )
                } else if entries.isEmpty && !isSearching && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(entries) { entry in
                        entryRow(entry)
                    }
                }
            }
            .navigationTitle(String(localized: "glossary.title", defaultValue: "Abbreviations"))
            .searchable(text: $query,
                        prompt: String(localized: "glossary.search.prompt",
                                       defaultValue: "Abbreviation or term"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .task(id: query) { await load() }
            .overlay {
                if isSearching && entries.isEmpty { ProgressView() }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.term)
                    .font(.headline)
                Spacer(minLength: 8)
                Text(String(format: String(localized: "glossary.volumeCount %lld",
                                           defaultValue: "%lld volumes"),
                            Int64(entry.volumeCount)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let primary = entry.primaryDefinition {
                Text(primary).font(.callout)
            }
            // Only the contested terms get a disclosure — for the ~47% defined one way it would
            // be a control that never has anything behind it.
            if entry.isContested {
                if expanded.contains(entry.term) {
                    ForEach(entry.variants.dropFirst(), id: \.definition) { variant in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(variant.definition)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Text(verbatim: "\(variant.volumeCount)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Button {
                    if expanded.contains(entry.term) { expanded.remove(entry.term) }
                    else { expanded.insert(entry.term) }
                } label: {
                    Text(expanded.contains(entry.term)
                         ? String(localized: "glossary.collapse", defaultValue: "Show fewer")
                         : String(format: String(localized: "glossary.expand %lld",
                                                 defaultValue: "%lld other definitions"),
                                  Int64(entry.variants.count - 1)))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        guard let pipeline = appState.indexingPipeline else {
            unavailable = true
            return
        }
        unavailable = false
        isSearching = true
        defer { isSearching = false }
        entries = (try? await pipeline.glossaryLookup(query: query)) ?? []
    }
}
