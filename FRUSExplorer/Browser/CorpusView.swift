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
///   1.1 — Session 58: wrap bare interpolation in accessibilityLabel with String(localized:) (F-022)
///   1.2 — Session 87: People cross-volume index entry
///   1.3 — Session 130: removed CorpusStatsView section (volume/document counts and date ranges
///          from the manifest were inaccurate or irrelevant to in-app navigation)
struct CorpusView: View {

    let vm: BrowserViewModel

    var body: some View {
        List {
            // Cross-volume indices
            Section {
                Button {
                    vm.navigationPath.append(.people)
                } label: {
                    Label(
                        String(localized: "browser.corpus.people", defaultValue: "People"),
                        systemImage: "person.2"
                    )
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(localized: "browser.corpus.people.a11y",
                           defaultValue: "Browse people mentioned across all indexed volumes")
                )
                .help(String(localized: "browser.corpus.people.help",
                             defaultValue: "Browse an alphabetical index of all people mentioned across your indexed volumes — tap a name to search for every document where they appear"))
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
                    .accessibilityLabel(
                        String(localized: "browser.corpus.subseries.a11y",
                               defaultValue: "Subseries \(group.subseries), \(group.totalVolumes) volumes")
                    )
                    .help(String(
                        localized: "browser.corpus.subseries.help",
                        defaultValue: "Browse the volumes and documents in this subseries"
                    ))
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "browser.corpus.title", defaultValue: "FRUS Corpus"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
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
