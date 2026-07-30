// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CreatorAuthorityRecord

/// A creating organization's or person's own NARA **authority record** — the enrichment behind
/// `creators[].naId`.
///
/// A description record's `creators` array carries only an identifier, a heading and a date span.
/// The authority record carries the prose: for an organization, `administrativeHistoryNote` (often
/// several paragraphs on the statutory basis, the reorganisations and the successor agency), the
/// full `organizationNames` succession chain, its jurisdictions and program areas; for a person, a
/// `biographicalNote`, variant names and life dates.
///
/// For a foreign-affairs harvest this is the difference between "created by U.S. International
/// Development Cooperation Agency. Trade and Development Program." and knowing that the office was
/// established 1980-07-01, abolished 1992-10-27, and succeeded by the U.S. Trade and Development
/// Agency — which is what tells a researcher which agency's files to look in for the years either
/// side of the citation.
///
/// Only the authority records actually referenced by harvested records are retained. NARA's
/// organization authority file alone is 400 shards / ~162 MB and covers the whole federal
/// government; a foreign-affairs index has no use for the other departments' offices.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CreatorAuthorityRecord: Codable, Sendable, Equatable {

    /// Authority NAID — matches `creators[].naId` on the description records.
    public var naId: String
    /// Preferred heading, inclusive of its date span.
    public var heading: String?
    /// `organization` | `person`.
    public var authorityType: String?
    /// Bare name without the parenthetical date span, when NARA supplies it separately.
    public var name: String?
    /// Whether this is NARA's preferred form for the entity.
    public var preferred: Bool?

    // MARK: Organization fields

    /// Administrative history prose. The single most valuable field here.
    public var administrativeHistoryNote: String?
    /// The succession chain: each name this entity has held, with its own NAID and date span.
    public var organizationNames: [AuthorityName]
    /// Jurisdiction labels.
    public var jurisdictions: [String]
    /// Program-area labels.
    public var programAreas: [String]

    // MARK: Person fields

    /// Biographical prose.
    public var biographicalNote: String?
    public var birthDate: CatalogDate?
    public var deathDate: CatalogDate?
    public var fullerFormOfName: String?
    public var personalTitle: String?
    /// Variant name forms.
    public var variantNames: [String]

    // MARK: Shared

    /// Citation notes for the authority record itself.
    public var sourceNotes: [String]
    /// Deep link to the authority record in the catalog.
    public var catalogURL: String

    /// The `creators[].naId` values on description records that this authority record answers for.
    ///
    /// Usually **not** the same as ``naId``. See ``resolvedVia``.
    public var matchedCreatorNaIds: [String]

    /// How the join was made: `self` when a description record's `creators[].naId` equalled this
    /// record's own NAID, `organizationNames` when it matched one of the nested name variants,
    /// `variantNames` for the person-side equivalent.
    ///
    /// ## Why this field exists
    /// The obvious join — `creators[].naId == authorityRecord.naId` — is **wrong for most records**,
    /// and finding that out is the single most valuable thing the first live run did. Measured on
    /// RG 486: all three of its creator NAIDs (10514123, 10514124, 475680186) appear nowhere as a
    /// top-level authority record among the 63,535 in NARA's organization export. Each is instead a
    /// nested `organizationNames[].naId` inside a *different* parent authority record (10566287,
    /// 10566288, 475680185 respectively).
    ///
    /// NARA's model is that an authority record holds an entity's whole succession of names, each
    /// name carrying its own NAID, and a description record cites the **name** in force when the
    /// records were created — not the entity. So the join must consider the nested names, and the
    /// naive version silently resolves nothing at all: the first run of this tool reported
    /// "0 resolved, 3 unresolved", which is what sent us looking.
    public var resolvedVia: String?

    /// Raw keys this projection did not map, sorted. Same anti-silence role as
    /// ``HarvestedRecord/unprojectedKeys``.
    public var unprojectedKeys: [String]

    /// One name in a succession chain.
    public struct AuthorityName: Codable, Sendable, Equatable {
        public var naId: String?
        public var name: String?
        public var heading: String?
        public var establishDate: CatalogDate?
        public var abolishDate: CatalogDate?

        public init(naId: String? = nil, name: String? = nil, heading: String? = nil,
                    establishDate: CatalogDate? = nil, abolishDate: CatalogDate? = nil) {
            self.naId = naId
            self.name = name
            self.heading = heading
            self.establishDate = establishDate
            self.abolishDate = abolishDate
        }

        /// Projects one member of `organizationNames`.
        init?(_ value: CatalogJSONValue) {
            guard value.objectValue != nil else { return nil }
            let naId = value["naId"]?.stringValue
            let name = value["name"]?.nonEmptyString
            let heading = value["heading"]?.nonEmptyString
            guard naId != nil || name != nil || heading != nil else { return nil }
            self.init(naId: naId, name: name, heading: heading,
                      establishDate: CatalogDate(value["establishDate"]),
                      abolishDate: CatalogDate(value["abolishDate"]))
        }

        var sortKey: String {
            "\(establishDate?.logicalDate ?? "")\u{1}\(heading ?? name ?? "")\u{1}\(naId ?? "")"
        }
    }

    /// Raw keys this projection reads. `role`, `linkCounts`, `importRecordControlNumber` and the
    /// cross-reference arrays are listed as consumed-but-unused: they are catalog plumbing rather
    /// than description, and listing them keeps ``unprojectedKeys`` meaningful — a tripwire that
    /// fires on every record for a known-uninteresting field is a tripwire nobody reads.
    static let consumedKeys: Set<String> = [
        "naId", "heading", "authorityType", "recordType", "name", "preferred",
        "administrativeHistoryNote", "organizationNames", "jurisdictions", "programAreas",
        "biographicalNote", "birthDate", "deathDate", "fullerFormOfName", "personalTitle",
        "variantPersonNames", "variantOrganizationNames", "sourceNotes",
        "role", "linkCounts", "importRecordControlNumber",
        "organizationalReferences", "personalReferences",
    ]

    /// Every NAID by which a description record's `creators[].naId` may reach this authority record:
    /// its own, plus each nested name variant's.
    ///
    /// The nested ones do the real work — see ``resolvedVia``.
    var joinableNaIds: [(naId: String, via: String)] {
        var out: [(String, String)] = [(naId, "self")]
        for name in organizationNames {
            if let nested = name.naId { out.append((nested, "organizationNames")) }
        }
        return out
    }

    /// Projects one raw authority record, or `nil` if it carries no NAID.
    public init?(_ record: CatalogJSONValue) {
        guard let naId = record["naId"]?.nonEmptyString else { return nil }
        self.naId = naId
        self.heading = record["heading"]?.nonEmptyString
        self.authorityType = record["authorityType"]?.nonEmptyString
        self.name = record["name"]?.nonEmptyString
        self.preferred = record["preferred"]?.boolValue
        self.administrativeHistoryNote = record["administrativeHistoryNote"]?.nonEmptyString
        self.organizationNames = (record["organizationNames"]?.asArray ?? [])
            .compactMap(AuthorityName.init)
            .sorted { $0.sortKey < $1.sortKey }
        self.jurisdictions = RecordProjector.stringList(
            record["jurisdictions"], preferredKeys: ["heading", "name", "jurisdiction"])
        self.programAreas = RecordProjector.stringList(
            record["programAreas"], preferredKeys: ["heading", "name", "programArea"])
        self.biographicalNote = record["biographicalNote"]?.nonEmptyString
        self.birthDate = CatalogDate(record["birthDate"])
        self.deathDate = CatalogDate(record["deathDate"])
        self.fullerFormOfName = record["fullerFormOfName"]?.nonEmptyString
        self.personalTitle = record["personalTitle"]?.nonEmptyString
        // The variant-name key differs by authority type; both are read so neither kind loses them.
        self.variantNames = RecordProjector.stringList(
            record["variantPersonNames"] ?? record["variantOrganizationNames"],
            preferredKeys: ["heading", "name"])
        self.sourceNotes = RecordProjector.stringList(
            record["sourceNotes"], preferredKeys: ["note", "source", "text"])
        self.catalogURL = RecordProjector.catalogIDBase + naId
        self.matchedCreatorNaIds = []
        self.resolvedVia = nil
        self.unprojectedKeys = (record.objectValue?.keys
            .filter { !Self.consumedKeys.contains($0) } ?? []).sorted()
    }

    /// Every NAID a description record's `creators[].naId` might use to reach this authority record,
    /// read from the **raw** tree rather than the projection.
    ///
    /// Read from the raw tree deliberately: the projected `variantNames` are flattened to strings and
    /// have already lost their NAIDs, so a projection-based join would work for organizations (whose
    /// `organizationNames` survive as structs) and silently fail for any other nested-name shape.
    static func joinableNaIds(in record: CatalogJSONValue) -> [(naId: String, via: String)] {
        var out: [(naId: String, via: String)] = []
        if let own = record["naId"]?.nonEmptyString { out.append((own, "self")) }
        for key in ["organizationNames", "variantOrganizationNames", "variantPersonNames"] {
            for name in record[key]?.asArray ?? [] {
                if let nested = name["naId"]?.nonEmptyString { out.append((nested, key)) }
            }
        }
        return out
    }
}

// MARK: - CreatorAuthorityHarvester

/// Streams NARA's authority-record shards and keeps only the records a harvest actually references.
///
/// ## Cost and why it is opt-in
/// The organization authority file is 400 shards totalling ~162 MB and the person file is comparable
/// — a full pass is therefore a few hundred megabytes of transfer on top of the description harvest,
/// and it is pure waste if the caller only wanted the index. So the pass runs on request
/// (`CREATOR_AUTHORITY=1`), and it short-circuits: once every wanted NAID has been found the
/// remaining shards are skipped, which in practice ends the scan well before shard 400 because the
/// wanted set is small and the shards are not ordered by relevance.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CreatorAuthorityHarvester: Sendable {

    /// Authority kinds that can appear as `creators[].authorityType`. The other three kinds NARA
    /// publishes (`topical-subject`, `geographic-reference`, `specific-records-type`) are subject
    /// authorities and never creators, so they are not scanned.
    public static let creatorKinds = ["organization", "person"]

    private let client: CatalogBulkExportClient
    private let log: @Sendable (String) -> Void

    public init(client: CatalogBulkExportClient, log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.client = client
        self.log = log
    }

    /// The result of an authority pass.
    public struct Result: Sendable, Equatable {
        /// Matched authority records, keyed by the **authority record's own** NAID.
        ///
        /// Keyed by the authority record rather than by the creator reference because one authority
        /// record commonly answers several creator NAIDs — the successive names of one office. Each
        /// record's ``CreatorAuthorityRecord/matchedCreatorNaIds`` carries the references it
        /// satisfies, so the creator-to-authority direction is still a lookup away without
        /// duplicating the administrative-history prose per reference.
        public var records: [String: CreatorAuthorityRecord] = [:]
        /// NAIDs that were wanted but never found in any shard.
        ///
        /// Reported rather than ignored: a referenced creator with no authority record is a real
        /// gap in NARA's data (or a stale reference), and the count is the reader's cue for how
        /// complete the enrichment is.
        public var unresolvedNaIds: [String] = []
        /// Shards actually fetched, per kind.
        public var shardsRead: [String: Int] = [:]
        /// Bytes fetched.
        public var bytesRead = 0
        /// Authority NDJSON lines that failed to decode.
        public var malformedLines = 0
        /// A few example decode failures.
        public var malformedExamples: [String] = []

        /// `true` when the pass stopped on its byte budget with creators still outstanding.
        ///
        /// The distinction this exists to protect: unresolved NAIDs after a *complete* scan mean NARA
        /// has no authority record for those creators — a real fact about the data. Unresolved NAIDs
        /// after a *truncated* scan mean only that this run stopped early. Reporting the second as the
        /// first would put a false claim about NARA's holdings into the manifest.
        public var truncatedByBudget = false
    }

    /// Fetches the authority records for `naIds`, stopping early once all are found.
    ///
    /// - Parameters:
    ///   - naIds: creator NAIDs to resolve, from ``CreatorCensus/referencedNaIds``.
    ///   - byteBudget: hard ceiling on bytes fetched by this pass. `nil` for unlimited.
    public func harvest(naIds: Set<String>, byteBudget: Int? = nil) async throws -> Result {
        var result = Result()
        guard !naIds.isEmpty else { return result }
        var wanted = naIds
        var malformedLines = 0
        var malformedExamples: [String] = []

        for kind in Self.creatorKinds {
            if wanted.isEmpty || result.truncatedByBudget { break }
            let shards = try await client.listShards(
                prefix: CatalogBulkExportClient.authorityPrefix(kind: kind))
            log("[RecordGroupCatalogGenerator] authority/\(kind): \(shards.count) shards, "
                + "\(wanted.count) creators still wanted")

            for shard in shards {
                if wanted.isEmpty { break }
                if let byteBudget, result.bytesRead >= byteBudget {
                    log("[RecordGroupCatalogGenerator] authority pass stopped: byte budget reached "
                        + "with \(wanted.count) creators unresolved")
                    result.truncatedByBudget = true
                    break
                }
                var found = 0
                let bytes = try await client.streamRecords(
                    shard: shard,
                    // Decode failures are surfaced, not swallowed. The default no-op closure hid
                    // them here during development, which made "0 resolved" ambiguous between "the
                    // join is wrong" and "nothing parsed" and cost a diagnostic detour.
                    onMalformedLine: { line, error in
                        malformedLines += 1
                        if malformedExamples.count < 5 {
                            malformedExamples.append("\(shard.key):\(line): \(error)")
                        }
                    },
                    body: { record in
                        // A creator reference may name this authority record itself or any of its
                        // nested name variants — see CreatorAuthorityRecord.resolvedVia.
                        let matches = CreatorAuthorityRecord.joinableNaIds(in: record)
                            .filter { wanted.contains($0.naId) }
                        guard !matches.isEmpty else { return }
                        guard var projected = CreatorAuthorityRecord(record) else { return }

                        projected.matchedCreatorNaIds = matches.map(\.naId).sorted()
                        // A self-match is the more precise description of the relationship, so it
                        // wins when a record matches both ways.
                        projected.resolvedVia = matches.contains { $0.via == "self" }
                            ? "self"
                            : matches[0].via

                        result.records[projected.naId] = projected
                        for match in matches { wanted.remove(match.naId) }
                        found += matches.count
                    })
                result.bytesRead += bytes
                result.shardsRead[kind, default: 0] += 1
                if found > 0 {
                    log("[RecordGroupCatalogGenerator]   \(shard.key): +\(found) "
                        + "(\(wanted.count) remaining)")
                }
            }
        }

        result.unresolvedNaIds = wanted.sorted()
        result.malformedLines = malformedLines
        result.malformedExamples = malformedExamples
        return result
    }
}

// MARK: - CreatorAuthorityIndex

/// The committed creator-authority artifact.
public struct CreatorAuthorityIndex: Codable, Sendable, Equatable {
    /// Schema version, so a consumer can refuse an index it does not understand.
    public var schemaVersion: Int
    /// `yyyy-MM-dd` generation stamp.
    public var generated: String
    /// Authority records, sorted by NAID for a stable diff.
    public var creators: [CreatorAuthorityRecord]
    /// Referenced NAIDs with no authority record found.
    public var unresolvedNaIds: [String]

    /// Current schema version emitted by this generator.
    public static let currentSchemaVersion = 1

    public init(schemaVersion: Int = CreatorAuthorityIndex.currentSchemaVersion,
                generated: String,
                creators: [CreatorAuthorityRecord],
                unresolvedNaIds: [String] = []) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.creators = creators.sorted { $0.naId.compare($1.naId, options: .numeric) == .orderedAscending }
        self.unresolvedNaIds = unresolvedNaIds.sorted()
    }
}
