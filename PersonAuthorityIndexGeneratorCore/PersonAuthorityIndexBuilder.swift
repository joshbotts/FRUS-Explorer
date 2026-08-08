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
        let doc = try XMLDocument(xmlString: xml, options: [])
        guard let root = doc.rootElement() else { return nil }

        guard let idText = root.firstChildText("id"), let canonicalId = Int(idText) else { return nil }

        let sourceURLs = root.descendantTexts("source-url")
        let anchors = sourceURLs.compactMap(parseAnchor(_:))
        guard !anchors.isEmpty else { return nil }
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

        public init(entries: [PersonsCompleteOverlay.Entry],
                    flaggedPeopleIds: Set<String>,
                    roleCharacterLimit: Int = 120) {
            self.entries = entries
            self.flaggedPeopleIds = flaggedPeopleIds
            self.roleCharacterLimit = roleCharacterLimit
        }
    }

    /// Builds the index from a directory of record XML files (recursively).
    ///
    /// `keepVolume` lets the caller restrict the crosswalk to known volumes (e.g. those in the app
    /// manifest); pass `nil` to keep all FRUS volumes.
    ///
    /// `overlay` applies the `frus-name-authority` drop (#736 / #260): identifier enrichment onto
    /// existing entries, and additional crosswalk anchors. It runs **after** the registry pass, so
    /// the registry always wins a disagreement — the overlay is a different pipeline carrying
    /// 1,662 unreviewed auto-merges, and it fills gaps rather than overwriting reconciled answers.
    public static func build(dataDirectory: URL, version: Int, generated: String,
                             source: String, keepVolume: ((String) -> Bool)? = nil,
                             overlay: Overlay? = nil)
    throws -> (index: PersonAuthorityIndex, stats: BuildStats) {
        var stats = BuildStats()
        var crosswalk: [String: [String: Int]] = [:]
        var authority: [String: AuthorityEntry] = [:]

        let fm = FileManager.default
        let enumerator = fm.enumerator(at: dataDirectory, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "xml" else { continue }
            guard let data = try? Data(contentsOf: url),
                  let xml = String(data: data, encoding: .utf8) else { continue }
            stats.recordsParsed += 1
            guard let record = try? parseRecord(xml: xml) else { continue }

            let kept = record.frusAnchors.filter { keepVolume?($0.volumeId) ?? true }
            guard !kept.isEmpty else { continue }
            stats.recordsWithFRUSAnchors += 1

            for anchor in kept {
                crosswalk[anchor.volumeId, default: [:]][anchor.ref] = record.canonicalId
            }
            authority[String(record.canonicalId)] = AuthorityEntry(
                n: record.name, b: record.birthYear, d: record.deathYear, v: record.viaf,
                s: record.pocomSlug)
        }

        if let overlay {
            applyOverlay(overlay, crosswalk: &crosswalk, authority: &authority,
                         keepVolume: keepVolume, stats: &stats)
        }

        stats.crosswalkEntries = crosswalk.values.reduce(0) { $0 + $1.count }
        stats.distinctVolumes = crosswalk.count
        stats.withViaf = authority.values.count { $0.v?.isEmpty == false }
        stats.withPOCOMSlug = authority.values.count { $0.s?.isEmpty == false }
        stats.withWikidata = authority.values.count { $0.q?.isEmpty == false }
        stats.withRole = authority.values.count { $0.r?.isEmpty == false }

        let index = PersonAuthorityIndex(version: version, generated: generated, source: source,
                                         crosswalk: crosswalk, authority: authority)
        return (index, stats)
    }

    /// Folds the `frus-name-authority` drop into an already-built registry index.
    ///
    /// Two independent passes, because they answer to different rules. Enrichment only touches
    /// entries the registry already has, and skips audit-flagged people entirely. Expansion adds
    /// anchors for people the registry already has — an anchor pointing at an id with no entry
    /// would resolve to a person the app cannot name, so those are counted and dropped.
    static func applyOverlay(_ overlay: Overlay,
                             crosswalk: inout [String: [String: Int]],
                             authority: inout [String: AuthorityEntry],
                             keepVolume: ((String) -> Bool)?,
                             stats: inout BuildStats) {
        let volumesBefore = Set(crosswalk.keys)
        stats.overlayEntriesRead = overlay.entries.count

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

            for id in ids where authority[id] != nil {
                authority[id] = authority[id]?.merging(
                    viaf: entry.viaf, wikidata: entry.wikidata, role: entry.role,
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
        stats.crosswalkVolumesAdded = Set(crosswalk.keys).subtracting(volumesBefore).count
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
