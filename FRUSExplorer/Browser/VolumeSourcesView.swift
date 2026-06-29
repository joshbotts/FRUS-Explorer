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
    /// When set, presents the Archival Neighbors sheet for a volume source entry.
    @State private var sourceNeighborsTarget: VolumeSourceNeighborsTarget? = nil

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
                        VolumeSourceRow(
                            entry: entry,
                            onShowNeighbors: makeNeighborsTarget(for: entry).map { target in
                                { sourceNeighborsTarget = target }
                            }
                        )
                    }
                }
            }
        }
        .task { await loadSources() }
        .sheet(item: $sourceNeighborsTarget) { target in
            ArchivalNeighborsSheet(appState: appState) {
                guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
                return (try? await pipeline.archivalNeighbors(
                    forLotFile:  target.lotFile,
                    recordGroup: target.recordGroup,
                    series:      target.series
                )) ?? ([], 0, nil)
            }
            .environment(appState)
        }
    }

    /// Builds an archival-neighbors target for a source entry, or `nil` when the entry
    /// has no match key (no lot file and no record-group + series). Used to gate the
    /// per-row "Archival Neighbors" affordance so it only appears where it can return results.
    private func makeNeighborsTarget(for entry: VolumeSourceEntry) -> VolumeSourceNeighborsTarget? {
        let hasLot = entry.lotFile?.trimmingCharacters(in: .whitespaces).isEmpty == false
        let hasCollection = (entry.recordGroup?.trimmingCharacters(in: .whitespaces).isEmpty == false)
            && (entry.seriesName?.trimmingCharacters(in: .whitespaces).isEmpty == false)
        guard hasLot || hasCollection else { return nil }
        return VolumeSourceNeighborsTarget(
            lotFile:     entry.lotFile,
            recordGroup: entry.recordGroup,
            series:      entry.seriesName
        )
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

// MARK: - VolumeSourceNeighborsTarget

/// Identifiable `.sheet(item:)` target carrying a volume source entry's archival match
/// keys (lot file, or record group + series) for the Archival Neighbors sheet.
private struct VolumeSourceNeighborsTarget: Identifiable {
    let lotFile: String?
    let recordGroup: String?
    let series: String?
    let id = UUID()
}

// MARK: - VolumeSourceRow

/// A single row in the volume archival sources list.
///
/// The `rawText` citation string is always the primary display. Structured metadata
/// fields (record group, repository, lot file, series) are shown as secondary lines
/// when non-nil — useful for eras where the indexing pipeline extracted structured data.
private struct VolumeSourceRow: View {
    let entry: VolumeSourceEntry
    /// Non-nil when this entry has an archival match key; shows a button that opens the
    /// Archival Neighbors sheet for the entry's lot file or record-group series.
    let onShowNeighbors: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
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

            if let onShowNeighbors {
                Spacer(minLength: 8)
                Button(action: onShowNeighbors) {
                    Image(systemName: "archivebox")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "browser.sources.archivalNeighbors.help",
                             defaultValue: "Show indexed documents drawn from this archival source"))
                .accessibilityLabel(String(localized: "browser.sources.archivalNeighbors",
                                           defaultValue: "Archival Neighbors"))
            }
        }
        .padding(.vertical, 3)
    }
}
