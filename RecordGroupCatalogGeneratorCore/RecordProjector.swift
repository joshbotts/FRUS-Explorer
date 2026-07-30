// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FieldAliasLedger

/// Records, per field, which spelling of its key actually matched — and, crucially, when none did.
///
/// ## The failure mode this exists to prevent
/// If a wanted field's key name is wrong, a typed projection returns an empty array, the harvest
/// completes, the artifact looks plausible, and the data the harvest existed to collect is simply
/// absent with nothing anywhere saying so. That is the single worst outcome available to this tool,
/// and it is not hypothetical: this repo's existing catalog mirror silently dropped
/// `variantControlNumbers` for a year, which is why #315 had to re-query the whole index to recover
/// HMS/MLR entry numbers that had been in every response all along.
///
/// So the ledger separates three states that an `Optional` conflates:
/// - **matched(alias)** — the key was found under this spelling.
/// - **presentButEmpty** — the key exists and is `null` or `[]`. Upstream says "no value here",
///   which is a fact about the records, not a bug in the harvester.
/// - **absent** — the key is not in the record at all under *any* known spelling. For a field
///   declared `required`, absent across an entire record group is a hard failure.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct FieldAliasLedger: Sendable, Equatable {

    /// What was observed for one canonical field.
    public struct Observation: Sendable, Equatable {
        /// Occurrences per matching key spelling.
        public var matchedAlias: [String: Int] = [:]
        /// Records where the key existed but held no value.
        public var presentButEmpty: Int = 0
        /// Records where no spelling of the key appeared at all.
        public var absent: Int = 0

        /// Records where a value was actually obtained.
        public var matchedCount: Int { matchedAlias.values.reduce(0, +) }
        /// Records examined.
        public var examined: Int { matchedCount + presentButEmpty + absent }
    }

    /// Canonical field name → what was seen.
    public private(set) var observations: [String: Observation] = [:]

    public init() {}

    /// Notes that `field` matched under `alias`.
    public mutating func noteMatch(field: String, alias: String) {
        observations[field, default: Observation()].matchedAlias[alias, default: 0] += 1
    }

    /// Notes that `field`'s key was present but carried no value.
    public mutating func notePresentButEmpty(field: String) {
        observations[field, default: Observation()].presentButEmpty += 1
    }

    /// Notes that no spelling of `field` appeared.
    public mutating func noteAbsent(field: String) {
        observations[field, default: Observation()].absent += 1
    }

    /// Merges another ledger in, so per-group ledgers roll up to a run total.
    public mutating func merge(_ other: FieldAliasLedger) {
        for (field, incoming) in other.observations {
            var existing = observations[field] ?? Observation()
            for (alias, count) in incoming.matchedAlias {
                existing.matchedAlias[alias, default: 0] += count
            }
            existing.presentButEmpty += incoming.presentButEmpty
            existing.absent += incoming.absent
            observations[field] = existing
        }
    }

    /// Fields that were examined but **never** produced a value under any spelling.
    ///
    /// The go/no-go list. A required field appearing here means the run must fail.
    public func neverMatched(among fields: [String]) -> [String] {
        fields.filter { field in
            guard let observation = observations[field], observation.examined > 0 else { return false }
            return observation.matchedCount == 0
        }.sorted()
    }

    /// Any spelling that matched which is **not** the field's own canonical name — i.e. the schema
    /// has drifted and the projection is running on a fallback. Reported so a silent fallback
    /// cannot pass for a clean run.
    public func nonCanonicalMatches() -> [(field: String, alias: String, count: Int)] {
        var out: [(String, String, Int)] = []
        for (field, observation) in observations {
            for (alias, count) in observation.matchedAlias where alias != field {
                out.append((field, alias, count))
            }
        }
        return out.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
    }
}

// MARK: - RecordProjector

/// Projects a raw NARA description record into a ``HarvestedRecord``.
///
/// ## Field names are verified, not guessed
/// Every key this projector reads was confirmed against real bytes from NARA's public bulk export
/// (RG 486 in full — 11 series, 11 of 11 carrying `creators` and `variantControlNumbers` — plus a
/// wider census across the export). The alias lists below are therefore a **drift detector**, not a
/// guessing game: the canonical name leads every list, and any match on a non-canonical spelling is
/// reported by ``FieldAliasLedger/nonCanonicalMatches()`` rather than quietly used.
///
/// Two aliases are included because NARA's own published OpenAPI documents disagree with the
/// shipped data on their spelling — `pyhsicalOccurrences` and `generalRecordTypes` are the
/// documents' spellings, not the export's. Tolerating both costs nothing and means a future
/// alignment in either direction does not empty a field.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordProjector: Sendable {

    /// Base for catalog deep links.
    public static let catalogIDBase = "https://catalog.archives.gov/id/"

    /// Canonical field names whose absence across a whole run is a **hard failure** — the two
    /// payloads this harvest exists to collect.
    public static let requiredFields = ["creators", "variantControlNumbers"]

    /// Canonical name → accepted key spellings, canonical first.
    static let aliases: [String: [String]] = [
        "creators": ["creators"],
        "contributors": ["contributors"],
        "variantControlNumbers": ["variantControlNumbers"],
        "physicalOccurrences": ["physicalOccurrences", "pyhsicalOccurrences"],
        "generalRecordsTypes": ["generalRecordsTypes", "generalRecordTypes"],
        "scopeAndContentNote": ["scopeAndContentNote"],
        "custodialHistoryNote": ["custodialHistoryNote"],
        "microformPublications": ["microformPublications", "microformPublicationNote"],
        "findingAids": ["findingAids", "findingAidNote"],
    ]

    /// Every raw key the projector consumes. Anything outside this set lands in
    /// ``HarvestedRecord/unprojectedKeys``.
    static let consumedKeys: Set<String> = {
        var keys: Set<String> = [
            "naId", "title", "levelOfDescription", "recordGroupNumber", "recordType",
            "ancestors", "creators", "variantControlNumbers",
            "inclusiveStartDate", "inclusiveEndDate", "coverageStartDate", "coverageEndDate",
            "dateNote", "scopeAndContentNote", "arrangement", "functionAndUse",
            "custodialHistoryNote", "generalNotes", "otherTitles", "findingAids",
            "physicalOccurrences", "accessRestriction", "useRestriction",
            "contributors", "localIdentifier", "productionDates", "soundType",
            "onlineResources", "fileUnitCount", "itemCount", "numberingNote",
            "formerAncestors", "formerlyContainedBy",
            "generalRecordsTypes", "languages", "subjects",
            "accessionNumbers", "dispositionAuthorityNumbers", "recordsCenterTransferNumbers",
            "microformPublications", "digitalObjects", "audiovisual",
        ]
        for spellings in aliases.values { keys.formUnion(spellings) }
        return keys
    }()

    public init() {}

    // MARK: Alias resolution

    /// Returns the value of `field` under the first alias that carries one, updating `ledger`.
    ///
    /// "Carries one" means non-`null` and, for arrays, non-empty — so a field that is always `[]`
    /// is recorded as `presentButEmpty` rather than counted as a successful match.
    static func resolve(
        _ field: String, in record: CatalogJSONValue, ledger: inout FieldAliasLedger
    ) -> CatalogJSONValue? {
        let spellings = aliases[field] ?? [field]
        var sawKey = false
        for alias in spellings {
            if record.hasKey(alias) { sawKey = true }
            guard let value = record[alias] else { continue }
            if let array = value.arrayValue, array.isEmpty { continue }
            ledger.noteMatch(field: field, alias: alias)
            return value
        }
        if sawKey { ledger.notePresentButEmpty(field: field) } else { ledger.noteAbsent(field: field) }
        return nil
    }

    // MARK: Projection

    /// Projects one raw record harvested under `recordGroup` at `depth`.
    ///
    /// - Parameters:
    ///   - record: the raw record tree (already unwrapped from its `{"record": …}` envelope).
    ///   - recordGroup: the group whose shards this record came from.
    ///   - depth: the group's harvest depth, which decides admitted levels.
    ///   - ledger: alias observations, updated in place.
    public func project(
        _ record: CatalogJSONValue,
        recordGroup: Int,
        depth: HarvestDepth,
        ledger: inout FieldAliasLedger
    ) -> RecordProjectionOutcome {

        let level = record["levelOfDescription"]?.nonEmptyString

        // The group's own node is never a harvested record — it is the metadata carrier
        // (`seriesCount`, authoritative title) the caller peels off separately.
        guard level != "recordGroup" else { return .levelNotAdmitted(level) }
        guard depth.admits(level) else { return .levelNotAdmitted(level) }

        guard let naId = record["naId"]?.nonEmptyString else { return .rejected(.missingNaId) }
        guard let title = record["title"]?.nonEmptyString else {
            return .rejected(.missingTitle(naId: naId))
        }

        // Attribution: the record group lives on the `recordGroup`-level ancestor, never on the
        // record itself. An unattributable record is refused, not accepted on the strength of the
        // shard it happened to be found in (#321).
        let ancestors = (record["ancestors"]?.asArray ?? []).compactMap(CatalogAncestor.init)
        let ancestorLevels = ancestors.compactMap(\.levelOfDescription)
        guard let groupAncestor = ancestors.first(where: {
            $0.levelOfDescription == "recordGroup" && $0.recordGroupNumber != nil
        }), let foundGroup = groupAncestor.recordGroupNumber else {
            return .rejected(.noRecordGroupAncestor(naId: naId, ancestorLevels: ancestorLevels))
        }
        guard foundGroup == recordGroup else {
            return .rejected(.recordGroupMismatch(
                naId: naId, expected: recordGroup, found: foundGroup))
        }

        let seriesAncestor = ancestors.first { $0.levelOfDescription == "series" }

        let creators = (Self.resolve("creators", in: record, ledger: &ledger)?.asArray ?? [])
            .compactMap(CatalogCreator.init)
            .sorted { $0.sortKey < $1.sortKey }

        let controlNumbers = (Self.resolve("variantControlNumbers", in: record, ledger: &ledger)?
            .asArray ?? [])
            .compactMap(CatalogControlNumber.init)
            .sorted { $0.sortKey < $1.sortKey }

        let occurrences = (Self.resolve("physicalOccurrences", in: record, ledger: &ledger)?
            .asArray ?? [])
            .compactMap(CatalogPhysicalOccurrence.init)

        let subjects = (record["subjects"]?.asArray ?? [])
            .compactMap(CatalogSubject.init)
            .sorted { $0.sortKey < $1.sortKey }

        let unprojected = (record.objectValue?.keys.filter { !Self.consumedKeys.contains($0) } ?? [])
            .sorted()

        let projected = HarvestedRecord(
            naId: naId,
            title: title,
            levelOfDescription: level ?? "",
            recordGroupNumber: recordGroup,
            catalogURL: Self.catalogIDBase + naId,
            ancestors: ancestors,
            formerAncestors: (record["formerAncestors"]?.asArray ?? [])
                .compactMap(CatalogAncestor.init),
            formerlyContainedByNaIds: (record["formerlyContainedBy"]?.asArray ?? [])
                .compactMap(\.nonEmptyString)
                .sorted { $0.compare($1, options: .numeric) == .orderedAscending },
            seriesNaId: level == "series" ? nil : seriesAncestor?.naId,
            seriesTitle: level == "series" ? nil : seriesAncestor?.title,
            creators: creators,
            variantControlNumbers: controlNumbers,
            contributors: (Self.resolve("contributors", in: record, ledger: &ledger)?.asArray ?? [])
                .compactMap(CatalogCreator.init)
                .sorted { $0.sortKey < $1.sortKey },
            localIdentifier: record["localIdentifier"]?.nonEmptyString,
            productionDates: (record["productionDates"]?.asArray ?? [])
                .compactMap { CatalogDate($0) }
                .sorted { ($0.logicalDate ?? "") < ($1.logicalDate ?? "") },
            soundType: record["soundType"]?.nonEmptyString,
            digitalObjects: (record["digitalObjects"]?.asArray ?? [])
                .compactMap(CatalogDigitalObject.init)
                .sorted { $0.sortKey < $1.sortKey },
            onlineResources: (record["onlineResources"]?.asArray ?? [])
                .compactMap(CatalogOnlineResource.init)
                .sorted { $0.sortKey < $1.sortKey },
            fileUnitCount: record["fileUnitCount"]?.intValue,
            itemCount: record["itemCount"]?.intValue,
            inclusiveStartDate: CatalogDate(record["inclusiveStartDate"]),
            inclusiveEndDate: CatalogDate(record["inclusiveEndDate"]),
            coverageStartDate: CatalogDate(record["coverageStartDate"]),
            coverageEndDate: CatalogDate(record["coverageEndDate"]),
            dateNote: record["dateNote"]?.nonEmptyString,
            scopeAndContentNote: Self.resolve("scopeAndContentNote", in: record, ledger: &ledger)?
                .nonEmptyString,
            arrangement: record["arrangement"]?.nonEmptyString,
            functionAndUse: record["functionAndUse"]?.nonEmptyString,
            custodialHistoryNote: Self.resolve("custodialHistoryNote", in: record, ledger: &ledger)?
                .nonEmptyString,
            generalNotes: Self.stringList(record["generalNotes"], preferredKeys: ["note", "text"]),
            otherTitles: Self.stringList(record["otherTitles"], preferredKeys: ["title", "otherTitle"]),
            numberingNote: record["numberingNote"]?.nonEmptyString,
            findingAids: (Self.resolve("findingAids", in: record, ledger: &ledger)?.asArray ?? [])
                .compactMap(CatalogFindingAid.init)
                .sorted { $0.sortKey < $1.sortKey },
            physicalOccurrences: occurrences,
            accessRestriction: CatalogRestriction(record["accessRestriction"]),
            useRestriction: CatalogRestriction(record["useRestriction"]),
            generalRecordsTypes: Self.stringList(
                Self.resolve("generalRecordsTypes", in: record, ledger: &ledger),
                preferredKeys: ["recordType", "type", "generalRecordsType"]),
            // DERIVED, not read from a `specificRecordsTypes` key — there is no such key.
            //
            // The alias lookup for it matched nothing across all 20,188 records, and the reason is that
            // NARA folds every authority kind into the single `subjects` array discriminated by
            // `authorityType`. The values are right there: 9,312 `specificRecordsType` subjects across
            // 16 of the 22 groups. So the dead lookup is gone, and the field is filled from where the
            // data actually lives rather than left permanently empty beside it.
            //
            // `specificRecordsTypes` is also no longer listed in `consumedKeys`, so if NARA ever does
            // start emitting a real key by that name, the unprojected-key tripwire will say so instead
            // of masking it.
            specificRecordsTypes: subjects
                .filter { $0.authorityType == "specificRecordsType" }
                .compactMap(\.heading)
                .sorted(),
            languages: Self.stringList(record["languages"], preferredKeys: ["language", "name"]),
            subjects: subjects,
            accessionNumbers: Self.stringList(
                record["accessionNumbers"], preferredKeys: ["number", "accessionNumber"]),
            dispositionAuthorityNumbers: Self.stringList(
                record["dispositionAuthorityNumbers"],
                preferredKeys: ["number", "dispositionAuthorityNumber"]),
            recordsCenterTransferNumbers: Self.stringList(
                record["recordsCenterTransferNumbers"],
                preferredKeys: ["number", "recordsCenterTransferNumber"]),
            microformPublications: Self.stringList(
                Self.resolve("microformPublications", in: record, ledger: &ledger),
                preferredKeys: ["title", "number", "note"]),
            digitalObjectCount: record["digitalObjects"]?.asArray.count ?? 0,
            audiovisual: record["audiovisual"]?.boolValue,
            unprojectedKeys: unprojected)

        return .projected(projected)
    }

    // MARK: Helpers

    /// Flattens a list-shaped field to sorted, de-duplicated strings.
    ///
    /// NARA is inconsistent about whether a list of short labels is an array of strings or an array
    /// of single-key objects, and the key name varies by field (`number`, `note`, `title`,
    /// `heading`, `language`…). Rather than hard-code one shape per field and empty the field when
    /// the guess is wrong, this accepts either: a scalar element is taken directly, and an object
    /// element is read through `preferredKeys` and then — if none matched — through *any* string
    /// member, so an unanticipated key name still yields its value.
    static func stringList(_ value: CatalogJSONValue?, preferredKeys: [String]) -> [String] {
        guard let value else { return [] }
        var out: [String] = []
        for element in value.asArray {
            if let scalar = element.nonEmptyString {
                out.append(scalar)
                continue
            }
            guard let object = element.objectValue else { continue }
            if let preferred = preferredKeys.lazy.compactMap({ element[$0]?.nonEmptyString }).first {
                out.append(preferred)
                continue
            }
            // Last resort: any string member, in sorted key order so the pick is deterministic.
            if let fallback = object.keys.sorted().lazy
                .compactMap({ object[$0]?.nonEmptyString }).first {
                out.append(fallback)
            }
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }.sorted()
    }
}
