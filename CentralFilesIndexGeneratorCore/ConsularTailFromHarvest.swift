// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LotClaimantsIndexGeneratorCore

// MARK: - ConsularTailFromHarvest

/// W-8's offline harvest: builds the three remaining Phase-3 consular-tail series —
/// Consular Instructions (604019), Notes to Foreign Consuls (1076611), Notes from Foreign
/// Consuls (1076629) — into `central-files-index.json` from the OFFLINE record-group
/// harvest, with **no `CATALOG_API_KEY` and no network**.
///
/// ## Why offline can answer what the plan reserved for the keyed API
/// The plan gated Phase 3 on a keyed survey + harvest because each series' structure was
/// unknown. Measured against the bulk shard (2026-08-27), the structure is now known and
/// the shard is COMPLETE for these series: every quoted-NAID occurrence count reconciles
/// exactly as `2 × fileUnitCount + 1`, and NARA's own `fileUnitCount` on the three series
/// records (7 / 4 / 11) matches the file units present. All three are SINGLE CHRONOLOGICAL
/// RUNS whose file units ARE the bound volumes, carrying their date spans in their titles —
/// the 2-level pattern Diplomatic Instructions and Notes to Foreign Missions already ship
/// at. The ITEM level, which the shard lacks (its depth stopped at file units), is exactly
/// what these series do not have: a chronological run has no per-post subdivision to
/// itemize. That is why Consular Despatches (302031) — item-grain, 3,357 rolls — HAD to
/// come from the keyed API in June, and why these three do not.
///
/// ## The `availableOnline=true` parity
/// The keyed route asks NARA only for digitized records. The offline analogue is
/// `digitalObjectCount > 0`, applied here for the same reason: a roll link opens the
/// page-by-page viewer, and an undigitized volume has no pages to view. Skipped volumes
/// are PRINTED, not silently dropped — Consular Instructions is documented as digitized
/// only for 1801–1834 (the archived plan's Risk 3), so skips are expected there.
///
/// ## Completeness is NARA's own number, and the health check is on the input
/// The pass fails when the file units it collects for a series disagree with the
/// `fileUnitCount` stated on that series' own record in the same shard — the
/// self-detecting-truncation rule the record-group harvest itself uses. It also refuses a
/// shard that yields fewer than 200,000 records (rg_59 holds 240,929): a truncated or
/// wrong file must fail loudly, not produce a plausible near-empty index.
///
/// ## Not reproducible from a clone — stdout is the review surface
/// `HARVEST_DIR` is 4.5 GB, gitignored, and on one machine (the same standing as
/// `SUPPLEMENT_FROM_HARVEST`). So the pass prints EVERY roll it writes — 22 rows — and
/// every volume it skips, so a reviewer who cannot re-run it can read what it decided.
///
/// ## Idempotence
/// A re-run that would write byte-identical series entries returns without writing —
/// `generated` is not bumped for a run that changed nothing.
///
/// ## The snapshot caveat, stated rather than hidden
/// The bulk export is a snapshot (2026-04-09). Digitization NARA finished since is
/// invisible here; the keyed harvest loop (`CountrySeriesCategory.allCases`) now includes
/// these categories, so any future keyed run refreshes them from the live catalog.
///
/// Version history:
///   1.0 — W-8: initial implementation
enum ConsularTailFromHarvest {

    /// The three tail categories this pass builds, in output order.
    static let tailCategories: [CountrySeriesCategory] = [
        .consularInstructions, .notesToForeignConsuls, .notesFromForeignConsuls,
    ]

    /// A shard smaller than this many records is a wrong or truncated file, not a harvest.
    static let minimumShardRecords = 200_000

    /// Offline golden checks — a real FRUS-era date resolving to the known volume, one per
    /// series, against the freshly built entries. NAIDs read from the shard 2026-08-27.
    struct TailGoldenCheck {
        let category: CountrySeriesCategory
        let dateISO: String
        let expectedNaId: String
    }

    static let goldenChecks: [TailGoldenCheck] = [
        // "Instructions: October 12, 1801 - February 26, 1817"
        TailGoldenCheck(category: .consularInstructions, dateISO: "1810-05-01",
                        expectedNaId: "220862827"),
        // "1/31/1865 - 9/29/1868"
        TailGoldenCheck(category: .notesToForeignConsuls, dateISO: "1866-01-15",
                        expectedNaId: "40038222"),
        // "January 2, 1864 - December 31, 1864"
        TailGoldenCheck(category: .notesFromForeignConsuls, dateISO: "1864-06-01",
                        expectedNaId: "216891526"),
    ]

    // MARK: - Run

    static func run(outputPath: String, harvestDir: String, generated: String) {
        guard var index = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("[CentralFilesIndexGenerator] ✗ CONSULAR_TAIL_FROM_HARVEST: cannot read \(outputPath) — this mode supplements an existing index, never creates one")
            exit(1)
        }

        let shard = URL(fileURLWithPath: harvestDir)
            .appending(path: "series").appending(path: "rg_59.json")

        let wanted = Dictionary(uniqueKeysWithValues: tailCategories.map { ($0.seriesNaId, $0) })
        var collected: [CountrySeriesCategory: [HarvestShardReader.Record]] = [:]
        var statedCounts: [CountrySeriesCategory: Int] = [:]
        var scanned = 0

        do {
            try HarvestShardReader.forEachRecord(shard) { record in
                scanned += 1
                if record.levelOfDescription == "fileUnit",
                   let seriesNaId = record.seriesAncestorNaId,
                   let category = wanted[seriesNaId] {
                    collected[category, default: []].append(record)
                }
                // The series' own record states NARA's file-unit count — the completeness
                // reference for what we just collected.
                if record.levelOfDescription == "series", let category = wanted[record.naId] {
                    statedCounts[category] = record.fileUnitCount
                }
            }
        } catch {
            print("[CentralFilesIndexGenerator] ✗ CONSULAR_TAIL_FROM_HARVEST: \(error)")
            exit(1)
        }

        guard scanned >= minimumShardRecords else {
            print("[CentralFilesIndexGenerator] ✗ CONSULAR_TAIL_FROM_HARVEST: only \(scanned) records in \(shard.path) — a truncated or wrong shard (rg_59 holds ~240,929)")
            exit(1)
        }
        print("[CentralFilesIndexGenerator] CONSULAR_TAIL_FROM_HARVEST: scanned \(scanned) records in rg_59.json")

        var newEntries: [CountrySeriesIndex] = []
        for category in tailCategories {
            let records = (collected[category] ?? []).sorted { $0.naId < $1.naId }

            // Completeness against NARA's own statement — a mismatch is a broken read, not
            // a judgment call.
            guard let stated = statedCounts[category] else {
                print("  ✗ \(category.rawValue): the series record (\(category.seriesNaId)) was not seen in the shard — cannot verify completeness")
                exit(1)
            }
            guard records.count == stated else {
                print("  ✗ \(category.rawValue): collected \(records.count) file units but NARA's own fileUnitCount says \(stated)")
                exit(1)
            }

            let digitized = records.filter { ($0.digitalObjectCount ?? 0) > 0 }
            for skipped in records where (skipped.digitalObjectCount ?? 0) == 0 {
                print("  – \(category.rawValue): SKIPPED undigitized volume \(skipped.naId) “\(skipped.title)” (the availableOnline parity — no pages to view)")
            }

            // Through the SAME parser + builder the keyed route uses — one grammar, no drift.
            let catalogRecords = digitized.map {
                CatalogRecord(naId: $0.naId, title: $0.title, levelOfDescription: "fileUnit")
            }
            let result = CountrySeriesIndexBuilder.build(category: category, records: catalogRecords)

            guard !result.index.rolls.isEmpty else {
                print("  ✗ \(category.rawValue): zero rolls built — an empty series entry silently disables the feature, refusing to write")
                exit(1)
            }
            if result.rollsWithoutDate > 0 {
                // A chronological-run roll with no date bound can never match a query —
                // dead weight that looks like coverage. All 22 real titles parse today.
                print("  ✗ \(category.rawValue): \(result.rollsWithoutDate) roll(s) with no parseable date: \(result.sampleNoDate.joined(separator: " | "))")
                exit(1)
            }

            print("  ✓ \(category.rawValue): \(stated) file units, \(digitized.count) digitized → \(result.index.rolls.count) rolls")
            for roll in result.index.rolls {
                print("      \(roll.naId)  \(roll.startISO ?? "……")–\(roll.endISO ?? "……")  “\(roll.title)”")
            }
            newEntries.append(result.index)
        }

        // Golden checks against the BUILT entries, before anything is written.
        for check in goldenChecks {
            guard let entry = newEntries.first(where: { $0.category == check.category.rawValue }),
                  entry.rolls(containingDate: check.dateISO).contains(where: { $0.naId == check.expectedNaId })
            else {
                print("  ✗ golden check failed: \(check.category.rawValue) @ \(check.dateISO) should resolve to \(check.expectedNaId)")
                exit(1)
            }
        }
        print("  ✓ all \(goldenChecks.count) tail golden checks pass")

        // Replace-or-append, preserving the existing entries' order; idempotent re-runs
        // return without writing.
        var countrySeries = index.countrySeries
        var changed = false
        for entry in newEntries {
            if let i = countrySeries.firstIndex(where: { $0.category == entry.category }) {
                if countrySeries[i] != entry { countrySeries[i] = entry; changed = true }
            } else {
                countrySeries.append(entry)
                changed = true
            }
        }
        guard changed else {
            print("[CentralFilesIndexGenerator] CONSULAR_TAIL_FROM_HARVEST: index already carries identical entries — nothing to write")
            return
        }
        index.countrySeries = countrySeries
        index.generated = generated
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            let total = newEntries.map(\.rolls.count).reduce(0, +)
            print("[CentralFilesIndexGenerator] ✓ CONSULAR_TAIL_FROM_HARVEST: wrote \(newEntries.count) series (\(total) rolls) into \(outputPath)")
        } catch {
            print("[CentralFilesIndexGenerator] ✗ CONSULAR_TAIL_FROM_HARVEST: write failed — \(error)")
            exit(1)
        }
    }
}
