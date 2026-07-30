// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit

// MARK: - RecordGroupCatalogRunner

/// Orchestrates the record-group catalog harvest.
///
/// ## Invocation
/// ```
/// swift run -c release RecordGroupCatalogGenerator
/// ```
/// No API key. The harvest reads NARA's public S3 bulk export.
///
/// ## Environment
/// | Variable | Default | Effect |
/// |---|---|---|
/// | `RECORD_GROUPS` | the 22 foreign-affairs groups | Comma-separated group numbers. |
/// | `DEPTH` | `series` | Baseline depth: `series`, `seriesAndFileUnits`, `all`. |
/// | `DEPTH_OVERRIDES` | — | `<rg>:<depth>` pairs — the per-group escalation path. |
/// | `OUTPUT_DIR` | `Planning/nara-record-group-catalog` | Artifact root. |
/// | `CACHE_DIR` | `.cache/nara-rg-catalog` | Raw NDJSON store + checkpoints. |
/// | `PROBE` | off | Fetch **one** shard per group, write the censuses only, no index. |
/// | `PROJECT_ONLY` | off | No network: rebuild everything from the stored raw NDJSON. |
/// | `CREATOR_AUTHORITY` | off | Also resolve `creators[].naId` against NARA's authority records. |
/// | `REFRESH` | off | Discard the store and checkpoints and re-harvest. |
/// | `MAX_BYTES` | unlimited | Byte budget for this run; exceeding it checkpoints and exits 0. |
/// | `SAMPLE_EVERY` | `25` | Sampling interval for the committed record sample. |
/// | `BASE_URL` | NARA's bucket | Origin override (used by the tests). |
/// | `GENERATED_DATE` | today, UTC | Reproducible `generated` stamp. |
/// | `ALLOW_SHORT` | off | Do not fail the run on a materially short group. |
///
/// ## Exit code
/// Non-zero when the harvest cannot be trusted: a required field (`creators`,
/// `variantControlNumbers`) matched **nothing** across the whole run, a checkpoint was refused, or a
/// group came in materially short of NARA's own `seriesCount` without `ALLOW_SHORT`. A run stopped
/// by the byte budget exits **zero** — it is a successful partial harvest that resumes.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordGroupCatalogRunner {

    /// Default artifact root, relative to the project root.
    public static let defaultOutputDir = "Planning/nara-record-group-catalog"
    /// Default cache root (gitignored).
    public static let defaultCacheDir = ".cache/nara-rg-catalog"

    /// Why the bulk export rather than the v2 search API. Recorded in the manifest so the choice
    /// travels with the data.
    static let sourceNote = """
        NARA's public S3 bulk export (no credentials, no API key, no quota). Chosen over the v2 \
        search API because it needs no CATALOG_API_KEY, is not subject to the 10,000-query monthly \
        quota, carries every level of description in one pass (so adding file units for a chosen \
        record group later is a filter change rather than a second harvest), and includes each \
        group's own recordGroup record whose seriesCount field is NARA's own expected series total \
        — which makes a truncated harvest self-detecting.
        """

    /// Reads the environment and runs. The entry point `main.swift` calls.
    public static func run() async throws {
        let env = ProcessInfo.processInfo.environment
        let plan = try RecordGroupHarvestPlan.resolve(
            recordGroups: env["RECORD_GROUPS"],
            depth: env["DEPTH"],
            depthOverrides: env["DEPTH_OVERRIDES"])

        let result = try await run(
            plan: plan,
            outputDirectory: URL(fileURLWithPath: env["OUTPUT_DIR"] ?? defaultOutputDir),
            cacheDirectory: URL(fileURLWithPath: env["CACHE_DIR"] ?? defaultCacheDir),
            baseURL: env["BASE_URL"] ?? CatalogBulkExportClient.defaultBaseURL,
            transport: URLSessionBulkTransport(),
            generated: generatorDateStamp(override: env["GENERATED_DATE"]),
            mode: Mode(env: env),
            byteBudget: env["MAX_BYTES"].flatMap { Int($0) },
            sampleEvery: env["SAMPLE_EVERY"].flatMap { Int($0) } ?? 25,
            allowShort: isTruthy(env["ALLOW_SHORT"]),
            apiKey: env["CATALOG_API_KEY"],
            apiPageSize: env["API_PAGE_SIZE"].flatMap { Int($0) } ?? 1000,
            maxAPIRequestsPerGroup: env["MAX_API_REQUESTS_PER_GROUP"].flatMap { Int($0) } ?? 200,
            apiTransport: URLSessionAPITransport(),
            log: { generatorLog($0) })

        if !result.isTrustworthy {
            generatorLog("[RecordGroupCatalogGenerator] ✗ harvest failed its own checks:")
            for failure in result.failures { generatorLog("    • \(failure)") }
            throw RunnerError.untrustworthyHarvest(result.failures)
        }
    }

    /// Whether an environment flag is set.
    static func isTruthy(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return ["1", "true", "yes", "y", "on"].contains(value)
    }

    // MARK: Mode

    /// Which pass to run.
    public struct Mode: Sendable, Equatable {
        /// One shard per group, censuses only, no index. The cheap first look.
        public var probe: Bool
        /// No network at all; rebuild from the stored raw NDJSON.
        public var projectOnly: Bool
        /// Also resolve creator authority records.
        public var creatorAuthority: Bool
        /// Discard the store and checkpoints first.
        public var refresh: Bool
        /// Re-page the live v2 API and overlay it on the bulk snapshot, emitting a changelog.
        public var apiRefresh: Bool
        /// Spend a handful of API calls answering the open questions about the live query shape.
        public var apiSurvey: Bool

        public init(probe: Bool = false, projectOnly: Bool = false,
                    creatorAuthority: Bool = false, refresh: Bool = false,
                    apiRefresh: Bool = false, apiSurvey: Bool = false) {
            self.probe = probe
            self.projectOnly = projectOnly
            self.creatorAuthority = creatorAuthority
            self.refresh = refresh
            self.apiRefresh = apiRefresh
            self.apiSurvey = apiSurvey
        }

        init(env: [String: String]) {
            self.init(probe: isTruthy(env["PROBE"]),
                      projectOnly: isTruthy(env["PROJECT_ONLY"]),
                      creatorAuthority: isTruthy(env["CREATOR_AUTHORITY"]),
                      refresh: isTruthy(env["REFRESH"]),
                      apiRefresh: isTruthy(env["API_REFRESH"]),
                      apiSurvey: isTruthy(env["API_SURVEY"]))
        }
    }

    // MARK: Result

    /// What a completed run produced, and whether it can be trusted.
    public struct RunResult: Sendable {
        public var manifest: RecordGroupCatalogManifest
        /// Reasons the harvest failed its own checks. Empty means trustworthy.
        public var failures: [String]
        public var isTrustworthy: Bool { failures.isEmpty }
    }

    /// A runner failure.
    public enum RunnerError: Error, CustomStringConvertible {
        case untrustworthyHarvest([String])

        public var description: String {
            switch self {
            case .untrustworthyHarvest(let failures):
                return "Harvest failed its own checks: " + failures.joined(separator: "; ")
            }
        }
    }

    // MARK: The parameterised run

    /// Runs the harvest with every input supplied explicitly.
    ///
    /// Tests call this directly with a stubbed transport and a temporary sandbox, so the whole
    /// pipeline is exercised without touching the network or the environment.
    @discardableResult
    public static func run(
        plan: RecordGroupHarvestPlan,
        outputDirectory: URL,
        cacheDirectory: URL,
        baseURL: String = CatalogBulkExportClient.defaultBaseURL,
        transport: any CatalogBulkTransport,
        generated: String,
        mode: Mode = Mode(),
        byteBudget: Int? = nil,
        sampleEvery: Int = 25,
        allowShort: Bool = false,
        apiKey: String? = nil,
        // 1000, not 100: the 2026-07-30 survey probe against RG 59 requested 1000 and received exactly
        // 1000 of its 4,449 series, so the documented maximum is honoured in practice. That is a 10x
        // reduction in calls against the monthly quota — the whole 22-group series layer becomes ~40.
        apiPageSize: Int = 1000,
        maxAPIRequestsPerGroup: Int = 200,
        apiTransport: (any CatalogAPITransport)? = nil,
        log: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> RunResult {

        let client = CatalogBulkExportClient(baseURL: baseURL, transport: transport)
        let rawStore = RawRecordStore(directory: cacheDirectory.appendingPathComponent("raw"))
        let checkpoints = CheckpointStore(
            directory: cacheDirectory.appendingPathComponent("checkpoints"))
        let harvester = RecordGroupHarvester(client: client, rawStore: rawStore,
                                            checkpoints: checkpoints, log: log)
        // The refresh lives in its own store rather than overwriting the snapshot's. Keeping both is
        // what makes a diff possible at all — and means a bad refresh can be deleted without costing
        // the 22 GB bulk harvest.
        let apiStore = RawRecordStore(directory: cacheDirectory.appendingPathComponent("raw-api"))
        let apiClient: CatalogAPIClient? = {
            guard mode.apiRefresh || mode.apiSurvey else { return nil }
            guard let apiKey, !apiKey.isEmpty else { return nil }
            return CatalogAPIClient(apiKey: apiKey, pageSize: apiPageSize,
                                    transport: apiTransport ?? URLSessionAPITransport(), log: log)
        }()
        if (mode.apiRefresh || mode.apiSurvey), apiClient == nil {
            throw CatalogAPIError.missingAPIKey
        }
        let builder = CatalogIndexBuilder(rawStore: rawStore)
        let writer = RecordGroupCatalogWriter(outputDirectory: outputDirectory,
                                              sampleEvery: sampleEvery)
        try writer.prepare()

        log("[RecordGroupCatalogGenerator] \(plan.groups.count) record groups"
            + (mode.probe ? " — PROBE mode (one shard each, censuses only)" : "")
            + (mode.projectOnly ? " — PROJECT_ONLY (offline re-projection)" : ""))

        if mode.apiSurvey, let apiClient {
            // Its own subtree, for the same reason PROBE has one: the survey writes a report, and
            // writing it at the output root would overwrite a completed harvest's harvest-report.txt
            // with a few pages of query-shape diagnostics.
            let surveyWriter = RecordGroupCatalogWriter(
                outputDirectory: outputDirectory.appendingPathComponent("api-survey"),
                sampleEvery: sampleEvery)
            try surveyWriter.prepare()
            return try await runAPISurvey(plan: plan, client: apiClient, writer: surveyWriter,
                                          generated: generated, baseURL: baseURL, log: log)
        }

        if mode.probe {
            // A probe describes one shard per group. Writing it into the same directory as a real
            // harvest would overwrite that harvest's manifest, censuses and report with a tiny
            // sample — so the probe gets its own subtree.
            let probeWriter = RecordGroupCatalogWriter(
                outputDirectory: outputDirectory.appendingPathComponent("probe"),
                sampleEvery: sampleEvery)
            try probeWriter.prepare()
            return try await runProbe(plan: plan, client: client, writer: probeWriter,
                                      generated: generated, baseURL: baseURL, log: log)
        }

        // MARK: Harvest + build, one group at a time

        var summaries: [RecordGroupSummary] = []
        var fieldCensus = FieldCensus()
        var valueCensus = ValueCensus()
        var controlNumberCensus = ControlNumberCensus()
        var creatorCensus = CreatorCensus()
        var ledger = FieldAliasLedger()
        // Sampled as we go rather than accumulated: retaining every projected record of every
        // group just to filter it at the end would defeat the one-group-at-a-time memory property.
        var sampleRecords: [HarvestedRecord] = []
        var totalRecordsProjected = 0
        var snapshots = Set<String>()
        var remainingBudget = byteBudget
        var reviewNotes: [String] = []
        var refusals: [String] = []
        var changeLog = RecordChangeLog()
        var apiRequestsSpent = 0
        var firstAPIObservation: APIEnvelopeObservation?

        for group in plan.groups {
            let outcome: RecordGroupHarvestOutcome
            if mode.projectOnly {
                guard rawStore.exists(recordGroup: group.number) else {
                    reviewNotes.append("RG \(group.number): PROJECT_ONLY found no raw store at "
                                       + "\(rawStore.url(recordGroup: group.number).path) — "
                                       + "nothing to re-project; harvest it first")
                    continue
                }
                // Re-projection reads whatever the last harvest stored; its mechanics come from the
                // checkpoint rather than from a fresh listing, so no network call is made.
                //
                // The state must come from the checkpoint, not be assumed: only the checkpoint knows
                // how much of the export the store covers, and stamping `resumedComplete` on a
                // half-finished store would put "complete" in the manifest for a group missing most
                // of its shards.
                let checkpoint = checkpoints.load(recordGroup: group.number)
                let isComplete = checkpoint.map {
                    $0.shardCount > 0 && $0.lastCompletedShardIndex >= $0.shardCount
                } ?? false
                outcome = RecordGroupHarvestOutcome(
                    recordGroup: group.number,
                    depth: checkpoint?.depth ?? group.depth,
                    shardsListed: checkpoint?.shardCount ?? 0,
                    recordsStored: checkpoint?.recordsWritten ?? 0,
                    snapshotLastModified: checkpoint?.snapshotLastModified,
                    state: isComplete ? .resumedComplete : .partial)
                if !isComplete {
                    reviewNotes.append("RG \(group.number): re-projected from an INCOMPLETE raw store "
                                       + "(\(checkpoint?.lastCompletedShardIndex ?? 0) of "
                                       + "\(checkpoint?.shardCount ?? 0) shards) — finish the harvest "
                                       + "before trusting this group's counts")
                }
            } else {
                outcome = try await harvester.harvest(plan: group, refresh: mode.refresh,
                                                      byteBudget: remainingBudget)
                if let budget = remainingBudget {
                    remainingBudget = max(0, budget - outcome.bytesRead)
                }
                if outcome.state == .refused {
                    refusals.append("RG \(group.number): checkpoint refused — see the log line above")
                    // A `continue` alone would leave the refusal in the exit message and NOWHERE on
                    // disk: no summary, no report row, no manifest entry. Anyone reading the artifacts
                    // later would see a manifest that simply omits the group, indistinguishable from
                    // never having asked for it. So the group gets a summary carrying its refused
                    // state.
                    summaries.append(RecordGroupSummary(
                        recordGroup: group.number, depth: group.depth,
                        shardsListed: outcome.shardsListed,
                        snapshotLastModified: outcome.snapshotLastModified,
                        state: .refused))
                    reviewNotes.append("RG \(group.number): REFUSED — its checkpoint is incompatible "
                                       + "with this run; nothing was harvested or re-projected for it")
                    continue
                }
            }

            if let snapshot = outcome.snapshotLastModified { snapshots.insert(snapshot) }

            // Refresh this group from the live API before building it, so the build sees both layers
            // and can classify the differences in one pass.
            var overlayForGroup: RawRecordStore? = nil

            // PROJECT_ONLY re-uses a refresh already on disk. This is the same principle the whole
            // design rests on — re-projection must be free — applied to the diff: correcting how
            // changes are CLASSIFIED must not cost another round of API calls, since the fetched
            // records are already sitting in raw-api/.
            if mode.projectOnly, apiStore.exists(recordGroup: group.number) {
                overlayForGroup = apiStore
                reviewNotes.append("RG \(group.number): re-classified against the API refresh already "
                                   + "on disk (no API calls spent)")
            }
            if mode.apiRefresh, let apiClient {
                do {
                    try apiStore.reset(recordGroup: group.number)
                    let writerHandle = try apiStore.openWriter(recordGroup: group.number)
                    defer { try? writerHandle.close() }
                    // One query per admitted level, rather than one unfiltered query. An unfiltered
                    // refresh of a `seriesAndFileUnits` group would page every level the catalog holds
                    // — items included, which for RG 59 is hundreds of thousands of records — and blow
                    // the per-group request ceiling long before reaching the file units we wanted.
                    // Paging each level separately also keeps the refresh's coverage identical to the
                    // snapshot's, which is what makes `missingFromRefresh` meaningful rather than an
                    // artefact of the two layers covering different levels.
                    var refreshedCount = 0
                    var spentForGroup = 0

                    // The group's own node first, so the completeness check survives an API-only
                    // harvest. Without it, `levelOfDescription=series` excludes the only record that
                    // states seriesCount and the harvest has nothing to check itself against.
                    if let node = try await apiClient.fetchRecordGroupNode(
                        recordGroup: group.number) {
                        try writerHandle.append(node)
                        if node["seriesCount"]?.intValue == nil {
                            reviewNotes.append("RG \(group.number): the API's record-group node carries "
                                               + "no seriesCount, so this refresh has no completeness "
                                               + "check — harvest the group from the bulk export if "
                                               + "that matters")
                        }
                    } else {
                        reviewNotes.append("RG \(group.number): the API returned no record-group node, "
                                           + "so this refresh has no completeness check")
                    }
                    spentForGroup += 1
                    for level in group.depth.admittedLevels.sorted() {
                        let result = try await apiClient.harvestGroup(
                            recordGroup: group.number, level: level,
                            maxRequests: maxAPIRequestsPerGroup - spentForGroup) { record in
                                try writerHandle.append(record)
                            }
                        refreshedCount += result.recordCount
                        spentForGroup += result.requestsSpent
                        if firstAPIObservation == nil { firstAPIObservation = result.observation }
                        log("[RecordGroupCatalogGenerator] RG \(group.number) [\(level)]: API "
                            + "refresh returned \(result.recordCount) records in "
                            + "\(result.requestsSpent) request(s)")
                        if spentForGroup >= maxAPIRequestsPerGroup { break }
                    }
                    apiRequestsSpent += spentForGroup
                    let result = (recordCount: refreshedCount, requestsSpent: spentForGroup)
                    _ = result.requestsSpent
                    if result.recordCount == 0 {
                        // Never merge an empty refresh: with the overlay logic, zero refresh records
                        // over a populated snapshot would classify EVERY record as
                        // `missingFromRefresh` and read as a catastrophic withdrawal.
                        reviewNotes.append("RG \(group.number): API refresh returned 0 records — the "
                                           + "refresh was DISCARDED for this group rather than merged "
                                           + "(merging it would have reported every snapshot record "
                                           + "as withdrawn). Check the API survey output.")
                    } else {
                        overlayForGroup = apiStore
                    }
                } catch {
                    // A refresh failure must not destroy a good snapshot-derived index.
                    reviewNotes.append("RG \(group.number): API refresh FAILED (\(error)) — this "
                                       + "group's index is from the bulk snapshot alone")
                }
            }

            let built = try builder.build(outcome: outcome, overlay: overlayForGroup)
            changeLog.merge(built.changeLog)
            summaries.append(built.summary)
            fieldCensus.merge(built.fieldCensus)
            valueCensus.merge(built.valueCensus)
            controlNumberCensus.merge(built.controlNumberCensus)
            creatorCensus.merge(built.creatorCensus)
            ledger.merge(built.aliasLedger)

            let shard = RecordGroupIndexShard(
                generated: generated, recordGroup: group.number,
                title: built.summary.title, depth: built.summary.depth,
                records: built.records)
            let bytes = try writer.writeShard(shard)
            log("[RecordGroupCatalogGenerator] RG \(group.number): wrote "
                + "\(shard.records.count) records (\(RecordGroupHarvester.formatBytes(bytes)))")

            for record in shard.records {
                if totalRecordsProjected % sampleEvery == 0 { sampleRecords.append(record) }
                totalRecordsProjected += 1
            }

            if outcome.state == .budgetExhausted {
                reviewNotes.append("RG \(group.number): stopped by MAX_BYTES with a checkpoint "
                                   + "written — re-run the same command to continue")
                break
            }
        }

        // MARK: Creator authority pass

        var authority: CreatorAuthorityHarvester.Result? = nil
        if mode.creatorAuthority {
            let naIds = creatorCensus.referencedNaIds
            if naIds.isEmpty {
                reviewNotes.append("CREATOR_AUTHORITY requested but no creator NAIDs were harvested")
            } else if mode.projectOnly {
                reviewNotes.append("CREATOR_AUTHORITY skipped: PROJECT_ONLY is offline and the "
                                   + "authority pass needs the network")
            } else {
                log("[RecordGroupCatalogGenerator] resolving \(naIds.count) creator authority "
                    + "records")
                let result = try await CreatorAuthorityHarvester(client: client, log: log)
                    .harvest(naIds: naIds, byteBudget: remainingBudget)
                try writer.writeCreatorAuthority(CreatorAuthorityIndex(
                    generated: generated,
                    creators: Array(result.records.values),
                    unresolvedNaIds: result.unresolvedNaIds))
                authority = result
                if !result.unresolvedNaIds.isEmpty {
                    // "Unresolved" means two very different things depending on whether the scan
                    // finished, and only one of them is a claim about NARA's holdings.
                    reviewNotes.append(result.truncatedByBudget
                        ? "\(result.unresolvedNaIds.count) creator NAIDs are still unresolved because "
                          + "the authority pass stopped on its byte budget — this says nothing about "
                          + "whether NARA holds their authority records; re-run to finish"
                        : "\(result.unresolvedNaIds.count) referenced creator NAIDs had no authority "
                          + "record anywhere in the export")
                }
                if result.malformedLines > 0 {
                    reviewNotes.append("\(result.malformedLines) authority-record lines failed to "
                                       + "decode: \(result.malformedExamples.prefix(2).joined(separator: "; "))")
                }
            }
        }

        // MARK: Manifest, censuses, report

        // The run-wide artifacts — manifest, all five censuses, the sample, the report — are rewritten
        // from THIS run's groups. Per-group index shards are not, so a subset run leaves the other
        // groups' shards intact while the manifest and censuses shrink to describe only the subset.
        //
        // That is a real trap for the recommended workflow, which harvests the 21 smaller groups and
        // then RG 59 separately: the second run would leave a manifest that mentions RG 59 alone. The
        // fix is not to merge partial manifests (which would silently mix snapshots and alias
        // reports); it is to finish with one offline `PROJECT_ONLY=1` pass over every group, which
        // rebuilds the run-wide artifacts from the raw stores at no network cost.
        let isSubset = Set(plan.groups.map(\.number))
            != Set(RecordGroupHarvestPlan.defaultRecordGroupNumbers)
        if isSubset {
            reviewNotes.append("SUBSET RUN (\(plan.groups.count) record group(s)): manifest.json, the "
                               + "census CSVs, series-sample.json and this report describe ONLY these "
                               + "groups. Per-group index shards for other groups are untouched. When "
                               + "every group has been harvested, run PROJECT_ONLY=1 with no "
                               + "RECORD_GROUPS to rebuild the run-wide artifacts over all of them "
                               + "(offline, no re-download).")
        }

        // True when a diff actually happened — either a live refresh, or PROJECT_ONLY re-classifying
        // against a refresh already on disk.
        let didDiff = mode.apiRefresh || !changeLog.counts.isEmpty

        // Appended BEFORE the manifest is constructed. The manifest captures `reviewNotes` by value,
        // so a note added after it is built reaches the log and nothing else — the same mistake the
        // refused-group path made.
        if didDiff {
            reviewNotes.append("API refresh spent \(apiRequestsSpent) request(s); "
                               + "added=\(changeLog.total(.added)) "
                               + "modified=\(changeLog.total(.modified)) "
                               + "unchanged=\(changeLog.total(.unchanged)) "
                               + "missingFromRefresh=\(changeLog.total(.missingFromRefresh))")
        }

        let totals = makeTotals(summaries: summaries, creatorCensus: creatorCensus,
                                controlNumberCensus: controlNumberCensus)
        if totals.malformedLines > 0 {
            reviewNotes.append("\(totals.malformedLines) source line(s) failed to decode and are "
                               + "therefore MISSING from the index — see the per-group counts in the "
                               + "report; a non-trivial count means the harvest is incomplete")
        }
        let manifest = RecordGroupCatalogManifest(
            generated: generated,
            source: .init(kind: "s3-bulk-export", baseURL: baseURL,
                          snapshotLastModified: snapshots.sorted(), note: sourceNote),
            totals: totals,
            recordGroups: summaries,
            fieldAliasReport: makeAliasReport(ledger),
            reviewNotes: reviewNotes)

        try writer.writeManifest(manifest)
        try writer.writeCensuses(fieldCensus: fieldCensus, valueCensus: valueCensus,
                                 controlNumberCensus: controlNumberCensus,
                                 creatorCensus: creatorCensus)
        try writer.writeSample(sampleRecords, totalRecords: totalRecordsProjected,
                               generated: generated)
        if didDiff { try writer.writeChangeLog(changeLog) }
        let report = HarvestReportBuilder().render(
            manifest: manifest, controlNumberCensus: controlNumberCensus,
            creatorCensus: creatorCensus, fieldCensus: fieldCensus,
            creatorAuthority: authority,
            changeLog: didDiff ? changeLog : nil,
            apiObservation: firstAPIObservation)
        try writer.writeReport(report)

        log(report)

        // MARK: Self-assessment

        var failures = refusals

        // The emptiness check has to come FIRST and stand on its own. Every other check is
        // conditional on there being records to check: `neverMatched` only reports a field it
        // actually examined, and `isMateriallyShort` needs NARA's own count, which lives on a group
        // node that an empty harvest never read. So a run that projected nothing at all would
        // satisfy every remaining check and exit 0 — the exact "plausible artifact, missing data"
        // outcome this tool exists to make impossible.
        let projected = totals.harvestedSeriesCount + totals.harvestedFileUnitCount
            + totals.harvestedItemCount
        if summaries.isEmpty {
            failures.append("no record group produced a summary — nothing was harvested or "
                            + "re-projected; check the log for listing or transport failures")
        } else if projected == 0 {
            failures.append("harvested 0 records across \(summaries.count) record group(s) — the "
                            + "index is empty. Nothing downstream can distinguish this from a "
                            + "corpus that genuinely has no series, so it is a failure by default")
        }

        for field in ledger.neverMatched(among: RecordProjector.requiredFields) {
            failures.append("required field '\(field)' matched no key spelling in any record — the "
                            + "harvest's whole purpose is missing; check census/field-census.csv "
                            + "for the real key name, correct RecordProjector.aliases, and re-run "
                            + "with PROJECT_ONLY=1 (no re-download needed)")
        }
        if !allowShort {
            for group in summaries where group.isMateriallyShort {
                // A group the byte budget stopped is *honestly* partial and says so in its state; it
                // must not also be reported as suspected truncation, or the documented "a budget stop
                // exits 0, re-run to continue" contract would be a lie.
                guard !group.state.isKnowinglyIncomplete else { continue }
                failures.append("RG \(group.recordGroup): harvested \(group.harvestedSeriesCount) "
                                + "series but NARA states \(group.expectedSeriesCount ?? 0) "
                                + "— possible truncation (set ALLOW_SHORT=1 if expected)")
            }
        }

        return RunResult(manifest: manifest, failures: failures)
    }

    // MARK: Probe

    /// Fetches one shard per group and writes only the censuses.
    ///
    /// The cheap first look, and the reason nothing in this design has to be taken on trust: a probe
    /// costs one shard per group (a few MB) and answers the only question that could invalidate the
    /// whole harvest — are `creators` and `variantControlNumbers` really there, under those names,
    /// in these record groups.
    static func runProbe(
        plan: RecordGroupHarvestPlan,
        client: CatalogBulkExportClient,
        writer: RecordGroupCatalogWriter,
        generated: String,
        baseURL: String,
        log: @escaping @Sendable (String) -> Void
    ) async throws -> RunResult {

        var fieldCensus = FieldCensus()
        var valueCensus = ValueCensus()
        var controlNumberCensus = ControlNumberCensus()
        var creatorCensus = CreatorCensus()
        var ledger = FieldAliasLedger()
        var summaries: [RecordGroupSummary] = []
        var snapshots = Set<String>()
        let projector = RecordProjector()

        for group in plan.groups {
            let shards = try await client.listDescriptionShards(recordGroup: group.number)
            guard let first = shards.first else { continue }
            if let snapshot = first.lastModified { snapshots.insert(snapshot) }

            // `.partial`, never `.complete`: the probe reads ONE shard of `shards.count`. Stamping
            // "complete" on a one-shard sample would put the word in the manifest for a group whose
            // other 399 shards were never opened.
            var summary = RecordGroupSummary(
                recordGroup: group.number, depth: group.depth,
                shardsListed: shards.count, shardsRead: 1,
                snapshotLastModified: first.lastModified, state: .partial)
            var levelCounts: [String: Int] = [:]

            let bytes = try await client.streamRecords(shard: first) { raw in
                let level = raw["levelOfDescription"]?.nonEmptyString ?? "(none)"
                levelCounts[level, default: 0] += 1

                if level == "recordGroup" {
                    summary.naId = raw["naId"]?.nonEmptyString
                    summary.title = raw["title"]?.nonEmptyString
                    summary.expectedSeriesCount = raw["seriesCount"]?.intValue
                    return
                }
                fieldCensus.ingest(raw)
                valueCensus.ingest(raw, recordGroup: group.number)
                // Probe at `all` depth regardless of the plan, so one shard reports on every level
                // present rather than on series alone — the census is the point here, not the index.
                if case .projected(let record) = projector.project(
                    raw, recordGroup: group.number, depth: .all, ledger: &ledger) {
                    // Every level is counted, not just series: the probe reads one arbitrary shard,
                    // and for a small record group that shard may hold no series at all (measured:
                    // RG 268 and RG 420 shard 1 are file units only). Counting series alone made the
                    // probe's coverage percentages divide by the wrong denominator.
                    switch record.levelOfDescription {
                    case "series":   summary.harvestedSeriesCount += 1
                    case "fileUnit": summary.harvestedFileUnitCount += 1
                    case "item":     summary.harvestedItemCount += 1
                    default:         break
                    }
                    if summary.naId == nil,
                       let ancestor = record.ancestors.first(where: {
                           $0.levelOfDescription == "recordGroup"
                       }) {
                        summary.naId = ancestor.naId
                        summary.title = ancestor.title
                    }
                    if !record.creators.isEmpty { summary.recordsWithCreators += 1 }
                    if !record.variantControlNumbers.isEmpty {
                        summary.recordsWithControlNumbers += 1
                    }
                    // Counted here too, or the probe's PRIORITY block reports 0 contributors while
                    // its own alias report and value census show sixteen — which reads as a bug in
                    // the projection rather than a gap in the summary.
                    if !record.contributors.isEmpty { summary.recordsWithContributors += 1 }
                    if record.localIdentifier != nil { summary.recordsWithLocalIdentifier += 1 }
                    controlNumberCensus.ingest(record.variantControlNumbers,
                                               recordGroup: group.number)
                    creatorCensus.ingest(record.creators, recordGroup: group.number)
                }
            }
            summary.bytesRead = bytes
            summaries.append(summary)

            let levels = levelCounts.keys.sorted()
                .map { "\($0)=\(levelCounts[$0] ?? 0)" }.joined(separator: " ")
            log("[RecordGroupCatalogGenerator] probe RG \(group.number): \(first.key) "
                + "(\(RecordGroupHarvester.formatBytes(bytes))) — \(levels)")
        }

        let manifest = RecordGroupCatalogManifest(
            generated: generated,
            source: .init(kind: "s3-bulk-export-probe", baseURL: baseURL,
                          snapshotLastModified: snapshots.sorted(), note: sourceNote),
            totals: makeTotals(summaries: summaries, creatorCensus: creatorCensus,
                               controlNumberCensus: controlNumberCensus),
            recordGroups: summaries,
            fieldAliasReport: makeAliasReport(ledger),
            reviewNotes: ["PROBE mode: one shard per record group. The censuses describe that "
                          + "sample only, and no index was written."])

        try writer.writeManifest(manifest)
        try writer.writeCensuses(fieldCensus: fieldCensus, valueCensus: valueCensus,
                                 controlNumberCensus: controlNumberCensus,
                                 creatorCensus: creatorCensus)
        let report = HarvestReportBuilder().render(
            manifest: manifest, controlNumberCensus: controlNumberCensus,
            creatorCensus: creatorCensus, fieldCensus: fieldCensus, creatorAuthority: nil)
        try writer.writeReport(report)
        log(report)

        // A probe fails only on the one thing it exists to check.
        let failures = ledger.neverMatched(among: RecordProjector.requiredFields).map {
            "required field '\($0)' matched no key spelling in the probed shards"
        }
        return RunResult(manifest: manifest, failures: failures)
    }

    // MARK: API survey

    /// Spends a handful of API calls answering the four open questions about the live query shape, and
    /// writes nothing but a report.
    ///
    /// Deliberately its own mode rather than a flag on the refresh: the whole point is to learn the
    /// query shape *before* spending a few hundred calls on it.
    static func runAPISurvey(
        plan: RecordGroupHarvestPlan,
        client: CatalogAPIClient,
        writer: RecordGroupCatalogWriter,
        generated: String,
        baseURL: String,
        log: @escaping @Sendable (String) -> Void
    ) async throws -> RunResult {

        // The smallest group in the plan by preference — RG 486 has 11 series, so one page covers it.
        let surveyGroup = plan.groups.map(\.number).contains(486) ? 486 : (plan.groups.first?.number ?? 486)
        log("[RecordGroupCatalogGenerator] API SURVEY on RG \(surveyGroup) — a handful of calls, "
            + "no index written")

        var lines = ["NARA Catalog API survey", "Generated: \(generated)",
                     "Record group: \(surveyGroup)", String(repeating: "─", count: 78)]
        var failures: [String] = []
        do {
            let observations = try await client.survey(recordGroup: surveyGroup, level: "series")
            for (index, observation) in observations.enumerated() {
                lines.append("PAGE \(index + 1)")
                lines.append(contentsOf: observation.reportLines)
                lines.append("")
            }
            if observations.first?.hitsPath == nil {
                failures.append("the API response had no recognisable hits container — see "
                                + "topLevelKeys in the survey report; CatalogAPIClient"
                                + ".hitsPathCandidates needs the real path")
            }
            if observations.count < 2 {
                lines.append("NOTE: only one page was returned. For a group that fits in one page "
                             + "(RG 486 has 11 series) that is the correct outcome.")
            }
            // Sort-consistency check. The first request now seeds `searchAfter=*` precisely so that
            // page 1 is ordered the same way as page 2; if page 1 still comes back arity 2, the seed
            // did not take effect and cursor paging is still unsafe for multi-page groups.
            if let firstArity = observations.first?.sortArity {
                if firstArity >= 2 {
                    lines.append("⚠ PAGE 1 SORT IS STILL ARITY \(firstArity) despite the seeded "
                                 + "cursor — the first page is relevance-ordered while later pages are "
                                 + "naId-ordered, so multi-page groups may skip or duplicate records. "
                                 + "The de-duplication and totalHits stop keep the RESULT correct, but "
                                 + "report this back.")
                } else {
                    lines.append("✓ page 1 sort arity \(firstArity) — the seeded cursor produced a "
                                 + "consistent ordering, so cursor paging is sound.")
                }
            }
            // Compare arity only across pages that actually returned hits. An empty terminator page
            // has no sort array at all (arity 0), and flagging that as unstable ordering reported a
            // healthy end-of-results as a defect — which is exactly what the 2026-07-30 re-run showed
            // ("1 → 0") immediately after the seeded cursor had in fact fixed the ordering.
            let nonEmpty = observations.filter { $0.returnedHitCount > 0 }
            let arities = Set(nonEmpty.map(\.sortArity))
            if arities.count > 1 {
                lines.append("⚠ sort arity DIFFERS across non-empty pages "
                             + "(\(nonEmpty.map(\.sortArity).map(String.init).joined(separator: " → ")))"
                             + " — the ordering is not stable across requests.")
            } else if nonEmpty.count >= 2 {
                lines.append("✓ sort arity is consistent across all non-empty pages.")
            }

            // The page-size question needs a group large enough to fill a big page: RG 486's 11 series
            // return 11 whether the limit is 100 or 1000, so a small group cannot answer it. One extra
            // call against RG 59 (~4,435 series) settles it.
            lines.append("")
            lines.append("PAGE-SIZE PROBE (RG 59, limit=1000)")
            do {
                let probe = try await client.surveyPageSizeLimit(recordGroup: 59, level: "series")
                lines.append(contentsOf: probe.reportLines)
                if probe.returnedHitCount >= 1000 {
                    lines.append("  ✓ limit=1000 is honoured — use API_PAGE_SIZE=1000")
                } else if let total = probe.totalHits, total > probe.returnedHitCount {
                    lines.append("  ⚠ CLAMPED to \(probe.returnedHitCount) of \(total) available — "
                                 + "set API_PAGE_SIZE to that value")
                }
            } catch {
                lines.append("  probe failed: \(error)")
            }
        } catch {
            lines.append("SURVEY FAILED: \(error)")
            failures.append("API survey failed: \(error)")
        }
        lines.append(String(repeating: "─", count: 78))
        lines.append("=== PASTE THIS BACK ===")
        lines.append("Send the whole block above. It settles: the envelope path, which sort element is "
                     + "the cursor, whether `limit` is honoured, and whether `q` is required.")

        let text = lines.joined(separator: "\n") + "\n"
        try writer.writeReport(text)
        log(text)

        return RunResult(
            manifest: RecordGroupCatalogManifest(
                generated: generated,
                source: .init(kind: "api-survey", baseURL: CatalogAPIClient.defaultEndpoint,
                              snapshotLastModified: [], note: sourceNote),
                totals: .init(), recordGroups: [],
                reviewNotes: ["API SURVEY only: no index, no censuses, nothing harvested."]),
            failures: failures)
    }

    // MARK: Aggregation helpers

    /// Rolls per-group summaries up to run totals.
    static func makeTotals(
        summaries: [RecordGroupSummary],
        creatorCensus: CreatorCensus,
        controlNumberCensus: ControlNumberCensus
    ) -> RecordGroupCatalogManifest.Totals {
        RecordGroupCatalogManifest.Totals(
            recordGroupCount: summaries.count,
            expectedSeriesCount: summaries.compactMap(\.expectedSeriesCount).reduce(0, +),
            harvestedSeriesCount: summaries.map(\.harvestedSeriesCount).reduce(0, +),
            harvestedFileUnitCount: summaries.map(\.harvestedFileUnitCount).reduce(0, +),
            harvestedItemCount: summaries.map(\.harvestedItemCount).reduce(0, +),
            recordsWithCreators: summaries.map(\.recordsWithCreators).reduce(0, +),
            recordsWithControlNumbers: summaries.map(\.recordsWithControlNumbers).reduce(0, +),
            // Distinct counts come from the merged censuses, not from summing per-group counts —
            // a creator active in six record groups must count once, not six times.
            distinctCreators: creatorCensus.entries.count,
            distinctControlNumberTypes: controlNumberCensus.typeSummaries.count,
            shardsRead: summaries.map(\.shardsRead).reduce(0, +),
            bytesRead: summaries.map(\.bytesRead).reduce(0, +),
            malformedLines: summaries.map(\.malformedLines).reduce(0, +),
            invariantViolations: summaries
                .flatMap { $0.invariantViolations.values }.reduce(0, +))
    }

    /// Renders the alias ledger into manifest entries, including the fields that never matched.
    static func makeAliasReport(
        _ ledger: FieldAliasLedger
    ) -> [RecordGroupCatalogManifest.AliasReportEntry] {
        var fields = Set(ledger.observations.keys)
        // Required fields appear even when nothing was examined, so their absence from the report
        // can never be mistaken for their presence in the data.
        fields.formUnion(RecordProjector.requiredFields)
        return fields.sorted().map { field in
            let observation = ledger.observations[field] ?? FieldAliasLedger.Observation()
            return .init(field: field,
                         matchedAliases: observation.matchedAlias,
                         presentButEmpty: observation.presentButEmpty,
                         absent: observation.absent,
                         required: RecordProjector.requiredFields.contains(field))
        }
    }
}
