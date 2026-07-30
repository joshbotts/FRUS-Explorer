// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import RecordGroupCatalogGeneratorCore

// MARK: - ScriptedTransport

/// An in-memory ``CatalogBulkTransport`` that serves canned bodies by URL and records every request.
///
/// This is the repo's first stubbed transport: no existing generator test injects the `session:`
/// parameter its client already accepts, so the paging, caching and resume paths have never had
/// coverage at any level. One request-log-keeping stub buys the whole pipeline an offline test.
final class ScriptedTransport: CatalogBulkTransport, @unchecked Sendable {

    /// URL suffix → body. Matched by suffix so tests need not spell the origin.
    private let bodies: [String: Data]
    private let lock = NSLock()
    private var _requests: [String] = []

    /// Every URL requested, in order.
    var requests: [String] { lock.withLock { _requests } }

    init(bodies: [String: String]) {
        self.bodies = bodies.mapValues { Data($0.utf8) }
    }

    func body(of url: URL) async throws -> Data {
        let absolute = url.absoluteString
        // `withLock` rather than `lock()`/`unlock()`: the bare calls are unavailable from an async
        // context under Swift 6, since holding a lock across a suspension point is unsound.
        lock.withLock { _requests.append(absolute) }
        // Listing requests carry a query; shard requests do not.
        if let match = bodies.first(where: { absolute.hasSuffix($0.key) })?.value { return match }
        if absolute.contains("list-type=2"),
           let prefix = URLComponents(string: absolute)?
               .queryItems?.first(where: { $0.name == "prefix" })?.value,
           let match = bodies["LIST:" + prefix] {
            return match
        }
        throw CatalogBulkError.badHTTPStatus(absolute, 404)
    }
}

// MARK: - Fixture builders

/// Collapses each pretty-printed record fixture onto a single line and joins them into an NDJSON
/// shard body.
///
/// Necessary because the fixtures are written multi-line for readability while the export is strictly
/// one JSON object per line — feeding a multi-line fixture through the transport makes every line a
/// fragment, and the harvest then reports zero records with every line counted as malformed. (That is
/// how these tests first failed, which is the behaviour working as intended: a silent zero would have
/// been far worse.)
///
/// Safe to join with no separator because no fixture breaks a line inside a string literal.
func ndjsonShard(_ records: [String]) -> String {
    records.map { $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined() }
        .joined(separator: "\n") + "\n"
}

extension ScriptedTransport {

    /// An S3 `ListObjectsV2` response for the given keys.
    static func listing(keys: [(key: String, size: Int)],
                        lastModified: String = "2026-04-09T13:45:50.000Z") -> String {
        let contents = keys.map { entry in
            """
            <Contents><Key>\(entry.key)</Key><LastModified>\(lastModified)</LastModified>\
            <ETag>&quot;abc123&quot;</ETag><Size>\(entry.size)</Size></Contents>
            """
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult><Name>nara-national-archives-catalog</Name>\
        <KeyCount>\(keys.count)</KeyCount><IsTruncated>false</IsTruncated>\(contents)\
        </ListBucketResult>
        """
    }
}

// MARK: - S3ListingParserTests

/// Tests the listing parser.
struct S3ListingParserTests {

    @Test("Parses keys, sizes, LastModified and ETag, and decodes XML entities")
    func parsesListing() {
        let xml = ScriptedTransport.listing(keys: [
            ("descriptions/record-groups/rg_486/rg_486-1.jsonl", 3805),
        ])
        let page = S3ListingParser.parse(Data(xml.utf8))
        #expect(page.shards.count == 1)
        #expect(page.shards[0].key == "descriptions/record-groups/rg_486/rg_486-1.jsonl")
        #expect(page.shards[0].size == 3805)
        #expect(page.shards[0].lastModified == "2026-04-09T13:45:50.000Z")
        // The ETag arrives &quot;-escaped and quote-wrapped; both are stripped.
        #expect(page.shards[0].eTag == "abc123")
        #expect(page.isTruncated == false)
    }

    @Test("Reports truncation and the continuation token")
    func parsesTruncation() {
        let xml = """
        <ListBucketResult><IsTruncated>true</IsTruncated>
        <NextContinuationToken>1ueGcx</NextContinuationToken>
        <Contents><Key>a.jsonl</Key><Size>1</Size></Contents></ListBucketResult>
        """
        let page = S3ListingParser.parse(Data(xml.utf8))
        #expect(page.isTruncated)
        #expect(page.nextContinuationToken == "1ueGcx")
    }

    @Test("Shard order is numeric, not S3's lexicographic order")
    func sortsShardsNumerically() async throws {
        // S3 lists rg_486-1, rg_486-10, rg_486-11, rg_486-2 … Harvest order must be numeric or the
        // checkpoint's "last completed shard index" does not mean what it says.
        let keys = [1, 10, 11, 2, 3].map {
            (key: "descriptions/record-groups/rg_486/rg_486-\($0).jsonl", size: 100)
        }
        let transport = ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_486/": ScriptedTransport.listing(keys: keys),
        ])
        let client = CatalogBulkExportClient(transport: transport)
        let shards = try await client.listDescriptionShards(recordGroup: 486)
        #expect(shards.map(\.shardIndex) == [1, 2, 3, 10, 11])
    }

    @Test("Directory markers and non-JSONL keys are not shards")
    func filtersNonShards() async throws {
        let transport = ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_486/": ScriptedTransport.listing(keys: [
                ("descriptions/record-groups/rg_486/", 0),
                ("descriptions/record-groups/rg_486/README.txt", 10),
                ("descriptions/record-groups/rg_486/rg_486-1.jsonl", 100),
            ]),
        ])
        let shards = try await CatalogBulkExportClient(transport: transport)
            .listDescriptionShards(recordGroup: 486)
        #expect(shards.count == 1)
    }

    @Test("A record group with no shards throws rather than reporting an empty harvest")
    func throwsOnEmptyListing() async throws {
        // Almost always a wrong record group number — a real group always has at least its own node.
        let transport = ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_9999/": ScriptedTransport.listing(keys: []),
        ])
        await #expect(throws: CatalogBulkError.emptyShardListing(9999)) {
            _ = try await CatalogBulkExportClient(transport: transport)
                .listDescriptionShards(recordGroup: 9999)
        }
    }
}

// MARK: - RecordGroupHarvestPlanTests

/// Tests plan and depth resolution.
struct RecordGroupHarvestPlanTests {

    @Test("Defaults to the 22 commissioned record groups")
    func defaultsToTheCommissionedSet() throws {
        let plan = try RecordGroupHarvestPlan.resolve(
            recordGroups: nil, depth: nil, depthOverrides: nil)
        #expect(plan.groups.count == 22)
        #expect(plan.groups.map(\.number) == RecordGroupHarvestPlan.defaultRecordGroupNumbers)
        #expect(plan.groups.allSatisfy { $0.depth == .series })
        #expect(plan.groups.map(\.number).contains(59))
        #expect(plan.groups.map(\.number).contains(490))
    }

    @Test("Parses an explicit list, preserving order and dropping duplicates")
    func parsesExplicitList() throws {
        let plan = try RecordGroupHarvestPlan.resolve(
            recordGroups: "486, 59,486 84", depth: nil, depthOverrides: nil)
        #expect(plan.groups.map(\.number) == [486, 59, 84])
    }

    @Test("Applies per-record-group depth overrides — the file-units-later path")
    func appliesDepthOverrides() throws {
        let plan = try RecordGroupHarvestPlan.resolve(
            recordGroups: "59,84,486", depth: "series",
            depthOverrides: "486:seriesAndFileUnits")
        #expect(plan.groups.first { $0.number == 486 }?.depth == .seriesAndFileUnits)
        #expect(plan.groups.first { $0.number == 59 }?.depth == .series)
    }

    @Test("A typo'd depth throws rather than silently harvesting series only")
    func rejectsInvalidDepth() {
        // DEPTH=fileUnits that quietly degraded to `series` would look like a successful run and
        // produce an index claiming a depth it does not have.
        #expect(throws: RecordGroupHarvestPlanError.invalidDepth("fileUnits")) {
            _ = try RecordGroupHarvestPlan.resolve(
                recordGroups: nil, depth: "fileUnits", depthOverrides: nil)
        }
        #expect(throws: RecordGroupHarvestPlanError.invalidRecordGroup("fifty-nine")) {
            _ = try RecordGroupHarvestPlan.resolve(
                recordGroups: "fifty-nine", depth: nil, depthOverrides: nil)
        }
        #expect(throws: RecordGroupHarvestPlanError.malformedOverride("486")) {
            _ = try RecordGroupHarvestPlan.resolve(
                recordGroups: nil, depth: nil, depthOverrides: "486")
        }
    }

    @Test("An override for an unselected record group throws")
    func rejectsStrayOverride() {
        // Otherwise the override is silently ignored and the operator believes a group was
        // harvested deeper than it was.
        #expect(throws: RecordGroupHarvestPlanError.overrideForUnselectedGroup(59)) {
            _ = try RecordGroupHarvestPlan.resolve(
                recordGroups: "486", depth: nil, depthOverrides: "59:all")
        }
    }

    @Test("Depth admits exactly the intended levels and never the record-group node as a record")
    func admitsLevels() {
        #expect(HarvestDepth.series.admits("series"))
        #expect(!HarvestDepth.series.admits("fileUnit"))
        #expect(HarvestDepth.seriesAndFileUnits.admits("fileUnit"))
        #expect(!HarvestDepth.seriesAndFileUnits.admits("item"))
        #expect(HarvestDepth.all.admits("item"))
        #expect(!HarvestDepth.all.admits(nil))
        for depth in HarvestDepth.allCases {
            #expect(!depth.admits("recordGroup"), "\(depth.rawValue) must not admit the group node")
        }
    }
}

// MARK: - HarvestCheckpointTests

/// Tests resume semantics.
struct HarvestCheckpointTests {

    @Test("Resumes after the last completed shard")
    func resumesAfterLastShard() {
        let checkpoint = HarvestCheckpoint(
            recordGroup: 59, depth: .series, lastCompletedShardIndex: 137, shardCount: 400)
        #expect(checkpoint.resumability(depth: .series, shardCount: 400)
                == .resume(fromShardIndexAfter: 137))
    }

    @Test("A finished group is skipped, not re-fetched")
    func reportsComplete() {
        let checkpoint = HarvestCheckpoint(
            recordGroup: 486, depth: .series, lastCompletedShardIndex: 12, shardCount: 12)
        #expect(checkpoint.resumability(depth: .series, shardCount: 12) == .complete)
    }

    @Test("A deeper depth refuses to resume, because the shallow pass never read those levels")
    func refusesDepthEscalation() {
        // Resuming would skip the already-read shards and so miss every file unit in them,
        // producing an index that claims a depth it does not have.
        let checkpoint = HarvestCheckpoint(
            recordGroup: 486, depth: .series, lastCompletedShardIndex: 6, shardCount: 12)
        let resumability = checkpoint.resumability(depth: .seriesAndFileUnits, shardCount: 12)
        #expect(resumability == .refuseDepthChanged(from: .series, to: .seriesAndFileUnits))
        // The refusal must name the flag that clears it.
        #expect(resumability.refusalMessage?.contains("REFRESH=1") == true)
    }

    @Test("A changed shard count refuses — NARA has re-published the snapshot")
    func refusesShardCountChange() {
        let checkpoint = HarvestCheckpoint(
            recordGroup: 486, depth: .series, lastCompletedShardIndex: 6, shardCount: 12)
        let resumability = checkpoint.resumability(depth: .series, shardCount: 14)
        #expect(resumability == .refuseShardCountChanged(from: 12, to: 14))
        #expect(resumability.refusalMessage?.contains("REFRESH=1") == true)
    }

    @Test("A truncated checkpoint file is treated as absent, not as corrupt state")
    func toleratesTruncatedCheckpoint() throws {
        // Writes are atomic so this should not arise — but a crash mid-write is exactly when the
        // recovery path must be forgiving rather than stalling the run.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ckpt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CheckpointStore(directory: directory)
        try Data("{\"recordGroup\":48".utf8)
            .write(to: directory.appendingPathComponent("rg_486.json"))
        #expect(store.load(recordGroup: 486) == nil)

        let checkpoint = HarvestCheckpoint(recordGroup: 486, depth: .series,
                                           lastCompletedShardIndex: 3, shardCount: 12)
        try store.save(checkpoint)
        #expect(store.load(recordGroup: 486) == checkpoint)
        try store.reset(recordGroup: 486)
        #expect(store.load(recordGroup: 486) == nil)
    }
}

// MARK: - CreatorAuthorityJoinTests

/// Tests the creator → authority join.
struct CreatorAuthorityJoinTests {

    /// A real organization authority record shape: the parent holds the succession of names, and each
    /// name carries its own NAID.
    static let parentAuthority = """
    {"record":{"naId":10566287,
      "heading":"U.S. International Development Cooperation Agency. Trade and Development Program. (07/01/1980 - 10/27/1992)",
      "authorityType":"organization","recordType":"authority","preferred":true,
      "administrativeHistoryNote":"The Trade and Development Program (TDP) was established July 1, 1980…",
      "organizationNames":[{"naId":10514123,
        "name":"U.S. International Development Cooperation Agency. Trade and Development Program.",
        "heading":"U.S. International Development Cooperation Agency. Trade and Development Program. (07/01/1980 - 10/27/1992)",
        "establishDate":{"day":1,"logicalDate":"1980-07-01","month":7,"year":1980},
        "abolishDate":{"day":27,"logicalDate":"1992-10-27","month":10,"year":1992}}],
      "programAreas":[{"heading":"Foreign Affairs"}],
      "sourceNotes":[{"note":"Reorganization Plan No. 2 of 1979"}]}}
    """

    @Test("A creator NAID matches a NESTED organizationNames entry, not the record's own NAID")
    func joinsOnNestedNames() async throws {
        // The measured lesson from the first live run: all three of RG 486's creator NAIDs
        // (10514123, 10514124, 475680186) appear nowhere among the 63,535 top-level organization
        // authority records. Each is a nested organizationNames[].naId inside a DIFFERENT parent.
        // The naive naId == naId join resolves nothing at all, which is exactly what the first run
        // reported before this was fixed.
        let transport = ScriptedTransport(bodies: [
            "LIST:authority-records/organization/": ScriptedTransport.listing(keys: [
                ("authority-records/organization/organization-1.jsonl", 500),
            ]),
            "authority-records/organization/organization-1.jsonl": ndjsonShard([Self.parentAuthority]),
            "LIST:authority-records/person/": ScriptedTransport.listing(keys: []),
        ])
        let harvester = CreatorAuthorityHarvester(
            client: CatalogBulkExportClient(transport: transport))

        let result = try await harvester.harvest(naIds: ["10514123"])
        #expect(result.unresolvedNaIds.isEmpty)
        #expect(result.records.count == 1)

        // Keyed by the AUTHORITY record's own NAID, not the creator reference.
        let record = result.records["10566287"]
        #expect(record != nil)
        #expect(record?.resolvedVia == "organizationNames")
        #expect(record?.matchedCreatorNaIds == ["10514123"])
        // And it carries the prose that motivated the pass.
        #expect(record?.administrativeHistoryNote?.hasPrefix("The Trade and Development Program") == true)
        #expect(record?.programAreas == ["Foreign Affairs"])
        #expect(record?.sourceNotes == ["Reorganization Plan No. 2 of 1979"])
    }

    @Test("A self-match is labelled 'self' and wins over a nested match")
    func prefersSelfMatch() {
        let record = try! CatalogFixtures.record(Self.parentAuthority)
        let joinable = CreatorAuthorityRecord.joinableNaIds(in: record)
        #expect(joinable.contains { $0.naId == "10566287" && $0.via == "self" })
        #expect(joinable.contains { $0.naId == "10514123" && $0.via == "organizationNames" })
    }

    @Test("An unresolvable creator NAID is reported, not silently dropped")
    func reportsUnresolved() async throws {
        let transport = ScriptedTransport(bodies: [
            "LIST:authority-records/organization/": ScriptedTransport.listing(keys: [
                ("authority-records/organization/organization-1.jsonl", 500),
            ]),
            "authority-records/organization/organization-1.jsonl": ndjsonShard([Self.parentAuthority]),
            "LIST:authority-records/person/": ScriptedTransport.listing(keys: []),
        ])
        let result = try await CreatorAuthorityHarvester(
            client: CatalogBulkExportClient(transport: transport))
            .harvest(naIds: ["10514123", "99999999"])
        #expect(result.records.count == 1)
        #expect(result.unresolvedNaIds == ["99999999"])
    }

    @Test("The pass stops early once every wanted creator is found")
    func stopsEarly() async throws {
        // The organization authority file is 400 shards / ~155 MB. Scanning all of it after the last
        // wanted creator has been found is pure waste.
        let transport = ScriptedTransport(bodies: [
            "LIST:authority-records/organization/": ScriptedTransport.listing(keys: (1...50).map {
                ("authority-records/organization/organization-\($0).jsonl", 500)
            }),
            "authority-records/organization/organization-1.jsonl": ndjsonShard([Self.parentAuthority]),
            "LIST:authority-records/person/": ScriptedTransport.listing(keys: []),
        ])
        let result = try await CreatorAuthorityHarvester(
            client: CatalogBulkExportClient(transport: transport))
            .harvest(naIds: ["10514123"])
        #expect(result.shardsRead["organization"] == 1)
        // Only the listing, the one shard, and no person listing at all (wanted was already empty).
        #expect(transport.requests.filter { $0.contains("organization-") }.count == 1)
        #expect(!transport.requests.contains { $0.contains("authority-records/person") })
    }

    @Test("The authority index sorts by NAID, so the artifact diff is stable")
    func sortsIndex() {
        let a = CreatorAuthorityRecord(try! CatalogFixtures.record(Self.parentAuthority))!
        var b = a
        b.naId = "999"
        var c = a
        c.naId = "1000"
        let index = CreatorAuthorityIndex(generated: "2026-07-29", creators: [b, c, a])
        // Digit-aware: 999 sorts before 1000, which a lexicographic sort would invert.
        #expect(index.creators.map(\.naId) == ["999", "1000", "10566287"])
    }
}
