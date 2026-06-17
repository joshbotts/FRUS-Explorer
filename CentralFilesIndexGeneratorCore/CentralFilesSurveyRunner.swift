// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Surveys the structure of a NARA Catalog series without committing to a parser.
///
/// Phase 2 covers the country-arranged diplomatic series, whose real roll/file-unit title
/// formats are unknown until harvested (only the Numerical File was harvested in Phase 1).
/// This runner enumerates a series and reports its shape — record counts by level, sample
/// titles per level, parent file-unit linkage, and how many item titles yield a parseable
/// date — so the per-series geo/date parsers can be finalized against real data before the
/// full index build (the same survey-first discipline that worked for Phase 1).
///
/// Invoked from `CentralFilesIndexGeneratorRunner` when `SURVEY_SERIES=<naId>` is set.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2 survey
public enum CentralFilesSurveyRunner {

    /// The Phase 2 diplomatic series, for reference when choosing a `SURVEY_SERIES`.
    public static let diplomaticSeries: [(name: String, naId: String)] = [
        ("Diplomatic Despatches",        "603720"),
        ("Diplomatic Instructions",      "593313"),
        ("Notes from Foreign Missions",  "594363"),
        ("Notes to Foreign Missions",    "597272"),
    ]

    /// Enumerates `seriesNaId` and prints a structural report. Calls `exit(1)` on failure.
    public static func run(
        seriesNaId: String,
        apiKey: String,
        pageSize: Int,
        cacheDirectory: URL,
        refresh: Bool,
        samplesPerLevel: Int = 20
    ) async {
        let name = diplomaticSeries.first { $0.naId == seriesNaId }?.name ?? "series"
        print("[CentralFilesIndexGenerator] SURVEY — \(name) (\(seriesNaId))")

        let client = NARACatalogHarvestClient(
            apiKey: apiKey, pageSize: pageSize, cacheDirectory: cacheDirectory, refresh: refresh)

        let records: [CatalogRecord]
        do {
            records = try await client.enumerateDescendants(ancestorNaId: seriesNaId)
        } catch {
            print("[CentralFilesIndexGenerator] ✗ Enumeration failed: \(error)")
            exit(1)
        }

        // Group by level.
        var byLevel: [String: [CatalogRecord]] = [:]
        for record in records {
            byLevel[record.levelOfDescription ?? "(none)", default: []].append(record)
        }

        print("  Total records: \(records.count)")
        for level in byLevel.keys.sorted() {
            print("  • \(level): \(byLevel[level]!.count)")
        }

        // Sample titles per level.
        for level in byLevel.keys.sorted() {
            let recs = byLevel[level]!
            print("\n  ── sample \(level) titles ──")
            for record in recs.prefix(samplesPerLevel) {
                print("    • \(record.title)")
            }
        }

        // Item-level analysis: parent linkage + date parseability.
        let items = byLevel["item"] ?? []
        if !items.isEmpty {
            let withParent = items.filter { $0.parentFileUnitNaId != nil }.count
            let dateParsed = items.filter { HistoricalDateParser.parse($0.title) != nil }.count
            print("""

              ── item analysis ──
                items with a parent file unit: \(withParent)/\(items.count)
                item titles yielding a date:   \(dateParsed)/\(items.count)
            """)
            print("    sample parent file-unit titles:")
            var seenParents = Set<String>()
            for record in items {
                guard let parent = record.parentFileUnitTitle,
                      seenParents.insert(parent).inserted else { continue }
                print("      • \(parent)")
                if seenParents.count >= samplesPerLevel { break }
            }
        }

        print("\n[CentralFilesIndexGenerator] ✓ Survey complete for \(name).")
    }
}
