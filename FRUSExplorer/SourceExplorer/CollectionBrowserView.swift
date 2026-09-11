// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CollectionBrowserView

/// Browse-by-collection (Source Explorer Phase 4): a searchable list of every archival
/// collection in the bundled cross-volume authority, grouped by repository, with
/// two-level disclosure to each collection's sub-series. Each row opens the shared
/// ``CollectionDetailView``.
///
/// Deliberately lean — a list with search, not a new navigation universe. Hosted:
/// - **iOS**: pushed from the document Source Explorer sheet ("Browse Archival
///   Collections").
/// - **macOS**: the Collections view of the Source Explorer window.
///
/// The 4,400-record authority is grouped once on appear (off the main thread via the
/// store warm-up); search filters over canonical names and alias forms.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
///   1.1 — #1051 B-5: the `onSelect` seam — the Browse Archives axis mounts this same
///          list and PUSHES the shared detail in its stack instead of sheeting it; `nil`
///          keeps the sheet for the existing Source Explorer hosts, so one list serves
///          both without a third collection browser being born (#777 class)
///   1.2 — 2026-09-10: the `arrangement` seam — the Browse Archives axis groups by repository
///          or record group and sorts by documents or name; `nil` keeps Source Explorer's order.
///          Both paths now build the same `ArchivesArrangement.CollectionSection`s
struct CollectionBrowserView: View {

    /// When set, a row hands its record here instead of presenting the detail sheet —
    /// the #1051 B-5 push-hosting seam. `nil` (the default) keeps the sheet.
    var onSelect: ((AuthorityCollectionRecord) -> Void)? = nil

    /// When set, the list is grouped and ordered this way and each row shows its document count —
    /// the Browse Archives axis's controls. `nil` (the default) keeps the order Source Explorer has
    /// always shown, so the two hosts that never asked for these controls do not change.
    var arrangement: ArchivesArrangement.CollectionArrangement? = nil

    @State private var searchText = ""
    /// The grouped authority (`nil` while loading), rebuilt when the arrangement changes.
    @State private var sections: [ArchivesArrangement.CollectionSection]? = nil
    /// When set, the collection detail sheet presents. Anchored once, on the `List`.
    @State private var detailRecord: AuthorityCollectionRecord? = nil
    /// The arrangement the current sections were built for. `.task` runs on EVERY appearance — a
    /// pop back from a collection's detail included — and without this the whole authority would
    /// be regrouped and re-sorted each time the list came back on screen.
    @State private var builtFor: BuildKey? = nil

    /// The arrangement a build was for. A wrapper, so "built in Source Explorer's order" (`nil`
    /// arrangement) and "not built yet" (`nil` key) stay two different states.
    private struct BuildKey: Equatable {
        let arrangement: ArchivesArrangement.CollectionArrangement?
    }

    var body: some View {
        Group {
            if let sections {
                let filtered = ArchivesArrangement.filter(sections, query: searchText)
                if filtered.isEmpty {
                    ContentUnavailableView(
                        String(localized: "collection.browser.empty",
                               defaultValue: "No Matching Collections"),
                        systemImage: "archivebox",
                        description: Text(String(localized: "collection.browser.empty.detail",
                            defaultValue: "No archival collection name or alias matches the search."))
                    )
                } else {
                    List {
                        ForEach(filtered) { section in
                            Section(header: Text(verbatim: section.title)) {
                                ForEach(section.rows) { row in
                                    recordRow(row)
                                }
                            }
                        }
                    }
                    #if os(macOS)
                    .listStyle(.inset)
                    #endif
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "collection.browser.title",
                                defaultValue: "Archival Collections"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText,
                    prompt: String(localized: "collection.browser.search",
                                   defaultValue: "Collection name or alias"))
        .sheet(item: $detailRecord) { record in
            CollectionDetailSheet(record: record)
        }
        // Keyed on the arrangement, so a new grouping or sort rebuilds the sections; a host that
        // passes none runs this once, as before.
        .task(id: arrangement) { await loadSections() }
    }

    // MARK: - Rows

    /// One collection row: a disclosure to its sub-series when it has any, else a
    /// plain row. The row itself opens the collection detail.
    @ViewBuilder
    private func recordRow(_ row: ArchivesArrangement.CollectionRow) -> some View {
        let record = row.record
        if record.children.isEmpty {
            recordButton(row)
        } else {
            DisclosureGroup {
                ForEach(Array(record.children.enumerated()), id: \.offset) { _, child in
                    HStack {
                        Text(child.name)
                            .font(.caption)
                        Spacer()
                        if child.volumeIds.count > 1 {
                            Text("\(child.volumeIds.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } label: {
                recordButton(row)
            }
        }
    }

    /// The tappable collection label: canonical name plus its series-wide volume count — and, when
    /// arranged, its document count, since a list ordered by documents that shows only volumes
    /// would leave the reader no way to see why a row sits where it does.
    private func recordButton(_ row: ArchivesArrangement.CollectionRow) -> some View {
        let record = row.record
        return Button {
            if let onSelect {
                onSelect(record)
            } else {
                detailRecord = record
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                    if let lot = record.lotFileNorm {
                        Text(String(format: String(localized: "collection.browser.lot %@",
                                                   defaultValue: "Lot %@"), lot))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(countLabel(for: row))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "collection.browser.row.hint",
                                  defaultValue: "Opens the collection’s detail"))
    }

    /// The row's trailing count.
    ///
    /// A collection with no documents shows its volumes alone rather than `0 docs`: it is cited in a
    /// volume's front matter and under no document, which a zero would misstate as absence.
    private func countLabel(for row: ArchivesArrangement.CollectionRow) -> String {
        let volumes = Int64(row.record.volumeIds.count)
        guard arrangement != nil, row.documents > 0 else {
            return String(format: String(localized: "collection.browser.volumes %lld",
                                         defaultValue: "%lld vols"), volumes)
        }
        return String(format: String(localized: "collection.browser.docsAndVolumes %lld %lld",
                                     defaultValue: "%1$lld docs · %2$lld vols"),
                      Int64(row.documents), volumes)
    }

    // MARK: - Grouping

    /// Builds the sections, off the main actor: the arranged path sorts 4,432 records with a
    /// reader's name comparison, which has no business on a frame.
    private func loadSections() async {
        let key = BuildKey(arrangement: arrangement)
        guard sections == nil || builtFor != key else { return }
        let arrangement = self.arrangement
        let built = await Task.detached(priority: .userInitiated) {
            // One ~2 MB decode on first use — warmed here, off the main thread (the bundled-store
            // pattern).
            guard let index = CollectionAuthorityStore.shared else {
                return [ArchivesArrangement.CollectionSection]()
            }
            guard let arrangement else {
                return ArchivesArrangement.sourceExplorerSections(records: index.collections)
            }
            let usage = CollectionUsageIndexStore.shared
            let titles = arrangement.grouping == .recordGroup
                ? (VolumeSourcesIndexStore.shared?.recordGroups.mapValues(\.title) ?? [:])
                : [:]
            return ArchivesArrangement.collectionSections(
                records: index.collections,
                documents: { usage?.documentCount(forCollectionId: $0) ?? 0 },
                arrangement: arrangement,
                recordGroupTitles: titles)
        }.value
        // `.task(id:)` cancels THIS task when the arrangement changes, but a detached build does
        // not inherit that cancellation — it runs to completion, and `.value` returns regardless.
        // Without this guard a build for the old arrangement that finished after the new one would
        // replace it, leaving the list out of step with the menus that chose it. The window is widest
        // on the FIRST load, when the menus stay live above the spinner while the 1.9 MB authority
        // decodes and — grouped by record group — the 1.1 MB record-group titles after it; a
        // repository build skips that second decode, so switching mid-load lets the newer build
        // finish first. Two reviewers judged the race unreachable by hand on a warm list; a third
        // showed the cold one.
        guard !Task.isCancelled else { return }
        sections = built
        builtFor = key
    }
}
