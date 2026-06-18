// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAuthorityIndex

/// The bundled person-authority index produced by `PersonAuthorityIndexGenerator`.
///
/// Built from the Office of the Historian's public-domain (CC0) `HistoryAtState/people`
/// registry, which reconciles per-volume FRUS person entries to canonical identities. The app
/// uses it to key its person rollup on authoritative ids instead of (only) heuristic clustering.
///
/// JSON keys are deliberately terse (`n`/`b`/`d`/`v`) to keep the bundled file compact; the
/// crosswalk is nested `volumeId → ref → canonicalId` so a `(volume, ref)` lookup is two hops.
public struct PersonAuthorityIndex: Codable, Sendable, Equatable {
    /// Schema version of this index file.
    public let version: Int
    /// ISO date the index was generated (yyyy-MM-dd).
    public let generated: String
    /// Provenance string (the upstream repo + license).
    public let source: String
    /// `volumeId → (ref → canonicalId)` crosswalk over FRUS person anchors only.
    public let crosswalk: [String: [String: Int]]
    /// `"canonicalId" → entry` for every canonical person referenced by the crosswalk.
    public let authority: [String: AuthorityEntry]

    public init(version: Int, generated: String, source: String,
                crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry]) {
        self.version = version
        self.generated = generated
        self.source = source
        self.crosswalk = crosswalk
        self.authority = authority
    }
}

// MARK: - AuthorityEntry

/// A canonical person: preferred name, optional birth/death years, and an optional VIAF id.
public struct AuthorityEntry: Codable, Sendable, Equatable {
    /// Preferred display name ("Surname, Given").
    public let n: String
    /// Birth year, if known.
    public let b: Int?
    /// Death year, if known.
    public let d: Int?
    /// VIAF authority id, if reconciled.
    public let v: String?

    public init(n: String, b: Int?, d: Int?, v: String?) {
        self.n = n
        self.b = b
        self.d = d
        self.v = v
    }
}

// MARK: - PersonAuthorityRecord

/// One parsed `people/data` record: a canonical identity plus the FRUS `(volume, ref)` anchors
/// that resolve to it. Intermediate value used while building the index.
public struct PersonAuthorityRecord: Sendable, Equatable {
    /// Canonical numeric id (e.g. 107252).
    public let canonicalId: Int
    /// Preferred display name.
    public let name: String
    public let birthYear: Int?
    public let deathYear: Int?
    public let viaf: String?
    /// FRUS person anchors mapping to this identity, as `(volumeId, ref)` pairs.
    public let frusAnchors: [FRUSAnchor]

    public init(canonicalId: Int, name: String, birthYear: Int?, deathYear: Int?,
                viaf: String?, frusAnchors: [FRUSAnchor]) {
        self.canonicalId = canonicalId
        self.name = name
        self.birthYear = birthYear
        self.deathYear = deathYear
        self.viaf = viaf
        self.frusAnchors = frusAnchors
    }
}

/// A FRUS person anchor decoded from a `…/historicaldocuments/{volume}/persons#{ref}` source URL.
public struct FRUSAnchor: Sendable, Equatable {
    public let volumeId: String
    public let ref: String
    public init(volumeId: String, ref: String) {
        self.volumeId = volumeId
        self.ref = ref
    }
}

// MARK: - BuildStats

/// Summary statistics emitted after a build, for the console report.
public struct BuildStats: Sendable, Equatable {
    public var recordsParsed = 0
    public var recordsWithFRUSAnchors = 0
    public var crosswalkEntries = 0
    public var distinctVolumes = 0
    public var withViaf = 0
    public init() {}
}
