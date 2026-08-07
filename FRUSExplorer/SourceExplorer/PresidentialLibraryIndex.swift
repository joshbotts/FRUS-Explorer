// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PresidentialLibraryIndex

/// The bundled `presidential-library-catalog.json` — NARA's own description of what each
/// presidential library holds, harvested by `PresidentialLibraryCatalogGenerator` (#681).
///
/// ## What this is for
/// The library route has never had an offline answer. `central-files-index.json` does that job
/// for State Department lot files; this is its counterpart, and it lets a citation resolve to a
/// NARA identifier with no network call rather than through a free-text query nothing constrains.
///
/// ## Why matching is deliberately strict
/// The join is title against title, and FRUS writes short forms of names NARA writes in full.
/// That is fuzzy, and this project's worst defect is a confidently wrong archival link — so a
/// match is returned only when it is **unique**. Where the citation names something NARA divides
/// (FRUS cites the Johnson `Country File` undivided; NARA splits it into seven regional series),
/// the honest answer is that several series match and none is *the* answer, which is reported as
/// `.ambiguous` rather than resolved to whichever sorted first.
struct PresidentialLibraryIndex: Codable, Sendable {

    let schemaVersion: Int
    let generated: String
    let source: String
    let libraries: [Library]

    struct Library: Codable, Sendable {
        let prefix: String
        let citedAs: String
        let collections: [Collection]
    }

    struct Collection: Codable, Sendable, Equatable {
        let identifier: String
        let title: String
        let naId: Int
        let statedSeriesCount: Int?
        let series: [Series]
    }

    struct Series: Codable, Sendable, Equatable, Identifiable {
        let naId: Int
        let title: String
        let inclusiveDates: String?
        var id: Int { naId }
        /// The catalogue record for this series.
        var catalogURL: URL? { URL(string: "https://catalog.archives.gov/id/\(naId)") }
    }

    /// What the index can say about a citation.
    enum Match: Sendable, Equatable {
        /// One series in one collection — safe to present as the resolution.
        case series(Series, inCollection: Collection)
        /// The collection is identified but the cited series matches several, or none.
        /// Named so a caller cannot mistake it for an answer.
        case collection(Collection, candidates: [Series])
        /// Nothing in the index matches.
        case none
    }

    /// Resolves a parsed citation against NARA's own description.
    ///
    /// - Parameters:
    ///   - repository: as the citation writes it (`Kennedy Library`).
    ///   - collection: the level-1 segment (`National Security Files`).
    ///   - series: the level-2 segment, when the citation names one (`Countries Series`).
    /// - Parameter collectionIdentifier: NARA's own identifier for the cited collection, from
    ///   the curated table. **This is what makes the join safe.** Measured, a title join
    ///   resolves 3.3% of library documents and misses 78.5%, because FRUS writes `Whitman File`
    ///   where NARA writes *"Papers as President of the United States"* — no title rule bridges
    ///   that, and a looser one picks a plausible wrong collection for exactly the rows with the
    ///   most documents behind them. With the identifier the collection is exact, and the
    ///   remaining title match is over ~20 series inside it rather than 3,837 collections.
    func match(repository: String?, collection: String, series: String?,
               collectionIdentifier: String? = nil) -> Match {
        guard let library = library(for: repository) else { return .none }
        let collections: [Collection]
        if let collectionIdentifier {
            // An identifier that names no collection resolves to nothing rather than falling
            // back to the title guess — a wrong identifier is a curation error to surface, not
            // to paper over.
            collections = library.collections.filter { $0.identifier == collectionIdentifier }
        } else {
            collections = library.collections.filter { Self.titlesAgree($0.title, collection) }
        }
        // More than one collection answering to the name is not a resolution. It happens: 22
        // identifiers name two records each, and a citation cannot tell them apart.
        guard collections.count == 1, let hit = collections.first else { return .none }
        guard let series, !series.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .collection(hit, candidates: hit.series)
        }
        let matches = hit.series.filter { Self.titlesAgree($0.title, series) }
        if matches.count == 1, let only = matches.first {
            return .series(only, inCollection: hit)
        }
        return .collection(hit, candidates: matches.isEmpty ? hit.series : matches)
    }

    /// The library a citation's repository names.
    func library(for repository: String?) -> Library? {
        guard let repository,
              let canonical = CollectionKeying.canonicalRepository(repository) else { return nil }
        let key = CollectionKeying.normalized(canonical)
        return libraries.first { CollectionKeying.normalized($0.citedAs) == key }
    }

    /// Whether a NARA title and a cited name are the same thing.
    ///
    /// Equality on the shared normal form, or NARA's title *ending with* the cited name — NARA
    /// writes `Papers of John F. Kennedy: Presidential Papers: President's Office Files` where
    /// FRUS writes `President's Office Files`, and the citation names the tail.
    ///
    /// Containment anywhere would be too loose: `Country Files` appears inside `Vietnam Country
    /// Files`, and treating that as a match would resolve a citation to a neighbouring series.
    static func titlesAgree(_ naraTitle: String, _ cited: String) -> Bool {
        let a = CollectionKeying.segmentNorm(naraTitle)
        let b = CollectionKeying.segmentNorm(cited)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        // Tail match, on a segment boundary so `…: President's Office Files` matches but
        // `Vietnam Country Files` does not match `Country Files`.
        return a.hasSuffix(": " + b) || a.hasSuffix(" — " + b)
    }
}

// MARK: - PresidentialLibraryIndexStore

/// Loads the bundled catalogue once, mirroring the other Source Explorer stores.
enum PresidentialLibraryIndexStore {

    /// The bundled index, or `nil` when the resource is absent or malformed — in which case the
    /// app falls back to the curated finding aids and the live query, as before.
    static let shared: PresidentialLibraryIndex? = load()

    private static func load() -> PresidentialLibraryIndex? {
        guard let url = Bundle.main.url(forResource: "presidential-library-catalog",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] PresidentialLibraryIndexStore: catalog not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(PresidentialLibraryIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] PresidentialLibraryIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
