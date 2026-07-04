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
struct CollectionBrowserView: View {

    /// One repository bucket of the grouped authority.
    private struct RepositoryGroup: Identifiable {
        /// Display name (`"(Unattributed)"` for records with no repository).
        let name: String
        /// The bucket's records, most-cited first.
        let records: [AuthorityCollectionRecord]
        var id: String { name }
    }

    @State private var searchText = ""
    /// The grouped authority, built once on appear (`nil` while loading).
    @State private var groups: [RepositoryGroup]? = nil
    /// When set, the collection detail sheet presents. Anchored once, on the `List`.
    @State private var detailRecord: AuthorityCollectionRecord? = nil

    /// Display name for the no-repository bucket.
    private static var unattributedName: String {
        String(localized: "collection.browser.unattributed", defaultValue: "(Unattributed)")
    }

    var body: some View {
        Group {
            if let groups {
                let filtered = filteredGroups(groups)
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
                        ForEach(filtered) { group in
                            Section(header: Text(verbatim: group.name)) {
                                ForEach(group.records) { record in
                                    recordRow(record)
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
        .task { await loadGroups() }
    }

    // MARK: - Rows

    /// One collection row: a disclosure to its sub-series when it has any, else a
    /// plain row. The row itself opens the collection detail.
    @ViewBuilder
    private func recordRow(_ record: AuthorityCollectionRecord) -> some View {
        if record.children.isEmpty {
            recordButton(record)
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
                recordButton(record)
            }
        }
    }

    /// The tappable collection label: canonical name plus its series-wide volume count.
    private func recordButton(_ record: AuthorityCollectionRecord) -> some View {
        Button {
            detailRecord = record
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
                Text(String(format: String(localized: "collection.browser.volumes %lld",
                                           defaultValue: "%lld vols"),
                            Int64(record.volumeIds.count)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "collection.browser.row.hint",
                                  defaultValue: "Opens the collection's detail"))
    }

    // MARK: - Grouping & filtering

    /// Groups the bundled authority by repository, most-cited records first within
    /// each bucket; buckets sorted by record count (largest first), unattributed last.
    private func loadGroups() async {
        guard groups == nil else { return }
        // One ~2 MB decode — warmed off the main thread (the bundled-store pattern).
        let index = await Task.detached(priority: .userInitiated) {
            CollectionAuthorityStore.shared
        }.value
        guard let index else {
            groups = []
            return
        }
        var buckets: [String: [AuthorityCollectionRecord]] = [:]
        for record in index.collections {
            buckets[record.repository ?? Self.unattributedName, default: []].append(record)
        }
        groups = buckets
            .map { name, records in
                RepositoryGroup(
                    name: name,
                    records: records.sorted {
                        ($0.volumeIds.count, $1.name) > ($1.volumeIds.count, $0.name)
                    })
            }
            .sorted {
                if ($0.name == Self.unattributedName) != ($1.name == Self.unattributedName) {
                    return $1.name == Self.unattributedName
                }
                return ($0.records.count, $1.name) > ($1.records.count, $0.name)
            }
    }

    /// Applies the search text over canonical names and alias forms.
    private func filteredGroups(_ groups: [RepositoryGroup]) -> [RepositoryGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let hits = group.records.filter { record in
                record.name.localizedCaseInsensitiveContains(query)
                    || record.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
                    || record.lotFileNorm?.localizedCaseInsensitiveContains(query) == true
            }
            return hits.isEmpty ? nil : RepositoryGroup(name: group.name, records: hits)
        }
    }
}
