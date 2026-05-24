// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - IndexingSummaryCard

/// Post-indexing success card shown after a volume finishes indexing.
///
/// Renders in two layout modes depending on platform:
/// - **iOS** (`.banner`): compact two-row strip above the tab bar, matching the height of
///   `IndexingBannerView`. Wraps itself in a `VStack + Divider + .bar` background.
/// - **macOS** (`.sheet`): full-size centred card for use inside `CorpusVolumeDetailSheet`.
///
/// Auto-dismisses after 6 seconds via a `.task` modifier; the task is cancelled automatically
/// when the card disappears (e.g. when the caller clears `completedIndexingMetadata`), so
/// `onDismiss` is never called twice.
///
/// ## Navigation
/// "Search this volume →" constructs a `SearchParameters` scoped to the volume ID and
/// calls `onSearchVolume`. The caller is responsible for setting `AppState.pendingSearch`
/// and switching to the Search tab / window. `onDismiss` is also called so the card
/// clears before the navigation completes.
///
/// Version history:
///   1.0 — Session 114: initial implementation
struct IndexingSummaryCard: View {

    /// Aggregate metrics from the completed indexing pass.
    let metadata: VolumeMetadataDiscovered
    /// Human-readable volume title resolved from `ManifestStore`, or `nil` to fall back
    /// to `metadata.volumeId`.
    let volumeTitle: String?
    /// Called when the user taps "Search this volume". The caller sets `pendingSearch`
    /// and switches to Search, then calls `onDismiss` to clear the card.
    let onSearchVolume: (String) -> Void
    /// Called when the card should be dismissed: after auto-dismiss or on action tap.
    let onDismiss: () -> Void

    var body: some View {
        #if os(iOS)
        bannerBody
        #else
        sheetBody
        #endif
    }

    // MARK: - iOS Banner Layout

    #if os(iOS)
    private var bannerBody: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: FRUSTheme.captionSize))
                        .foregroundStyle(.green)

                    Text(String(
                        localized: "indexing.summary.banner.title",
                        defaultValue: "Indexed \(volumeTitle ?? metadata.volumeId)"
                    ))
                    .font(.system(size: FRUSTheme.captionSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                    Spacer()

                    Button {
                        onSearchVolume(metadata.volumeId)
                        onDismiss()
                    } label: {
                        Text(String(localized: "indexing.summary.search", defaultValue: "Search →"))
                            .font(.system(size: FRUSTheme.captionSize, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                }

                if let summary = statsSummaryLine {
                    Text(summary)
                        .font(.system(size: FRUSTheme.captionSmallSize))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 5)
            .background(.bar)
        }
        .task {
            try? await Task.sleep(for: .seconds(6))
            onDismiss()
        }
    }
    #endif

    // MARK: - macOS Sheet Layout

    #if os(macOS)
    private var sheetBody: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text(volumeTitle ?? metadata.volumeId)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let summary = statsSummaryLine {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let dateRange = formattedDateRange {
                    Text(dateRange)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: 380)
            .multilineTextAlignment(.center)

            Button {
                onSearchVolume(metadata.volumeId)
                onDismiss()
            } label: {
                Label(
                    String(localized: "indexing.summary.searchVolume",
                           defaultValue: "Search this volume"),
                    systemImage: "magnifyingglass"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            try? await Task.sleep(for: .seconds(6))
            onDismiss()
        }
    }
    #endif

    // MARK: - Shared Helpers

    private var statsSummaryLine: String? {
        var segments: [String] = []
        if metadata.totalDocuments > 0 {
            segments.append(String(
                localized: "indexing.summary.docs",
                defaultValue: "\(metadata.totalDocuments) documents"
            ))
        }
        if metadata.uniquePersonCount > 0 {
            segments.append(String(
                localized: "indexing.summary.persons",
                defaultValue: "\(metadata.uniquePersonCount) persons"
            ))
        }
        if metadata.crossReferenceCount > 0 {
            segments.append(String(
                localized: "indexing.summary.links",
                defaultValue: "\(metadata.crossReferenceCount) links"
            ))
        }
        return segments.isEmpty ? nil : segments.joined(separator: " · ")
    }

    private var formattedDateRange: String? {
        guard let minISO = metadata.dateRangeMin,
              let maxISO = metadata.dateRangeMax else { return nil }
        let minStr = formatISODate(minISO) ?? minISO
        let maxStr = formatISODate(maxISO) ?? maxISO
        return String(
            localized: "indexing.summary.dateRange",
            defaultValue: "\(minStr) – \(maxStr)"
        )
    }

    private func formatISODate(_ iso: String) -> String? {
        let parse = DateFormatter()
        parse.locale = Locale(identifier: "en_US_POSIX")
        parse.dateFormat = "yyyy-MM-dd"
        guard let date = parse.date(from: iso) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMM yyyy"
        return out.string(from: date)
    }
}
