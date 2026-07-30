// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HarvestedRecord

/// One projected NARA Catalog description record, as it appears in the harvested index.
///
/// This is the *typed* view. The authoritative view is the raw tree it was projected from, which is
/// what ``FieldCensus`` walks and what `KEEP_RAW=1` persists — so a field this struct forgot is
/// visible in the census and recoverable by re-projection without re-downloading 22 GB.
///
/// Field order in the JSON is alphabetised by the encoder (`.sortedKeys`), so the on-disk shape does
/// not depend on the declaration order here.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct HarvestedRecord: Codable, Sendable, Equatable {

    // MARK: Identity

    /// NARA unique identifier, stringified.
    public var naId: String
    /// Record title.
    public var title: String
    /// `series` | `fileUnit` | `item` | `recordGroup` | `collection`.
    public var levelOfDescription: String
    /// Record group this record was harvested under, from its `recordGroup`-level ancestor (or, for
    /// the group's own node, from its `recordGroupNumber`).
    public var recordGroupNumber: Int
    /// Deep link to the catalog record.
    public var catalogURL: String

    // MARK: Hierarchy

    /// Full ancestor chain, **farthest first** — outermost ancestor at index 0.
    ///
    /// Measured, not assumed: a file unit's chain arrives as
    /// `[(distance 3, recordGroup), (distance 2, series), (distance 1, fileUnit)]`, i.e. descending
    /// `distance`, so the record's immediate parent is *last*. Preserved in NARA's own order rather
    /// than re-sorted, so `distance` remains the authority; read `distance` rather than relying on
    /// position.
    public var ancestors: [CatalogAncestor]
    /// A hierarchy this record used to sit in, when NARA has moved it.
    ///
    /// Found by the unprojected-key tripwire, not by design: one of RG 420's 31 series carries a
    /// `formerAncestors` naming **RG 286** (Agency for International Development). That is archival
    /// provenance a researcher tracing records across an agency reorganisation actually needs — the
    /// series is filed under one record group today and was filed under another before.
    ///
    /// Note that these ancestors are deliberately **not** consulted by the record-group invariant:
    /// attribution reads `ancestors` only, so a former RG 286 parent cannot make this record look
    /// like an RG 286 record.
    public var formerAncestors: [CatalogAncestor]
    /// NAIDs of containers this record was formerly part of (`formerlyContainedBy`).
    public var formerlyContainedByNaIds: [String]
    /// NAID of the enclosing series, when this record is below series level.
    public var seriesNaId: String?
    /// Title of the enclosing series.
    public var seriesTitle: String?

    // MARK: The two priority payloads

    /// Creating organizations and persons. Empty means the record genuinely has none.
    public var creators: [CatalogCreator]
    /// Every control number NARA indexes for this record, verbatim and unfiltered.
    public var variantControlNumbers: [CatalogControlNumber]
    /// Contributing organizations and persons — the same shape as ``creators`` but carrying
    /// `contributorType` (`Producer`, `Originator`, …). Chiefly populated on audiovisual series, so
    /// expect these in RG 208 and RG 306 rather than in the textual State groups.
    public var contributors: [CatalogCreator]
    /// NARA's `localIdentifier` (e.g. `"59.83"`) — an **agency-assigned** identifier that is NOT part
    /// of ``variantControlNumbers`` and would be missed by any control-number query.
    public var localIdentifier: String?

    // MARK: Dates

    public var inclusiveStartDate: CatalogDate?
    public var inclusiveEndDate: CatalogDate?
    public var coverageStartDate: CatalogDate?
    public var coverageEndDate: CatalogDate?
    public var dateNote: String?
    /// `productionDates` — when the records were produced, as distinct from the coverage span.
    public var productionDates: [CatalogDate]

    // MARK: Descriptive text

    public var scopeAndContentNote: String?
    public var arrangement: String?
    public var functionAndUse: String?
    public var custodialHistoryNote: String?
    public var generalNotes: [String]
    public var otherTitles: [String]
    /// `numberingNote` — how to actually cite or request an item from this series.
    ///
    /// Not a note about numbering so much as **ordering instructions**. RG 229, for example:
    /// "Requests for items in the series must include the record group number, series designator, box
    /// number, and item number. (Example=229-IIA-1-1)." Present on 385 records across 15 of the 22
    /// groups, and squarely on-topic for a researcher assembling a citation — which is why it was worth
    /// promoting out of `unprojectedKeys`.
    public var numberingNote: String?
    public var findingAids: [CatalogFindingAid]

    // MARK: Holdings, restrictions, classification

    public var physicalOccurrences: [CatalogPhysicalOccurrence]
    public var accessRestriction: CatalogRestriction?
    public var useRestriction: CatalogRestriction?

    // MARK: Records management and typing

    public var generalRecordsTypes: [String]
    public var specificRecordsTypes: [String]
    public var languages: [String]
    public var subjects: [CatalogSubject]
    public var accessionNumbers: [String]
    public var dispositionAuthorityNumbers: [String]
    public var recordsCenterTransferNumbers: [String]
    public var microformPublications: [String]

    // MARK: Digitization

    /// Number of digital objects attached. `availableOnline` is **not** a record field — it exists
    /// only as a query parameter and an aggregation bucket — so this count is the record-side
    /// evidence of digitization, and the harvest keeps every record regardless of its value.
    public var digitalObjectCount: Int
    /// Whether the record is flagged audiovisual. Projected through the case-insensitive
    /// string-to-Bool coercion, because NARA ships this as a quoted string of varying case.
    public var audiovisual: Bool?
    /// `soundType` (e.g. `Sound`, `Silent`), for audiovisual holdings.
    public var soundType: String?
    /// Digital objects, minus their OCR text — see ``CatalogDigitalObject``.
    public var digitalObjects: [CatalogDigitalObject]
    /// Off-site digitisation (Ancestry, FamilySearch, …) that the catalog records but does not host.
    public var onlineResources: [CatalogOnlineResource]

    // MARK: Child counts

    /// NARA's own count of file units beneath this record.
    ///
    /// The same self-validating device as the record group's `seriesCount`, one level down: a
    /// `seriesAndFileUnits` harvest can check what it collected against what NARA says exists, so a
    /// truncated file-unit pass is detectable rather than merely plausible.
    public var fileUnitCount: Int?
    /// NARA's own count of items beneath this record.
    public var itemCount: Int?

    // MARK: Provenance of the projection itself

    /// Raw record keys this projection did not map, sorted.
    ///
    /// The anti-silence field. A schema addition upstream shows up here per record and in the field
    /// census in aggregate, rather than being discarded at the decode boundary the way the repo's
    /// existing catalog mirror discards everything it was not told about.
    public var unprojectedKeys: [String]

    public init(
        naId: String, title: String, levelOfDescription: String, recordGroupNumber: Int,
        catalogURL: String, ancestors: [CatalogAncestor] = [],
        formerAncestors: [CatalogAncestor] = [], formerlyContainedByNaIds: [String] = [],
        seriesNaId: String? = nil,
        seriesTitle: String? = nil, creators: [CatalogCreator] = [],
        variantControlNumbers: [CatalogControlNumber] = [],
        contributors: [CatalogCreator] = [], localIdentifier: String? = nil,
        productionDates: [CatalogDate] = [], soundType: String? = nil,
        digitalObjects: [CatalogDigitalObject] = [],
        onlineResources: [CatalogOnlineResource] = [],
        fileUnitCount: Int? = nil, itemCount: Int? = nil,
        inclusiveStartDate: CatalogDate? = nil, inclusiveEndDate: CatalogDate? = nil,
        coverageStartDate: CatalogDate? = nil, coverageEndDate: CatalogDate? = nil,
        dateNote: String? = nil, scopeAndContentNote: String? = nil, arrangement: String? = nil,
        functionAndUse: String? = nil, custodialHistoryNote: String? = nil,
        generalNotes: [String] = [], otherTitles: [String] = [], numberingNote: String? = nil,
        findingAids: [CatalogFindingAid] = [],
        physicalOccurrences: [CatalogPhysicalOccurrence] = [],
        accessRestriction: CatalogRestriction? = nil, useRestriction: CatalogRestriction? = nil,
        generalRecordsTypes: [String] = [], specificRecordsTypes: [String] = [],
        languages: [String] = [], subjects: [CatalogSubject] = [],
        accessionNumbers: [String] = [], dispositionAuthorityNumbers: [String] = [],
        recordsCenterTransferNumbers: [String] = [], microformPublications: [String] = [],
        digitalObjectCount: Int = 0, audiovisual: Bool? = nil, unprojectedKeys: [String] = []
    ) {
        self.naId = naId
        self.title = title
        self.levelOfDescription = levelOfDescription
        self.recordGroupNumber = recordGroupNumber
        self.catalogURL = catalogURL
        self.ancestors = ancestors
        self.formerAncestors = formerAncestors
        self.formerlyContainedByNaIds = formerlyContainedByNaIds
        self.seriesNaId = seriesNaId
        self.seriesTitle = seriesTitle
        self.creators = creators
        self.variantControlNumbers = variantControlNumbers
        self.contributors = contributors
        self.localIdentifier = localIdentifier
        self.productionDates = productionDates
        self.soundType = soundType
        self.digitalObjects = digitalObjects
        self.onlineResources = onlineResources
        self.fileUnitCount = fileUnitCount
        self.itemCount = itemCount
        self.inclusiveStartDate = inclusiveStartDate
        self.inclusiveEndDate = inclusiveEndDate
        self.coverageStartDate = coverageStartDate
        self.coverageEndDate = coverageEndDate
        self.dateNote = dateNote
        self.scopeAndContentNote = scopeAndContentNote
        self.arrangement = arrangement
        self.functionAndUse = functionAndUse
        self.custodialHistoryNote = custodialHistoryNote
        self.generalNotes = generalNotes
        self.otherTitles = otherTitles
        self.numberingNote = numberingNote
        self.findingAids = findingAids
        self.physicalOccurrences = physicalOccurrences
        self.accessRestriction = accessRestriction
        self.useRestriction = useRestriction
        self.generalRecordsTypes = generalRecordsTypes
        self.specificRecordsTypes = specificRecordsTypes
        self.languages = languages
        self.subjects = subjects
        self.accessionNumbers = accessionNumbers
        self.dispositionAuthorityNumbers = dispositionAuthorityNumbers
        self.recordsCenterTransferNumbers = recordsCenterTransferNumbers
        self.microformPublications = microformPublications
        self.digitalObjectCount = digitalObjectCount
        self.audiovisual = audiovisual
        self.unprojectedKeys = unprojectedKeys
    }
}

// MARK: - RecordProjectionOutcome

/// The result of projecting one raw record.
public enum RecordProjectionOutcome: Sendable, Equatable {
    /// Projected successfully.
    case projected(HarvestedRecord)
    /// The record's level is not admitted at this group's depth. Not a problem — the expected
    /// outcome for the overwhelming majority of lines in a series-only harvest.
    case levelNotAdmitted(String?)
    /// The record failed an invariant and was **not** projected. Counted and reported, never
    /// silently dropped.
    case rejected(RecordInvariantViolation)
}

// MARK: - RecordInvariantViolation

/// Why a record was refused.
///
/// These are the generalisation of this repo's #321 / #352 lessons. There, a lot-file resolver
/// accepted records whose ancestry exposed no record group, and the measured precision of that
/// fallback was 0 correct out of 16 — every accepted record was a presidential-library staff file
/// masquerading as an RG 59/84 lot. The rule that follows is that *unattributable is not the same
/// as attributable to the group we happened to be asking about*, and it is enforced here rather
/// than assumed.
public enum RecordInvariantViolation: Sendable, Equatable {
    /// No `naId`, or an empty one.
    case missingNaId
    /// No usable title.
    case missingTitle(naId: String)
    /// The ancestor chain contains no `recordGroup` level, so the record cannot be attributed.
    case noRecordGroupAncestor(naId: String, ancestorLevels: [String])
    /// The record's own record group is not the one being harvested.
    case recordGroupMismatch(naId: String, expected: Int, found: Int)

    /// One-line audit form, for the review block.
    public var auditLine: String {
        switch self {
        case .missingNaId:
            return "record with no naId"
        case .missingTitle(let naId):
            return "naId \(naId): no title"
        case .noRecordGroupAncestor(let naId, let levels):
            return "naId \(naId): no recordGroup in ancestry [\(levels.joined(separator: " > "))]"
        case .recordGroupMismatch(let naId, let expected, let found):
            return "naId \(naId): RG \(found) found under RG \(expected)'s shards"
        }
    }
}
