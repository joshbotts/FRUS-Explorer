// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - ArchivesAxis

/// The Archives browse axis's pure logic (#1051 B-5, A-9): the provenance-type doors,
/// their R-1 drill specs, and the honesty captions — computed from the LIVE artifact
/// coverage block, never copied from doc comments (several in-code figures are stale).
///
/// ## The settled shape (owner decision, 2026-08-22): SIBLING LENSES, never nested
/// The axis offers two ways in side by side — ten provenance-type doors drilling straight
/// to volume lists, and the repository-grouped collection index — because **no shipped
/// data maps a collection to a provenance category**. The join was measured many-to-many
/// against the export sample (decimal-file parses land on `txt:` records 76×), the
/// id-prefix + repository heuristic was refuted there, and the schema-2 generator field
/// that nesting would need was explicitly not taken. Do not nest one lens under the other.
///
/// ## Which universe the numbers describe
/// Everything here counts DOCUMENT SOURCE NOTES from `collection-usage-index.json` —
/// the note printed under each document — with `volumeNoteCounts` as the per-volume share
/// denominator. It is NOT `source-provenance-index.json`'s universe (raw `type="source"`
/// elements; a 4,696-note gap, two questions, neither wrong), and never the corpus's
/// 314,571 document divs. The captions say so.
///
/// Version history:
///   1.0 — #1051 B-5: initial implementation
enum ArchivesAxis {

    /// One provenance-type door: a category and its series-wide reach.
    struct CategoryDoor: Identifiable {
        /// The artifact's category slug (also `SourceProvenanceCategory`'s raw value).
        let slug: String
        /// The localized display name.
        let name: String
        /// Volumes the category reaches.
        let volumeCount: Int
        /// Documents attributed to the category.
        let docCount: Int

        var id: String { slug }
    }

    /// The display name for a category slug, through the shipped localized vocabulary.
    ///
    /// - Parameter slug: The artifact slug.
    /// - Returns: The `SourceProvenanceCategory` display name, or the slug itself for an
    ///   unknown future category (skipped gracefully, never trapped — the enum's rule).
    static func displayName(forCategory slug: String) -> String {
        SourceProvenanceCategory(rawValue: slug)?.displayName ?? slug
    }

    /// The ten doors, in the artifact's own display order, with live counts.
    ///
    /// - Parameter usage: The bundled usage index.
    /// - Returns: One door per category the artifact carries.
    static func categoryDoors(usage: CollectionUsageIndex) -> [CategoryDoor] {
        usage.categories.map { slug in
            let byVolume = usage.documentsByVolume(forCategory: slug)
            return CategoryDoor(
                slug: slug,
                name: displayName(forCategory: slug),
                volumeCount: byVolume.count,
                docCount: byVolume.values.reduce(0, +)
            )
        }
    }

    /// The axis's top caption: the population, its reach, and the collection-lens
    /// ceiling — every figure from the live coverage block.
    ///
    /// - Parameter coverage: The artifact's coverage block.
    /// - Returns: The caption.
    static func indexCaption(coverage: CollectionUsageIndex.Coverage) -> String {
        let percent = collectionSharePercent(coverage: coverage)
        let noteless = coverage.volumesScanned - coverage.volumesWithNotes
        return String(
            localized: "browser.archives.coverage",
            defaultValue: "FRUS’s editors printed a source note under \(coverage.noteCount) documents across \(coverage.volumesWithNotes) of \(coverage.volumesScanned) volumes — the archival record this axis browses. About \(percent)% of those notes name an archival collection; most of the rest cite a State Department central-file number. \(noteless) volumes, mostly the pre-1906 annuals, print no notes and cannot appear here."
        )
    }

    /// The share of notes that resolve to a named collection, as a whole percent.
    ///
    /// - Parameter coverage: The artifact's coverage block.
    /// - Returns: 0–100.
    static func collectionSharePercent(coverage: CollectionUsageIndex.Coverage) -> Int {
        guard coverage.noteCount > 0 else { return 0 }
        return Int((Double(coverage.notesInACollection) / Double(coverage.noteCount) * 100)
            .rounded())
    }

    /// The R-1 drill spec for one provenance-type door: volumes largest-count first, a
    /// "N docs · P%" accessory whose denominator is the volume's own sourced-document
    /// count, and the caption that names both universes.
    ///
    /// - Parameters:
    ///   - slug: The category slug.
    ///   - usage: The bundled usage index.
    /// - Returns: The spec.
    static func spec(forCategory slug: String, usage: CollectionUsageIndex) -> VolumeListSpec {
        let byVolume = usage.documentsByVolume(forCategory: slug)
        let ordered = byVolume.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }
        var accessories: [String: String] = [:]
        for (volumeId, docs) in byVolume {
            if let notes = usage.noteCount(forVolumeId: volumeId), notes > 0 {
                let share = Int((Double(docs) / Double(notes) * 100).rounded())
                accessories[volumeId] = String(
                    localized: "browser.archives.accessory",
                    defaultValue: "\(docs) docs · \(share)%")
            } else {
                accessories[volumeId] = String(
                    localized: "browser.archives.accessory.plain",
                    defaultValue: "\(docs) docs")
            }
        }
        let name = displayName(forCategory: slug)
        return VolumeListSpec(
            axisKey: "archives:category:\(slug)",
            title: name,
            volumeIds: ordered.map(\.key),
            caption: String(
                localized: "browser.archives.drill.caption",
                defaultValue: "\(byVolume.count) volumes with documents drawn from \(name), largest count first. Percentages are each volume’s share of its own sourced documents — the notes printed under documents, not every document in the volume."),
            accessories: accessories
        )
    }
}

// MARK: - ArchivesIndexView

/// The Archives axis (#1051 B-5, A-9): two SIBLING lenses — the ten provenance-type
/// doors, and the repository-grouped collection index (the shipped
/// `CollectionBrowserView`, mounted through its B-5 `onSelect` seam so one list serves
/// Source Explorer and Browse without a third being born).
///
/// Shared across both platforms behind two closures.
///
/// Version history:
///   1.0 — #1051 B-5: initial implementation
struct ArchivesIndexView: View {

    /// The volume universe, for the class lens's era buckets.
    let entries: [VolumeManifestEntry]
    /// A provenance-type door's drill.
    let onSelectCategory: @MainActor (VolumeListSpec) -> Void
    /// A collection row's drill (the push-hosted detail).
    let onSelectCollection: @MainActor (AuthorityCollectionRecord) -> Void

    /// The three sibling lenses.
    private enum Lens: String, CaseIterable, Identifiable {
        case types, collections, classes
        var id: String { rawValue }

        var label: String {
            switch self {
            case .types:
                return String(localized: "browser.archives.lens.types",
                              defaultValue: "Provenance Types")
            case .collections:
                return String(localized: "browser.archives.lens.collections",
                              defaultValue: "Collections")
            case .classes:
                return String(localized: "browser.archives.lens.classes",
                              defaultValue: "Classes")
            }
        }
    }

    @State private var lens: Lens = .types
    /// The class lens's eras and rows, built off `body` — the sweep is over ten thousand class
    /// keys and is not work for a view update. Held in the order ``classSectionsSort`` names.
    @State private var classSections: [(era: ArchivesClassAxis.FilingEra,
                                        rows: [ArchivesClassAxis.ClassRow])] = []
    /// The sort `classSections` is currently in, so a task that re-runs for another reason — a lens
    /// switch, a re-appearance — does not re-sort 9,908 rows into the order they are already in.
    @State private var classSectionsSort: ArchivesArrangement.Sort? = nil

    // The arrangement, device-local and persistent — the catalogue's rule: browse state lives in
    // UserDefaults, never on a synced model. Each lens keeps its own sort, because "Name" means a
    // collection's name on one and a class number on the other.
    @AppStorage("browse.archives.collections.grouping")
    private var collectionGroupingRaw = ArchivesArrangement.CollectionGrouping.repository.rawValue
    @AppStorage("browse.archives.collections.sortKey")
    private var collectionSortKeyRaw = ArchivesArrangement.Sort.standard.key.rawValue
    @AppStorage("browse.archives.collections.ascending")
    private var collectionAscending = ArchivesArrangement.Sort.standard.ascending
    @AppStorage("browse.archives.classes.sortKey")
    private var classSortKeyRaw = ArchivesArrangement.Sort.standard.key.rawValue
    @AppStorage("browse.archives.classes.ascending")
    private var classAscending = ArchivesArrangement.Sort.standard.ascending

    private var collectionGrouping: ArchivesArrangement.CollectionGrouping {
        ArchivesArrangement.CollectionGrouping(rawValue: collectionGroupingRaw) ?? .repository
    }

    private var collectionSort: Binding<ArchivesArrangement.Sort> {
        Binding(
            get: {
                ArchivesArrangement.Sort(
                    key: ArchivesArrangement.SortKey(rawValue: collectionSortKeyRaw) ?? .documents,
                    ascending: collectionAscending)
            },
            set: { collectionSortKeyRaw = $0.key.rawValue; collectionAscending = $0.ascending })
    }

    private var classSort: Binding<ArchivesArrangement.Sort> {
        Binding(
            get: {
                ArchivesArrangement.Sort(
                    key: ArchivesArrangement.SortKey(rawValue: classSortKeyRaw) ?? .documents,
                    ascending: classAscending)
            },
            set: { classSortKeyRaw = $0.key.rawValue; classAscending = $0.ascending })
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "browser.archives.lens.picker", defaultValue: "Lens"),
                   selection: $lens) {
                ForEach(Lens.allCases) { lens in
                    Text(lens.label).tag(lens)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Pinned above the list rather than scrolled with it: the 1910–49 era alone is 6,118
            // rows, and a control a reader has to scroll back to find is a control they stop using.
            arrangementControls

            switch lens {
            case .types:
                typesList
            case .collections:
                collectionsLens
            case .classes:
                classesLens
            }
        }
        .navigationTitle(String(localized: "browser.archives.title", defaultValue: "Archives"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // On the whole axis, not on the Classes list, and keyed on the sort. The stored choice is
        // shared by every window, so on iPad a sort changed in one window while another shows a
        // different lens must still reorder that other window's classes — an `.onChange` hung on
        // the list only fires while the list is mounted, and left the rows in the old order under
        // a menu naming the new one.
        .task(id: ClassesTaskKey(volumes: entries.count, sort: classSort.wrappedValue,
                                 showing: lens == .classes)) {
            arrangeClassSections()
        }
    }

    /// What the class sections depend on.
    private struct ClassesTaskKey: Equatable {
        let volumes: Int
        let sort: ArchivesArrangement.Sort
        /// Whether the Classes lens is on screen. The first build waits for it, so a reader who
        /// never opens that lens never pays for ten thousand gloss lookups.
        let showing: Bool
    }

    /// Builds the class sections the first time the Classes lens is shown, in the stored order, and
    /// re-sorts them whenever that order changes afterwards.
    private func arrangeClassSections() {
        let sort = classSort.wrappedValue
        if classSections.isEmpty {
            guard lens == .classes, let usage = CollectionUsageIndexStore.shared else { return }
            let coverage = ArchivalVolumeCoverage.map(from: entries)
            classSections = ArchivesClassAxis.eras().map { era in
                (era: era, rows: ArchivesArrangement.sortedClassRows(
                    ArchivesClassAxis.rows(inEra: era, usage: usage, coverage: coverage), by: sort))
            }
            classSectionsSort = sort
        } else if classSectionsSort != sort {
            // A re-sort, not a rebuild: the rows and their glosses are already made, and the order
            // is total, so sorting from any previous order gives the same list.
            classSections = classSections.map {
                (era: $0.era, rows: ArchivesArrangement.sortedClassRows($0.rows, by: sort))
            }
            classSectionsSort = sort
        }
    }

    // MARK: Arrangement

    /// The grouping and sort controls for the lens on screen. Provenance Types has none: its ten
    /// doors are the artifact's own display order, and there are only ten.
    @ViewBuilder
    private var arrangementControls: some View {
        switch lens {
        case .types:
            EmptyView()
        case .collections:
            HStack(spacing: 8) {
                ArchivesGroupingMenu(groupingRaw: $collectionGroupingRaw)
                ArchivesSortMenu(sort: collectionSort, label: \.collectionLabel)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        case .classes:
            HStack(spacing: 8) {
                ArchivesSortMenu(sort: classSort, label: \.classLabel)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }

    // MARK: Central-file classes

    /// The classes, divided by filing era.
    ///
    /// The division is the point rather than a tidying: a class key means different things under
    /// different schedules — `POL 24` is *SUBVERSION. ESPIONAGE.* in 1963 and *SANCTIONS* from
    /// 1964, and the 1950 decimal renumbering moved class 7 outright — so one flat list would have
    /// to pick a reading and be wrong for the other era. Here the same designator appears in two
    /// sections saying two different things.
    @ViewBuilder
    private var classesLens: some View {
        List {
            Section {
                Text(String(localized: "browser.archives.classes.caption",
                            defaultValue: """
                                Central-file classes, grouped by the filing schedule in force. \
                                A volume is counted in the era its coverage falls inside; one \
                                spanning two schedules is counted in neither, because the same \
                                number means different things on either side. Readings come from \
                                the Department’s own filing manuals. Each era lists every class \
                                its volumes’ source notes cite; by class number, it follows its \
                                own file — decimal numbers digit by digit, so 711.11 comes before \
                                711.2, and subject-numeric designators by their numbers.
                                """))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ForEach(classSections, id: \.era.id) { section in
                Section(section.era.title) {
                    if section.rows.isEmpty {
                        Text(String(localized: "browser.archives.classes.empty",
                                    defaultValue: "No volumes fall inside this schedule."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    ForEach(section.rows) { row in
                        Button {
                            guard let usage = CollectionUsageIndexStore.shared else { return }
                            onSelectCategory(ArchivesClassAxis.spec(for: row, era: section.era,
                                                                    usage: usage))
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.key)
                                        .font(.body.monospaced())
                                    if let gloss = row.gloss {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(gloss)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            // #1257: one code, several places.
                                            GlossAlternatesLink(alternates: row.glossAlternates,
                                                                key: row.key)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(String(localized: "browser.archives.classes.count",
                                            defaultValue: "\(row.documents) docs"))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Provenance types

    @ViewBuilder
    private var typesList: some View {
        if let usage = CollectionUsageIndexStore.shared {
            List {
                Section {
                    Text(ArchivesAxis.indexCaption(coverage: usage.coverage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(ArchivesAxis.categoryDoors(usage: usage)) { door in
                        Button {
                            onSelectCategory(ArchivesAxis.spec(forCategory: door.slug, usage: usage))
                            #if DEBUG
                            print("[ArchivesIndexView] Navigate → category \(door.slug)")
                            #endif
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(door.name)
                                    .font(.body)
                                Spacer(minLength: 8)
                                Text(String(localized: "browser.archives.door.counts",
                                            defaultValue: "\(door.volumeCount) vols · \(door.docCount) docs"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            // Both modifiers, in this order — the #312 idiom.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            String(localized: "browser.archives.door.a11y",
                                   defaultValue: "\(door.name), \(door.volumeCount) volumes")
                        )
                        .help(String(localized: "browser.archives.door.help",
                                     defaultValue: "Browse the volumes with documents drawn from this kind of file"))
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
        } else {
            // The lazy store is nil only when the bundled artifact is missing or
            // malformed — an explicit state, never a silent blank axis.
            ContentUnavailableView(
                String(localized: "browser.archives.unavailable.title",
                       defaultValue: "Archives Unavailable"),
                systemImage: "archivebox",
                description: Text(String(
                    localized: "browser.archives.unavailable.detail",
                    defaultValue: "The bundled archival-usage data could not be loaded. Reinstalling the app restores it."))
            )
        }
    }

    // MARK: Collections

    @ViewBuilder
    private var collectionsLens: some View {
        VStack(spacing: 0) {
            if let usage = CollectionUsageIndexStore.shared {
                // The lens's ceiling, said before the list: most sourced documents cite a
                // central-file number, not a named collection — the types lens holds them.
                Text(String(localized: "browser.archives.collections.ceiling",
                            defaultValue: "About \(ArchivesAxis.collectionSharePercent(coverage: usage.coverage))% of sourced documents name an archival collection; the rest — mostly central-file citations — are under Provenance Types."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            // What the counts are, said once: 2,599 of the 4,432 collections are cited only in
            // front matter, and a list sorted by documents drops every one of them to the end.
            Text(collectionCountsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 6)
            CollectionBrowserView(
                onSelect: onSelectCollection,
                arrangement: ArchivesArrangement.CollectionArrangement(
                    grouping: collectionGrouping, sort: collectionSort.wrappedValue))
        }
    }

    /// The counts caption, and — grouped by record group — where the collections with none went.
    private var collectionCountsCaption: String {
        let counts = String(localized: "browser.archives.collections.counts",
                            defaultValue: "Counts are documents whose printed source note names the collection; one cited only in a volume’s front matter shows its volumes alone.")
        guard collectionGrouping == .recordGroup else { return counts }
        let remainder = String(localized: "browser.archives.collections.noRecordGroup",
                               defaultValue: "Record groups are the National Archives’ own divisions. Collections whose citations name none — nearly every presidential-library collection among them — are listed together last.")
        return "\(counts) \(remainder)"
    }
}

// MARK: - Arrangement controls

/// The sort control both counting lenses share: a key and a direction, with the current choice
/// named on the button so a reader can see what the list is ordered by without opening it.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
private struct ArchivesSortMenu: View {
    /// The lens's sort.
    @Binding var sort: ArchivesArrangement.Sort
    /// How this lens names each key — "Name" for collections, "Class Number" for classes.
    let label: (ArchivesArrangement.SortKey) -> String

    var body: some View {
        Menu {
            Picker(String(localized: "browser.archives.sort.by", defaultValue: "Sort By"),
                   selection: Binding(get: { sort.key }, set: { sort = sort.selecting($0) })) {
                ForEach(ArchivesArrangement.SortKey.allCases) { key in
                    Text(label(key)).tag(key)
                }
            }
            .pickerStyle(.inline)
            Picker(String(localized: "browser.archives.sort.order", defaultValue: "Order"),
                   selection: $sort.ascending) {
                Text(ArchivesArrangement.Sort.directionLabel(ascending: true)).tag(true)
                Text(ArchivesArrangement.Sort.directionLabel(ascending: false)).tag(false)
            }
            .pickerStyle(.inline)
        } label: {
            Label(summary, systemImage: "arrow.up.arrow.down")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "browser.archives.sort.a11y", defaultValue: "Sort"))
        .accessibilityValue(summary)
        // Voice Control and Full Keyboard Access name a control by its INPUT labels, which default
        // to the accessibility label — so without these, a reader who sees "Document Count,
        // Descending" on the button and says it gets nothing (WCAG 2.5.3, Label in Name; found by
        // the review's completeness critic). VoiceOver still reads the label and the value above.
        .accessibilityInputLabels([
            summary, label(sort.key),
            String(localized: "browser.archives.sort.a11y", defaultValue: "Sort"),
        ])
    }

    /// `Document Count, Descending`.
    private var summary: String {
        String(format: String(localized: "browser.archives.sort.summary %@ %@",
                              defaultValue: "%1$@, %2$@"),
               label(sort.key), ArchivesArrangement.Sort.directionLabel(ascending: sort.ascending))
    }
}

/// The Collections lens's grouping control: repository or record group — the counterpart of the
/// Classes lens's division by filing era.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
private struct ArchivesGroupingMenu: View {
    /// The stored grouping's raw value.
    @Binding var groupingRaw: String

    private var grouping: ArchivesArrangement.CollectionGrouping {
        ArchivesArrangement.CollectionGrouping(rawValue: groupingRaw) ?? .repository
    }

    var body: some View {
        Menu {
            Picker(String(localized: "browser.archives.group.by", defaultValue: "Group By"),
                   selection: Binding(get: { grouping }, set: { groupingRaw = $0.rawValue })) {
                ForEach(ArchivesArrangement.CollectionGrouping.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(summary, systemImage: "rectangle.stack")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "browser.archives.group.a11y",
                                   defaultValue: "Group By"))
        .accessibilityValue(grouping.label)
        // The visible text must be speakable, for the reason the sort menu's note gives.
        .accessibilityInputLabels([
            summary, grouping.label,
            String(localized: "browser.archives.group.a11y", defaultValue: "Group By"),
        ])
    }

    /// `By Record Group`.
    private var summary: String {
        String(format: String(localized: "browser.archives.group.summary %@",
                              defaultValue: "By %@"), grouping.label)
    }
}

// MARK: - iOS mounts

#if os(iOS)

/// The iOS mount of the Archives axis (`BrowserLevel.archives`).
///
/// Version history:
///   1.0 — #1051 B-5: initial implementation
struct BrowseArchivesLevel: View {
    let vm: BrowserViewModel

    var body: some View {
        ArchivesIndexView(
            entries: vm.allVolumes,
            onSelectCategory: { [vm] spec in vm.navigationPath.append(.volumeList(spec)) },
            onSelectCollection: { [vm] record in
                vm.navigationPath.append(.archivalCollection(id: record.id, name: record.name))
            }
        )
    }
}

/// The iOS mount of a pushed collection detail (`BrowserLevel.archivalCollection`):
/// the shared `CollectionDetailView`, with citing-volume rows routed IN PLACE so the
/// axis back-stack survives (the B-5 seam). The NAID/catalog-link trust gate stays
/// inside the shared detail — this axis never renders `record.naId` itself.
///
/// Version history:
///   1.0 — #1051 B-5: initial implementation
struct BrowseArchivalCollectionLevel: View {
    let vm: BrowserViewModel
    let collectionId: String

    @Environment(AppState.self) private var appState

    var body: some View {
        if let record = CollectionAuthorityStore.shared?.record(id: collectionId) {
            // The detail carries its OWN List and navigation title — mounted directly,
            // never wrapped in another List.
            CollectionDetailView(record: record, onOpenVolumeInPlace: { [vm] volumeId in
                if let entry = appState.manifestStore.entry(forVolumeId: volumeId) {
                    vm.navigationPath.append(.volume(entry))
                    #if DEBUG
                    print("[BrowseArchivalCollectionLevel] In-place volume push: \(volumeId)")
                    #endif
                }
            })
        } else {
            ContentUnavailableView(
                String(localized: "browser.archives.collection.unavailable.title",
                       defaultValue: "Collection Unavailable"),
                systemImage: "archivebox",
                description: Text(String(
                    localized: "browser.archives.collection.unavailable.detail",
                    defaultValue: "This collection is not in the bundled archival authority."))
            )
        }
    }
}

#endif // os(iOS)
