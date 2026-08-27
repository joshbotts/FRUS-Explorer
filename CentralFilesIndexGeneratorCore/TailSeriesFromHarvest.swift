// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LotClaimantsIndexGeneratorCore

// MARK: - TailSeriesFromHarvest

/// W-8's offline harvest: builds the Phase-3 tail series — Consular Instructions (604019),
/// Notes to Foreign Consuls (1076611), Notes from Foreign Consuls (1076629), Domestic
/// Letters (568025), Letters Received (583574), and the two Special Agents series
/// (876974 / 871874) — into `central-files-index.json` from the OFFLINE record-group
/// harvest, with **no `CATALOG_API_KEY` and no network**. (Named
/// `TAIL_FROM_HARVEST` for the one day it covered only the consular three; the
/// env var is `TAIL_FROM_HARVEST` since the domestic/special-agent remainder joined.)
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
///   1.0 — W-8: initial implementation (the consular three)
///   1.1 — W-8 remainder: Domestic Letters, Letters Received, both Special Agents series;
///         renamed from `ConsularTailFromHarvest`; unparseable-date volumes are now
///         SKIPPED AND PRINTED rather than fatal (Letters Received carries container and
///         microfilm-publication rows with no volume date), with a >half-skipped refusal
///         so a garbled re-harvest still fails loudly
enum TailSeriesFromHarvest {

    /// The tail categories this pass builds, in output order.
    static let tailCategories: [CountrySeriesCategory] = [
        .consularInstructions, .notesToForeignConsuls, .notesFromForeignConsuls,
        .domesticLetters, .lettersReceived,
        .specialAgentsDespatches, .specialAgentsInstructions,
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
        // "Volume: 1 - Dates: Dec 11, 1784-Nov 28, 1785"
        TailGoldenCheck(category: .domesticLetters, dateISO: "1785-06-01",
                        expectedNaId: "29716958"),
        // "January THRU December 1810"
        TailGoldenCheck(category: .lettersReceived, dateISO: "1810-06-15",
                        expectedNaId: "57362782"),
        // "Volumes 34-36: James H. Blount: 1893" (the Hawaii mission)
        TailGoldenCheck(category: .specialAgentsDespatches, dateISO: "1893-06-01",
                        expectedNaId: "213816650"),
        // "Volume 2: Special Missions: Dec. 30, 1859 - June 28, 1871"
        TailGoldenCheck(category: .specialAgentsInstructions, dateISO: "1870-01-01",
                        expectedNaId: "152648809"),
    ]

    // MARK: - Run

    static func run(outputPath: String, harvestDir: String, generated: String) {
        guard var index = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("[CentralFilesIndexGenerator] ✗ TAIL_FROM_HARVEST: cannot read \(outputPath) — this mode supplements an existing index, never creates one")
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
            print("[CentralFilesIndexGenerator] ✗ TAIL_FROM_HARVEST: \(error)")
            exit(1)
        }

        guard scanned >= minimumShardRecords else {
            print("[CentralFilesIndexGenerator] ✗ TAIL_FROM_HARVEST: only \(scanned) records in \(shard.path) — a truncated or wrong shard (rg_59 holds ~240,929)")
            exit(1)
        }
        print("[CentralFilesIndexGenerator] TAIL_FROM_HARVEST: scanned \(scanned) records in rg_59.json")

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

            var digitized = records.filter { ($0.digitalObjectCount ?? 0) > 0 }
            for skipped in records where (skipped.digitalObjectCount ?? 0) == 0 {
                print("  – \(category.rawValue): SKIPPED undigitized volume \(skipped.naId) “\(skipped.title)” (the availableOnline parity — no pages to view)")
            }
            // A microfilm-publication row ("M179 - Miscellaneous Letters …") describes the
            // whole series' microcopy, not a volume — as a roll it would date-match the
            // entire run and shadow every real volume.
            digitized.removeAll { record in
                let isMicrofilmRow = record.title.range(
                    of: #"^[A-Z]{1,2}\d+ - "#, options: .regularExpression) != nil
                if isMicrofilmRow {
                    print("  – \(category.rawValue): SKIPPED microfilm-publication row \(record.naId) “\(record.title)”")
                }
                return isMicrofilmRow
            }

            // Through the SAME parser + builder the keyed route uses — one grammar, no drift.
            let catalogRecords = digitized.map {
                CatalogRecord(naId: $0.naId, title: $0.title, levelOfDescription: "fileUnit")
            }
            var result = CountrySeriesIndexBuilder.build(category: category, records: catalogRecords)

            if result.rollsWithoutDate > 0 {
                // A chronological-run roll with no date bound can never match a query —
                // dead weight that looks like coverage. Letters Received carries a dateless
                // container row, so these are SKIPPED AND PRINTED rather than fatal; a run
                // where parsing failed for more than half the digitized volumes still
                // refuses, so a garbled re-harvest cannot quietly gut a series.
                for title in result.sampleNoDate {
                    print("  – \(category.rawValue): SKIPPED dateless volume “\(title)”")
                }
                let dated = result.index.rolls.filter { $0.startISO != nil || $0.endISO != nil }
                guard dated.count * 2 >= result.index.rolls.count else {
                    print("  ✗ \(category.rawValue): more than half the digitized volumes (\(result.rollsWithoutDate) of \(result.index.rolls.count)) have no parseable date — refusing")
                    exit(1)
                }
                result = CountrySeriesHarvestResult(
                    index: CountrySeriesIndex(category: category.rawValue,
                                              seriesNaId: category.seriesNaId,
                                              displayName: category.displayName,
                                              rolls: dated),
                    totalRecords: result.totalRecords,
                    resolutionRecords: result.resolutionRecords,
                    rollsWithoutGeo: result.rollsWithoutGeo,
                    rollsWithoutDate: result.rollsWithoutDate,
                    sampleNoGeo: result.sampleNoGeo,
                    sampleNoDate: result.sampleNoDate)
            }

            guard !result.index.rolls.isEmpty else {
                print("  ✗ \(category.rawValue): zero rolls built — an empty series entry silently disables the feature, refusing to write")
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
            print("[CentralFilesIndexGenerator] TAIL_FROM_HARVEST: index already carries identical entries — nothing to write")
            return
        }
        index.countrySeries = countrySeries
        index.generated = generated
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            let total = newEntries.map(\.rolls.count).reduce(0, +)
            print("[CentralFilesIndexGenerator] ✓ TAIL_FROM_HARVEST: wrote \(newEntries.count) series (\(total) rolls) into \(outputPath)")
        } catch {
            print("[CentralFilesIndexGenerator] ✗ TAIL_FROM_HARVEST: write failed — \(error)")
            exit(1)
        }
    }
}
