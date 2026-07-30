// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CatalogDate

/// A NARA Catalog date. Every date field in the export — `inclusiveStartDate`, `abolishDate`,
/// `coverageEndDate` and the rest — has this same shape.
///
/// `logicalDate` is NARA's own ISO rendering and is the field to sort and compare on;
/// `year`/`month`/`day` are the component parts, and a year-only date carries just `year` plus a
/// `logicalDate` of `"1980-01-01"` (verified on RG 486's record-group node), so `logicalDate`
/// alone cannot tell a precise date from an imputed one. Both are kept for that reason.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CatalogDate: Codable, Sendable, Equatable {
    public var year: Int?
    public var month: Int?
    public var day: Int?
    public var logicalDate: String?

    public init(year: Int? = nil, month: Int? = nil, day: Int? = nil, logicalDate: String? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.logicalDate = logicalDate
    }

    /// Projects a date object, returning `nil` when nothing usable is present.
    public init?(_ value: CatalogJSONValue?) {
        guard let value, value.objectValue != nil else { return nil }
        let year = value["year"]?.intValue
        let month = value["month"]?.intValue
        let day = value["day"]?.intValue
        let logical = value["logicalDate"]?.nonEmptyString
        guard year != nil || month != nil || day != nil || logical != nil else { return nil }
        self.init(year: year, month: month, day: day, logicalDate: logical)
    }

    /// Whether only a year is known — i.e. `logicalDate` is a January-1st placeholder rather than a
    /// real day. Kept as a computed property so no caller has to re-derive the rule.
    public var isYearOnly: Bool { year != nil && month == nil && day == nil }
}

// MARK: - CatalogCreator

/// One creating organization or person on a description record — the **first** of the two things
/// this harvest exists to capture.
///
/// Verified shape, from 11/11 series in RG 486 and ~5,000 series across the export:
/// ```json
/// { "naId": 10514123,
///   "heading": "U.S. International Development Cooperation Agency. Trade and Development Program. (07/01/1980 - 10/27/1992)",
///   "authorityType": "organization",
///   "creatorType": "Predecessor",
///   "establishDate": { "day": 1, "logicalDate": "1980-07-01", "month": 7, "year": 1980 },
///   "abolishDate":   { "day": 27, "logicalDate": "1992-10-27", "month": 10, "year": 1992 } }
/// ```
/// `authorityType` is `organization` or `person`; `creatorType` is `Most Recent` or `Predecessor`.
/// A person carries `birthDate`/`deathDate` where an organization carries
/// `establishDate`/`abolishDate` — but all four are projected unconditionally rather than switched
/// on `authorityType`, because a mislabelled record then keeps its dates instead of losing them.
///
/// `naId` is the join key into NARA's separate authority records (`authority-records/organization/`,
/// `authority-records/person/`), which carry the administrative-history prose. See
/// ``CreatorAuthorityIndex``.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CatalogCreator: Codable, Sendable, Equatable {
    /// Authority-record NAID — the join key for creator enrichment.
    public var naId: String?
    /// The full authority heading, inclusive of its parenthetical date span.
    public var heading: String?
    /// `organization` | `person`.
    public var authorityType: String?
    /// `Most Recent` | `Predecessor`. Present on `creators` members.
    public var creatorType: String?
    /// `Producer`, `Originator`, … Present on `contributors` members instead of `creatorType`.
    ///
    /// The same struct serves both arrays because they are shaped identically apart from this one
    /// discriminator, and both resolve against the same authority records. NARA distinguishes the
    /// agency that *created* a series from one that *contributed* to it — for a film series in RG 208
    /// or RG 306 the producer is the agent a researcher actually wants, so contributors are projected
    /// and enriched alongside creators rather than dropped.
    public var contributorType: String?
    public var establishDate: CatalogDate?
    public var abolishDate: CatalogDate?
    public var birthDate: CatalogDate?
    public var deathDate: CatalogDate?

    public init(naId: String? = nil, heading: String? = nil, authorityType: String? = nil,
                creatorType: String? = nil, contributorType: String? = nil,
                establishDate: CatalogDate? = nil,
                abolishDate: CatalogDate? = nil, birthDate: CatalogDate? = nil,
                deathDate: CatalogDate? = nil) {
        self.naId = naId
        self.heading = heading
        self.authorityType = authorityType
        self.creatorType = creatorType
        self.contributorType = contributorType
        self.establishDate = establishDate
        self.abolishDate = abolishDate
        self.birthDate = birthDate
        self.deathDate = deathDate
    }

    /// Projects one member of a `creators` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        let naId = value["naId"]?.stringValue
        let heading = value["heading"]?.nonEmptyString
        guard naId != nil || heading != nil else { return nil }
        self.init(
            naId: naId,
            heading: heading,
            authorityType: value["authorityType"]?.nonEmptyString,
            creatorType: value["creatorType"]?.nonEmptyString,
            contributorType: value["contributorType"]?.nonEmptyString,
            establishDate: CatalogDate(value["establishDate"]),
            abolishDate: CatalogDate(value["abolishDate"]),
            birthDate: CatalogDate(value["birthDate"]),
            deathDate: CatalogDate(value["deathDate"]))
    }

    /// The agent's role, whichever discriminator the source array used. This is what the creator
    /// census reports, so a `Producer` and a `Most Recent` creator are distinguishable in one column.
    public var role: String? { creatorType ?? contributorType }

    /// Sort key giving agents a total, locale-independent order inside a record.
    var sortKey: String { "\(heading ?? "")\u{1}\(role ?? "")\u{1}\(naId ?? "")" }
}

// MARK: - CatalogControlNumber

/// One entry of `variantControlNumbers` — the **second** thing this harvest exists to capture, and
/// the one where interpretation is most dangerous.
///
/// Verified shape: exactly three keys, `number`, `type`, and an optional free-text `note`. `type`
/// itself is occasionally absent.
///
/// ## Why nothing here is filtered
/// The existing `CentralFilesIndexGeneratorCore` keeps only `type == "HMS/MLR Entry Number"`,
/// exactly, and that is correct *for its purpose*. It would be wrong here. Measured across the
/// export, State Department lot-file numbers are recorded under **both**
/// `"State Department Lot File Number"` **and** `"Agency-Assigned Identifier"` — the latter with
/// thousands of occurrences, distinguishable only by the free-text `note`, which itself appears in
/// several different spellings. `type` is an open vocabulary; NARA's own OpenAPI examples name two
/// values that appear nowhere in the data.
///
/// So this type stores all three strings verbatim, unfiltered and unnormalised, and
/// ``ControlNumberCensus`` reports the observed `(type × note × record group)` cross-tab. Any
/// classification is the census's additive commentary, never a rewrite of the raw value: a
/// filter applied here would silently answer the owner's question wrongly.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CatalogControlNumber: Codable, Sendable, Equatable {
    /// The control number as recorded, verbatim.
    public var number: String?
    /// NARA's type label, verbatim. An open vocabulary — do not switch exhaustively on it.
    public var type: String?
    /// Free-text qualifier, verbatim. Often the only thing distinguishing an agency-specific
    /// number recorded under a generic `type`.
    public var note: String?

    public init(number: String? = nil, type: String? = nil, note: String? = nil) {
        self.number = number
        self.type = type
        self.note = note
    }

    /// Projects one member of a `variantControlNumbers` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        let number = value["number"]?.nonEmptyString
        let type = value["type"]?.nonEmptyString
        let note = value["note"]?.nonEmptyString
        guard number != nil || type != nil || note != nil else { return nil }
        self.init(number: number, type: type, note: note)
    }

    /// Sort key giving control numbers a total, locale-independent order inside a record.
    var sortKey: String { "\(type ?? "")\u{1}\(number ?? "")\u{1}\(note ?? "")" }
}

// MARK: - CatalogAncestor

/// One ancestor in a record's hierarchy chain.
///
/// `recordGroupNumber` appears **only** on the `recordGroup`-level ancestor, never on the record
/// itself (verified: 1 of 12 records in RG 486 carried the key, and it was the group node). This
/// is why record-group attribution reads the ancestor chain rather than a field on the record, and
/// why a record whose chain contains no `recordGroup` cannot be attributed — the #321 failure class
/// in this repo, where records parented by a `collection` were accepted as if they were RG 59/84
/// lots at a measured precision of 0/16.
public struct CatalogAncestor: Codable, Sendable, Equatable {
    public var naId: String?
    public var title: String?
    public var levelOfDescription: String?
    public var distance: Int?
    public var recordGroupNumber: Int?

    public init(naId: String? = nil, title: String? = nil, levelOfDescription: String? = nil,
                distance: Int? = nil, recordGroupNumber: Int? = nil) {
        self.naId = naId
        self.title = title
        self.levelOfDescription = levelOfDescription
        self.distance = distance
        self.recordGroupNumber = recordGroupNumber
    }

    /// Projects one member of an `ancestors` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        self.init(
            naId: value["naId"]?.stringValue,
            title: value["title"]?.nonEmptyString,
            levelOfDescription: value["levelOfDescription"]?.nonEmptyString,
            distance: value["distance"]?.intValue,
            recordGroupNumber: value["recordGroupNumber"]?.intValue)
    }
}

// MARK: - CatalogRestriction

/// An `accessRestriction` or `useRestriction` block.
///
/// Verified shapes, measured over 513 real records (RG 486 in full plus RG 59 shard 1):
/// ```json
/// "accessRestriction": { "status": "Restricted - Possibly", "note": "…",
///   "specificAccessRestrictions": [ { "restriction": "FOIA (b)(6) Personal Information" },
///                                   { "securityClassification": "Secret" } ] }
/// "useRestriction":    { "status": "Restricted - Possibly", "note": "…",
///                        "specificUseRestrictions": [ "Copyright" ] }
/// ```
/// Two asymmetries the projection has to absorb, both measured rather than assumed:
///
/// 1. **The specifics container is named differently** in the two blocks
///    (`specificAccessRestrictions` / `specificUseRestrictions`), so both are tried.
/// 2. **The specifics members are shaped differently.** Access restrictions are objects keyed
///    `restriction`; use restrictions are **bare strings**. Hence the scalar fallback.
///
/// And one outright bug this shape caused: `securityClassification` is **not** a member of the
/// block — it is a member of the *specifics array elements*, alongside `restriction` (measured: 27
/// of 513 records carry one, always nested). Reading it at block level, as this type first did,
/// returned `nil` on every record ever harvested and silently dropped the classification of every
/// classified series. It is collected from the nested elements now, with the block-level read kept
/// only as a fallback in case NARA ever hoists it.
public struct CatalogRestriction: Codable, Sendable, Equatable {
    public var status: String?
    public var note: String?
    /// Flattened specific-restriction labels, sorted.
    public var specificRestrictions: [String]
    /// Security classification(s) found among the specifics, sorted. Plural because the specifics are
    /// an array and nothing guarantees one.
    public var securityClassifications: [String]

    public init(status: String? = nil, note: String? = nil,
                specificRestrictions: [String] = [], securityClassifications: [String] = []) {
        self.status = status
        self.note = note
        self.specificRestrictions = specificRestrictions
        self.securityClassifications = securityClassifications
    }

    /// Projects a restriction block, returning `nil` when nothing usable is present.
    public init?(_ value: CatalogJSONValue?) {
        guard let value, value.objectValue != nil else { return nil }
        let specifics = (value["specificAccessRestrictions"]
                         ?? value["specificUseRestrictions"]
                         ?? value["specificRestrictions"])?.asArray ?? []
        // Objects keyed `restriction` (access) and bare strings (use) both yield their label.
        let labels = specifics
            .compactMap { ($0["restriction"] ?? $0["specificRestriction"])?.nonEmptyString
                            ?? $0.nonEmptyString }
            .sorted()
        // The classification lives on the specifics elements, not on the block.
        var classifications = specifics
            .compactMap { $0["securityClassification"]?.nonEmptyString }
        if let hoisted = value["securityClassification"]?.nonEmptyString {
            classifications.append(hoisted)
        }
        classifications = Array(Set(classifications)).sorted()

        let status = value["status"]?.nonEmptyString
        let note = value["note"]?.nonEmptyString
        guard status != nil || note != nil || !classifications.isEmpty || !labels.isEmpty else {
            return nil
        }
        self.init(status: status, note: note,
                  specificRestrictions: labels, securityClassifications: classifications)
    }
}

// MARK: - CatalogPhysicalOccurrence

/// One `physicalOccurrences` entry — where the records physically are and how much of them there is.
///
/// The `referenceUnits` member carries a full postal address and contact block for the holding
/// facility; only the unit name and city are projected, because the artifact is an index of
/// archival holdings, not a copy of NARA's facility directory. The full block survives in the raw
/// capture and in the field census.
public struct CatalogPhysicalOccurrence: Codable, Sendable, Equatable {
    public var copyStatus: String?
    public var extent: String?
    /// `(count, type)` holdings measurements, e.g. `1 × "Letter Archives Box, Narrow 4 inch"`.
    /// `count` is a `Double` because NARA emits it as one (`1.0`, `13.0`) even for discrete boxes.
    public var holdingsMeasurements: [HoldingsMeasurement]
    public var mediaTypes: [String]
    public var referenceUnitNames: [String]

    public struct HoldingsMeasurement: Codable, Sendable, Equatable {
        public var count: Double?
        public var type: String?
        public init(count: Double? = nil, type: String? = nil) {
            self.count = count
            self.type = type
        }
    }

    public init(copyStatus: String? = nil, extent: String? = nil,
                holdingsMeasurements: [HoldingsMeasurement] = [],
                mediaTypes: [String] = [], referenceUnitNames: [String] = []) {
        self.copyStatus = copyStatus
        self.extent = extent
        self.holdingsMeasurements = holdingsMeasurements
        self.mediaTypes = mediaTypes
        self.referenceUnitNames = referenceUnitNames
    }

    /// Projects one member of a `physicalOccurrences` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        let measurements = (value["holdingsMeasurements"]?.asArray ?? []).compactMap {
            m -> HoldingsMeasurement? in
            let count = m["count"]?.doubleValue
            let type = m["type"]?.nonEmptyString
            guard count != nil || type != nil else { return nil }
            return HoldingsMeasurement(count: count, type: type)
        }
        var media: [String] = []
        for occurrence in value["mediaOccurrences"]?.asArray ?? [] {
            if let specific = occurrence["specificMediaType"]?.nonEmptyString {
                media.append(specific)
            }
            media.append(contentsOf: (occurrence["generalMediaTypes"]?.asArray ?? [])
                .compactMap(\.nonEmptyString))
        }
        let units = (value["referenceUnits"]?.asArray ?? [])
            .compactMap { $0["name"]?.nonEmptyString }
        let copyStatus = value["copyStatus"]?.nonEmptyString
        let extent = value["extent"]?.nonEmptyString
        guard copyStatus != nil || extent != nil || !measurements.isEmpty
                || !media.isEmpty || !units.isEmpty else { return nil }
        self.init(copyStatus: copyStatus, extent: extent,
                  holdingsMeasurements: measurements,
                  mediaTypes: Array(Set(media)).sorted(),
                  referenceUnitNames: Array(Set(units)).sorted())
    }
}

// MARK: - CatalogOnlineResource

/// One `onlineResources` entry — an off-site place the records can be viewed.
///
/// Measured shape: `{ "description": "Ancestry", "note": "This file was scanned as part of a
/// collaboration effort between Ancestry and the National Archives.",
/// "url": "https://www.ancestry.com/search/collections/1664/" }`. Worth keeping because it records
/// digitisation that lives *outside* NARA's own catalog, which no other field reveals.
public struct CatalogOnlineResource: Codable, Sendable, Equatable {
    public var url: String?
    public var description: String?
    public var note: String?

    public init(url: String? = nil, description: String? = nil, note: String? = nil) {
        self.url = url
        self.description = description
        self.note = note
    }

    /// Projects one member of an `onlineResources` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        let url = value["url"]?.nonEmptyString
        let description = value["description"]?.nonEmptyString
        let note = value["note"]?.nonEmptyString
        guard url != nil || description != nil || note != nil else { return nil }
        self.init(url: url, description: description, note: note)
    }

    var sortKey: String { "\(url ?? "")\u{1}\(description ?? "")" }
}

// MARK: - CatalogDigitalObject

/// One `digitalObjects` entry — a scanned page, photograph or film reel.
///
/// **`extractedText` and `completeExtractedText` are deliberately not projected.** They are the OCR
/// transcription, they are enormous (they are the reason RG 59's shards total 17.2 GB), and an index
/// of archival holdings has no use for them — a full-text corpus is a different artifact with
/// different storage requirements. Everything needed to *fetch* the object is kept.
public struct CatalogDigitalObject: Codable, Sendable, Equatable {
    public var objectId: String?
    public var objectType: String?
    public var objectUrl: String?
    public var objectFilename: String?
    public var objectFileSize: Int?
    public var objectDescription: String?
    public var objectDesignator: String?
    /// Whether NARA holds an OCR transcription for this object. The flag is kept even though the text
    /// is not, so a consumer can tell that full text exists without this index carrying it.
    public var hasExtractedText: Bool

    public init(objectId: String? = nil, objectType: String? = nil, objectUrl: String? = nil,
                objectFilename: String? = nil, objectFileSize: Int? = nil,
                objectDescription: String? = nil, objectDesignator: String? = nil,
                hasExtractedText: Bool = false) {
        self.objectId = objectId
        self.objectType = objectType
        self.objectUrl = objectUrl
        self.objectFilename = objectFilename
        self.objectFileSize = objectFileSize
        self.objectDescription = objectDescription
        self.objectDesignator = objectDesignator
        self.hasExtractedText = hasExtractedText
    }

    /// Projects one member of a `digitalObjects` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        let id = value["objectId"]?.stringValue
        let url = value["objectUrl"]?.nonEmptyString
        guard id != nil || url != nil else { return nil }
        self.init(objectId: id,
                  objectType: value["objectType"]?.nonEmptyString,
                  objectUrl: url,
                  objectFilename: value["objectFilename"]?.nonEmptyString,
                  objectFileSize: value["objectFileSize"]?.intValue,
                  objectDescription: value["objectDescription"]?.nonEmptyString,
                  objectDesignator: value["objectDesignator"]?.nonEmptyString,
                  hasExtractedText: value.hasKey("extractedText")
                      || value.hasKey("completeExtractedText"))
    }

    var sortKey: String { "\(objectId ?? "")\u{1}\(objectUrl ?? "")" }
}

// MARK: - CatalogFindingAid

/// One `findingAids` entry — how to actually find things inside a series.
///
/// Measured member keys: `findingAidType` (11/11 of the sampled entries), `note` (11/11),
/// `fileFormat` (4), `source` (4). For example:
/// ```json
/// { "findingAidType": "Container List",
///   "note": "An agency provided container list is located with the reference unit." }
/// ```
/// Projected as a struct rather than flattened to a string, because flattening lost the thing a
/// researcher most wants. The generic list flattener was given the candidate keys
/// `["note", "type", "source"]` — and NARA's key is `findingAidType`, not `type`. So the *kind* of
/// finding aid was never captured at all, and for any entry without a `note` the flattener fell
/// through to `source` and stored the holding institution's name as though it were the finding aid.
public struct CatalogFindingAid: Codable, Sendable, Equatable {
    /// e.g. `Container List`, `Index`, `Folder Title List`.
    public var findingAidType: String?
    /// Descriptive note — usually where the aid physically is.
    public var note: String?
    /// Institution or agency that produced it.
    public var source: String?
    /// e.g. `PDF`.
    public var fileFormat: String?

    public init(findingAidType: String? = nil, note: String? = nil,
                source: String? = nil, fileFormat: String? = nil) {
        self.findingAidType = findingAidType
        self.note = note
        self.source = source
        self.fileFormat = fileFormat
    }

    /// Projects one member of a `findingAids` array.
    public init?(_ value: CatalogJSONValue) {
        // A bare string is accepted too, in case NARA ever simplifies the shape.
        if value.objectValue == nil {
            guard let scalar = value.nonEmptyString else { return nil }
            self.init(note: scalar)
            return
        }
        let type = (value["findingAidType"] ?? value["type"])?.nonEmptyString
        let note = value["note"]?.nonEmptyString
        let source = value["source"]?.nonEmptyString
        let format = value["fileFormat"]?.nonEmptyString
        guard type != nil || note != nil || source != nil || format != nil else { return nil }
        self.init(findingAidType: type, note: note, source: source, fileFormat: format)
    }

    var sortKey: String { "\(findingAidType ?? "")\u{1}\(note ?? "")\u{1}\(source ?? "")" }
}

// MARK: - CatalogSubject

/// One `subjects` entry.
///
/// NARA folds every authority kind into this single array, discriminated by `authorityType`
/// (`topicalSubject`, `geographicPlaceName`, `specificRecordsType`, `organization`, `person`).
/// There are no separate `topicalSubjects` / `geographicReferences` keys, so a projection looking
/// for those would find nothing.
public struct CatalogSubject: Codable, Sendable, Equatable {
    public var naId: String?
    public var heading: String?
    public var authorityType: String?

    public init(naId: String? = nil, heading: String? = nil, authorityType: String? = nil) {
        self.naId = naId
        self.heading = heading
        self.authorityType = authorityType
    }

    /// Projects one member of a `subjects` array.
    public init?(_ value: CatalogJSONValue) {
        guard value.objectValue != nil else { return nil }
        let heading = value["heading"]?.nonEmptyString
        let naId = value["naId"]?.stringValue
        guard heading != nil || naId != nil else { return nil }
        self.init(naId: naId, heading: heading,
                  authorityType: value["authorityType"]?.nonEmptyString)
    }

    var sortKey: String { "\(authorityType ?? "")\u{1}\(heading ?? "")\u{1}\(naId ?? "")" }
}
