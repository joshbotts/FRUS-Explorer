// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CorpusView

/// The top-level Browser view showing corpus-wide statistics and the subseries list.
///
/// Tapping a subseries row navigates to `SubseriesView` via `BrowserViewModel.navigationPath`.
///
/// Version history:
///   1.0 — Session 11: initial implementation
struct CorpusView: View {

    let vm: BrowserViewModel

    var body: some View {
        List {
            // Statistics header
            Section {
                CorpusStatsView(stats: vm.corpusStats)
            }

            // Subseries list
            Section(header: Text(String(localized: "browser.corpus.subseries.header",
                                        defaultValue: "Subseries"))) {
                ForEach(vm.allSubseriesGroups) { group in
                    Button {
                        vm.navigationPath.append(.subseries(group))
                        #if DEBUG
                        print("[BrowserView] Navigate → subseries \(group.subseries)")
                        #endif
                    } label: {
                        SubseriesRowLabel(group: group)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Subseries \(group.subseries), \(group.totalVolumes) volumes")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "browser.corpus.title", defaultValue: "FRUS Corpus"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - CorpusStatsView

private struct CorpusStatsView: View {
    let stats: CorpusStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 24) {
                StatCell(
                    label: String(localized: "browser.stats.volumes", defaultValue: "Volumes"),
                    value: "\(stats.totalVolumes)"
                )
                StatCell(
                    label: String(localized: "browser.stats.documents", defaultValue: "Documents"),
                    value: stats.totalDocuments > 0
                        ? "\(stats.totalDocuments)"
                        : String(localized: "browser.stats.unknown", defaultValue: "—")
                )
            }
            if let earliest = stats.earliestDocumentDate, let latest = stats.latestDocumentDate {
                Text("Documents: \(earliest) – \(latest)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let earliest = stats.earliestPublicationDate, let latest = stats.latestPublicationDate {
                Text("Published: \(earliest) – \(latest)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - SubseriesRowLabel

struct SubseriesRowLabel: View {
    let group: SubseriesGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(group.subseries)
                .font(.headline)
            HStack(spacing: 12) {
                Text("\(group.totalVolumes) vol.")
                if group.totalDocuments > 0 {
                    Text("\(group.totalDocuments) docs")
                }
                if let e = group.earliestDate, let l = group.latestDate {
                    Text("\(e.prefix(4))–\(l.prefix(4))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
