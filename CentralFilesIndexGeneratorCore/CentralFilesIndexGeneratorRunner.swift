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
///
/// Exit code is non-zero if any golden check fails, so the harvest signals correctness.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 1 — Numerical File
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
    ]

    private init() {}

    /// Runs the Phase 1 harvest. Calls `exit(1)` on a fatal error or golden-check failure.
    public static func run() async {
        let env = ProcessInfo.processInfo.environment

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
