// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SubseriesDirectoryView

/// The subseries directory (`BrowserLevel.subseriesIndex`, #1051 B-1): the era hierarchy
/// that was the corpus root's whole content until root direction 2a moved it behind the
/// "Subseries" tile.
///
/// Rows keep the exact accessibility contract they had at the root ("Subseries <name>,
/// <n> volumes") — several UI suites drill into a subseries through that label, and the
/// move one level deep must not also change what they match. Tapping a row APPENDS
/// `.subseries` (this is a pushed level, not the root — the breadcrumb reads
/// FRUS › Subseries › <era>), and the downloaded-only filter applies exactly as it did
/// at the root.
///
/// Version history:
///   1.0 — #1051 B-1: extracted from `CorpusView` (root direction 2a); the row's dead
///          `totalDocuments` gate ("N docs" never rendered — it summed the manifest's
///          structurally-zero `documentCount`) is rewired to the R-2 accessor
struct SubseriesDirectoryView: View {

    let vm: BrowserViewModel

    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                ForEach(vm.allSubseriesGroups) { group in
                    Button {
                        vm.navigationPath.append(.subseries(group))
                        #if DEBUG
                        print("[BrowserView] Navigate → subseries \(group.subseries)")
                        #endif
                    } label: {
                        SubseriesRowLabel(group: group, documentCount: documentCount(for: group))
                            // See CorpusView's People row for why the frame has to precede the
                            // contentShape, and for the measurement: the label's VStack is only as
                            // wide as its longest line, so contentShape alone does not reach the
                            // rest of the row. Both modifiers, in this order.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
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
        .navigationTitle(String(localized: "browser.subseriesIndex.title", defaultValue: "Subseries"))
        #if os(iOS)
        // Inline title at this depth, like every pushed level: the breadcrumb bar is the
        // single location label (the corpus root keeps its large title).
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The subseries' total document count via the R-2 accessor, or `nil` when the index
    /// cannot answer (the row then simply omits its "N docs" caption).
    private func documentCount(for group: SubseriesGroup) -> Int? {
        let store = appState.administrationProfilesStore
        guard store.index != nil else { return nil }
        let total = group.volumes.reduce(0) {
            $0 + (store.documentCount(forVolumeId: $1.volumeId) ?? 0)
        }
        return total > 0 ? total : nil
    }
}

// MARK: - SubseriesRowLabel

/// Row content for one subseries in the directory (and, before 2a, the corpus root).
///
/// Version history:
///   1.0 — Session 11: initial implementation (in `CorpusView.swift`)
///   1.1 — #1051 B-1: moved here; `documentCount` is a parameter fed by the R-2 accessor
///          instead of the dead `group.totalDocuments` sum, so "N docs" renders for the
///          first time
struct SubseriesRowLabel: View {
    let group: SubseriesGroup
    /// The subseries' total document count, or `nil` to omit the caption.
    var documentCount: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(group.subseries)
                .font(.headline)
            HStack(spacing: 12) {
                Text("\(group.totalVolumes) vol.")
                if let documentCount {
                    Text("\(documentCount) docs")
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
