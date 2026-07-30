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

// MARK: - RunnerEndToEndTests

/// Drives the whole pipeline — list, stream, store, checkpoint, project, census, write — over a
/// stubbed transport in a temporary sandbox. No network, no API key, no environment.
struct RunnerEndToEndTests {

    // MARK: Sandbox

    /// A throwaway directory pair for one test.
    private struct Sandbox {
        let root: URL
        var output: URL { root.appendingPathComponent("out") }
        var cache: URL { root.appendingPathComponent("cache") }

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("rgcatalog-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func destroy() { try? FileManager.default.removeItem(at: root) }

        /// Every file under `output`, relative-path keyed, for byte comparison.
        ///
        /// Both sides are symlink-resolved before the prefix is stripped. On macOS
        /// `FileManager.temporaryDirectory` is `/var/folders/…`, a symlink to `/private/var/folders/…`,
        /// and the directory enumerator hands back the resolved form — so a naive prefix strip matches
        /// nothing and every key stays an absolute path. That is not a cosmetic bug in a test helper:
        /// it made `outputFiles()` return an empty dictionary, which in turn made the determinism test
        /// pass by comparing two empty dictionaries. Hence `#expect(!files.isEmpty)` in the callers.
        func outputFiles() throws -> [String: Data] {
            var out: [String: Data] = [:]
            let base = output.resolvingSymlinksInPath().path + "/"
            guard let walker = FileManager.default.enumerator(
                at: output, includingPropertiesForKeys: [.isRegularFileKey]) else { return out }
            for case let url as URL in walker {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?
                    .isRegularFile == true else { continue }
                let resolved = url.resolvingSymlinksInPath().path
                let key = resolved.hasPrefix(base)
                    ? String(resolved.dropFirst(base.count))
                    : resolved
                out[key] = try Data(contentsOf: url)
            }
            return out
        }
    }

    // MARK: Fixtures

    /// A series record with the given identity, carrying one creator and one control number.
    ///
    /// Includes `dataControlGroup` because every real record does, and its presence matters to the
    /// drift tests: the projection does not map it, so it lands in `unprojectedKeys`. A fixture missing
    /// it entirely would make an incidental value change look like a *new key*, which legitimately
    /// counts as a modification — so the fixture has to carry the key on both sides, exactly as the
    /// live data does.
    private static func series(naId: Int, title: String, recordGroup: Int = 486) -> String {
        """
        {"record":{"naId":\(naId),"title":"\(title)","levelOfDescription":"series",
          "dataControlGroup":{"groupCd":"RRAT","groupId":"RRAT"},
          "creators":[{"naId":10514123,"heading":"Trade and Development Program",
            "authorityType":"organization","creatorType":"Most Recent"}],
          "variantControlNumbers":[{"number":"P \(naId)","type":"HMS/MLR Entry Number"}],
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
            "recordGroupNumber":\(recordGroup),
            "title":"Records of the U.S. Trade and Development Agency"}]}}
        """
    }

    /// A file unit, for the depth-escalation test.
    private static func fileUnit(naId: Int, recordGroup: Int = 486) -> String {
        """
        {"record":{"naId":\(naId),"title":"File unit \(naId)","levelOfDescription":"fileUnit",
          "ancestors":[
            {"distance":1,"levelOfDescription":"series","naId":1,"title":"Series One"},
            {"distance":2,"levelOfDescription":"recordGroup","naId":22345815,
             "recordGroupNumber":\(recordGroup),"title":"Records of the U.S. Trade and Development Agency"}]}}
        """
    }

    /// Two shards: the group node plus three series, with a file unit in each shard so a series-only
    /// run has something to filter out — mirroring the real export, whose shards interleave levels
    /// rather than grouping them.
    private static func transport(seriesCount: Int = 3) -> ScriptedTransport {
        ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_486/": ScriptedTransport.listing(keys: [
                ("descriptions/record-groups/rg_486/rg_486-1.jsonl", 900),
                ("descriptions/record-groups/rg_486/rg_486-2.jsonl", 900),
            ]),
            "descriptions/record-groups/rg_486/rg_486-1.jsonl": ndjsonShard([
                """
                {"record":{"naId":22345815,
                  "title":"Records of the U.S. Trade and Development Agency",
                  "levelOfDescription":"recordGroup","recordGroupNumber":486,
                  "seriesCount":\(seriesCount)}}
                """,
                series(naId: 1, title: "Series One"),
                fileUnit(naId: 100),
                series(naId: 2, title: "Series Two"),
            ]),
            "descriptions/record-groups/rg_486/rg_486-2.jsonl": ndjsonShard([
                series(naId: 3, title: "Series Three"),
                fileUnit(naId: 101),
            ]),
        ])
    }

    private static let plan = RecordGroupHarvestPlan(
        groups: [RecordGroupPlan(number: 486, depth: .series)])

    @discardableResult
    private func run(
        _ sandbox: Sandbox,
        transport: any CatalogBulkTransport,
        plan: RecordGroupHarvestPlan = RunnerEndToEndTests.plan,
        mode: RecordGroupCatalogRunner.Mode = .init(),
        byteBudget: Int? = nil
    ) async throws -> RecordGroupCatalogRunner.RunResult {
        try await RecordGroupCatalogRunner.run(
            plan: plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: transport, generated: "2026-07-29", mode: mode, byteBudget: byteBudget)
    }

    // MARK: Tests

    @Test("A full run writes every artifact and validates itself against NARA's own series count")
    func harvestsEndToEnd() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let result = try await run(sandbox, transport: Self.transport())

        #expect(result.isTrustworthy)
        #expect(result.failures.isEmpty)

        let group = try #require(result.manifest.recordGroups.first)
        // The completeness check: NARA states 3, we harvested 3.
        #expect(group.expectedSeriesCount == 3)
        #expect(group.harvestedSeriesCount == 3)
        #expect(group.seriesCountDelta == 0)
        #expect(!group.isMateriallyShort)
        // Identity comes from the group's own node, never from a baked table.
        #expect(group.title == "Records of the U.S. Trade and Development Agency")
        #expect(group.naId == "22345815")
        // File units were stored-and-filtered, not harvested, at series depth.
        #expect(group.harvestedFileUnitCount == 0)
        #expect(group.recordsWithCreators == 3)
        #expect(group.recordsWithControlNumbers == 3)

        // Every artifact exists.
        let files = try sandbox.outputFiles()
        for expected in ["manifest.json", "harvest-report.txt", "series-sample.json",
                         "series/rg_486.json", "census/field-census.csv", "census/value-census.csv",
                         "census/control-number-census.csv", "census/control-number-types.csv",
                         "census/creator-census.csv"] {
            #expect(files[expected] != nil, "missing \(expected)")
        }

        // The index shard holds the projected series, NAID-sorted.
        let shard = try JSONDecoder().decode(
            RecordGroupIndexShard.self, from: try #require(files["series/rg_486.json"]))
        #expect(shard.records.map(\.naId) == ["1", "2", "3"])
        #expect(shard.records.allSatisfy { !$0.creators.isEmpty })
        #expect(shard.depth == .series)
    }

    @Test("Two identical runs produce byte-identical output")
    func isDeterministic() async throws {
        // Run-it-twice-and-compare-bytes, not encode-the-same-value-twice: only the full form catches
        // dictionary-iteration order leaking out of a census walker, which is the realistic way a
        // 165 MB artifact starts producing meaningless diffs.
        let first = try Sandbox()
        defer { first.destroy() }
        let second = try Sandbox()
        defer { second.destroy() }

        try await run(first, transport: Self.transport())
        try await run(second, transport: Self.transport())

        let a = try first.outputFiles()
        let b = try second.outputFiles()
        // Guard against the vacuous pass: two empty dictionaries are trivially equal, and an earlier
        // version of `outputFiles()` returned exactly that.
        #expect(a.count >= 9, "expected the full artifact set, got \(a.count) files")
        #expect(Set(a.keys) == Set(b.keys))
        for key in a.keys.sorted() {
            #expect(a[key] == b[key], "\(key) differs between two runs")
        }
    }

    @Test("A short harvest fails the run rather than shipping quietly")
    func failsOnShortHarvest() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // NARA says 11 series; the shards hold 3. This is the signature of a truncated harvest, and
        // it is the one thing that must never pass silently.
        let result = try await run(sandbox, transport: Self.transport(seriesCount: 11))

        #expect(!result.isTrustworthy)
        #expect(result.failures.count == 1)
        #expect(result.failures[0].contains("harvested 3 series but NARA states 11"))
        #expect(result.manifest.recordGroups[0].isMateriallyShort)
        #expect(result.manifest.recordGroups[0].seriesCountDelta == -8)
    }

    @Test("ALLOW_SHORT downgrades the shortfall to a report line")
    func allowsShortWhenAsked() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let result = try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: Self.transport(seriesCount: 11), generated: "2026-07-29", allowShort: true)
        #expect(result.isTrustworthy)
        // Still visible in the manifest — permitted, not hidden.
        #expect(result.manifest.recordGroups[0].isMateriallyShort)
    }

    @Test("A second run resumes from the checkpoint and re-fetches nothing")
    func resumesWithoutRefetching() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let first = Self.transport()
        try await run(sandbox, transport: first)
        let firstShardFetches = first.requests.filter { $0.hasSuffix(".jsonl") }.count
        #expect(firstShardFetches == 2)

        let second = Self.transport()
        let result = try await run(sandbox, transport: second)
        // Only the listing is re-issued; no shard body is fetched again.
        #expect(second.requests.filter { $0.hasSuffix(".jsonl") }.isEmpty)
        #expect(result.manifest.recordGroups[0].state == .resumedComplete)
        // And the index is still complete, rebuilt from the stored raw records.
        #expect(result.manifest.recordGroups[0].harvestedSeriesCount == 3)
    }

    @Test("A byte budget stops mid-group, checkpoints, and still exits trustworthy")
    func stopsOnByteBudget() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // A budget smaller than the second shard: the first shard lands, then the run stops.
        let transport = Self.transport()
        let result = try await run(sandbox, transport: transport,
                                   plan: RecordGroupHarvestPlan(groups: [
                                       RecordGroupPlan(number: 486, depth: .series)]),
                                   byteBudget: 10)

        // Budget exhaustion is a SUCCESSFUL partial harvest — the whole point is that re-running
        // continues rather than starting over.
        #expect(result.isTrustworthy || result.failures.allSatisfy { $0.contains("NARA states") })
        #expect(result.manifest.recordGroups[0].state == .budgetExhausted)
        #expect(transport.requests.filter { $0.hasSuffix(".jsonl") }.count == 1)
        #expect(result.manifest.reviewNotes.contains { $0.contains("MAX_BYTES") })

        // Resuming with no budget finishes the group.
        let resume = Self.transport()
        let finished = try await run(sandbox, transport: resume)
        #expect(finished.manifest.recordGroups[0].harvestedSeriesCount == 3)
        #expect(finished.isTrustworthy)
        // Only the outstanding shard was fetched, not both.
        #expect(resume.requests.filter { $0.hasSuffix(".jsonl") }.count == 1)
    }

    @Test("A process killed mid-shard does not duplicate that shard's records on resume")
    func recoversFromPartialShardWrite() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // Harvest shard 1 only, by giving the run a budget that stops after it.
        let firstPass = Self.transport()
        try await run(sandbox, transport: firstPass, byteBudget: 10)

        let rawStore = RawRecordStore(
            directory: sandbox.cache.appendingPathComponent("raw"))
        let checkpoints = CheckpointStore(
            directory: sandbox.cache.appendingPathComponent("checkpoints"))
        let checkpoint = try #require(checkpoints.load(recordGroup: 486))
        #expect(checkpoint.lastCompletedShardIndex == 1)
        #expect(checkpoint.ndjsonByteLength == rawStore.byteLength(recordGroup: 486))

        // Simulate a kill partway through shard 2: its records are partly appended, but the
        // checkpoint still names shard 1. Without the truncate-on-resume, shard 2 would be re-read
        // and its records appended a SECOND time.
        let partial = try #require(try? Data(
            contentsOf: rawStore.url(recordGroup: 486)))
        let strayRecord = ndjsonShard([Self.series(naId: 3, title: "Series Three")])
        try (partial + Data(strayRecord.utf8)).write(to: rawStore.url(recordGroup: 486))
        #expect(rawStore.byteLength(recordGroup: 486) > (checkpoint.ndjsonByteLength ?? 0))

        // Resume with no budget: the partial tail is discarded, shard 2 is re-read, and NAID 3
        // appears exactly once.
        let resumed = try await run(sandbox, transport: Self.transport())
        let group = try #require(resumed.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 3)
        #expect(group.seriesCountDelta == 0)
        #expect(group.invariantViolations["duplicateRecord"] == nil)
        #expect(resumed.isTrustworthy)

        let shard = try JSONDecoder().decode(
            RecordGroupIndexShard.self,
            from: try #require(try sandbox.outputFiles()["series/rg_486.json"]))
        #expect(shard.records.map(\.naId) == ["1", "2", "3"])
    }

    @Test("A duplicated record is de-duplicated and reported, never absorbed")
    func deduplicatesAndReports() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // A shard that repeats a series. Belt-and-braces behind the resume truncation: a duplicate
        // would otherwise push harvestedSeriesCount PAST NARA's seriesCount, and the completeness
        // check only tests for a shortfall — so it would pass unnoticed.
        let transport = ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_486/": ScriptedTransport.listing(keys: [
                ("descriptions/record-groups/rg_486/rg_486-1.jsonl", 900),
            ]),
            "descriptions/record-groups/rg_486/rg_486-1.jsonl": ndjsonShard([
                """
                {"record":{"naId":22345815,"title":"RG","levelOfDescription":"recordGroup",
                  "recordGroupNumber":486,"seriesCount":1}}
                """,
                Self.series(naId: 1, title: "Series One"),
                Self.series(naId: 1, title: "Series One"),
            ]),
        ])

        let result = try await run(sandbox, transport: transport)
        let group = try #require(result.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 1)
        #expect(group.seriesCountDelta == 0)
        #expect(group.invariantViolations["duplicateRecord"] == 1)
        #expect(group.invariantExamples.contains { $0.contains("naId 1 appeared more than once") })
    }

    @Test("PROJECT_ONLY rebuilds the index offline, with zero transport calls")
    func reprojectsOffline() async throws {
        // The schema-correction path: if a projection is wrong, fixing it must not cost another
        // download of the export.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        try await run(sandbox, transport: Self.transport())

        let offline = ScriptedTransport(bodies: [:])   // any request would throw 404
        let result = try await run(sandbox, transport: offline,
                                   mode: .init(projectOnly: true))
        #expect(offline.requests.isEmpty)
        #expect(result.manifest.recordGroups[0].harvestedSeriesCount == 3)
        #expect(result.manifest.recordGroups[0].expectedSeriesCount == 3)
        #expect(result.isTrustworthy)
    }

    @Test("PROJECT_ONLY with no stored records says so instead of writing an empty index")
    func reportsMissingRawStore() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let offline = ScriptedTransport(bodies: [:])
        let result = try await run(sandbox, transport: offline, mode: .init(projectOnly: true))
        #expect(result.manifest.recordGroups.isEmpty)
        #expect(result.manifest.reviewNotes.contains { $0.contains("no raw store") })
    }

    @Test("REFRESH plus a deeper depth re-harvests and picks up the file units")
    func escalatesDepthWithRefresh() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        try await run(sandbox, transport: Self.transport())

        // Without REFRESH the checkpoint refuses, because the series pass never read the deeper level.
        let deeperPlan = RecordGroupHarvestPlan(
            groups: [RecordGroupPlan(number: 486, depth: .seriesAndFileUnits)])
        let refused = try await run(sandbox, transport: Self.transport(), plan: deeperPlan)
        #expect(!refused.isTrustworthy)
        #expect(refused.failures.contains { $0.contains("checkpoint refused") })

        // With REFRESH it re-harvests and the file units appear.
        let escalated = try await run(sandbox, transport: Self.transport(), plan: deeperPlan,
                                     mode: .init(refresh: true))
        #expect(escalated.isTrustworthy)
        #expect(escalated.manifest.recordGroups[0].harvestedSeriesCount == 3)
        #expect(escalated.manifest.recordGroups[0].harvestedFileUnitCount == 2)
        #expect(escalated.manifest.recordGroups[0].depth == .seriesAndFileUnits)
    }

    @Test("A required field matching nothing fails the run with an actionable message")
    func failsWhenPriorityFieldNeverMatches() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // The nightmare case, simulated: records with neither creators nor control numbers. The run
        // must refuse rather than produce a plausible-looking index with its whole purpose missing.
        let transport = ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_486/": ScriptedTransport.listing(keys: [
                ("descriptions/record-groups/rg_486/rg_486-1.jsonl", 400),
            ]),
            "descriptions/record-groups/rg_486/rg_486-1.jsonl": ndjsonShard([
                """
                {"record":{"naId":22345815,"title":"RG","levelOfDescription":"recordGroup",
                  "recordGroupNumber":486,"seriesCount":1}}
                """,
                """
                {"record":{"naId":1,"title":"Bare series","levelOfDescription":"series",
                  "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
                    "recordGroupNumber":486,"title":"RG"}]}}
                """,
            ]),
        ])

        let result = try await run(sandbox, transport: transport)
        #expect(!result.isTrustworthy)
        #expect(result.failures.count == 2)
        #expect(result.failures.contains { $0.contains("'creators' matched no key spelling") })
        #expect(result.failures.contains {
            $0.contains("'variantControlNumbers' matched no key spelling")
        })
        // And it names the recovery that costs nothing.
        #expect(result.failures.allSatisfy { $0.contains("PROJECT_ONLY=1") })

        // The manifest carries the same signal for a reader who never sees the exit code.
        let creatorsEntry = result.manifest.fieldAliasReport.first { $0.field == "creators" }
        #expect(creatorsEntry?.matchedAliases.isEmpty == true)
        #expect(creatorsEntry?.required == true)
        #expect(creatorsEntry?.absent == 1)
    }

    @Test("An unattributable record is refused and reported, not counted as harvested")
    func refusesAndReportsUnattributableRecords() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let transport = ScriptedTransport(bodies: [
            "LIST:descriptions/record-groups/rg_486/": ScriptedTransport.listing(keys: [
                ("descriptions/record-groups/rg_486/rg_486-1.jsonl", 400),
            ]),
            "descriptions/record-groups/rg_486/rg_486-1.jsonl": ndjsonShard([
                """
                {"record":{"naId":22345815,"title":"RG","levelOfDescription":"recordGroup",
                  "recordGroupNumber":486,"seriesCount":1}}
                """,
                Self.series(naId: 1, title: "Good series"),
                // Parented by a collection, so it exposes no record group — the #321 shape.
                """
                {"record":{"naId":2,"title":"Library staff file","levelOfDescription":"series",
                  "ancestors":[{"distance":1,"levelOfDescription":"collection","naId":77,
                    "title":"A Presidential Library Collection"}]}}
                """,
            ]),
        ])

        let result = try await run(sandbox, transport: transport, byteBudget: nil)
        let group = try #require(result.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 1)
        #expect(group.invariantViolations["noRecordGroupAncestor"] == 1)
        #expect(group.invariantExamples.contains { $0.contains("naId 2") })
        // Refusals are surfaced in the report, never a silent drop.
        let report = try #require(try sandbox.outputFiles()["harvest-report.txt"])
        #expect(String(decoding: report, as: UTF8.self).contains("INVARIANT VIOLATIONS"))
    }

    @Test("PROBE fetches one shard per group and writes censuses but no index")
    func probesCheaply() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let transport = Self.transport()
        let result = try await run(sandbox, transport: transport, mode: .init(probe: true))

        // One shard only — the cheap first look.
        #expect(transport.requests.filter { $0.hasSuffix(".jsonl") }.count == 1)
        #expect(result.manifest.source.kind == "s3-bulk-export-probe")
        let files = try sandbox.outputFiles()
        // The probe writes into its own subtree so it cannot overwrite a real harvest's manifest,
        // censuses and report with a one-shard sample.
        #expect(files["probe/census/field-census.csv"] != nil)
        #expect(files["probe/manifest.json"] != nil)
        #expect(files["census/field-census.csv"] == nil)
        #expect(files["series/rg_486.json"] == nil)
        #expect(files["probe/series/rg_486.json"] == nil)
        #expect(result.manifest.reviewNotes.contains { $0.contains("PROBE mode") })
        // The probe still answers the only question that could invalidate the whole harvest.
        #expect(result.isTrustworthy)

        // And it counts every level in its one shard, not just series — for a small group that
        // shard may hold no series at all.
        let group = try #require(result.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 2)
        #expect(group.harvestedFileUnitCount == 1)
        // Never `complete` for a one-shard sample of a two-shard group.
        #expect(group.state == .partial)
        #expect(group.shardsListed == 2)
        #expect(group.shardsRead == 1)
    }

    @Test("A refused group leaves a trace in the manifest, not only in the exit message")
    func recordsRefusalOnDisk() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        try await run(sandbox, transport: Self.transport())
        // Ask for a deeper depth without REFRESH: the checkpoint refuses.
        let refused = try await run(sandbox, transport: Self.transport(),
                                   plan: RecordGroupHarvestPlan(groups: [
                                       RecordGroupPlan(number: 486, depth: .seriesAndFileUnits)]))
        #expect(!refused.isTrustworthy)

        // The refusal must be visible to someone reading the artifacts, not just the exit message —
        // otherwise the manifest simply omits the group, indistinguishable from never asking for it.
        let group = try #require(refused.manifest.recordGroups.first { $0.recordGroup == 486 })
        #expect(group.state == .refused)
        #expect(refused.manifest.reviewNotes.contains { $0.contains("REFUSED") })
        let report = try #require(try sandbox.outputFiles()["harvest-report.txt"])
        #expect(String(decoding: report, as: UTF8.self).contains("refused"))
    }

    // MARK: API refresh over the bulk snapshot

    /// Runs a bulk harvest, then an API refresh over it, and returns the refresh's result.
    private func harvestThenRefresh(
        _ sandbox: Sandbox, apiResponses: [(String, Int)]
    ) async throws -> RecordGroupCatalogRunner.RunResult {
        try await run(sandbox, transport: Self.transport())
        return try await refreshOnly(sandbox, apiResponses: apiResponses)
    }

    /// A refresh against whatever is already in the sandbox.
    ///
    /// The group-node response is prepended because every refresh now asks for it first — one call to
    /// recover NARA's `seriesCount`, which `levelOfDescription=series` would otherwise exclude.
    private func refreshOnly(
        _ sandbox: Sandbox, apiResponses: [(String, Int)]
    ) async throws -> RecordGroupCatalogRunner.RunResult {
        try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: Self.transport(), generated: "2026-07-30",
            mode: .init(apiRefresh: true), apiKey: "test-key",
            apiTransport: ScriptedAPITransport(
                responses: [(ScriptedAPITransport.groupNodePage(), 200)] + apiResponses))
    }

    @Test("A refresh that changes a record classifies it modified and the API version wins")
    func refreshAppliesModifications() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // The API returns series 1 and 2 with a different title, and 3 unchanged.
        let modified = """
        {"statusCode":200,"body":{"hits":{"hits":[
          {"_source":{"record":{"naId":1,"title":"Series One RETITLED",
            "levelOfDescription":"series",
            "creators":[{"naId":10514123,"heading":"H","authorityType":"organization",
              "creatorType":"Most Recent"}],
            "variantControlNumbers":[{"number":"P 1","type":"HMS/MLR Entry Number"}],
            "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
              "recordGroupNumber":486,"title":"RG"}]}},"sort":["1"]}
        ]}}}
        """
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            (modified, 200), (ScriptedAPITransport.emptyPage, 200),
        ])

        // Series 1 was modified; 2 and 3 were in the snapshot but not this refresh.
        let counts = try #require(result.manifest.recordGroups.first)
        #expect(counts.harvestedSeriesCount == 3)

        let changelog = try #require(try sandbox.outputFiles()["census/refresh-changelog.csv"])
        let csv = String(decoding: changelog, as: UTF8.self)
        #expect(csv.contains("486,1,modified"))
        #expect(csv.contains("missingFromRefresh"))

        // The API's version is what landed in the index.
        let shard = try JSONDecoder().decode(
            RecordGroupIndexShard.self,
            from: try #require(try sandbox.outputFiles()["series/rg_486.json"]))
        #expect(shard.records.first { $0.naId == "1" }?.title == "Series One RETITLED")
    }

    @Test("A record only in the refresh is classified added and appears in the index")
    func refreshAddsNewRecords() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let withNew = ScriptedAPITransport.page(naIds: [1, 2, 3, 99])
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            (withNew, 200), (ScriptedAPITransport.emptyPage, 200),
        ])

        let group = try #require(result.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 4)
        // Over NARA's stated 3 — surfaced, not hidden.
        #expect(group.seriesCountDelta == 1)

        let csv = String(decoding: try #require(
            try sandbox.outputFiles()["census/refresh-changelog.csv"]), as: UTF8.self)
        #expect(csv.contains("486,99,added"))

        let shard = try JSONDecoder().decode(
            RecordGroupIndexShard.self,
            from: try #require(try sandbox.outputFiles()["series/rg_486.json"]))
        #expect(shard.records.map(\.naId).contains("99"))
    }

    @Test("An EMPTY refresh is discarded, not merged as a mass withdrawal")
    func discardsEmptyRefresh() async throws {
        // The dangerous case. With the overlay logic, zero refresh records over a populated snapshot
        // would classify EVERY record as missingFromRefresh and read as the catalog having been
        // emptied — when the likeliest cause is a wrong query shape.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            (ScriptedAPITransport.emptyPage, 200),
        ])

        let group = try #require(result.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 3)          // snapshot intact
        #expect(group.seriesCountDelta == 0)
        #expect(result.manifest.reviewNotes.contains { $0.contains("DISCARDED") })
        // No record was classified as gone.
        let csv = String(decoding: try #require(
            try sandbox.outputFiles()["census/refresh-changelog.csv"]), as: UTF8.self)
        #expect(!csv.contains("missingFromRefresh"))
    }

    @Test("A refresh that errors leaves the snapshot-derived index intact")
    func survivesRefreshFailure() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        // An unrecognisable envelope throws inside the refresh.
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            ("{\"unexpected\":true}", 200),
        ])
        let group = try #require(result.manifest.recordGroups.first)
        #expect(group.harvestedSeriesCount == 3)
        #expect(result.manifest.reviewNotes.contains { $0.contains("API refresh FAILED") })
        #expect(result.isTrustworthy)
    }

    @Test("A refresh identical to the snapshot reports no changes")
    func detectsNoDrift() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        // Same three series, same content as the bulk fixture's records.
        let identical = """
        {"statusCode":200,"body":{"hits":{"hits":[
        \((1...3).map { naId in """
          {"_source":{"record":{"naId":\(naId),"title":"Series \(["","One","Two","Three"][naId])",
            "levelOfDescription":"series",
            "dataControlGroup":{"groupCd":"RRAT","groupId":"RRAT"},
            "creators":[{"naId":10514123,"heading":"Trade and Development Program",
              "authorityType":"organization","creatorType":"Most Recent"}],
            "variantControlNumbers":[{"number":"P \(naId)","type":"HMS/MLR Entry Number"}],
            "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
              "recordGroupNumber":486,
              "title":"Records of the U.S. Trade and Development Agency"}]}},"sort":["\(naId)"]}
        """ }.joined(separator: ","))
        ]}}}
        """
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            (identical, 200), (ScriptedAPITransport.emptyPage, 200),
        ])
        #expect(result.manifest.reviewNotes.contains { $0.contains("unchanged=3") })
        #expect(!(try #require(result.manifest.reviewNotes.first { $0.contains("API refresh spent") })
            .contains("modified=3")))
        let csv = String(decoding: try #require(
            try sandbox.outputFiles()["census/refresh-changelog.csv"]), as: UTF8.self)
        // Header only — nothing changed.
        #expect(csv.split(separator: "\r\n").count == 1)
    }

    @Test("API_REFRESH without a key fails loudly rather than silently skipping the refresh")
    func requiresKeyForRefresh() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        await #expect(throws: CatalogAPIError.missingAPIKey) {
            _ = try await RecordGroupCatalogRunner.run(
                plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
                transport: Self.transport(), generated: "2026-07-30",
                mode: .init(apiRefresh: true), apiKey: nil)
        }
    }

    @Test("A record differing only outside the indexed fields is not reported as modified")
    func classifiesIncidentalDriftEndToEnd() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // Series 1, identical to the snapshot except for a `dataControlGroup` the projection ignores —
        // the exact shape of the real RG 486 drift (RRAT -> RRAR).
        let drifted = """
        {"statusCode":200,"body":{"hits":{"hits":[
          {"_source":{"record":{"naId":1,"title":"Series One","levelOfDescription":"series",
            "dataControlGroup":{"groupCd":"RRAR","groupId":"RRAR"},
            "creators":[{"naId":10514123,"heading":"Trade and Development Program",
              "authorityType":"organization","creatorType":"Most Recent"}],
            "variantControlNumbers":[{"number":"P 1","type":"HMS/MLR Entry Number"}],
            "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
              "recordGroupNumber":486,
              "title":"Records of the U.S. Trade and Development Agency"}]}},"sort":["1"]}
        ]}}}
        """
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            (drifted, 200), (ScriptedAPITransport.emptyPage, 200),
        ])

        let note = try #require(result.manifest.reviewNotes.first { $0.contains("API refresh spent") })
        #expect(note.contains("modified=0"))
        // And it is not listed as a change in the CSV.
        let csv = String(decoding: try #require(
            try sandbox.outputFiles()["census/refresh-changelog.csv"]), as: UTF8.self)
        #expect(!csv.contains(",1,modified"))
        // The report says plainly why.
        let report = String(decoding: try #require(
            try sandbox.outputFiles()["harvest-report.txt"]), as: UTF8.self)
        #expect(report.contains("ONLY outside"))
    }

    /// An API_ONLY run: no bulk transport activity at all.
    private func apiOnlyRun(
        _ sandbox: Sandbox, apiResponses: [(String, Int)],
        bulk: ScriptedTransport? = nil
    ) async throws -> (RecordGroupCatalogRunner.RunResult, ScriptedTransport) {
        let bulkTransport = bulk ?? ScriptedTransport(bodies: [:])
        let result = try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: bulkTransport, generated: "2026-07-30",
            mode: .init(apiOnly: true), apiKey: "test-key",
            apiTransport: ScriptedAPITransport(responses: apiResponses))
        return (result, bulkTransport)
    }

    @Test("API_ONLY harvests without touching the bulk export at all")
    func apiOnlySkipsBulkEntirely() async throws {
        // The route that becomes attractive now the API is field-complete and limit=1000 is honoured:
        // ~40 calls for the whole series layer instead of streaming 22 GB. API_REFRESH alone did NOT
        // do this — it harvested the bulk export first and layered the API over it.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let (result, bulkTransport) = try await apiOnlyRun(sandbox, apiResponses: [
            (ScriptedAPITransport.groupNodePage(seriesCount: 3), 200),
            (ScriptedAPITransport.page(naIds: [1, 2, 3], total: 3), 200),
        ])

        // Not one bulk request — no listing, no shards. An empty bodies map would 404 on any call.
        #expect(bulkTransport.requests.isEmpty)

        let group = try #require(result.manifest.recordGroups.first)
        // NARA's own count came from the API node, and the check passes.
        #expect(group.expectedSeriesCount == 3)
        #expect(group.harvestedSeriesCount == 3)
        #expect(group.seriesCountDelta == 0)
        #expect(!group.isMateriallyShort)
        #expect(group.title == "Records of the U.S. Trade and Development Agency")
        #expect(group.bytesRead == 0)
        #expect(result.isTrustworthy)

        // A full index shard was written from the API alone.
        let shard = try JSONDecoder().decode(
            RecordGroupIndexShard.self,
            from: try #require(try sandbox.outputFiles()["series/rg_486.json"]))
        #expect(shard.records.map(\.naId) == ["1", "2", "3"])
        #expect(shard.records.allSatisfy { !$0.creators.isEmpty })
    }

    @Test("API_ONLY writes no changelog — there is no snapshot to diff against")
    func apiOnlyEmitsNoChangelog() async throws {
        // Built as an OVERLAY on an absent base, every record would classify as `added` and the
        // changelog would be tens of thousands of lines of noise. API-only builds from the api store
        // as its base instead.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let (_, _) = try await apiOnlyRun(sandbox, apiResponses: [
            (ScriptedAPITransport.groupNodePage(seriesCount: 3), 200),
            (ScriptedAPITransport.page(naIds: [1, 2, 3], total: 3), 200),
        ])
        #expect(try sandbox.outputFiles()["census/refresh-changelog.csv"] == nil)
    }

    @Test("An API-only harvest that comes up short FAILS, thanks to the group node")
    func apiOnlyShortHarvestFails() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // The node says 11; the harvest yields 3. This is the failure the check exists to catch, and it
        // is only catchable because the node was fetched.
        let (result, _) = try await apiOnlyRun(sandbox, apiResponses: [
            (ScriptedAPITransport.groupNodePage(seriesCount: 11), 200),
            (ScriptedAPITransport.page(naIds: [1, 2, 3], total: 3), 200),
        ])
        #expect(!result.isTrustworthy)
        #expect(result.failures.contains { $0.contains("but NARA states 11") })
    }

    @Test("An API-only group that returns nothing is reported and leaves its shard alone")
    func apiOnlyEmptyGroupIsReported() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        // Harvest from bulk first so a shard exists, then an API-only run that comes back empty.
        try await run(sandbox, transport: Self.transport())
        let before = try #require(try sandbox.outputFiles()["series/rg_486.json"])

        let (result, _) = try await apiOnlyRun(sandbox, apiResponses: [
            (ScriptedAPITransport.groupNodePage(seriesCount: 3), 200),
            (ScriptedAPITransport.emptyPage, 200),
        ])
        #expect(result.manifest.reviewNotes.contains { $0.contains("returned no records") })
        // The existing index must survive an empty API run rather than being replaced by nothing.
        #expect(try sandbox.outputFiles()["series/rg_486.json"] == before)
    }

    @Test("A group node missing seriesCount is reported, not silently treated as checked")
    func reportsNodeWithoutSeriesCount() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let result = try await refreshOnlyWithNode(
            sandbox, node: ScriptedAPITransport.groupNodePage(seriesCount: nil),
            apiResponses: [(ScriptedAPITransport.page(naIds: [1], total: 1), 200)])
        #expect(result.manifest.reviewNotes.contains { $0.contains("no seriesCount") })
    }

    /// A refresh with an explicit group-node response, for the node-shape cases.
    private func refreshOnlyWithNode(
        _ sandbox: Sandbox, node: String, apiResponses: [(String, Int)]
    ) async throws -> RecordGroupCatalogRunner.RunResult {
        try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: Self.transport(), generated: "2026-07-30",
            mode: .init(apiRefresh: true), apiKey: "test-key",
            apiTransport: ScriptedAPITransport(responses: [(node, 200)] + apiResponses))
    }

    @Test("The group node is never reported as an added record")
    func groupNodeIsNotAChange() async throws {
        // It is metadata, not content. The base pass returns early on it without marking it seen, so
        // without an explicit guard it would show up as newly ADDED on every single refresh.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let result = try await harvestThenRefresh(sandbox, apiResponses: [
            (ScriptedAPITransport.page(naIds: [1, 2, 3], total: 3), 200),
        ])
        let csv = String(decoding: try #require(
            try sandbox.outputFiles()["census/refresh-changelog.csv"]), as: UTF8.self)
        #expect(!csv.contains("22345815"))
        let note = try #require(result.manifest.reviewNotes.first { $0.contains("API refresh spent") })
        #expect(note.contains("added=0"))
    }

    @Test("A FAILED API harvest leaves the previous good store and shard intact")
    func failedApiHarvestPreservesPreviousData() async throws {
        // The RG 59 lesson, and the most expensive bug in this tool's history. The harvest used to
        // reset() the store and then fetch into it, so an HTTP 500 part-way through destroyed 4,449
        // already-harvested series — the exact opposite of the raw store's promise.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        // A good API-only harvest first.
        let (good, _) = try await apiOnlyRun(sandbox, apiResponses: [
            (ScriptedAPITransport.groupNodePage(seriesCount: 3), 200),
            (ScriptedAPITransport.page(naIds: [1, 2, 3], total: 3), 200),
        ])
        #expect(good.manifest.recordGroups.first?.harvestedSeriesCount == 3)
        let shardBefore = try #require(try sandbox.outputFiles()["series/rg_486.json"])
        let store = RawRecordStore(directory: sandbox.cache.appendingPathComponent("raw-api"))
        let storeBefore = try Data(contentsOf: store.url(recordGroup: 486))

        // Now a harvest that dies after the node — the RG 59 shape exactly.
        let (failed, _) = try await apiOnlyRun(sandbox, apiResponses: [
            (ScriptedAPITransport.groupNodePage(seriesCount: 3), 200),
            ("{\"message\":\"boom\"}", 500),
        ])
        #expect(!failed.isTrustworthy)
        #expect(failed.manifest.reviewNotes.contains { $0.contains("API harvest FAILED") })
        #expect(failed.manifest.reviewNotes.contains { $0.contains("intact") })

        // The previous store and shard survive, byte for byte.
        #expect(try Data(contentsOf: store.url(recordGroup: 486)) == storeBefore)
        #expect(try sandbox.outputFiles()["series/rg_486.json"] == shardBefore)
        // And no staging file is left lying around.
        #expect(!FileManager.default.fileExists(atPath: store.stagingURL(recordGroup: 486).path))
    }

    @Test("One group's API failure does not abort the others")
    func apiFailureIsIsolatedPerGroup() async throws {
        // Before per-group isolation, a single 500 threw out of the whole run — in a 22-group harvest
        // that is most of the work lost to one bad page.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let plan = RecordGroupHarvestPlan(groups: [
            RecordGroupPlan(number: 486, depth: .series),
            RecordGroupPlan(number: 420, depth: .series),
        ])
        let result = try await RecordGroupCatalogRunner.run(
            plan: plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: ScriptedTransport(bodies: [:]), generated: "2026-07-30",
            mode: .init(apiOnly: true), apiKey: "test-key",
            apiTransport: ScriptedAPITransport(responses: [
                // RG 486's node succeeds, then every series page fails. Seven failures, because the
                // adaptive halving walks 1000 → 500 → 250 → 125 → 62 → 31 → 25 before giving up at the
                // floor — worth knowing as a quota cost: a genuinely unservable page burns 7 calls.
                [(ScriptedAPITransport.groupNodePage(seriesCount: 3), 200)],
                Array(repeating: ("{\"message\":\"boom\"}", 500), count: 7),
                // …and RG 420 then harvests normally, which is the point.
                [(ScriptedAPITransport.groupNodePage(recordGroup: 420, seriesCount: 2,
                                                     naId: 9999), 200),
                 (ScriptedAPITransport.page(naIds: [7, 8], recordGroup: 420, total: 2), 200)],
            ].flatMap { $0 }))
        // The second group still harvested.
        let rg420 = try #require(result.manifest.recordGroups.first { $0.recordGroup == 420 })
        #expect(rg420.harvestedSeriesCount == 2)
        // And the failure is recorded rather than swallowed.
        #expect(result.failures.contains { $0.contains("RG 486") })
    }

    @Test("A materially short build does not overwrite a good existing shard")
    func doesNotClobberAGoodShard() async throws {
        // How RG 59's index went to zero records: a re-projection over a damaged raw store built an
        // empty shard and wrote it over the good one. The run failed loudly — after the damage.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        try await run(sandbox, transport: Self.transport())
        let good = try #require(try sandbox.outputFiles()["series/rg_486.json"])

        // Gut the raw store, leaving only the group node — exactly the RG 59 state.
        let store = RawRecordStore(directory: sandbox.cache.appendingPathComponent("raw"))
        let node = """
        {"naId":22345815,"title":"Records of the U.S. Trade and Development Agency",\
        "levelOfDescription":"recordGroup","recordGroupNumber":486,"seriesCount":3}
        """
        try Data((node + "\n").utf8).write(to: store.url(recordGroup: 486))

        let result = try await run(sandbox, transport: Self.transport(),
                                  mode: .init(projectOnly: true))
        #expect(!result.isTrustworthy)
        #expect(result.failures.contains { $0.contains("but NARA states 3") })
        // The good shard survived.
        #expect(try sandbox.outputFiles()["series/rg_486.json"] == good)
        #expect(result.manifest.reviewNotes.contains { $0.contains("left in place") })
    }

    @Test("ALLOW_SHORT permits the overwrite, for a deliberately partial build")
    func allowShortPermitsOverwrite() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        try await run(sandbox, transport: Self.transport())
        let good = try #require(try sandbox.outputFiles()["series/rg_486.json"])

        // Short but NOT empty: one series against NARA's three. A zero-record build fails regardless of
        // ALLOW_SHORT — the emptiness check is deliberately stricter, since nothing downstream can tell
        // an empty index from a corpus that genuinely has no series.
        let store = RawRecordStore(directory: sandbox.cache.appendingPathComponent("raw"))
        let node = """
        {"naId":22345815,"title":"RG","levelOfDescription":"recordGroup",\
        "recordGroupNumber":486,"seriesCount":3}
        """
        try Data((ndjsonShard([node, Self.series(naId: 1, title: "Series One")
            .replacingOccurrences(of: "{\"record\":", with: "")
            .replacingOccurrences(of: "}}", with: "}")])).utf8)
            .write(to: store.url(recordGroup: 486))

        let result = try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: Self.transport(), generated: "2026-07-30",
            mode: .init(projectOnly: true), allowShort: true)
        #expect(result.isTrustworthy)
        // Opted in, so the shard IS replaced.
        #expect(try sandbox.outputFiles()["series/rg_486.json"] != good)
    }

    @Test("PROJECT_ONLY re-projects an API store at the depth it was HARVESTED at")
    func projectOnlyHonoursHarvestedDepth() async throws {
        // The bug that cost 21 groups their file units: PROJECT_ONLY took depth from the plan, which
        // defaults to `series`, so a bare consolidation over a seriesAndFileUnits store silently
        // discarded every file unit and still reported success.
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let deepPlan = RecordGroupHarvestPlan(
            groups: [RecordGroupPlan(number: 486, depth: .seriesAndFileUnits)])
        let harvested = try await RecordGroupCatalogRunner.run(
            plan: deepPlan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: ScriptedTransport(bodies: [:]), generated: "2026-07-30",
            mode: .init(apiOnly: true), apiKey: "test-key",
            apiTransport: ScriptedAPITransport(responses: [
                (ScriptedAPITransport.groupNodePage(seriesCount: 2), 200),
                (ScriptedAPITransport.page(naIds: [1, 2], total: 2), 200),          // series
                (ScriptedAPITransport.fileUnitPage(naIds: [100, 101], total: 2), 200),
            ]))
        #expect(harvested.manifest.recordGroups.first?.harvestedFileUnitCount == 2)

        // Now consolidate with NO DEPTH set — the plan therefore says `series`.
        let consolidated = try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: ScriptedTransport(bodies: [:]), generated: "2026-07-30",
            mode: .init(projectOnly: true))
        // The file units survive, because the depth came from the API checkpoint.
        let group = try #require(consolidated.manifest.recordGroups.first)
        #expect(group.depth == .seriesAndFileUnits)
        #expect(group.harvestedFileUnitCount == 2)
        #expect(group.harvestedSeriesCount == 2)
    }

    @Test("The committed sample is capped, and stays a cross-section rather than a prefix")
    func sampleIsCapped() throws {
        // A fixed interval does not bound a committed file: 1-in-25 of 751,880 file-unit records
        // produced a 250 MB series-sample.json, which is not a thing to put in git.
        let many = (1...5000).map {
            HarvestedRecord(naId: String($0), title: "T\($0)", levelOfDescription: "series",
                            recordGroupNumber: 486, catalogURL: "u")
        }
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let writer = RecordGroupCatalogWriter(outputDirectory: sandbox.output, sampleEvery: 1)
        try writer.prepare()
        try writer.writeSample(many, totalRecords: 5000, generated: "2026-07-30")

        struct Sample: Codable { let totalRecords: Int; let sampledRecords: Int
                                 let records: [HarvestedRecord] }
        let decoded = try JSONDecoder().decode(
            Sample.self, from: try Data(contentsOf: writer.sampleURL))
        #expect(decoded.records.count == RecordGroupCatalogWriter.sampleCap)
        #expect(decoded.sampledRecords == RecordGroupCatalogWriter.sampleCap)
        #expect(decoded.totalRecords == 5000)
        // Evenly spread, not the first 500: the last kept record is near the end of the input.
        let lastNaId = Int(decoded.records.last?.naId ?? "0") ?? 0
        #expect(lastNaId > 4000, "sample should span the corpus, got last naId \(lastNaId)")
    }

    @Test("API_SURVEY writes into its own subtree and cannot clobber a harvest's report")
    func surveyDoesNotClobber() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        try await run(sandbox, transport: Self.transport())
        let harvestReport = try #require(try sandbox.outputFiles()["harvest-report.txt"])

        let result = try await RecordGroupCatalogRunner.run(
            plan: Self.plan, outputDirectory: sandbox.output, cacheDirectory: sandbox.cache,
            transport: Self.transport(), generated: "2026-07-30",
            mode: .init(apiSurvey: true), apiKey: "test-key",
            apiTransport: ScriptedAPITransport(responses: [
                (ScriptedAPITransport.page(naIds: [1, 2]), 200),
                (ScriptedAPITransport.emptyPage, 200),
            ]))

        let files = try sandbox.outputFiles()
        #expect(files["api-survey/harvest-report.txt"] != nil)
        // The real harvest's report is byte-identical to before the survey ran.
        #expect(files["harvest-report.txt"] == harvestReport)
        #expect(result.manifest.source.kind == "api-survey")
        // A survey writes no index.
        #expect(files["api-survey/series/rg_486.json"] == nil)

        let survey = String(decoding: try #require(files["api-survey/harvest-report.txt"]),
                            as: UTF8.self)
        #expect(survey.contains("PASTE THIS BACK"))
        #expect(survey.contains("body.hits.hits"))
        #expect(survey.contains("arity=2"))
    }

    @Test("The census CSVs report the priority payloads over the harvested corpus")
    func writesUsefulCensuses() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        try await run(sandbox, transport: Self.transport())
        let files = try sandbox.outputFiles()

        let fieldCensus = String(decoding: try #require(files["census/field-census.csv"]),
                                 as: UTF8.self)
        #expect(fieldCensus.contains("creators[].heading"))
        #expect(fieldCensus.contains("variantControlNumbers[].type"))

        let types = String(decoding: try #require(files["census/control-number-types.csv"]),
                           as: UTF8.self)
        #expect(types.contains("HMS/MLR Entry Number"))
        // The record-group spread column is what makes "agency-specific" answerable.
        #expect(types.contains("486"))

        let creators = String(decoding: try #require(files["census/creator-census.csv"]),
                              as: UTF8.self)
        #expect(creators.contains("Trade and Development Program"))
        #expect(creators.contains("10514123"))
    }
}
