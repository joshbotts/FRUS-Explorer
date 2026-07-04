// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - IndexingContextCard

/// Contextual information card shown during volume indexing.
///
/// Transforms idle wait time into a moment of historical discovery by surfacing:
///
/// 1. **Era header** — volume title and year range from the manifest.
/// 2. **Series context** — count of volumes in the same `subseries` and how many
///    are already downloaded.
/// 3. **Key persons** — up to 12 names from the volume's biographical glossary,
///    shown as tappable chips (appears once `VolumeMetadataDiscovered` arrives,
///    before storage begins).
/// 4. **Cross-reference preview** — total cross-reference edge count from metadata.
///
/// ## Placement
/// - `CorpusVolumeDetailView` (macOS): shown below the progress bar in the
///   indexing phase view.
/// - `IndexingBannerView` (iOS): shown only when `horizontalSizeClass == .regular`
///   (iPad), where vertical space permits the card.
///
/// ## Progressive rendering
/// The card renders as much as possible immediately (era + series) and enriches
/// itself when `metadata` becomes non-nil (persons + cross-refs).
///
/// Version history:
///   1.0 — Session 116: initial implementation
///   1.1 — Dynamic Type pass 2026-07-04: fixed-point caption font replaced with
///          scalable `FRUSTheme.captionFont`.
struct IndexingContextCard: View {

    /// The manifest entry for the volume being indexed.
    let volume: VolumeManifestEntry
    /// Discovery metadata emitted after the XML parse completes.
    var metadata: VolumeMetadataDiscovered? = nil
    /// Called when the user taps a person chip. Receives the person's display name.
    var onPersonSearch: ((String) -> Void)? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            eraSection
            seriesSection
            if let meta = metadata, !meta.glossaryPersonNames.isEmpty {
                keyPersonsSection(meta.glossaryPersonNames)
            }
            if let meta = metadata, meta.crossReferenceCount > 0 {
                crossRefSection(count: meta.crossReferenceCount)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Sections

    private var eraSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(volume.title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
            if let earliest = volume.dateRange.earliest,
               let latest = volume.dateRange.latest,
               earliest.prefix(4) != latest.prefix(4) {
                Text(String(
                    localized: "indexing.context.era.dateRange",
                    defaultValue: "\(earliest.prefix(4)) – \(latest.prefix(4))"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var seriesSection: some View {
        let allVolumes = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let seriesVolumes = allVolumes.filter { $0.subseries == volume.subseries }
        let downloadedCount = seriesVolumes.filter {
            appState.downloadManager?.isVolumeDownloaded($0.volumeId) == true
        }.count

        return HStack(spacing: 4) {
            Image(systemName: "books.vertical")
                .foregroundStyle(.secondary)
                .font(.caption)
            if downloadedCount > 0 {
                Text(String(
                    localized: "indexing.context.series.withDownloads",
                    defaultValue: "\(volume.subseries) series · \(seriesVolumes.count) volumes · \(downloadedCount) downloaded"
                ))
            } else {
                Text(String(
                    localized: "indexing.context.series",
                    defaultValue: "\(volume.subseries) series · \(seriesVolumes.count) volumes"
                ))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func keyPersonsSection(_ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(
                localized: "indexing.context.keyPersons",
                defaultValue: "Key Persons"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            onPersonSearch?(name)
                        } label: {
                            Text(name)
                                .font(FRUSTheme.captionFont)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12),
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(
                            localized: "indexing.context.personChip.a11y",
                            defaultValue: "Search for \(name)"
                        ))
                    }
                }
            }
        }
    }

    private func crossRefSection(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(String(
                localized: "indexing.context.crossRefs",
                defaultValue: "\(count) cross-references to other volumes"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
