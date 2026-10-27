// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `ArchivalResolver` (FRUS Explorer Light, S18b): what reads the app's bundled indexes
// through their stores, and the front-matter resolution, which also reads the presidential-library
// catalogue. The document resolution, the three indexes and `ArchivalIndexes` are FRUSCoreKit's
// (`FRUSCoreKit/SourceExplorer/ArchivalResolver.swift`).

extension ArchivalResolver {

    /// The resolution for a **volume front-matter Sources node**: its lot, else its
    /// record-group header.
    ///
    /// The record-group branch belongs here and only here. A front-matter node *is* a
    /// collection — "General Records of the Department of State" is a fair answer to a row
    /// that names nothing more specific — and this is the surface volume-sources' 31 headers
    /// were harvested from in the first place.
    ///
    /// - Parameters:
    ///   - recordGroup: The node's record group. `volume_sources` stores these bare (measured:
    ///     0 of 7,374 rows carry the parser's `"RG-"` prefix), which is the form the map is
    ///     keyed by; `bareRG` normalizes anyway so the entry point cannot be form-sensitive.
    ///   - lotFile: The raw lot citation (`"63 D 135"`, `"Lot 61–D 146"`); normalized by the
    ///     indexes themselves.
    ///   - centralFiles: The central-files index. Injected so tests drive the real precedence.
    ///   - volumeSources: The volume-sources index, supplying both the lot fallback and the
    ///     record-group branch.
    static func frontMatterResolution(recordGroup: String?,
                                      lotFile: String?,
                                      entryText: String,
                                      repository: String? = nil,
                                      centralFiles: CentralFilesIndex?,
                                      volumeSources: VolumeSourcesIndex?,
                                      claimants: LotClaimantsIndex? = nil) -> ArchivalResolution? {
        if let lotHit = lotResolution(lotFile, centralFiles, volumeSources, claimants) {
            return lotHit
        }
        guard (lotFile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty else {
            return nil   // the lot-only rule
        }
        // #668: a presidential-library collection, from the catalogue #681 harvested. This
        // surface never asked it — the bundle was wired into Source Explorer's *document*
        // route in #710 and nowhere else — so `John Foster Dulles Papers` and `James C.
        // Hagerty Papers` sat unresolved under `Dwight D. Eisenhower Library` while their
        // records (NAIDs 580942 and 581740) were sitting in the shipped bundle. Tried before
        // the record-group branch because it answers the row itself, where that branch answers
        // the record group the row sits in.
        if let libraryHit = libraryResolution(repository: repository, entryText: entryText) {
            return libraryHit
        }
        // The row must NAME the record group, not merely sit under one. `volume_sources`
        // stores the inherited value on every descendant, so without this a descriptive line
        // like "Reference works, visual materials, transcripts of oral histories…" borrows its
        // ancestor's link — and where the ancestor is the wrong record group, so is the link.
        guard let named = CollectionKeying.recordGroupNamedIn(entryText),
              let stored = CollectionKeying.bareRG(recordGroup),
              CollectionKeying.bareRG(named) == stored
        else { return nil }
        return volumeSources?.resolution(recordGroup: stored, lotFile: nil)
    }

    /// The bundled presidential-library catalogue's answer for a front-matter row, or `nil`.
    ///
    /// Routed through `PresidentialLibraryIndex.match`, the same matcher #710 uses, rather
    /// than a title comparison written here — and the reason is a real case in the corpus.
    /// frus1952-54Guat cites `Ann Whitman File`, the common name for the Eisenhower Papers as
    /// President; the catalogue separately holds `Ann C. Whitman Papers`, a different body of
    /// records. `titlesAgree` requires equality after normalisation or a segment-boundary tail
    /// match, so it refuses that pair — and a looser rule written for this surface would have
    /// handed a researcher a real NARA record for the wrong papers.
    ///
    /// Only a **collection-level** hit resolves. The row names a collection, so a series
    /// candidate list is not an answer to it, and `match` returns `.none` when more than one
    /// collection answers to the name.
    static func libraryResolution(repository: String?, entryText: String,
                                  index: PresidentialLibraryIndex?
                                    = PresidentialLibraryIndexStore.shared) -> ArchivalResolution? {
        guard let index, let repository, !repository.isEmpty,
              case .collection(let hit, _) = index.match(repository: repository,
                                                         collection: entryText, series: nil),
              let url = hit.catalogURL
        else { return nil }
        return ArchivalResolution(naId: String(hit.naId), catalogURL: url.absoluteString,
                                  title: hit.title, recordGroup: nil, matchType: "library",
                                  hmsMlrEntryNumbers: nil, levelOfDescription: "collection",
                                  seriesNaId: nil, seriesTitle: nil,
                                  seriesHmsMlrEntryNumbers: nil)
    }

    /// Whether the bundled claimants index says NARA divided this lot across several series.
    ///
    /// Exposed so a surface can say *why* a lot carries no catalogue link — "NARA divides this
    /// lot across N series" is a fact worth printing, and without this the only signal is the
    /// same `nil` an unresolvable lot produces. The trip packet reaches the claimants directly
    /// for its restriction line and does not need this; the Collections export block does.
    static func dividedLotClaimants(lotFile: String?,
                                    claimants: LotClaimantsIndex?
                                      = LotClaimantsIndexStore.shared) -> [LotClaimant]? {
        let lot = lotFile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !lot.isEmpty else { return nil }
        return claimants?.claimants(forRawLot: lot)
    }

    /// ``frontMatterResolution(recordGroup:lotFile:centralFiles:volumeSources:)`` against the
    /// app's bundled indexes.
    static func frontMatterResolution(recordGroup: String?, lotFile: String?,
                                      entryText: String,
                                      repository: String? = nil) -> ArchivalResolution? {
        frontMatterResolution(recordGroup: recordGroup, lotFile: lotFile, entryText: entryText,
                              repository: repository,
                              centralFiles: CentralFilesIndexStore.shared,
                              volumeSources: VolumeSourcesIndexStore.shared,
                              claimants: LotClaimantsIndexStore.shared)
    }

    /// ``documentResolution(lotFile:centralFiles:volumeSources:)`` against the app's bundled
    /// indexes.
    static func documentResolution(lotFile: String?) -> ArchivalResolution? {
        documentResolution(lotFile: lotFile,
                           centralFiles: CentralFilesIndexStore.shared,
                           volumeSources: VolumeSourcesIndexStore.shared,
                           claimants: LotClaimantsIndexStore.shared)
    }
}

// MARK: - ArchivalIndexes.bundled

extension ArchivalIndexes {

    /// The app's bundled indexes, from their three stores: what the app's Sources & Archives block and its
    /// document resolution read.
    static var bundled: ArchivalIndexes {
        ArchivalIndexes(centralFiles: CentralFilesIndexStore.shared,
                        volumeSources: VolumeSourcesIndexStore.shared,
                        claimants: LotClaimantsIndexStore.shared)
    }
}
