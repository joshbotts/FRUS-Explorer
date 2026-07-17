// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - GoldenCheck

/// A known-correct lookup drawn from the user's hand-traced reference data
/// (`Planning/Pre1910-CentralFiles-Reference-Data.md`). The harvest validates itself
/// against these so a broken parse or a missing roll fails loudly rather than shipping.
public struct GoldenCheck: Sendable, Equatable {
    /// FRUS "File No." citation as printed.
    public let fileNumber: String
    /// Expected roll NAID the citation should resolve to.
    public let expectedRollNaId: String
    /// Human-readable provenance (e.g. "frus1907p2/d246").
    public let source: String

    public init(fileNumber: String, expectedRollNaId: String, source: String) {
        self.fileNumber = fileNumber
        self.expectedRollNaId = expectedRollNaId
        self.source = source
    }
}

// MARK: - CentralFilesIndexGeneratorRunner

/// Orchestrates the Phase 1 (Numerical File) harvest.
///
/// Steps:
/// 1. Enumerate all digitized rolls under the Numerical File series (NAID 654171),
///    paging the NARA Catalog v2 API and caching each page to disk.
/// 2. Build the case-number → roll index and a survey of parse coverage.
/// 3. Validate against the golden checks from the reference data.
/// 4. Write `central-files-index.json`.
///
/// ## Invocation
/// ```
/// CATALOG_API_KEY=<key> swift run CentralFilesIndexGenerator
/// ```
/// Optional environment variables:
///   OUTPUT_PATH — index output path (default `FRUSExplorer/Resources/central-files-index.json`)
///   CACHE_DIR   — raw-page cache directory (default `.cache/central-files`)
///   PAGE_SIZE   — rows per request (default 25; try 100 on the first survey run)
///   REFRESH     — `1`/`true` to ignore the page cache and re-fetch
///   PRUNE_FLAGGED_LOTS — `1`/`true`: offline mode (NO API key) — drop lot files flagged
///                 `ancestryLacksRecordGroup` from an already-harvested index and rewrite it,
///                 then exit. Applies the #321 policy (drop the candidate mis-resolutions the
///                 removed null-record-group fallback let in) to the shipped index without a
///                 full re-harvest.
///
/// Exit code is non-zero if any golden check fails, so the harvest signals correctness.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 1 — Numerical File
///   1.1 — #321: PRUNE_FLAGGED_LOTS offline mode
public struct CentralFilesIndexGeneratorRunner {

    /// NARA series NAID for the 1906–1910 Numerical File.
    public static let numericalFileSeriesNaId = "654171"
    /// Microfilm publication for the Numerical File.
    public static let numericalFileMicrofilm = "M862"
    /// Default index output path, relative to the project root.
    public static let defaultOutputPath = "FRUSExplorer/Resources/central-files-index.json"
    /// Default raw-page cache directory.
    public static let defaultCacheDir = ".cache/central-files"

    /// Golden checks from the hand-traced reference data (Docs 6 & 7).
    public static let goldenChecks: [GoldenCheck] = [
        GoldenCheck(fileNumber: "7187",   expectedRollNaId: "19779414", source: "frus1907p2/d246"),
        GoldenCheck(fileNumber: "697/43", expectedRollNaId: "19174810", source: "frus1909/d299"),
    ]

    /// Phase 2 golden checks (Docs 1–5): a `(category, geoKey, date)` lookup must surface
    /// the roll the user reached by hand.
    public static let countryGoldenChecks: [CountryGoldenCheck] = [
        CountryGoldenCheck(category: .instructions, geoKey: "great britain", dateISO: "1863-07-06",
                           expectedNaId: "149311973", source: "frus1863p1/d229"),
        CountryGoldenCheck(category: .notesFrom, geoKey: "venezuela", dateISO: "1893-10-26",
                           expectedNaId: "188287901", source: "frus1894/d815"),
        CountryGoldenCheck(category: .notesTo, geoKey: "paraguay", dateISO: "1878-11-13",
                           expectedNaId: "216926854", source: "frus1878/d412"),
        CountryGoldenCheck(category: .despatches, geoKey: "japan", dateISO: "1905-03-14",
                           expectedNaId: "188401761", source: "frus1905/d544"),
        CountryGoldenCheck(category: .despatches, geoKey: "switzerland", dateISO: "1875-09-28",
                           expectedNaId: "189376306", source: "frus1876/d311"),
        // Doc 8: consular despatch from Havana (the enclosure's originating series).
        CountryGoldenCheck(category: .consularDespatches, geoKey: "havana", dateISO: "1895-06-19",
                           expectedNaId: "211373468", source: "frus1895p2/d464"),
    ]

    private init() {}

    /// Runs the Phase 1 harvest. Calls `exit(1)` on a fatal error or golden-check failure.
    /// Attaches HMS/MLR entry numbers + `levelOfDescription` to the already-resolved lot
    /// files in the bundled index, in place (#315).
    ///
    /// Reads the existing index rather than re-harvesting: the NAIDs are already there and
    /// are the stable key (the control-number index has drifted since the June harvest — see
    /// `NARACatalogHarvestClient.fetchRecord(naId:)`). Every other section of the index is
    /// round-tripped untouched.
    ///
    /// **Queries are keyed by distinct NAID, not by lot.** One catalog series is indexed
    /// under many lot numbers — the verifying spike's record carried four — so grouping cuts
    /// the request count well below the entry count and makes the reverse mapping explicit:
    /// every lot sharing a NAID gets that record's entry numbers, by construction rather
    /// than by a second lookup.
    ///
    /// Failures are per-NAID and non-fatal: a miss leaves that record's entries `nil`
    /// (indistinguishable from "genuinely has none", which is what the UI wants anyway) and
    /// the pass continues. Re-running is safe and cheap — it is idempotent, and the client's
    /// throttle/backoff already governs the request rate.
    /// Offline prune (#321 + #351): drops the two classes of candidate mis-resolution from an
    /// already-harvested index, then rewrites it through the same writer so the diff stays clean.
    ///   - `ancestryLacksRecordGroup` (#321): the null-record-group `firstAccepted` fallback let
    ///     presidential-library staff files (no record group in their ancestry) resolve as lots.
    ///   - `levelOfDescription == "fileUnit"` (#351): a lot query that matched a *file unit* whose
    ///     own control-number list is empty — the #335 audit measured this class as almost
    ///     entirely wrong-collection (Conference Files Lot 60 D 627 → an "Operation Mongoose" file
    ///     unit; others → Nazi-War-Crimes disclosure folders, the Polish Foreign Ministry). A real
    ///     State lot resolves to a `series`; a `fileUnit` hit is a false positive.
    ///
    /// This is the offline equivalent of a full re-harvest for both policies: each class only ever
    /// entered via a resolver quirk, so pruning here yields the same trustworthy lot set without the
    /// Phase 1/2/3 enumerations — which matters when the page cache is cold. Both classes are also
    /// treated as unresolved at read time by the app's `CentralFilesIndex` and the SPM
    /// `BundledLotResolver`, so this prune only shrinks dead weight; it changes no resolvable link.
    /// Deterministic and idempotent (a second run finds nothing to drop).
    static func pruneFlaggedLots(outputPath: String, generated: String) {
        guard var index = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("[CentralFilesIndexGenerator] ✗ PRUNE_FLAGGED_LOTS: cannot read \(outputPath)")
            exit(1)
        }
        func isMisResolution(_ lf: LotFileEntry) -> Bool {
            lf.ancestryLacksRecordGroup == true || lf.levelOfDescription == "fileUnit"
        }
        let dropped = index.lotFiles.filter(isMisResolution)
        let before = index.lotFiles.count
        index.lotFiles = index.lotFiles.filter { !isMisResolution($0) }
        index.generated = generated
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            print("[CentralFilesIndexGenerator] ✓ PRUNE_FLAGGED_LOTS: dropped \(dropped.count) "
                  + "flagged lot(s), \(before) → \(index.lotFiles.count), wrote \(outputPath)")
            for lf in dropped.sorted(by: { $0.lotNumber < $1.lotNumber }) {
                let reason = lf.ancestryLacksRecordGroup == true ? "null-RG #321" : "fileUnit #351"
                print("    dropped \(lf.recordGroup)_\(lf.lotNumber) → naId \(lf.naId) "
                      + "“\(lf.title.prefix(40))” [\(reason)]")
            }
        } catch {
            print("[CentralFilesIndexGenerator] ✗ PRUNE_FLAGGED_LOTS: failed to write: \(error)")
            exit(1)
        }
    }

    /// Re-harvests only the lot files (#352 `RESOLVE_LOTS_ONLY`), preserving the existing Numerical
    /// File + country-series sections read from `outputPath`. Runs Phase 3 (`harvestLotFiles`, which
    /// applies the #352 post-validation) and nothing else — no Phase 1/2 enumeration, no golden
    /// checks — then writes the combined index. Fails loudly if there is no existing index to
    /// preserve (this mode augments a shipped bundle; it does not build one from scratch).
    static func resolveLotsOnly(outputPath: String, csvPath: String,
                                client: NARACatalogHarvestClient) async {
        guard let existing = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("""
            [CentralFilesIndexGenerator] ✗ RESOLVE_LOTS_ONLY: cannot read \(outputPath).
              This mode preserves the existing Numerical File / country-series sections and only
              re-harvests lots — it needs an already-built index. Run the full keyed harvest first,
              or point OUTPUT_PATH at the shipped central-files-index.json.
            """)
            exit(1)
        }
        let lotFiles = await harvestLotFiles(csvPath: csvPath, client: client)
        let index = CentralFilesIndex(
            generated: isoToday(),
            numericalFile: existing.numericalFile,
            countrySeries: existing.countrySeries,
            lotFiles: lotFiles)
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            print("[CentralFilesIndexGenerator] ✓ RESOLVE_LOTS_ONLY wrote \(lotFiles.count) lot files "
                  + "(Numerical File + \(existing.countrySeries.count) country series preserved) to \(outputPath)")
            print("  Next: run ENRICH_LOTS to re-attach #315/#351 fields, then PRUNE_FLAGGED_LOTS.")
        } catch {
            print("[CentralFilesIndexGenerator] ✗ RESOLVE_LOTS_ONLY: failed to write index: \(error)")
            exit(1)
        }
    }

    static func enrichLotFiles(outputPath: String, client: NARACatalogHarvestClient) async {
        guard let existing = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("[CentralFilesIndexGenerator] ✗ ENRICH_LOTS: cannot read \(outputPath) — "
                  + "run the full harvest first.")
            exit(1)
        }
        var lotFiles = existing.lotFiles
        guard !lotFiles.isEmpty else {
            print("[CentralFilesIndexGenerator] ✗ ENRICH_LOTS: the index has no lot files to enrich.")
            exit(1)
        }

        // NAID -> every lot entry resolving to it.
        let byNaId = Dictionary(grouping: lotFiles.indices) { lotFiles[$0].naId }
        print("""
        [CentralFilesIndexGenerator] #315 lot enrichment
          lot entries:   \(lotFiles.count)
          distinct NAIDs:\(byNaId.count)   (one query each)
        """)

        var enriched = 0, misses = 0, withEntries = 0, nonSeries = 0
        var noRecordGroup: [String] = []
        var fileUnitResolutions: [String] = []
        // Enclosing-series records, memoized by series NAID: file units share series (both
        // Numerical File units resolve to the same "Numerical Files" series), so this collapses
        // the follow-up queries to one per DISTINCT series. `nil` marks a series that missed,
        // so it is not retried per file unit.
        var seriesCache: [String: CatalogRecord?] = [:]

        for naId in byNaId.keys.sorted() {          // sorted: deterministic logs
            guard let indices = byNaId[naId] else { continue }
            guard let record = try? await client.fetchRecord(naId: naId), !record.naId.isEmpty else {
                misses += 1
                continue
            }
            let entries = record.hmsMlrEntryNumbers
            if !entries.isEmpty { withEntries += 1 }

            let isSeries = record.levelOfDescription == CatalogRecord.seriesLevel
            if record.levelOfDescription != nil && !isSeries { nonSeries += 1 }

            // #351 candidate mis-resolution: a lot query that landed on a `fileUnit` record (a
            // folder inside another collection), not the series a real lot names. Reported like
            // the null-RG class — never silently dropped here; the owner runs PRUNE_FLAGGED_LOTS.
            if record.levelOfDescription == "fileUnit" {
                let lots = indices.map { lotFiles[$0].lotNumber }.sorted().joined(separator: "/")
                fileUnitResolutions.append("\(lots) → naId \(naId) “\(record.title.prefix(40))”")
            }

            // Data-quality flag: an RG-59/84 lot whose chain contains no record group at all
            // (e.g. `collection > series` — a presidential-library record) is a candidate
            // mis-resolution. Reported, never silently dropped: the call is the owner's.
            let lacksRG = !record.ancestorLevels.isEmpty
                && !record.ancestorLevels.contains("recordGroup")
            if lacksRG {
                // Every affected lot, not just the first: one bad NAID is typically shared by
                // several lot numbers (three distinct lots resolve to NAID 323153965), and
                // reporting one of them understates the blast radius.
                let lots = indices.map { lotFiles[$0].lotNumber }.sorted().joined(separator: "/")
                noRecordGroup.append("\(lots) → naId \(naId) “\(record.title.prefix(40))”")
            }

            // The enclosing series — only for records that are not themselves series (#315).
            var seriesRecord: CatalogRecord? = nil
            if !isSeries, let seriesNaId = record.seriesAncestorNaId {
                if let cached = seriesCache[seriesNaId] {
                    seriesRecord = cached
                } else {
                    seriesRecord = try? await client.fetchRecord(naId: seriesNaId)
                    seriesCache[seriesNaId] = seriesRecord
                }
            }

            for i in indices {
                lotFiles[i].hmsMlrEntryNumbers = entries.isEmpty ? nil : entries
                lotFiles[i].levelOfDescription = record.levelOfDescription
                lotFiles[i].ancestryLacksRecordGroup = lacksRG ? true : nil
                if !isSeries {
                    // Prefer the fetched series record's own title over the ancestor stub's;
                    // fall back to the stub, which is what makes the title free.
                    lotFiles[i].seriesNaId = record.seriesAncestorNaId
                    lotFiles[i].seriesTitle = seriesRecord?.title ?? record.seriesAncestorTitle
                    let se = seriesRecord?.hmsMlrEntryNumbers ?? []
                    lotFiles[i].seriesHmsMlrEntryNumbers = se.isEmpty ? nil : se
                }
            }
            enriched += 1
        }

        let updated = CentralFilesIndex(
            generated: isoToday(),
            numericalFile: existing.numericalFile,
            countrySeries: existing.countrySeries,
            lotFiles: lotFiles)
        do {
            try CentralFilesIndexWriter.write(updated, to: outputPath)
        } catch {
            print("[CentralFilesIndexGenerator] ✗ ENRICH_LOTS: failed to write index: \(error)")
            exit(1)
        }
        let entryCount = lotFiles.filter { !($0.hmsMlrEntryNumbers ?? []).isEmpty }.count
        let withSeriesTitle = lotFiles.filter { $0.seriesTitle != nil }.count
        // NB: the generator's LotFileEntry is a distinct type from the app's and has no
        // isSeriesLevel helper — compare the level directly.
        let namedSeries = lotFiles.filter {
            $0.levelOfDescription == CatalogRecord.seriesLevel || $0.seriesTitle != nil
        }.count
        let seriesEntryCounts = lotFiles.compactMap { $0.seriesHmsMlrEntryNumbers?.count }
        print("""
        [CentralFilesIndexGenerator] ✓ ENRICH_LOTS wrote \(outputPath)
          NAIDs enriched:        \(enriched)   (query misses: \(misses))
          NAIDs with an entry #: \(withEntries) / \(enriched)
          lot entries carrying an entry #: \(entryCount) / \(lotFiles.count)
          NAIDs NOT at series level: \(nonSeries)   (+\(seriesCache.count) series follow-up queries)
          lot entries given an enclosing-series title: \(withSeriesTitle)
          lot entries that can now name a file series: \(namedSeries) / \(lotFiles.count)
        """)
        if !seriesEntryCounts.isEmpty {
            let sorted = seriesEntryCounts.sorted()
            print("""
              enclosing-series entry-number counts (the #315-B presentation call):
                min \(sorted.first!)  median \(sorted[sorted.count / 2])  max \(sorted.last!)
                a large max means the parent's identifiers do NOT pinpoint the file unit
            """)
        }
        if !noRecordGroup.isEmpty {
            let affected = lotFiles.filter { $0.ancestryLacksRecordGroup == true }.count
            print("""
              ⚠︎ MIS-RESOLUTION CANDIDATES — \(noRecordGroup.count) NAID(s), \(affected) lot entr(ies)
                resolve to a record whose ancestry contains NO recordGroup. A State Department
                lot file is by definition RG 59/84, so a record parented by a `collection`
                (i.e. a presidential library) is not one. Measured 2026-07-15: every flagged
                record was a presidential-library staff file, and several distinct lots
                collapsed onto a single NAID — see #321.
                \(noRecordGroup.sorted().joined(separator: "\n                "))
            """)
        }
        if !fileUnitResolutions.isEmpty {
            let affected = lotFiles.filter { $0.levelOfDescription == "fileUnit" }.count
            print("""
              ⚠︎ FILE-UNIT RESOLUTIONS — \(fileUnitResolutions.count) NAID(s), \(affected) lot entr(ies)
                resolve to a `fileUnit`-level record, not a series. A lot file is catalogued as a
                series; a fileUnit hit means the control-number query matched a folder inside some
                other collection whose own control list is empty (#335 audit: 60 D 627 →
                “Operation Mongoose”). The app and BundledLotResolver already treat these as
                unresolved (#351); run PRUNE_FLAGGED_LOTS to drop them from the shipped bundle.
                \(fileUnitResolutions.sorted().joined(separator: "\n                "))
            """)
        }
    }

    public static func run() async {
        let env = ProcessInfo.processInfo.environment

        // Offline prune mode (#321): drop lot files flagged `ancestryLacksRecordGroup` and exit.
        // No API key — checked before the key guard because it needs none. A reproducible way to
        // apply the #321 policy (drop the candidate mis-resolutions the removed null-record-group
        // fallback let in) to an already-shipped index without a full re-harvest.
        if ["1", "true", "yes"].contains((env["PRUNE_FLAGGED_LOTS"] ?? "").lowercased()) {
            pruneFlaggedLots(outputPath: env["OUTPUT_PATH"] ?? defaultOutputPath,
                             generated: env["GENERATED_DATE"] ?? isoToday())
            return
        }

        guard let apiKey = env["CATALOG_API_KEY"], !apiKey.isEmpty else {
            print("""
            [CentralFilesIndexGenerator] ✗ CATALOG_API_KEY is not set.
              Get a key at https://catalog.archives.gov/ and run:
              CATALOG_API_KEY=<key> swift run CentralFilesIndexGenerator
            """)
            exit(1)
        }

        let outputPath = env["OUTPUT_PATH"] ?? defaultOutputPath
        let cacheDir = URL(fileURLWithPath: env["CACHE_DIR"] ?? defaultCacheDir, isDirectory: true)
        let pageSize = env["PAGE_SIZE"].flatMap(Int.init) ?? 25
        let refresh = ["1", "true", "yes"].contains((env["REFRESH"] ?? "").lowercased())

        // Phase 2 survey mode: when SURVEY_SERIES is set, report that series' structure
        // (record levels, sample titles, parent linkage, date parseability) and exit —
        // used to finalize the diplomatic-series parsers before the full index build.
        if let surveySeries = env["SURVEY_SERIES"], !surveySeries.isEmpty {
            await CentralFilesSurveyRunner.run(
                seriesNaId: surveySeries, apiKey: apiKey,
                pageSize: pageSize, cacheDirectory: cacheDir, refresh: refresh)
            return
        }

        // Lot enrichment mode (#315): re-query only the already-resolved lot records to
        // attach their HMS/MLR entry numbers, then exit. A mode rather than a phase because
        // enrichment must NOT drag the Phase 1/2 enumerations (thousands of requests) along
        // behind it — it needs one cheap query per distinct NAID and nothing else.
        if ["1", "true", "yes"].contains((env["ENRICH_LOTS"] ?? "").lowercased()) {
            await enrichLotFiles(
                outputPath: outputPath,
                client: NARACatalogHarvestClient(apiKey: apiKey,
                                                 cacheDirectory: cacheDir,
                                                 refresh: refresh))
            return
        }

        // Lots-only resolution mode (#352): re-harvest the lot files from CITATIONS_CSV and
        // **preserve** the existing Numerical File + country-series sections, skipping the Phase 1/2
        // enumerations (thousands of requests) and their golden checks — the same reason
        // `ENRICH_LOTS` is a mode. Use this to apply the #352 post-validation to the lot set on a
        // machine with a cold page cache, without paying for a full re-enumeration of data that is
        // already correct and shipped. Requires an existing index (to preserve) + CITATIONS_CSV.
        if ["1", "true", "yes"].contains((env["RESOLVE_LOTS_ONLY"] ?? "").lowercased()) {
            guard let csvPath = env["CITATIONS_CSV"], !csvPath.isEmpty else {
                print("[CentralFilesIndexGenerator] ✗ RESOLVE_LOTS_ONLY requires CITATIONS_CSV=<path>.")
                exit(1)
            }
            await resolveLotsOnly(
                outputPath: outputPath, csvPath: csvPath,
                client: NARACatalogHarvestClient(apiKey: apiKey, pageSize: pageSize,
                                                 cacheDirectory: cacheDir, refresh: refresh))
            return
        }

        print("""
        [CentralFilesIndexGenerator] Phase 1 — Numerical File (series \(numericalFileSeriesNaId), \(numericalFileMicrofilm))
          page size: \(pageSize)   cache: \(cacheDir.path)   refresh: \(refresh)
        """)

        let client = NARACatalogHarvestClient(
            apiKey: apiKey, pageSize: pageSize, cacheDirectory: cacheDir, refresh: refresh)

        // 1. Enumerate.
        let records: [CatalogRecord]
        do {
            records = try await client.enumerateDescendants(ancestorNaId: numericalFileSeriesNaId)
        } catch {
            print("[CentralFilesIndexGenerator] ✗ Catalog enumeration failed: \(error)")
            exit(1)
        }

        // 2. Build + survey.
        let result = NumericalFileIndexBuilder.build(
            records: records,
            seriesNaId: numericalFileSeriesNaId,
            microfilm: numericalFileMicrofilm)

        printSurvey(result)

        // 3. Golden checks.
        let numericalPassed = runGoldenChecks(against: result.index)

        // 4. Phase 2 — country-arranged diplomatic series.
        print("\n[CentralFilesIndexGenerator] Phase 2 — country-arranged diplomatic series")
        var seriesIndexes: [CountrySeriesIndex] = []
        for category in CountrySeriesCategory.allCases {
            do {
                let recs = try await client.enumerateDescendants(ancestorNaId: category.seriesNaId)
                let r = CountrySeriesIndexBuilder.build(category: category, records: recs)
                printCountrySurvey(category, r)
                seriesIndexes.append(r.index)
            } catch {
                print("[CentralFilesIndexGenerator] ✗ \(category.displayName) enumeration failed: \(error)")
                exit(1)
            }
        }

        // 4b. Phase 3 — pre-resolve lot files from the citations CSV (optional). Preserves
        // any previously-harvested lot files when CITATIONS_CSV is not supplied this run.
        var lotFiles: [LotFileEntry] = (try? CentralFilesIndexWriter.read(from: outputPath))?.lotFiles ?? []
        if let csvPath = env["CITATIONS_CSV"], !csvPath.isEmpty {
            lotFiles = await harvestLotFiles(csvPath: csvPath, client: client)
        }

        // 5. Write the combined index.
        let index = CentralFilesIndex(
            generated: isoToday(),
            numericalFile: result.index,
            countrySeries: seriesIndexes,
            lotFiles: lotFiles)
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            let countryRolls = seriesIndexes.reduce(0) { $0 + $1.rolls.count }
            print("[CentralFilesIndexGenerator] ✓ wrote \(result.matchedRolls) numerical rolls "
                  + "+ \(countryRolls) country rolls + \(lotFiles.count) lot files to \(outputPath)")
        } catch {
            print("[CentralFilesIndexGenerator] ✗ Failed to write index: \(error)")
            exit(1)
        }

        // 6. Phase 2 golden checks.
        let countryPassed = runCountryGoldenChecks(against: index)

        if !numericalPassed || !countryPassed {
            print("[CentralFilesIndexGenerator] ✗ One or more golden checks failed — see above.")
            exit(1)
        }
        print("[CentralFilesIndexGenerator] ✓ Done.")
    }

    // MARK: Phase 3 — Lot files

    /// Extracts every distinct lot file from the citations CSV and resolves each to its
    /// NARA Catalog series record (cached per lot). Prints a survey.
    private static func harvestLotFiles(csvPath: String, client: NARACatalogHarvestClient) async -> [LotFileEntry] {
        print("\n[CentralFilesIndexGenerator] Phase 3 — lot files (CSV: \(csvPath))")

        // 1. Extract distinct lots (offline).
        var distinct: [String: LotFileCitation] = [:]
        do {
            try CitationCSVReader.forEachPlainText(path: csvPath) { plainText in
                for citation in LotFileCitationExtractor.citations(in: plainText) {
                    distinct[citation.normalizedLot] = citation
                }
            }
        } catch {
            print("[CentralFilesIndexGenerator] ✗ Could not read citations CSV: \(error)")
            return []
        }
        let citations = distinct.values.sorted { $0.normalizedLot < $1.normalizedLot }
        print("  distinct lot numbers: \(citations.count)")

        // 2. Resolve each (cached per lot). RETRY_LOT_MISSES re-attempts only the
        //    previously-unresolved lots (keeps cached hits) — for use after improving the
        //    resolver or after a transient-503 run.
        let retryMisses = ["1", "true", "yes"].contains(
            (ProcessInfo.processInfo.environment["RETRY_LOT_MISSES"] ?? "").lowercased())
        var entries: [LotFileEntry] = []
        var unresolvedLots: [String] = []
        var resolved = 0, missed = 0
        for (i, citation) in citations.enumerated() {
            do {
                // Control-only bundle: skip any stale phrase hits left in the cache from
                // earlier runs (the resolver no longer produces them).
                if let resolved0 = try await client.resolveLotFile(
                    normalized: citation.normalizedLot, recordGroup: citation.recordGroup,
                    retryMisses: retryMisses), resolved0.matchType == "control" {
                    entries.append(LotFileEntry(
                        lotNumber: citation.normalizedLot,
                        recordGroup: citation.recordGroup,
                        naId: resolved0.record.naId,
                        title: resolved0.record.title,
                        catalogURL: NARACatalogHarvestClient.catalogIDBase + resolved0.record.naId,
                        matchType: resolved0.matchType))
                    resolved += 1
                } else {
                    missed += 1
                    unresolvedLots.append("\(citation.normalizedLot)\tRG \(citation.recordGroup)")
                }
            } catch {
                missed += 1
                unresolvedLots.append("\(citation.normalizedLot)\tRG \(citation.recordGroup)\t(error)")
                #if DEBUG
                print("[CentralFilesIndexGenerator] lot \(citation.normalizedLot) errored: \(error)")
                #endif
            }
            if (i + 1) % 100 == 0 {
                print("  …\(i + 1)/\(citations.count) (\(resolved) resolved)")
            }
        }

        let rg59 = entries.filter { $0.recordGroup == "59" }.count
        let rg84 = entries.filter { $0.recordGroup == "84" }.count
        let control = entries.filter { $0.matchType == "control" }.count
        let phrase = entries.filter { $0.matchType == "phrase" }.count
        print("""
          Lot-file survey:
            distinct:  \(citations.count)
            resolved:  \(resolved)  (RG 59: \(rg59), RG 84: \(rg84))
              by match: control \(control), phrase \(phrase)
            unresolved:\(missed)
        """)
        // Emit the unresolved list next to the cache for spot-checking which lots are
        // genuinely uncatalogued vs. a fixable format/RG issue.
        if !unresolvedLots.isEmpty {
            let cacheDir = URL(fileURLWithPath:
                ProcessInfo.processInfo.environment["CACHE_DIR"] ?? defaultCacheDir, isDirectory: true)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let url = cacheDir.appendingPathComponent("unresolved-lots.txt")
            try? unresolvedLots.sorted().joined(separator: "\n")
                .write(to: url, atomically: true, encoding: .utf8)
            print("  unresolved lots written to \(url.path)")
        }
        // #352 post-validation audit: lots where an RG-matching record existed but was dropped
        // for being a file unit or for not carrying the queried lot in its own control numbers
        // (the 60 D 627 → "Operation Mongoose" empty-list class). These are wrong matches the old
        // RG-only rule would have bundled; printed so the owner can eyeball for any false drop.
        let rejections = await client.lotPostValidationRejections
        if !rejections.isEmpty {
            print("""
              ⚠︎ #352 POST-VALIDATION — \(rejections.count) lot(s) dropped a candidate RG match
                (fileUnit, or the record does not carry the queried lot in variantControlNumbers).
                Review for false rejections; the old RG-only rule would have bundled these:
                \(rejections.sorted().joined(separator: "\n                "))
            """)
        }
        return entries.sorted { $0.lotNumber < $1.lotNumber }
    }

    // MARK: Reporting

    private static func printSurvey(_ result: NumericalFileHarvestResult) {
        let rolls = result.index.rolls
        let caseSpan = rolls.isEmpty ? "—"
            : "\(rolls.first!.caseStart)–\(rolls.map(\.caseEnd).max() ?? rolls.last!.caseEnd)"
        print("""
        [CentralFilesIndexGenerator] Survey:
          Total records:   \(result.totalRecords)
          Duplicates:      \(result.duplicatesSkipped) (same NAID returned more than once)
          Parsed as rolls: \(result.matchedRolls)
          Unmatched:       \(result.unmatchedCount) (name/place rolls + non-case records)
          Case span:       \(caseSpan)
          Coverage gaps:   \(result.coverageGaps.count)
          Range overlaps:  \(result.overlaps.count)
        """)
        if !result.unmatchedTitles.isEmpty {
            print("  Sample unmatched titles (should be name/place or finding-aid records):")
            for title in result.unmatchedTitles { print("    • \(title)") }
        }
        for gap in result.coverageGaps.prefix(10) {
            print("  ⚠︎ coverage gap: cases \(gap.from)–\(gap.to) unclaimed")
        }
        for overlap in result.overlaps.prefix(10) {
            print("  ⚠︎ overlap: \(overlap.lower.title) & \(overlap.higher.title)")
        }
    }

    private static func runGoldenChecks(against index: NumericalFileIndex) -> Bool {
        var allPassed = true
        print("[CentralFilesIndexGenerator] Golden checks (from reference data):")
        for check in goldenChecks {
            let roll = index.roll(forFileNumber: check.fileNumber)
            let ok = roll?.naId == check.expectedRollNaId
            allPassed = allPassed && ok
            let mark = ok ? "✓" : "✗"
            let got = roll.map { "\($0.naId) (\($0.title))" } ?? "no roll"
            print("    \(mark) \(check.source): File No. \(check.fileNumber) → \(got)"
                  + (ok ? "" : "  [expected \(check.expectedRollNaId)]"))
        }
        return allPassed
    }

    private static func printCountrySurvey(_ category: CountrySeriesCategory,
                                           _ r: CountrySeriesHarvestResult) {
        let distinctGeo = Set(r.index.rolls.flatMap(\.geoKeys)).count
        print("""
          ── \(category.displayName) (\(category.seriesNaId)) ──
            total records:     \(r.totalRecords)
            resolution rolls:  \(r.rollCount)  (distinct countries: \(distinctGeo))
            without geo key:   \(r.rollsWithoutGeo)
            without date:      \(r.rollsWithoutDate)
        """)
        if !r.sampleNoGeo.isEmpty {
            print("    sample no-geo titles:")
            for t in r.sampleNoGeo.prefix(6) { print("      • \(t)") }
        }
        if !r.sampleNoDate.isEmpty {
            print("    sample no-date titles:")
            for t in r.sampleNoDate.prefix(6) { print("      • \(t)") }
        }
    }

    private static func runCountryGoldenChecks(against index: CentralFilesIndex) -> Bool {
        var allPassed = true
        print("[CentralFilesIndexGenerator] Phase 2 golden checks (from reference data):")
        for check in countryGoldenChecks {
            let matches = index.series(category: check.category.rawValue)?
                .rolls(geoKey: check.geoKey, dateISO: check.dateISO) ?? []
            let ok = matches.contains { $0.naId == check.expectedNaId }
            allPassed = allPassed && ok
            let mark = ok ? "✓" : "✗"
            let got = matches.isEmpty ? "no roll"
                : matches.map(\.naId).joined(separator: ", ")
            print("    \(mark) \(check.source): \(check.category.displayName) / "
                  + "\(check.geoKey) / \(check.dateISO) → \(got)"
                  + (ok ? "" : "  [expected \(check.expectedNaId)]"))
        }
        return allPassed
    }

    private static func isoToday() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - CountryGoldenCheck

/// A known-correct `(category, country, date)` lookup from the reference data (Docs 1–5).
public struct CountryGoldenCheck: Sendable, Equatable {
    public let category: CountrySeriesCategory
    public let geoKey: String
    public let dateISO: String
    public let expectedNaId: String
    public let source: String

    public init(category: CountrySeriesCategory, geoKey: String, dateISO: String,
                expectedNaId: String, source: String) {
        self.category = category
        self.geoKey = geoKey
        self.dateISO = dateISO
        self.expectedNaId = expectedNaId
        self.source = source
    }
}
