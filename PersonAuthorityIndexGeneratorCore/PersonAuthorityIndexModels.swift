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
///
/// `apart` (#1767) lists the anchors that belong to no reconciled person, so that the app's
/// clusterer never joins them to one by name. A file without the key reads as one listing none.
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
    /// `volumeId → [ref]`, refs sorted: the anchors a correction holds apart that no source, join or
    /// assignment answered (`PersonAuthorityIndexBuilder.apartAnchors`), or `nil` when there are none,
    /// so that a run without the overlay writes the file it always did.
    public let apart: [String: [String]]?

    public init(version: Int, generated: String, source: String,
                crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry],
                apart: [String: [String]]? = nil) {
        self.version = version
        self.generated = generated
        self.source = source
        self.crosswalk = crosswalk
        self.authority = authority
        self.apart = apart
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
    /// Short role text (schema v2), cut to `ROLE_CHAR_LIMIT` at a word boundary and marked with an
    /// ellipsis when it did not fit (`truncatedRole(_:limit:)`, #1370). Display only.
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
                       r: r ?? role.map { Self.truncatedRole($0, limit: roleLimit) })
    }

    /// `role`, cut to at most `limit` characters at the last word that fits and marked with an
    /// ellipsis; `role` unchanged when it already fits (#1370).
    ///
    /// The ellipsis counts toward `limit`, so `ROLE_CHAR_LIMIT` stays the bundle-size budget it was.
    /// The kept prefix ends on a word when the character after it is not a letter or digit;
    /// otherwise the cut moves back to the last whitespace, and the separators that would then end
    /// the line (", ", "; ", "–") go with it. A single word longer than the budget is still cut
    /// hard, since there is no boundary to move back to.
    ///
    /// The old cut was `prefix(limit)`: 1,949 of the 12,811 shipped roles were exactly 120
    /// characters and ended mid-word with nothing to say so — "…Prime Minister and Minister of
    /// Defense, Apr".
    public static func truncatedRole(_ role: String, limit: Int) -> String {
        guard role.count > limit else { return role }
        guard limit > 1 else { return "…" }
        let head = role.prefix(limit - 1)
        let next = role[head.endIndex]
        var kept = Substring(head)
        if next.isLetter || next.isNumber,
           let lastSpace = head.lastIndex(where: { $0.isWhitespace }) {
            kept = head[..<lastSpace]
        }
        let trailing: Set<Character> = [",", ";", ":", "–", "—", "-", "(", "["]
        while let last = kept.last, last.isWhitespace || trailing.contains(last) {
            kept.removeLast()
        }
        return (kept.isEmpty ? Substring(head) : kept) + "…"
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
    /// The text of each of the record's remarks, its whitespace collapsed, in the record's order (#1767).
    /// The registry writes a remark with the anchors it came from, so these are this person's own roles.
    public let remarks: [String]
    /// The record's alternate names (`names/alternates/name`), its whitespace collapsed (#1767).
    public let alternateNames: [String]

    public init(canonicalId: Int, name: String, birthYear: Int?, deathYear: Int?,
                viaf: String?, pocomSlug: String? = nil, frusAnchors: [FRUSAnchor],
                remarks: [String] = [], alternateNames: [String] = []) {
        self.canonicalId = canonicalId
        self.name = name
        self.birthYear = birthYear
        self.deathYear = deathYear
        self.viaf = viaf
        self.pocomSlug = pocomSlug
        self.frusAnchors = frusAnchors
        self.remarks = remarks
        self.alternateNames = alternateNames
    }
}

// MARK: - RegistryFacts

/// What the overlay pass reads of a registry record beyond its ``AuthorityEntry`` (#1767): its remarks and
/// alternate names, which the bundle does not carry, and the year of its earliest FRUS volume.
///
/// The identifier rule tests an item against all three (``PersonIdentifierRule/Record``), and a role text
/// of an entry carrying several people goes only to the records whose remarks hold it
/// (``remarksHold(_:)``).
public struct RegistryFacts: Sendable, Equatable {
    /// The record's remarks.
    public let remarks: [String]
    /// The record's alternate names.
    public let alternateNames: [String]
    /// The year of the record's earliest FRUS volume, every anchor of the registry's counted, a volume
    /// that is not a year's (Public Diplomacy) not; `nil` when it has none.
    public let firstVolumeYear: Int?

    /// Creates the facts.
    public init(remarks: [String], alternateNames: [String] = [], firstVolumeYear: Int? = nil) {
        self.remarks = remarks
        self.alternateNames = alternateNames
        self.firstVolumeYear = firstVolumeYear
    }

    /// A registry record's facts.
    public init(record: PersonAuthorityRecord) {
        self.init(remarks: record.remarks, alternateNames: record.alternateNames,
                  firstVolumeYear: record.frusAnchors.compactMap { Self.year(ofVolume: $0.volumeId) }.min())
    }

    /// Whether one of the remarks holds `role`, the entry's role text as
    /// ``PersonsCompleteOverlay/roleText(from:)`` takes it, with case, accents, dashes and runs of spaces
    /// folded, and the full stops, commas and semicolons that open or close it set aside (#1767, item 2).
    public func remarksHold(_ role: String) -> Bool {
        let wanted = Self.folded(role)
        guard !wanted.isEmpty else { return false }
        return remarks.contains { Self.folded($0).contains(wanted) }
    }

    /// The year a volume id opens with (`frus1961-63v14` → 1961), or `nil` for a Public Diplomacy volume.
    static func year(ofVolume volumeId: String) -> Int? {
        guard !volumeId.contains("PubDip"), volumeId.hasPrefix("frus") else { return nil }
        let digits = volumeId.dropFirst(4).prefix(4)
        guard digits.count == 4, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(digits)
    }

    /// `text` folded, each run of spaces and dashes one space, and " .;," trimmed from its ends.
    static func folded(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        var inGap = false
        for scalar in AuthorityText.fold(text).unicodeScalars {
            if scalar.properties.isWhitespace || scalar == "-" || ("\u{2010}"..."\u{2015}").contains(scalar) {
                if !inGap { out.append(" ") }
                inGap = true
            } else {
                out.append(scalar)
                inGap = false
            }
        }
        let trimmed = Set<Unicode.Scalar>([" ", ".", ";", ","])
        var scalars = Array(out)
        while let first = scalars.first, trimmed.contains(first) { scalars.removeFirst() }
        while let last = scalars.last, trimmed.contains(last) { scalars.removeLast() }
        return String(String.UnicodeScalarView(scalars))
    }
}

/// A FRUS person anchor decoded from a `…/historicaldocuments/{volume}/persons#{ref}` source URL.
public struct FRUSAnchor: Sendable, Hashable {
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
    /// Overlay anchors a correction holds apart from the entry's people-ids (#1657), in kept volumes.
    public var overlayAnchorsHeldApart = 0
    /// Overlay identifiers, Wikidata or VIAF, a correction kept off the entry's people-ids (#1657).
    public var overlayIdentifiersWithheld = 0
    /// Overlay entries whose role text a correction kept off the entry's people-ids.
    public var overlayRolesWithheld = 0
    /// Wikidata and VIAF ids of entries reaching a registry record that were not stamped, because the
    /// run takes none of the overlay's identifiers (decision 55, `Overlay.takesIdentifiers`).
    public var overlayIdentifiersNotTaken = 0
    /// Overlay ids the identifier rule kept off a record (#1767), each with why: one a record and id.
    public var identifiersWithheldByRule: [WithheldIdentifier] = []
    /// Role texts of entries carrying several people kept off a record whose remarks do not hold them
    /// (#1767, item 2): one an entry and record.
    public var multiPersonRolesKeptOff = 0
    /// Held-apart anchors that joined the registry record their correction names.
    public var overlayAnchorsJoined = 0
    /// Anchors the corrections file assigns to a registry record, written where no source answered.
    public var anchorsAssigned = 0
    /// Registry records with no anchor in a kept volume, kept because a join or an assignment named
    /// them and placed an anchor (#1767).
    public var recordsKeptForAJoin = 0
    /// Held-apart anchors in kept volumes that nothing answered, written to the index's `apart`.
    public var anchorsStandingApart = 0
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

// MARK: - WithheldIdentifier

/// An overlay Wikidata or VIAF id the identifier rule kept off a registry record (#1767), and why.
///
/// The runner prints every one, as it prints the crosswalk's disagreements: the rule's word lists and
/// thresholds decide them, and a change to either is read in this list.
public struct WithheldIdentifier: Sendable, Equatable {
    /// Which kind of id.
    public enum Kind: String, Sendable, Equatable {
        case wikidata = "Wikidata"
        case viaf = "VIAF"
    }

    /// The record's people-id.
    public let peopleId: String
    /// The record's name in the registry.
    public let name: String
    /// Which kind of id.
    public let kind: Kind
    /// The id.
    public let identifier: String
    /// The tests it failed, or what it lacked (``PersonIdentifierRule/Decision/reason``).
    public let reason: String

    public init(peopleId: String, name: String, kind: Kind, identifier: String, reason: String) {
        self.peopleId = peopleId
        self.name = name
        self.kind = kind
        self.identifier = identifier
        self.reason = reason
    }
}
