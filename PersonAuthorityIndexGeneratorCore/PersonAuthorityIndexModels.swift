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
/// JSON keys are deliberately terse (`n`/`b`/`d`/`v`/`s`/`q`/`r`) to keep the bundled file
/// compact; the crosswalk is nested `volumeId → ref → canonicalId` so a `(volume, ref)` lookup is
/// two hops.
///
/// Schema v2 (#736) adds the POCOM slug, Wikidata QID and role text, and expands the crosswalk
/// from the `frus-name-authority` drop.
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

/// A canonical person: preferred name, life years, and whatever external identifiers upstream
/// has reconciled.
///
/// Every field but `n` is optional and omitted when absent — `AuthorityEntry` is repeated 12,836
/// times in the bundled file, so a null costs more than it says.
public struct AuthorityEntry: Codable, Sendable, Equatable {
    /// Preferred display name ("Surname, Given").
    public let n: String
    /// Birth year, if known.
    public let b: Int?
    /// Death year, if known.
    public let d: Int?
    /// VIAF authority id, if reconciled.
    public let v: String?
    /// POCOM slug (schema v2) — the key into `pocom-index.json`'s career records.
    public let s: String?
    /// Wikidata QID (schema v2), e.g. `Q58156`.
    public let q: String?
    /// Short role text (schema v2), truncated. Display only.
    public let r: String?

    public init(n: String, b: Int?, d: Int?, v: String?,
                s: String? = nil, q: String? = nil, r: String? = nil) {
        self.n = n
        self.b = b
        self.d = d
        self.v = v
        self.s = s
        self.q = q
        self.r = r
    }

    /// A copy carrying the overlay's identifiers where this entry has none.
    ///
    /// The registry wins on every field it already has. The overlay is a *different* upstream
    /// pipeline with 1,662 unreviewed auto-merges in it, so it fills gaps rather than
    /// overwriting a value the reconciled registry asserted.
    public func merging(viaf: String?, wikidata: String?, role: String?,
                        roleLimit: Int) -> AuthorityEntry {
        AuthorityEntry(n: n, b: b, d: d,
                       v: v ?? viaf, s: s, q: q ?? wikidata,
                       r: r ?? role.map { String($0.prefix(roleLimit)) })
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
    /// POCOM slug decoded from a `departmenthistory/people/{slug}` source-url, if the record has
    /// one. Schema v2 — the previous builder read these URLs and threw them away.
    public let pocomSlug: String?
    /// FRUS person anchors mapping to this identity, as `(volumeId, ref)` pairs.
    public let frusAnchors: [FRUSAnchor]

    public init(canonicalId: Int, name: String, birthYear: Int?, deathYear: Int?,
                viaf: String?, pocomSlug: String? = nil, frusAnchors: [FRUSAnchor]) {
        self.canonicalId = canonicalId
        self.name = name
        self.birthYear = birthYear
        self.deathYear = deathYear
        self.viaf = viaf
        self.pocomSlug = pocomSlug
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
    /// Schema v2 (#736) — overlay and expansion outcomes.
    public var withPOCOMSlug = 0
    public var withWikidata = 0
    public var withRole = 0
    public var overlayEntriesRead = 0
    public var overlayEntriesSkippedByAudit = 0
    public var crosswalkPairsAdded = 0
    public var crosswalkVolumesAdded = 0
    /// Anchors both sources name where the people-ids disagree. The registry keeps its answer;
    /// these are listed for review rather than silently resolved.
    public var crosswalkConflicts: [CrosswalkConflict] = []
    /// People-ids the overlay's new anchors reach that the registry has no entry for.
    public var unknownOverlayIds: Set<String> = []
    public init() {}
}

// MARK: - CrosswalkConflict

/// One `(volume, ref)` anchor the registry and the overlay resolve to different people.
///
/// A named struct rather than a tuple so `BuildStats` can stay `Equatable` — and because these are
/// meant to be read: the runner prints every one, since the acceptance rule for the expansion is
/// that a human looks at the disagreements before the index ships.
public struct CrosswalkConflict: Sendable, Equatable {
    public let volumeId: String
    public let ref: String
    /// What the `HistoryAtState/people` registry says. This is what the index keeps.
    public let registry: Int
    /// What `persons-complete.xml` says, as text — it may not be an id the registry knows.
    public let overlay: String

    public init(volumeId: String, ref: String, registry: Int, overlay: String) {
        self.volumeId = volumeId
        self.ref = ref
        self.registry = registry
        self.overlay = overlay
    }
}
