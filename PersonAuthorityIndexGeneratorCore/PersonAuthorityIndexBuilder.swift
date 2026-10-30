// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAuthorityIndexBuilder

/// Parses `HistoryAtState/people` record XML into the bundled `PersonAuthorityIndex`.
///
/// Each record aggregates the per-volume FRUS `persName` anchors (`<source-url>` of the form
/// `…/historicaldocuments/{volume}/persons#{ref}`) that refer to one human, under one canonical
/// `<id>`. The builder keeps only the FRUS anchors (the app's corpus) and the canonical metadata
/// (preferred name, birth/death years, VIAF). Pure and file-system-light: `parseRecord(xml:)` works
/// on a string for testability; `build(dataDirectory:…)` walks a checkout.
public enum PersonAuthorityIndexBuilder {

    /// Matches a FRUS persons-page anchor and captures `(volume, ref)`.
    /// e.g. `https://history.state.gov/historicaldocuments/frus1961-63v14/persons#p_KHA1`.
    private static let frusAnchor = try! NSRegularExpression(
        pattern: #"historicaldocuments/(frus[^/]+)/persons#(.+)$"#)

    /// Matches the registry's link to a person's POCOM page and captures the slug
    /// (`…/departmenthistory/people/acheson-dean-gooderham`).
    ///
    /// These URLs sit in the same `<source-url>` list as the FRUS anchors, and until schema v2
    /// this builder read them and threw them away — which is why the app had no career data
    /// despite the crosswalk it needed being one capture group wide.
    private static let pocomAnchor = try! NSRegularExpression(
        pattern: #"departmenthistory/people/([A-Za-z0-9\-]+)"#)

    // MARK: - Single record

    /// Parses one record's XML. Returns `nil` when the record has no numeric id or no FRUS anchor
    /// (e.g. a person known only from Visits/Principals, outside the app's corpus).
    public static func parseRecord(xml: String) throws -> PersonAuthorityRecord? {
        guard let record = try parseRegistryRecord(xml: xml), !record.frusAnchors.isEmpty else { return nil }
        return record
    }

    /// Parses one record's XML whether or not it has a FRUS anchor, for the registry's names and the
    /// records a join or an assignment may keep (#1767). Returns `nil` when the record has no
    /// numeric id.
    static func parseRegistryRecord(xml: String) throws -> PersonAuthorityRecord? {
        let doc = try XMLDocument(xmlString: xml, options: [])
        guard let root = doc.rootElement() else { return nil }

        guard let idText = root.firstChildText("id"), let canonicalId = Int(idText) else { return nil }

        let sourceURLs = root.descendantTexts("source-url")
        let anchors = sourceURLs.compactMap(parseAnchor(_:))
        let slug = sourceURLs.compactMap(parsePOCOMSlug(_:)).first

        let name = root.elements(forName: "names").first?
            .elements(forName: "preferred").first?
            .firstChildText("name")?.trimmed ?? ""

        let birth = root.firstChildText("birth-year").flatMap { Int($0.trimmed) }
        let death = root.firstChildText("death-year").flatMap { Int($0.trimmed) }

        var viaf: String?
        if let authorities = root.elements(forName: "authorities").first {
            for a in authorities.elements(forName: "authority") where a.attribute(forName: "service")?.stringValue == "viaf" {
                if let v = a.stringValue?.trimmed, !v.isEmpty { viaf = v }
            }
        }

        return PersonAuthorityRecord(canonicalId: canonicalId, name: name,
                                     birthYear: birth, deathYear: death, viaf: viaf,
                                     pocomSlug: slug, frusAnchors: anchors)
    }

    /// Decodes a single `source-url` into a FRUS `(volume, ref)` anchor, or `nil` if it isn't one.
    public static func parseAnchor(_ url: String) -> FRUSAnchor? {
        let s = url.trimmed
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = frusAnchor.firstMatch(in: s, range: range),
              let volRange = Range(m.range(at: 1), in: s),
              let refRange = Range(m.range(at: 2), in: s) else { return nil }
        let ref = String(s[refRange]).trimmed
        guard !ref.isEmpty else { return nil }
        return FRUSAnchor(volumeId: String(s[volRange]), ref: ref)
    }

    /// Decodes a POCOM slug out of a `departmenthistory/people/{slug}` source-url, or `nil`.
    public static func parsePOCOMSlug(_ url: String) -> String? {
        let s = url.trimmed
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = pocomAnchor.firstMatch(in: s, range: range),
              let slugRange = Range(m.range(at: 1), in: s) else { return nil }
        let slug = String(s[slugRange])
        return slug.isEmpty ? nil : slug
    }

    // MARK: - Full build

    /// What an overlay pass contributes, and the rules it runs under.
    public struct Overlay: Sendable {
        /// Parsed `persons-complete.xml` entries.
        public let entries: [PersonsCompleteOverlay.Entry]
        /// People-ids to enrich from **no** entry — resolved from `merge_audit_report.csv`.
        public let flaggedPeopleIds: Set<String>
        /// Longest role text to keep. The lever for the bundle-size budget.
        public let roleCharacterLimit: Int
        /// Entries that merge two people, and what of each to hold apart (#1657):
        /// `PersonsCompleteCorrections`.
        public let corrections: [PersonsCompleteCorrections.HeldApart]
        /// Whether the entries' Wikidata and VIAF ids are stamped on the registry's records.
        ///
        /// `false` unless a caller asks, and the runner never does (plan of record decision 55,
        /// 2026-10-17). About 1,600 of the 3,769 Wikidata ids the overlay gave the bundle named
        /// someone else, and so did about 580 of the 2,186 of its VIAF ids that could be checked
        /// (`Planning/Person-Authority-Identifier-Assessment-2026-10-17.md`). The entries' role text
        /// and anchors still apply, and the registry's own VIAF ids are the registry's. The path stays
        /// for the rule that is to check each id against its record before it is taken.
        public let takesIdentifiers: Bool
        /// Anchors no source answers, and the registry records they belong to (#1767):
        /// `PersonsCompleteCorrections.Assigned`.
        public let assigned: [PersonsCompleteCorrections.Assigned]

        public init(entries: [PersonsCompleteOverlay.Entry],
                    flaggedPeopleIds: Set<String>,
                    roleCharacterLimit: Int = 120,
                    corrections: [PersonsCompleteCorrections.HeldApart] = [],
                    takesIdentifiers: Bool = false,
                    assigned: [PersonsCompleteCorrections.Assigned] = []) {
            self.entries = entries
            self.flaggedPeopleIds = flaggedPeopleIds
            self.roleCharacterLimit = roleCharacterLimit
            self.corrections = corrections
            self.takesIdentifiers = takesIdentifiers
            self.assigned = assigned
        }
    }

    /// Builds the index from a directory of record XML files (recursively).
    ///
    /// `keepVolume` lets the caller restrict the crosswalk to known volumes (e.g. those in the app
    /// manifest); pass `nil` to keep all FRUS volumes.
    ///
    /// `overlay` applies the `frus-name-authority` drop (#736 / #260): role text onto existing
    /// entries, their Wikidata and VIAF ids only when `Overlay.takesIdentifiers` (no shipped run,
    /// decision 55), and additional crosswalk anchors. It runs **after** the registry pass, so
    /// the registry always wins a disagreement — the overlay is a different pipeline carrying
    /// 1,662 unreviewed auto-merges, and it fills gaps rather than overwriting reconciled answers.
    /// The overlay's assignments are written after it (`applyAssignments`), and the anchors its
    /// corrections hold apart that nothing answered are the index's `apart` (#1767).
    ///
    /// - Throws: `PersonsCompleteCorrections.Problem` when one of the overlay's corrections does not
    ///   fit the registry or the overlay (#1657), before anything is applied, or when an assignment
    ///   does not fit them (#1767); or a read error.
    public static func build(dataDirectory: URL, version: Int, generated: String,
                             source: String, keepVolume: ((String) -> Bool)? = nil,
                             overlay: Overlay? = nil)
    throws -> (index: PersonAuthorityIndex, stats: BuildStats) {
        var stats = BuildStats()
        var crosswalk: [String: [String: Int]] = [:]
        var authority: [String: AuthorityEntry] = [:]
        // Every record, with or without an anchor in a kept volume: the names a correction is
        // checked against, and the records a join or an assignment may keep (#1767).
        var registry: [String: AuthorityEntry] = [:]

        let fm = FileManager.default
        let enumerator = fm.enumerator(at: dataDirectory, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "xml" else { continue }
            guard let data = try? Data(contentsOf: url),
                  let xml = String(data: data, encoding: .utf8) else { continue }
            stats.recordsParsed += 1
            guard let record = try? parseRegistryRecord(xml: xml) else { continue }
            let entry = AuthorityEntry(
                n: record.name, b: record.birthYear, d: record.deathYear, v: record.viaf,
                s: record.pocomSlug)
            registry[String(record.canonicalId)] = entry

            let kept = record.frusAnchors.filter { keepVolume?($0.volumeId) ?? true }
            guard !kept.isEmpty else { continue }
            stats.recordsWithFRUSAnchors += 1

            for anchor in kept {
                crosswalk[anchor.volumeId, default: [:]][anchor.ref] = record.canonicalId
            }
            authority[String(record.canonicalId)] = entry
        }

        var apart: [String: [String]] = [:]
        if let overlay {
            // A stale or mistyped correction would do nothing, silently; it is checked against the
            // registry and the overlay it is about to change (#1657). A join may name a record
            // with no anchor of its own, so the names are the whole registry's (#1767).
            if let misfit = PersonsCompleteCorrections.misfit(
                of: overlay.corrections, entries: overlay.entries,
                registryName: { registry[$0]?.n }) {
                throw misfit
            }
            let registryCrosswalk = crosswalk
            applyOverlay(overlay, crosswalk: &crosswalk, authority: &authority,
                         keepVolume: keepVolume, stats: &stats, registry: registry)
            try applyAssignments(overlay.assigned, registryCrosswalk: registryCrosswalk,
                                 crosswalk: &crosswalk, authority: &authority, registry: registry,
                                 keepVolume: keepVolume, stats: &stats)
            apart = apartAnchors(of: overlay.corrections, crosswalk: crosswalk, keepVolume: keepVolume)
            stats.anchorsStandingApart = apart.values.reduce(0) { $0 + $1.count }
        }

        stats.crosswalkEntries = crosswalk.values.reduce(0) { $0 + $1.count }
        stats.distinctVolumes = crosswalk.count
        stats.withViaf = authority.values.count { $0.v?.isEmpty == false }
        stats.withPOCOMSlug = authority.values.count { $0.s?.isEmpty == false }
        stats.withWikidata = authority.values.count { $0.q?.isEmpty == false }
        stats.withRole = authority.values.count { $0.r?.isEmpty == false }

        let index = PersonAuthorityIndex(version: version, generated: generated, source: source,
                                         crosswalk: crosswalk, authority: authority,
                                         apart: apart.isEmpty ? nil : apart)
        return (index, stats)
    }

    /// Folds the `frus-name-authority` drop into an already-built registry index.
    ///
    /// Two independent passes, because they answer to different rules. Enrichment only touches
    /// entries the registry already has, and skips audit-flagged people entirely; it takes an entry's
    /// role text, and its Wikidata and VIAF ids only when `overlay.takesIdentifiers`. Expansion adds
    /// anchors for people the registry already has — an anchor pointing at an id with no entry
    /// would resolve to a person the app cannot name, so those are counted and dropped.
    ///
    /// An entry a correction names (`overlay.corrections`, #1657) merges two people: the anchors,
    /// identifiers and role text the correction lists are not the keyed person's, and reach none of
    /// the entry's people-ids. The rest of the entry applies as any entry does. After every entry,
    /// the anchors of a correction that names the record they belong to join it where no source
    /// answered for them, and a joined record `authority` lacks is taken from `registry` (#1767).
    static func applyOverlay(_ overlay: Overlay,
                             crosswalk: inout [String: [String: Int]],
                             authority: inout [String: AuthorityEntry],
                             keepVolume: ((String) -> Bool)?,
                             stats: inout BuildStats,
                             registry: [String: AuthorityEntry] = [:]) {
        let volumesBefore = Set(crosswalk.keys)
        stats.overlayEntriesRead = overlay.entries.count
        var correctionsByPeopleId: [String: PersonsCompleteCorrections.HeldApart] = [:]
        for correction in overlay.corrections { correctionsByPeopleId[correction.peopleId] = correction }

        for entry in overlay.entries {
            // Every people-id, not just the first: 64 entries are auto-merges carrying several,
            // and 46 ids the app uses exist only as an entry's secondary idno.
            let ids = entry.peopleIds
            guard !ids.isEmpty else { continue }

            if ids.contains(where: overlay.flaggedPeopleIds.contains) {
                // A human review called this merge wrong or doubtful. Attaching its identifiers
                // would put one person's Wikidata id on another person's record, and adding its
                // anchors would key a FRUS person to a merged identity that should not exist.
                stats.overlayEntriesSkippedByAudit += 1
                continue
            }

            // What of this entry belongs to another person (#1657): none of it reaches any of the
            // entry's people-ids, so no correction depends on which id is the canonical one.
            let corrections = ids.compactMap { correctionsByPeopleId[$0] }
            let heldApart = Set(corrections.flatMap(\.parsedAnchors))
            let wikidata = entry.wikidata.flatMap { id in
                corrections.contains { $0.wikidata == id } ? nil : id
            }
            let viaf = entry.viaf.flatMap { id in
                corrections.contains { $0.viaf == id } ? nil : id
            }
            let role = entry.role.flatMap { text in
                corrections.contains { $0.role == text } ? nil : text
            }
            if wikidata != entry.wikidata { stats.overlayIdentifiersWithheld += 1 }
            if viaf != entry.viaf { stats.overlayIdentifiersWithheld += 1 }
            if role != entry.role { stats.overlayRolesWithheld += 1 }
            // Decision 55: the overlay's identifiers too often name someone else to be taken
            // unchecked (`Overlay.takesIdentifiers`).
            let reachesARecord = ids.contains { authority[$0] != nil }
            if !overlay.takesIdentifiers, reachesARecord {
                stats.overlayIdentifiersNotTaken += [wikidata, viaf].compactMap { $0 }.count
            }

            for id in ids where authority[id] != nil {
                authority[id] = authority[id]?.merging(
                    viaf: overlay.takesIdentifiers ? viaf : nil,
                    wikidata: overlay.takesIdentifiers ? wikidata : nil, role: role,
                    roleLimit: overlay.roleCharacterLimit)
            }

            // Expansion: an anchor is only usable if one of the entry's ids names a person the
            // registry knows. Where several do, the first in document order is taken — upstream
            // orders the primary idno first.
            guard let canonicalText = ids.first(where: { authority[$0] != nil }),
                  let canonicalId = Int(canonicalText) else {
                if !entry.anchors.isEmpty { stats.unknownOverlayIds.formUnion(ids) }
                continue
            }
            for anchor in entry.anchors {
                guard keepVolume?(anchor.volumeId) ?? true else { continue }
                if heldApart.contains(anchor) {
                    // Another person's, by a correction: not this entry's, and so no disagreement
                    // with the registry either, which may give it to that person.
                    stats.overlayAnchorsHeldApart += 1
                    continue
                }
                if let existing = crosswalk[anchor.volumeId]?[anchor.ref] {
                    // The registry already answered. Recorded for review, never overwritten:
                    // measured, the two sources agree on 98.96% of shared anchors, and the 0.45%
                    // that differ are upstream merge decisions the registry has not adopted.
                    if existing != canonicalId {
                        stats.crosswalkConflicts.append(CrosswalkConflict(
                            volumeId: anchor.volumeId, ref: anchor.ref,
                            registry: existing, overlay: canonicalText))
                    }
                    continue
                }
                crosswalk[anchor.volumeId, default: [:]][anchor.ref] = canonicalId
                stats.crosswalkPairsAdded += 1
            }
        }
        // A held-apart anchor joins the record its correction names, wherever neither the registry
        // nor an overlay entry answered for it: held apart and left to the app's clusterer, it can
        // be merged back by name with the person it was held apart from.
        for correction in overlay.corrections {
            guard let joins = correction.joins, let joinedId = Int(joins.peopleId) else { continue }
            for anchor in correction.parsedAnchors where keepVolume?(anchor.volumeId) ?? true {
                guard crosswalk[anchor.volumeId]?[anchor.ref] == nil else { continue }
                crosswalk[anchor.volumeId, default: [:]][anchor.ref] = joinedId
                stats.overlayAnchorsJoined += 1
                keepRecord(joins.peopleId, from: registry, in: &authority, stats: &stats)
            }
        }
        stats.crosswalkVolumesAdded = Set(crosswalk.keys).subtracting(volumesBefore).count
    }

    /// Writes the corrections file's assignments (#1767): each anchor no source answered goes to the
    /// registry record its assignment names, which is taken from `registry` when `authority` lacks it.
    ///
    /// Run after the overlay, so that `crosswalk` holds every source's answer, and checked as a join
    /// is, so that a stale assignment never does nothing silently. An assignment in a volume the run
    /// does not keep writes nothing.
    ///
    /// - Parameters:
    ///   - registryCrosswalk: The crosswalk the registry alone gave, before the overlay.
    ///   - registry: Every registry record, with or without an anchor in a kept volume.
    /// - Throws: `PersonsCompleteCorrections.Problem` when the registry names an assignment's record
    ///   otherwise than the assignment does, or has no such record; when the registry answers for its
    ///   anchor, with that record or another; or when an overlay entry gives the anchor to another.
    static func applyAssignments(_ assigned: [PersonsCompleteCorrections.Assigned],
                                 registryCrosswalk: [String: [String: Int]],
                                 crosswalk: inout [String: [String: Int]],
                                 authority: inout [String: AuthorityEntry],
                                 registry: [String: AuthorityEntry],
                                 keepVolume: ((String) -> Bool)?,
                                 stats: inout BuildStats) throws {
        for assignment in assigned {
            let found = registry[assignment.peopleId]?.n
            guard found == assignment.registryName else {
                throw PersonsCompleteCorrections.Problem.assignedNameDiffers(
                    anchor: assignment.anchor, peopleId: assignment.peopleId,
                    expected: assignment.registryName, found: found)
            }
            // `loadAssignments` refuses an anchor that does not parse, and a registry key is numeric.
            guard let anchor = assignment.parsedAnchor, let id = Int(assignment.peopleId),
                  keepVolume?(anchor.volumeId) ?? true else { continue }
            if let answer = registryCrosswalk[anchor.volumeId]?[anchor.ref] {
                throw PersonsCompleteCorrections.Problem.assignmentAnsweredByRegistry(
                    anchor: assignment.anchor, peopleId: assignment.peopleId, registry: answer)
            }
            if let answer = crosswalk[anchor.volumeId]?[anchor.ref] {
                guard answer == id else {
                    throw PersonsCompleteCorrections.Problem.assignmentAnsweredByOverlay(
                        anchor: assignment.anchor, peopleId: assignment.peopleId, overlay: answer)
                }
                continue
            }
            crosswalk[anchor.volumeId, default: [:]][anchor.ref] = id
            stats.anchorsAssigned += 1
            keepRecord(assignment.peopleId, from: registry, in: &authority, stats: &stats)
        }
    }

    /// The anchors that belong to no reconciled person (#1767): each anchor a correction holds apart,
    /// in a kept volume, that no source answered and no join or assignment placed. No record could be
    /// shown to be their person's: where one is, the correction joins it or an assignment names it.
    ///
    /// Left uncovered and unmarked, the app's clusterer can join such an anchor by name to the person
    /// it was held apart from: nine did, among them Hamilton Fish III and IV under the Secretary of
    /// State. The index lists them as `apart`, and the clusterer never joins one to a reconciled
    /// person (`PersonClusterInput.standsApart`).
    ///
    /// - Returns: `volumeId → [ref]`, refs sorted; empty when every held-apart anchor is answered.
    static func apartAnchors(of corrections: [PersonsCompleteCorrections.HeldApart],
                             crosswalk: [String: [String: Int]],
                             keepVolume: ((String) -> Bool)?) -> [String: [String]] {
        var apart: [String: Set<String>] = [:]
        for correction in corrections {
            for anchor in correction.parsedAnchors
            where (keepVolume?(anchor.volumeId) ?? true) && crosswalk[anchor.volumeId]?[anchor.ref] == nil {
                apart[anchor.volumeId, default: []].insert(anchor.ref)
            }
        }
        return apart.mapValues { $0.sorted() }
    }

    /// Puts the registry's record for `peopleId` in `authority` when a join or an assignment has
    /// just placed an anchor on it and it is not there: a record with no anchor in a kept volume of
    /// its own, which the registry pass leaves out (#1767).
    private static func keepRecord(_ peopleId: String, from registry: [String: AuthorityEntry],
                                   in authority: inout [String: AuthorityEntry],
                                   stats: inout BuildStats) {
        guard authority[peopleId] == nil, let entry = registry[peopleId] else { return }
        authority[peopleId] = entry
        stats.recordsKeptForAJoin += 1
    }
}

// MARK: - XML helpers

private extension XMLElement {
    /// Text of the first direct child element with `name`.
    func firstChildText(_ name: String) -> String? {
        elements(forName: name).first?.stringValue
    }
    /// Text of every descendant element with `name`, at any depth.
    func descendantTexts(_ name: String) -> [String] {
        (try? nodes(forXPath: ".//\(name)"))?.compactMap { $0.stringValue } ?? []
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
