// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HarvestError

/// Fatal conditions for this harvest.
///
/// Deliberately not a case on `GeneratorKit.GeneratorError`, whose cases are about scanning the
/// TEI corpus (`noVolumes`, `missingFile`) and have nothing to do with a catalogue query.
public struct HarvestError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

// MARK: - PresidentialLibraryCatalog

/// An offline index of the NARA Catalog's presidential-library holdings, at the two levels a
/// FRUS citation names (#681).
///
/// ## Why this exists
/// `central-files-index.json` made State Department lot files resolvable without a network call.
/// The presidential libraries had no equivalent, so the library route ran a live free-text query
/// whose results nothing constrained — the defect #704 and #705 hedged rather than fixed.
///
/// The survey on #681 found the missing hook: a library collection carries a
/// `collectionIdentifier` (`LBJ-NSF`, `RR-EXSEC`), the catalogue's analogue of a record-group
/// number, and the search filter resolves it **through the ancestry**, so the series beneath a
/// collection are reachable by it even though they do not carry the field themselves.
///
/// ## Why only two levels
/// Measured across the eleven libraries FRUS draws on:
///
/// | level | records |
/// |---|---|
/// | collection | 3,837 |
/// | series | 14,656 |
/// | file unit + item | 934,144 |
///
/// FRUS cites a collection and a series (`National Security Files, Countries Series`) and never a
/// file unit, so the first two levels are the whole useful payload and the third is 98% of the
/// bytes. Harvesting all levels would turn an 18,000-record index into a million-record one that
/// answers no question the app asks.
public struct PresidentialLibraryCatalog: Codable, Sendable, Equatable {

    /// Bumped when the shape changes.
    public let schemaVersion: Int
    /// Harvest date (`YYYY-MM-DD`).
    public let generated: String
    /// Which route produced it, so a reader can tell a keyed harvest from a public-proxy one.
    public let source: String
    /// One entry per library, sorted by identifier prefix.
    public let libraries: [Library]

    public init(schemaVersion: Int, generated: String, source: String, libraries: [Library]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.source = source
        self.libraries = libraries
    }

    /// One NARA-administered presidential library.
    public struct Library: Codable, Sendable, Equatable {
        /// The `collectionIdentifier` prefix NARA uses for this library (`LBJ`, `JFK`, `RR`).
        public let prefix: String
        /// The library's name as FRUS writes it (`Johnson Library`), for keying from a citation.
        public let citedAs: String
        /// Its collections, sorted by identifier.
        public let collections: [Collection]

        public init(prefix: String, citedAs: String, collections: [Collection]) {
            self.prefix = prefix; self.citedAs = citedAs; self.collections = collections
        }
    }

    /// One collection, and the series beneath it.
    public struct Collection: Codable, Sendable, Equatable {
        /// e.g. `LBJ-NSF`.
        public let identifier: String
        /// NARA's own title.
        public let title: String
        public let naId: Int
        /// The collection record's own `seriesCount`, when NARA states one.
        ///
        /// NARA's number rather than ours, which is what makes it worth checking against.
        public let statedSeriesCount: Int?
        /// Series beneath this collection, sorted by NAID.
        public let series: [Series]

        public init(identifier: String, title: String, naId: Int,
                    statedSeriesCount: Int?, series: [Series]) {
            self.identifier = identifier; self.title = title; self.naId = naId
            self.statedSeriesCount = statedSeriesCount; self.series = series
        }

        /// Whether the harvested series match the count NARA states. `nil` when NARA states none.
        ///
        /// ## A `false` here has two causes, and only one of them is ours
        /// 1. **Our harvest paged short.** That is a defect, and it is caught earlier and harder
        ///    — see `CatalogSearchClient.streamRecords`, which throws when a level's record count
        ///    disagrees with the total the endpoint states for that level.
        /// 2. **NARA's own description is ahead of its catalogue.** A collection can state a
        ///    `seriesCount` for series that are not described in the catalogue yet.
        ///
        /// Cause 2 is real and measured. In the first keyed run, `RR-0121` (*Records of the
        /// Crisis Management Center (CMC), National Security Council*) states `seriesCount: 1`
        /// and the catalogue contains **no** record carrying `RR-0121` at any level except the
        /// collection itself — one of 103 Reagan collections. The collection is described; its
        /// contents are not catalogued.
        ///
        /// So this is **reported, never thrown**. Throwing would make the harvest unrunnable for
        /// a reason nobody in this repository can fix.
        public var isComplete: Bool? {
            statedSeriesCount.map { $0 == series.count }
        }
    }

    /// One series — the grain a FRUS collection citation actually names.
    public struct Series: Codable, Sendable, Equatable {
        public let naId: Int
        public let title: String
        /// Coverage as NARA states it, for disambiguating same-named series.
        public let inclusiveDates: String?

        public init(naId: Int, title: String, inclusiveDates: String?) {
            self.naId = naId; self.title = title; self.inclusiveDates = inclusiveDates
        }
    }
}

// MARK: - Libraries harvested

extension PresidentialLibraryCatalog {

    /// The libraries FRUS draws on, with the `collectionIdentifier` prefix each uses and the name
    /// the citations write.
    ///
    /// Measured document counts in the corpus are in the comments — the harvest covers every
    /// library with corpus presence, including the small ones, because the marginal cost of a
    /// library is a few hundred records.
    public static let harvestedLibraries: [(prefix: String, citedAs: String)] = [
        ("HH",  "Hoover Library"),        //     ~0 — included for completeness
        ("FDR", "Roosevelt Library"),     //   130
        ("HST", "Truman Library"),        //   141
        ("DDE", "Eisenhower Library"),    // 3,877
        ("JFK", "Kennedy Library"),       // 2,603
        ("LBJ", "Johnson Library"),       // 4,933
        ("RN",  "Nixon"),                 // 8,023
        ("GRF", "Ford Library"),          // 2,025
        ("JC",  "Carter Library"),        // 4,704
        ("RR",  "Reagan Library"),        // 1,912
        ("GB",  "Bush Library"),          //   108
    ]
}
