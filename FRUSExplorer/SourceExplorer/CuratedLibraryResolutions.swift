// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CuratedLibraryResolution

/// One hand-curated archival destination for a presidential-library or manuscript-repository
/// citation (#355, workstream N-4).
///
/// ## Why this exists at all
/// Source Explorer resolves State Department lot files to NARA series through
/// `central-files-index.json`. For the libraries it resolves **nothing**: measured, all 438
/// library clusters in `collection-authority.json` carry `naId: nil`, and that is structural —
/// presidential libraries sit outside every NARA record group, so the record-group-filtered
/// catalogue harvest excludes them by construction. No amount of re-harvesting fixes it.
///
/// What the libraries *do* publish is a finding aid, which is the thing a researcher actually
/// needs. So the destination here is a **URL first**, with `naId` carried only where the library
/// itself publishes one — some subgroups do (the LBJ National Security File is NAID 567979,
/// Carter's White House Central File Subject File is 246607128), which is worth keeping because
/// it lets those rows reuse the NARA affordance the lot resolutions already have.
struct CuratedLibraryResolution: Codable, Sendable, Equatable, Identifiable {
    /// The finding aid's own title, as the repository prints it. Shown rather than the FRUS
    /// shorthand so the researcher can confirm they are looking at the right collection —
    /// "Matlock Files" is the citation, "Matlock, Jack F., JR.: Files, 1983-1986" is the aid.
    let title: String
    /// The finding aid. Always present; this is the point of the record.
    let url: String
    /// NARA catalogue identifier, where the repository publishes one.
    let naId: String?
    /// Why this destination, in the curator's words — shown so a researcher can judge the
    /// claim rather than trust it.
    let rationale: String?

    var id: String { url }

    /// The finding aid's URL, parsed once for `Link`/`openURL`.
    var findingAid: URL? { URL(string: url) }
    /// The NARA catalogue record, when the repository publishes an identifier.
    var catalogURL: URL? { naId.flatMap { URL(string: "https://catalog.archives.gov/id/\($0)") } }
}

// MARK: - CuratedLibraryResolutions

/// The bundled `curated-library-resolutions.json` — curated destinations keyed by repository,
/// collection, and **optionally a sub-collection** (#355 / N-4).
///
/// ## Why a sub-collection level is needed, and why only sometimes
/// A citation names more than the app's level-1 authority key keeps. Measured over the corpus:
///
/// - **Carter Library / National Security Affairs** — 3,591 documents that split
///   `Brzezinski Material` 2,065 (57.5%) and `Staff Material` 1,444 (40.2%), 97.7% in two
///   branches the library describes with two different finding aids. One link for the row would
///   be right for at most 57% of it.
/// - **Library of Congress / Manuscript Division** — 958 documents naming **12 distinct
///   personal-papers collections** (Kissinger 745, Harriman 54, Harold Brown 30 …). The row is
///   not a collection at all; it is the division that holds them.
///
/// Elsewhere the level-1 key is the collection, and a sub-collection entry would be noise. So
/// the sub-collection is **optional**, and `resolution(repository:collection:subCollection:)`
/// prefers the more specific entry — never falling back from a wrong specific answer to a
/// vaguer one, only from *no* specific answer.
///
/// ## Why a separate artifact
/// The same reasoning as `CuratedLotResolutions` (#669) and `LotClaimantsIndex` (#675): the
/// generated bundles are rebuilt wholesale by their harvests, so anything hand-curated that
/// lived inside one would be deleted by the next routine regeneration. Hand curation gets its
/// own file, read alongside them.
///
/// Version history:
///   1.0 — Session 2026-08-06: #355 / N-4, seeded with Carter and the Library of Congress
struct CuratedLibraryResolutions: Codable, Sendable {
    /// Bumped when the entry shape changes.
    let schemaVersion: Int
    /// Curation date (`YYYY-MM-DD`).
    let generated: String
    /// Why the file exists.
    let note: String?
    /// The curated entries.
    let entries: [Entry]

    /// One curated destination and the citation shape it answers.
    struct Entry: Codable, Sendable, Equatable {
        /// The canonical repository (`CollectionKeying.canonicalRepository` form).
        let repository: String
        /// The level-1 collection segment, as the citation writes it.
        let collection: String
        /// The level-2 segment, when the destination depends on it. `nil` means the entry
        /// answers the whole collection.
        let subCollection: String?
        /// Other spellings of `subCollection` the corpus writes — including misspellings, which
        /// are real: the Carter citations include `Brzezinksi` and `Brzezinsky`.
        let subCollectionAliases: [String]?
        /// The curated destination.
        let resolution: CuratedLibraryResolution
    }

    /// Entries indexed by their normalized `(repository, collection)` pair, built once.
    private var byCollection: [String: [Entry]] {
        Dictionary(grouping: entries) { Self.collectionKey($0.repository, $0.collection) }
    }

    /// The curated destination for a citation, or `nil`.
    ///
    /// Prefers a sub-collection match; falls back to a collection-wide entry only when no
    /// sub-collection entry matches. A collection whose entries are *all* sub-collection-keyed
    /// deliberately resolves to nothing for an unrecognized sub-collection — the Library of
    /// Congress row has no honest whole-row answer, and inventing one would be the
    /// repository-level link this work exists to remove.
    func resolution(repository: String?, collection: String,
                    subCollection: String?) -> CuratedLibraryResolution? {
        let candidates = byCollection[Self.collectionKey(repository, collection)] ?? []
        guard !candidates.isEmpty else { return nil }
        if let sub = subCollection?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty {
            let norm = CollectionKeying.segmentNorm(sub)
            if let hit = candidates.first(where: { entry in
                guard let entrySub = entry.subCollection else { return false }
                if CollectionKeying.segmentNorm(entrySub) == norm { return true }
                return (entry.subCollectionAliases ?? [])
                    .contains { CollectionKeying.segmentNorm($0) == norm }
            }) { return hit.resolution }
        }
        return candidates.first { $0.subCollection == nil }?.resolution
    }

    /// The lookup key for a `(repository, collection)` pair, through the shared normalizers so
    /// a curated entry matches the same spellings the authority keying merges.
    static func collectionKey(_ repository: String?, _ collection: String) -> String {
        CollectionKeying.normalized(CollectionKeying.canonicalRepository(repository) ?? "")
            + "|" + CollectionKeying.segmentNorm(collection)
    }
}

// MARK: - CuratedLibraryResolutionsStore

/// Loads the bundled curated library resolutions once, mirroring `CuratedLotResolutionsStore`.
///
/// Version history:
///   1.0 — Session 2026-08-06: #355 / N-4
enum CuratedLibraryResolutionsStore {

    /// The bundled entries, or `nil` when the resource is missing or malformed — in which case
    /// the app degrades to the repository-level fallback, which is vague but not wrong.
    static let shared: CuratedLibraryResolutions? = load()

    private static func load() -> CuratedLibraryResolutions? {
        guard let url = Bundle.main.url(forResource: "curated-library-resolutions",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CuratedLibraryResolutionsStore: curated-library-resolutions.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(CuratedLibraryResolutions.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] CuratedLibraryResolutionsStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Sub-collection extraction

extension CuratedLibraryResolutions {

    /// The level-2 segment of a citation — the one after the collection — or `nil`.
    ///
    /// The per-document parse keeps only the level-1 collection, and the authority artifact's
    /// `children` are volume-grain vocabulary with no document linkage, so neither can answer
    /// "which sub-collection is *this* citation in". It has to come back out of the note.
    ///
    /// Box and folder locators are refused: `Carter Library, Plains File, Box 17` names no
    /// sub-collection, and treating `Box 17` as one would key every document separately.
    static func subCollection(inNote note: String, afterCollection collection: String) -> String? {
        let segments = SourceNoteParser.citationSentence(of: note)
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let target = CollectionKeying.segmentNorm(collection)
        guard let index = segments.firstIndex(where: {
            CollectionKeying.segmentNorm($0) == target
        }), index + 1 < segments.count else { return nil }
        let candidate = segments[index + 1]
        guard candidate.range(of: #"^(Box|Boxes|Folder|Reel|Container|Lot)\b"#,
                              options: [.regularExpression, .caseInsensitive]) == nil,
              !candidate.isEmpty else { return nil }
        return candidate
    }
}
