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
/// elements; a 4,293-note gap, two questions, neither wrong), and never the corpus's
/// 314,483 document divs. The captions say so.
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
            defaultValue: "FRUS's editors printed a source note under \(coverage.noteCount) documents across \(coverage.volumesWithNotes) of \(coverage.volumesScanned) volumes — the archival record this axis browses. About \(percent)% of those notes name an archival collection; most of the rest cite a State Department central-file number. \(noteless) volumes, mostly the pre-1906 annuals, print no notes and cannot appear here."
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
                defaultValue: "\(byVolume.count) volumes with documents drawn from \(name), largest count first. Percentages are each volume's share of its own sourced documents — the notes printed under documents, not every document in the volume."),
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

    /// A provenance-type door's drill.
    let onSelectCategory: @MainActor (VolumeListSpec) -> Void
    /// A collection row's drill (the push-hosted detail).
    let onSelectCollection: @MainActor (AuthorityCollectionRecord) -> Void

    /// The two sibling lenses.
    private enum Lens: String, CaseIterable, Identifiable {
        case types, collections
        var id: String { rawValue }

        var label: String {
            switch self {
            case .types:
                return String(localized: "browser.archives.lens.types",
                              defaultValue: "Provenance Types")
            case .collections:
                return String(localized: "browser.archives.lens.collections",
                              defaultValue: "Collections")
            }
        }
    }

    @State private var lens: Lens = .types

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

            switch lens {
            case .types:
                typesList
            case .collections:
                collectionsLens
            }
        }
        .navigationTitle(String(localized: "browser.archives.title", defaultValue: "Archives"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            CollectionBrowserView(onSelect: onSelectCollection)
        }
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
