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
/// collection in the bundled cross-volume authority, with two-level disclosure to each
/// collection's sub-series. Each row opens the shared ``CollectionDetailView``.
///
/// Deliberately lean — a list with search, not a new navigation universe. Hosted:
/// - **iOS**: pushed from the document Source Explorer sheet ("Browse Archival
///   Collections"), and the Collections lens of Browse ▸ Archives.
/// - **macOS**: the Collections view of the Source Explorer window, and the Collections lens of
///   the Corpus Browser's Archives axis.
///
/// **It draws its own controls** — Group (repository, record group, ungrouped), Sort (document
/// count or name, either direction) and Expand All / Collapse All — so all three hosts get one
/// implementation rather than three copies to drift apart. Each host stores its choices under its
/// own ``ArchivesArrangement/CollectionListHost``.
///
/// The 4,400-record authority is grouped off the main thread; search filters over canonical names,
/// alias forms and lot keys.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
///   1.1 — #1051 B-5: the `onSelect` seam — the Browse Archives axis mounts this same
///          list and PUSHES the shared detail in its stack instead of sheeting it; `nil`
///          keeps the sheet for the existing Source Explorer hosts, so one list serves
///          both without a third collection browser being born (#777 class)
///   1.2 — 2026-09-10: the `arrangement` seam — the Browse Archives axis groups by repository
///          or record group and sorts by documents or name; `nil` kept Source Explorer's order
///   1.3 — 2026-09-10: the controls move INSIDE the list and every host gets them; an Ungrouped
///          option; collapsible sections. Source Explorer's separate volume-count order is retired
struct CollectionBrowserView: View {

    /// Which host this is, and so where its choices are stored.
    private let host: ArchivesArrangement.CollectionListHost
    /// A caption the host places before the list's own — the Archives axis's statement of what the
    /// Collections lens cannot reach. `nil` for none.
    private let leadingCaption: String?
    /// When set, a row hands its record here instead of presenting the detail sheet —
    /// the #1051 B-5 push-hosting seam. `nil` keeps the sheet.
    private let onSelect: ((AuthorityCollectionRecord) -> Void)?
    /// The host's own closed-groups state, when it wants that state to outlive this view. `nil`
    /// keeps it here, for as long as the list is on screen.
    private let hostCollapsed: Binding<Set<String>>?

    // Device-local and persistent — the catalogue's rule: browse state lives in UserDefaults, never
    // on a synced model. The keys come from the host, so each host remembers its own.
    @AppStorage private var groupingRaw: String
    @AppStorage private var sortKeyRaw: String
    @AppStorage private var ascending: Bool

    @State private var searchText = ""
    /// The grouped authority (`nil` while loading), rebuilt when the arrangement changes.
    @State private var sections: [ArchivesArrangement.CollectionSection]? = nil
    /// When set, the collection detail sheet presents. Anchored once, on the `List`.
    @State private var detailRecord: AuthorityCollectionRecord? = nil
    /// The arrangement the current sections were built for. `.task` runs on EVERY appearance — a
    /// pop back from a collection's detail included — and without this the whole authority would
    /// be regrouped and re-sorted each time the list came back on screen.
    @State private var builtFor: ArchivesArrangement.CollectionArrangement? = nil
    /// Sections the reader has closed, by id, when the host passes none of its own. An id carries its
    /// grouping, so switching grouping and back restores what was closed.
    @State private var ownCollapsed: Set<String> = []

    /// Creates the list.
    ///
    /// - Parameters:
    ///   - host: Where this list is mounted — which decides where its choices are stored.
    ///   - leadingCaption: A caption for the host to place before the list's own.
    ///   - collapsed: The host's closed-groups state, for a host that tears this view down and brings
    ///     it back — Browse on every lens switch, the macOS Source Explorer window on every mode switch —
    ///     or `nil` to keep it here.
    ///   - onSelect: A row's hand-off, or `nil` to present the detail sheet.
    init(host: ArchivesArrangement.CollectionListHost,
         leadingCaption: String? = nil,
         collapsed: Binding<Set<String>>? = nil,
         onSelect: ((AuthorityCollectionRecord) -> Void)? = nil) {
        self.host = host
        self.leadingCaption = leadingCaption
        self.hostCollapsed = collapsed
        self.onSelect = onSelect
        _groupingRaw = AppStorage(
            wrappedValue: ArchivesArrangement.CollectionGrouping.repository.rawValue, host.groupingKey)
        _sortKeyRaw = AppStorage(
            wrappedValue: ArchivesArrangement.Sort.standard.key.rawValue, host.sortKeyKey)
        _ascending = AppStorage(
            wrappedValue: ArchivesArrangement.Sort.standard.ascending, host.ascendingKey)
    }

    /// The stored choices, as one value.
    private var arrangement: ArchivesArrangement.CollectionArrangement {
        ArchivesArrangement.CollectionArrangement(
            grouping: ArchivesArrangement.CollectionGrouping(rawValue: groupingRaw) ?? .repository,
            sort: ArchivesArrangement.Sort(
                key: ArchivesArrangement.SortKey(rawValue: sortKeyRaw) ?? .documents,
                ascending: ascending))
    }

    private var sortBinding: Binding<ArchivesArrangement.Sort> {
        Binding(get: { arrangement.sort },
                set: { sortKeyRaw = $0.key.rawValue; ascending = $0.ascending })
    }

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The closed groups, wherever they are kept.
    private var collapsedBinding: Binding<Set<String>> { hostCollapsed ?? $ownCollapsed }
    private var collapsed: Set<String> { collapsedBinding.wrappedValue }

    var body: some View {
        let filtered = sections.map { ArchivesArrangement.filter($0, query: searchText) }
        let listShown = !(filtered?.isEmpty ?? true)
        // At accessibility text sizes the controls stack into several rows, and pinned above the list
        // they left it a sliver of the screen — confirmed by the review, and new in iOS Source
        // Explorer, which had drawn the list alone. There they scroll WITH the list instead. At other
        // sizes they stay pinned, because ungrouped the list is 4,432 rows and a control a reader must
        // scroll back to find is one they stop using. With no list on screen — loading, or a search
        // that matched nothing — they stay pinned at every size, since there is nothing to crowd.
        let controlsScroll = dynamicTypeSize.isAccessibilitySize && listShown
        VStack(spacing: 0) {
            if !controlsScroll {
                controlsRow
                    .padding(.horizontal)
                    .padding(.top, host == .sourceExplorer ? 8 : 0)
                    .padding(.bottom, 6)
            }
            if let filtered, listShown {
                List {
                    if controlsScroll {
                        Section { controlsRow }
                    }
                    // The captions scroll at every size: they are read once, and pinned they cost the
                    // list its height for as long as the screen is open — a dozen lines at the largest
                    // text sizes, measured by the review.
                    Section { captions }
                    ForEach(filtered) { section in
                        if section.grouping.hasSections {
                            let expanded = ArchivesArrangement.isExpanded(
                                section.id, collapsed: collapsed, query: searchText)
                            Section {
                                if expanded {
                                    ForEach(section.rows) { row in recordRow(row) }
                                }
                            } header: {
                                ArchivesSectionHeader(
                                    title: section.title,
                                    detail: ArchivesArrangement.collectionCountLabel(section.rows.count),
                                    isExpanded: expanded,
                                    isCollapsible: !isSearching,
                                    onToggle: {
                                        collapsedBinding.wrappedValue = ArchivesArrangement.toggling(
                                            section.id, collapsed: collapsed)
                                    })
                            }
                        } else {
                            Section {
                                ForEach(section.rows) { row in recordRow(row) }
                            }
                        }
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
            } else if sections != nil {
                ContentUnavailableView(
                    String(localized: "collection.browser.empty",
                           defaultValue: "No Matching Collections"),
                    systemImage: "archivebox",
                    description: Text(String(localized: "collection.browser.empty.detail",
                        defaultValue: "No archival collection name or alias matches the search."))
                )
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
        // Keyed on the arrangement, so a new grouping or sort rebuilds the sections.
        .task(id: arrangement) { await loadSections() }
    }

    /// The Group, Sort and Expand All / Collapse All row.
    private var controlsRow: some View {
        ArchivesControlsRow(expansion: expansion) {
            ArchivesGroupingMenu(groupingRaw: $groupingRaw)
            ArchivesSortMenu(sort: sortBinding, label: \.collectionLabel)
        }
    }

    /// The host's caption and the list's own, as one list row.
    private var captions: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let leadingCaption { Text(leadingCaption) }
            // What the counts are, said once: 2,599 of the 4,432 collections are cited only in
            // front matter, and a list sorted by documents drops every one of them to the end.
            Text(ArchivesArrangement.collectionCaption(grouping: arrangement.grouping))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// The Expand All / Collapse All control — present in EVERY grouping, and disabled when
    /// ungrouped rather than removed. A control that came and went with the Group menu changed the
    /// row's width, and a changed width is what moved the list and dropped focus.
    private var expansion: ArchivesExpansion {
        // The rule — label from the sections on screen, action only when they are this grouping's —
        // is `ArchivesArrangement.expansionState`, where a test can drive it.
        let state = ArchivesArrangement.expansionState(
            onScreen: sections, builtGrouping: builtFor?.grouping,
            current: arrangement.grouping, searching: isSearching)
        return ArchivesExpansion(sectionIDs: state.sectionIDs, collapsed: collapsedBinding,
                                 isDisabled: state.isDisabled)
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

    /// The tappable collection label: canonical name plus its series-wide volume count and its
    /// document count, since a list ordered by documents that shows only volumes would leave the
    /// reader no way to see why a row sits where it does.
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
        guard row.documents > 0 else {
            return String(format: String(localized: "collection.browser.volumes %lld",
                                         defaultValue: "%lld vols"), volumes)
        }
        return String(format: String(localized: "collection.browser.docsAndVolumes %lld %lld",
                                     defaultValue: "%1$lld docs · %2$lld vols"),
                      Int64(row.documents), volumes)
    }

    // MARK: - Grouping

    /// Builds the sections, off the main actor: this sorts 4,432 records with a reader's name
    /// comparison, which has no business on a frame.
    private func loadSections() async {
        let arrangement = self.arrangement
        guard sections == nil || builtFor != arrangement else { return }
        let built = await Task.detached(priority: .userInitiated) {
            // One ~2 MB decode on first use — warmed here, off the main thread (the bundled-store
            // pattern).
            guard let index = CollectionAuthorityStore.shared else {
                return [ArchivesArrangement.CollectionSection]()
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
        builtFor = arrangement
    }
}
