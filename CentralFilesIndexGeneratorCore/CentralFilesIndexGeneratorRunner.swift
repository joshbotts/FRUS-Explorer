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
        let passed = runGoldenChecks(against: result.index)

        // 4. Write.
        let index = CentralFilesIndex(
            generated: isoToday(),
            numericalFile: result.index)
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            print("[CentralFilesIndexGenerator] ✓ wrote \(result.matchedRolls) rolls to \(outputPath)")
        } catch {
            print("[CentralFilesIndexGenerator] ✗ Failed to write index: \(error)")
            exit(1)
        }

        if !passed {
            print("[CentralFilesIndexGenerator] ✗ One or more golden checks failed — see above.")
            exit(1)
        }
        print("[CentralFilesIndexGenerator] ✓ Done.")
    }

    // MARK: Reporting

    private static func printSurvey(_ result: NumericalFileHarvestResult) {
        let rolls = result.index.rolls
        let caseSpan = rolls.isEmpty ? "—"
            : "\(rolls.first!.caseStart)–\(rolls.map(\.caseEnd).max() ?? rolls.last!.caseEnd)"
        print("""
        [CentralFilesIndexGenerator] Survey:
          Total records:   \(result.totalRecords)
          Parsed as rolls: \(result.matchedRolls)
          Unmatched:       \(result.totalRecords - result.matchedRolls)
          Case span:       \(caseSpan)
          Coverage gaps:   \(result.coverageGaps.count)
          Range overlaps:  \(result.overlaps.count)
        """)
        if !result.unmatchedTitles.isEmpty {
            print("  Sample unmatched titles (filter check):")
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

    private static func isoToday() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
