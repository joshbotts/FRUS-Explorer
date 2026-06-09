// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeSourcesView

/// Shows the archival sources list from a volume's front-matter `<div type="sources">` section.
///
/// Sources are loaded from `IndexingPipeline.volumeSources(forVolumeId:)`, which queries the
/// `volume_sources` SQLite table populated during indexing. Entries are shown in insertion
/// order (matching the TEI source list). Each entry displays:
/// - `rawText`: the full human-readable citation string (always present)
/// - `recordGroup` / `repository` / `lotFile` / `seriesName` as secondary metadata when non-nil
///
/// The view is embedded inside `CompilationView` when the browser navigates to a
/// `<div type="sources">` structural section.
///
/// ## Indexing Dependency
/// The `volume_sources` table is populated during indexing — volumes that have not been
/// indexed yet will show an empty list with a prompt to index the volume.
///
/// Version history:
///   1.0 — Session 2026-06-08: initial implementation
struct VolumeSourcesView: View {

    /// The volume whose sources list is being shown.
    let volumeId: String

    @Environment(AppState.self) private var appState

    @State private var sources: [VolumeSourceEntry] = []
    @State private var isLoading = true
    @State private var searchText: String = ""

    /// Sources filtered by `searchText` (case-insensitive match against rawText).
    private var displaySources: [VolumeSourceEntry] {
        guard !searchText.isEmpty else { return sources }
        let q = searchText.lowercased()
        return sources.filter { $0.rawText.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(String(localized: "browser.sources.loading",
                                    defaultValue: "Loading sources…"))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .padding(.vertical, 4)
                }
            } else if displaySources.isEmpty {
                Section {
                    if sources.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "browser.sources.empty.title",
                                        defaultValue: "No Sources Listed"))
                                .font(.headline)
                            Text(String(localized: "browser.sources.empty.detail",
                                        defaultValue: "Index this volume to load its archival sources list."))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        Text(String(localized: "browser.sources.noResults",
                                    defaultValue: "No sources match your search."))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            } else {
                Section(header: Text(String(
                    localized: "browser.sources.count.header",
                    defaultValue: "Sources (\(displaySources.count))"
                ))) {
                    ForEach(Array(displaySources.enumerated()), id: \.offset) { _, entry in
                        VolumeSourceRow(entry: entry)
                    }
                }
            }
        }
        .task { await loadSources() }
    }

    // MARK: - Data Loading

    private func loadSources() async {
        guard let pipeline = appState.indexingPipeline else {
            isLoading = false
            return
        }
        let entries = (try? await pipeline.volumeSources(forVolumeId: volumeId)) ?? []
        sources = entries
        isLoading = false
        #if DEBUG
        print("[VolumeSourcesView] Loaded \(entries.count) sources for \(volumeId)")
        #endif
    }
}

// MARK: - VolumeSourceRow

/// A single row in the volume archival sources list.
///
/// The `rawText` citation string is always the primary display. Structured metadata
/// fields (record group, repository, lot file, series) are shown as secondary lines
/// when non-nil — useful for eras where the indexing pipeline extracted structured data.
private struct VolumeSourceRow: View {
    let entry: VolumeSourceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.rawText)
                .font(.callout)

            Group {
                if let rg = entry.recordGroup, !rg.isEmpty {
                    Text(rg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let repo = entry.repository, !repo.isEmpty {
                    Text(repo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
