// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LotClaimantsIndexGeneratorCore
import SourceNoteKit
import GeneratorKit

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
///   CONSULAR_TAIL_FROM_HARVEST — `1`/`true`: offline mode (NO API key, W-8) — build the three
///     remaining Phase-3 consular-tail series (Consular Instructions 604019, Notes to Foreign
///     Consuls 1076611, Notes from Foreign Consuls 1076629) from the record-group harvest's
///     rg_59.json (HARVEST_DIR), verified against NARA's own per-series fileUnitCount, and
///     rewrite OUTPUT_PATH in place. See ConsularTailFromHarvest.
///   SUPPLEMENT_FROM_HARVEST — `1`/`true`: offline mode (NO API key) — resolve the lot files the
///                 corpus cites and this index cannot answer, against the 4.5 GB record-group
///                 harvest at `HARVEST_DIR`, then exit. Closes #372 item 1b. Env also:
///                 `COLLECTION_AUTHORITY` (the cited-lot list), `CURATED_LOTS` (the refuse list).
///   FOLD_VOLUME_SOURCES — `1`/`true`: offline mode (NO API key) — absorb the orphan lots from
///                 `volume-sources-index.json` (env `VOLUME_SOURCES_INDEX`) into this index and
///                 rewrite it, then exit. Closes #372 item 1 from the central-files side; the
///                 volume-sources runner's `lotsToWrite` then emits an empty `lots` map on its
///                 next run. fileUnit and null-record-group rows are refused, per #351/#321.
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
///   1.2 — Session 2026-08-19: #372 item 1 — FOLD_VOLUME_SOURCES offline mode
///   1.3 — Session 2026-08-19: #372 item 1b — SUPPLEMENT_FROM_HARVEST offline mode
///   1.4 — W-8: CONSULAR_TAIL_FROM_HARVEST offline mode (the three chronological-run
///         consular-tail series, keyless)
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

    // MARK: - SUPPLEMENT_FROM_HARVEST (#372 item 1b)

    /// Resolves the lot files the corpus cites and this index cannot answer, from the **offline**
    /// record-group harvest (#372 item 1b). Keyless; checked before the API-key guard.
    ///
    /// ## Why the offline harvest and not the re-harvest the issue names
    /// #372 item 1b asks for the acceptance-rule swap "then re-harvest". Measured, that cannot
    /// deliver most of its own value, for a reason upstream of any acceptance rule: the keyed
    /// route asks NARA for the *cited* spelling of a lot (`lotVariants` emits `80D135`,
    /// `80 D 135`, `80 D135`) and NARA indexes many State lots only in an expanded form —
    /// `80D135` is held solely as `1980D0135`, and `grep "80D135" rg_59.json` returns nothing.
    /// An exact-match filter on spellings NARA never used returns no record, whichever rule runs
    /// downstream. The keyed route also sends `recordGroupNumber` = the *cited* group, which
    /// filters a cross-record-group record out before acceptance is ever consulted. The offline
    /// harvest is subject to neither constraint, because it reads every record and asks the
    /// question locally.
    ///
    /// ## Measured, 2026-08-19
    /// 1,716 distinct cited lot keys; 931 already answered; **785 wanted**. This pass admits
    /// **87** — 62 same-record-group, 25 through O-7's `crossRecordGroupLots` — reaching 92
    /// distinct volumes of 552. 698 resolve to nothing and that is a property of the catalogue,
    /// not of the rule. Of the 87, only 9 come from the harvest holding a series the keyed API
    /// missed; **53 come from the shared fold's #679 spelling expansions**, which the private
    /// rule this generator used to carry did not apply. The rule swap is the larger half.
    ///
    /// ## Not reproducible from a clone, and the artifact diff is therefore the review surface
    /// `HARVEST_DIR` is 4.5 GB, gitignored, and present on one machine — the same standing as
    /// `LotClaimantsIndexGenerator` and `SeriesFactsIndexGenerator`, which read it too. So this
    /// prints **every admitted row and every divided lot**: a reviewer who cannot re-run the
    /// pass can still read what it decided.
    ///
    /// ## The scan is control-number-only, by construction
    /// It visits a record for a lot only when one of that record's `variantControlNumbers` folds
    /// to a wanted key, which means `evidence`'s **`consolidationNote` branch can never fire
    /// here** — that branch exists for a record that names the lot in prose while not indexing
    /// it. Reaching it would mean testing every wanted lot against every record: 765 × 751,880
    /// is 575 million calls, against the ~40,000 this does. The narrowing is free rather than
    /// merely cheap: measured over the whole harvest, the note channel admits **zero** lots that
    /// the control-number channel does not already admit, and the three notes it can reach
    /// (`58D776`, `61D67`, `62D42`) are lots central-files already carries.
    ///
    /// ## Re-running is a clean no-op, and the health check is on the input
    /// A second run finds every lot it would admit already in the index, so it admits nothing,
    /// prints why, and **returns without writing** — the artifact stays byte-identical and
    /// `generated` is not bumped for a run that changed nothing. The refusal that guards a broken
    /// `HARVEST_DIR` therefore tests how many RECORDS were read (the harvest holds ~751,880), not
    /// how many lots were admitted. Guarding on the outcome is the obvious version and it is
    /// wrong twice over: it fails the clean re-run, and `candidates.isEmpty` fails it too, since
    /// the scan is pre-filtered by `wanted`.
    ///
    /// ## Run order
    /// After this: `PRUNE_FLAGGED_LOTS` (a live test asserts the shipped bundle trips neither
    /// guard — this pass cannot admit a flagged row, but the interlock is cheap), then
    /// `CollectionAuthorityGenerator` → `CollectionUsageIndexGenerator` →
    /// `LotClaimantsIndexGenerator` → `SeriesFactsIndexGenerator`. The claimants step is the one
    /// that is both silent and user-visible if skipped: the five divided lots would render as a
    /// confident single answer.
    static func supplementFromHarvest(outputPath: String, authorityPath: String,
                                      curatedPath: String, harvestDir: String,
                                      generated: String) {
        guard var index = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: cannot read \(outputPath)")
            exit(1)
        }
        let known = Set(index.lotFiles.map(\.lotNumber))
        guard let cited = citedLotKeys(authorityPath: authorityPath), !cited.isEmpty else {
            print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: no cited lots in \(authorityPath)")
            exit(1)
        }
        let curated = curatedLotKeys(curatedPath: curatedPath)
        if curated.isEmpty {
            // A silent empty refuse-list is how a guard stops guarding. The curated file ships
            // with 20 rows; zero means the path is wrong, not that curation was retired.
            print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: no curated lots read "
                  + "from \(curatedPath) — refusing to run without the exclusion list")
            exit(1)
        }
        let wanted = cited.subtracting(known).subtracting(curated)
        print("[CentralFilesIndexGenerator] SUPPLEMENT_FROM_HARVEST: cited \(cited.count), "
              + "known \(known.count), curated \(curated.count) → wanted \(wanted.count)")

        let shardDir = URL(fileURLWithPath: harvestDir).appending(path: "series")
        guard let shards = try? FileManager.default
            .contentsOfDirectory(at: shardDir, includingPropertiesForKeys: nil)
            .filter({ $0.lastPathComponent.hasPrefix("rg_") && $0.pathExtension == "json" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }), !shards.isEmpty else {
            print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: no shards under \(shardDir.path)")
            exit(1)
        }

        var candidates: [String: [SupplementCandidate]] = [:]
        var harvestGenerated: String?
        var scannedRecords = 0
        for shard in shards {
            do {
                let stamp = try HarvestShardReader.forEachRecord(shard) { record in
                    scannedRecords += 1
                    // Only records carrying a control number that folds to a wanted lot are
                    // considered, so the accumulator stays a few hundred rows rather than the
                    // 751,880-record harvest. Membership is checked on the FOLDED value, the
                    // same key `evidence` compares — a raw-string check here would miss every
                    // expanded spelling and quietly undo the point of the rule swap.
                    for control in record.variantControlNumbers {
                        let key = LotResolutionAcceptance.foldControlNumber(control)
                        guard wanted.contains(key) else { continue }
                        guard let evidence = LotResolutionAcceptance.evidence(
                            recordGroup: LotFileCitationExtractor.recordGroup(forNormalized: key),
                            normalizedLot: key,
                            candidateRecordGroup: record.recordGroupNumber,
                            levelOfDescription: record.levelOfDescription,
                            variantControlNumbers: record.variantControlNumbers,
                            controlNumberNotes: record.controlNumberNotes)
                        else { continue }
                        let candidate = SupplementCandidate(
                            naId: record.naId,
                            title: record.title,
                            recordGroup: record.recordGroupNumber ?? "",
                            // NATURALLY sorted, the way `CatalogRecord.hmsMlrEntries` sorts the
                            // keyed route's. `HarvestShardReader` returns NARA's own arbitrary
                            // order, so taking it raw puts "UD-14D 10" before "UD-14D 4" — which
                            // is precisely the keyed/offline drift this whole item exists to
                            // remove, reintroduced in a different field. Caught by
                            // `CentralFilesIndexTests.bundledEntryNumbersAreNaturallySorted`.
                            hmsMlrEntryNumbers: CatalogRecord.sortedNaturally(record.hmsMlrEntryNumbers),
                            levelOfDescription: record.levelOfDescription,
                            evidence: evidence == .controlNumber ? "controlNumber" : "consolidationNote",
                            crossRecordGroup: record.recordGroupNumber
                                != LotFileCitationExtractor.recordGroup(forNormalized: key))
                        if !(candidates[key] ?? []).contains(where: { $0.naId == candidate.naId }) {
                            candidates[key, default: []].append(candidate)
                        }
                    }
                }
                harvestGenerated = harvestGenerated ?? stamp
                print("    \(shard.lastPathComponent): \(candidates.count) lot(s) with a candidate so far")
            } catch {
                print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: \(shard.lastPathComponent): \(error)")
                exit(1)
            }
        }

        // The health check is on the INPUT, not the outcome. A first draft guarded on "admitted
        // nothing", which is the wrong test in both directions: a second run legitimately admits
        // nothing because every lot it would admit is now in `known`, and it failed exactly that
        // way when the idempotency check was run. `candidates.isEmpty` is no better — the scan is
        // pre-filtered by `wanted`, so it is empty on that same clean re-run. What actually
        // distinguishes an unreadable or truncated HARVEST_DIR is that no RECORDS were read.
        guard scannedRecords > 100_000 else {
            print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: scanned only "
                  + "\(scannedRecords) records across \(shards.count) shard(s). The harvest holds "
                  + "~751,880 — check HARVEST_DIR (\(harvestDir)). Refusing to write.")
            exit(1)
        }

        let decision = supplementDecision(wanted: wanted, known: known,
                                          curated: curated, candidates: candidates)
        if decision.admitted.isEmpty {
            // A clean no-op: the input was read in full and had nothing new to offer. Returning
            // WITHOUT writing is deliberate — rewriting would bump `generated` and produce an
            // artifact diff for a run that changed nothing, which is how a no-op re-run ends up
            // looking like a data change in review.
            print("[CentralFilesIndexGenerator] ✓ SUPPLEMENT_FROM_HARVEST: nothing to admit — "
                  + "\(scannedRecords) records scanned, every wanted lot already answered or "
                  + "unresolvable. Artifact left untouched.")
            let byReason = Dictionary(grouping: decision.refused, by: \.reason)
                .mapValues(\.count).sorted { $0.key < $1.key }
            print("    refused: " + byReason.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
            return
        }

        let before = index.lotFiles.count
        index.lotFiles = (index.lotFiles + decision.admitted).sorted { $0.lotNumber < $1.lotNumber }
        index.generated = generated
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
        } catch {
            print("[CentralFilesIndexGenerator] ✗ SUPPLEMENT_FROM_HARVEST: failed to write: \(error)")
            exit(1)
        }

        let crossRG = decision.admitted.filter {
            $0.recordGroup != LotFileCitationExtractor.recordGroup(forNormalized: $0.lotNumber)
        }
        print("[CentralFilesIndexGenerator] ✓ SUPPLEMENT_FROM_HARVEST: admitted "
              + "\(decision.admitted.count) lot(s) — \(decision.admitted.count - crossRG.count) "
              + "same-record-group, \(crossRG.count) cross-record-group (O-7 table); "
              + "\(before) → \(index.lotFiles.count). Harvest stamp \(harvestGenerated ?? "unknown").")
        for lf in decision.admitted {
            let cited = LotFileCitationExtractor.recordGroup(forNormalized: lf.lotNumber)
            let mark = lf.recordGroup == cited ? " " : "*"
            print("    +\(mark) \(lf.lotNumber) → naId \(lf.naId) RG \(lf.recordGroup)"
                  + (lf.recordGroup == cited ? "" : " (cited RG \(cited))")
                  + " “\(lf.title.prefix(46))”")
        }
        if !decision.divided.isEmpty {
            print("    \(decision.divided.count) DIVIDED lot(s) — the bundle names the lowest NAID; "
                  + "re-run LotClaimantsIndexGenerator so the app discloses the rest:")
            for row in decision.divided {
                print("      \(row.lot): \(row.claimants.map(\.naId).joined(separator: ", "))")
            }
        }
        let byReason = Dictionary(grouping: decision.refused, by: \.reason)
            .mapValues(\.count).sorted { $0.key < $1.key }
        print("    refused: " + byReason.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
    }

    /// Every lot key the corpus cites, from `collection-authority.json`'s `lot:` collections.
    ///
    /// Folded through the shared rule so the wanted set and the harvest's control numbers are in
    /// one key space; two authority ids can fold together (`89D56` is reached by two spellings),
    /// which a `Set` absorbs and a dictionary keyed on the raw id would have crashed on.
    static func citedLotKeys(authorityPath: String) -> Set<String>? {
        guard let data = FileManager.default.contents(atPath: authorityPath),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let collections = root["collections"] as? [[String: Any]] else { return nil }
        var keys: Set<String> = []
        for record in collections {
            guard let id = record["id"] as? String, id.hasPrefix("lot:") else { continue }
            let key = LotResolutionAcceptance.foldControlNumber(String(id.dropFirst(4)))
            if !key.isEmpty { keys.insert(key) }
        }
        return keys
    }

    /// The lots `curated-lot-resolutions.json` deliberately leaves unresolved.
    static func curatedLotKeys(curatedPath: String) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: curatedPath),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lots = root["lots"] as? [[String: Any]] else { return [] }
        return Set(lots.compactMap { $0["lotNumber"] as? String }
            .map(LotResolutionAcceptance.foldControlNumber)
            .filter { !$0.isEmpty })
    }

    /// One accepted (lot → record) pairing, before the artifact decides what to do with it.
    struct SupplementCandidate: Sendable, Equatable {
        let naId: String
        let title: String
        let recordGroup: String
        let hmsMlrEntryNumbers: [String]
        let levelOfDescription: String?
        /// `controlNumber` or `consolidationNote` — which branch of the shared rule accepted it.
        let evidence: String
        /// `true` when the record sits in a record group other than the one FRUS's citation
        /// implies, i.e. it was admitted through O-7's `crossRecordGroupLots` table.
        let crossRecordGroup: Bool
    }

    /// What a supplement run would do, given the lots wanted and the candidates the harvest offers.
    ///
    /// The pure half of ``supplementFromHarvest(outputPath:authorityPath:curatedPath:harvestDir:generated:)``
    /// — the seam `foldDecision` has for the item-1 fold and `lotsToWrite` has on the
    /// volume-sources side — so the admission rule is driven directly rather than through a
    /// 4.5 GB scan and a file round trip.
    ///
    /// ## Divided lots are admitted, not refused
    /// Five of the 87 have more than one acceptable series, because NARA divides a lot across
    /// series as readily as it consolidates several into one. `LotFileEntry` stores one `naId`,
    /// so this picks the **numerically lowest** — a stated, reproducible rule rather than
    /// shard-scan order — and returns the full claimant list so the caller can log it. The
    /// disclosure lives where #675 put it: `lot-claimants-index.json`, which takes its lot list
    /// from central-files and therefore only sees these lots once this pass has run. **That
    /// artifact must be regenerated after this one**, or Source Explorer renders the single
    /// bundled card and asserts one series where NARA names several.
    ///
    /// ## The three refusals
    ///   - **already resolved** — deduped against `central-files-index.json` itself, never
    ///     against `collection-authority.json`'s `naId` field. The authority's join is stale
    ///     relative to the bundle it was built from (`83D66` is listed there as unresolved while
    ///     central-files has answered it since the keyed harvest), so trusting it would re-admit
    ///     a row that already exists and silently change its NAID.
    ///   - **curated** — the 20 lots in `curated-lot-resolutions.json`, refused BY NAME rather
    ///     than by trusting the rule to miss them. It does miss all 20 against this snapshot, and
    ///     that is a property of the snapshot: curation exists because NARA carries no matching
    ///     control number, and a re-harvest could produce one. `CuratedLotResolutionsTests`
    ///     forbids a curated lot from reaching this artifact, which cannot express doubt.
    ///   - **no candidate** — the overwhelming majority. 698 of 785 wanted lots resolve to
    ///     nothing in the harvest, and no amount of rule-loosening changes that: the records are
    ///     genuinely absent (`61D385`, 46 volumes, returns zero hits in `rg_59.json` in every
    ///     fold-expanded spelling).
    ///
    /// - Parameters:
    ///   - wanted: Normalized lot keys the corpus cites, in any order.
    ///   - known: Lot keys `central-files-index.json` already answers.
    ///   - curated: Lot keys deliberately left unresolved.
    ///   - candidates: Accepted (lot → records) pairings from the harvest scan.
    /// - Returns: The rows to append, the divided lots for the log, and each refusal with a reason.
    static func supplementDecision(
        wanted: Set<String>,
        known: Set<String>,
        curated: Set<String>,
        candidates: [String: [SupplementCandidate]]
    ) -> (admitted: [LotFileEntry],
          divided: [(lot: String, claimants: [SupplementCandidate])],
          refused: [(lot: String, reason: String)]) {
        var admitted: [LotFileEntry] = []
        var divided: [(lot: String, claimants: [SupplementCandidate])] = []
        var refused: [(lot: String, reason: String)] = []

        for lot in wanted.sorted() {
            if known.contains(lot) { refused.append((lot, "already in central-files")); continue }
            if curated.contains(lot) { refused.append((lot, "curated as non-deterministic")); continue }
            let accepted = candidates[lot] ?? []
            guard !accepted.isEmpty else { refused.append((lot, "no candidate in the harvest")); continue }

            // Numerically lowest NAID, falling back to lexicographic so a non-numeric id (there
            // are none today) still yields a total order rather than an arbitrary one.
            let ordered = accepted.sorted {
                switch (Int($0.naId), Int($1.naId)) {
                case let (a?, b?): return a == b ? $0.naId < $1.naId : a < b
                default: return $0.naId < $1.naId
                }
            }
            if ordered.count > 1 { divided.append((lot, ordered)) }
            let pick = ordered[0]
            admitted.append(LotFileEntry(
                lotNumber: lot,
                recordGroup: pick.recordGroup,
                naId: pick.naId,
                title: pick.title,
                catalogURL: "https://catalog.archives.gov/id/\(pick.naId)",
                matchType: "control",
                hmsMlrEntryNumbers: pick.hmsMlrEntryNumbers.isEmpty ? nil : pick.hmsMlrEntryNumbers,
                levelOfDescription: pick.levelOfDescription,
                ancestryLacksRecordGroup: nil))
        }
        return (admitted, divided, refused)
    }

    /// Absorbs `volume-sources-index.json`'s orphan lots into the central-files index (#372 item 1).
    ///
    /// Offline and keyless, on the `PRUNE_FLAGGED_LOTS` pattern and checked before the key guard
    /// for the same reason: the rows already exist, resolved, in a shipped artifact — no catalogue
    /// call can tell us anything new about them.
    ///
    /// **Why they were orphans, and why the fold is not a re-harvest.** The two generators reach
    /// NARA by different routes, so each finds lots the other cannot. Five of the seven —
    /// `64D171`, `67D317`, `67D333`, `68D393`, `70D449` — are **RG 306** (USIA), a record group
    /// the central-files harvest structurally never enumerates. The other two, `74D267` and
    /// `78D26`, are RG 59: the group *is* harvested, so what the keyed
    /// `variantControlNumber_is` pass missed on them, the volume-sources front-matter pass
    /// resolved. Both facts point the same way — the resolutions already exist and are already
    /// shipped, so admitting them is a merge and not a network call. `lotsToWrite` in the
    /// volume-sources runner already keeps only what central-files cannot answer, which is what
    /// cut that map from 758 to 7; this closes it from the other side, taking it to 0.
    ///
    /// **fileUnit rows are refused**, the #351 rule the sibling prune applies: a file-unit title is
    /// not the series title `#315` asks the UI to present. `ancestryLacksRecordGroup` cannot appear
    /// here — the volume-sources resolver records a record group for every row it keeps — but the
    /// same guard runs anyway, so a future input shape cannot smuggle one in.
    ///
    /// Deterministic and idempotent: a second run finds every orphan already present and admits
    /// nothing. Rows are appended and the whole array re-sorted, so output does not depend on
    /// arrival order.
    static func foldVolumeSourceLots(outputPath: String, volumeSourcesPath: String,
                                     generated: String) {
        guard var index = try? CentralFilesIndexWriter.read(from: outputPath) else {
            print("[CentralFilesIndexGenerator] ✗ FOLD_VOLUME_SOURCES: cannot read \(outputPath)")
            exit(1)
        }
        guard let data = FileManager.default.contents(atPath: volumeSourcesPath),
              let root = try? JSONDecoder().decode(VolumeSourceLots.self, from: data) else {
            print("[CentralFilesIndexGenerator] ✗ FOLD_VOLUME_SOURCES: cannot read \(volumeSourcesPath)")
            exit(1)
        }
        let decision = foldDecision(rows: root.lots ?? [:],
                                    known: Set(index.lotFiles.map(\.lotNumber)))

        let before = index.lotFiles.count
        index.lotFiles = (index.lotFiles + decision.admitted).sorted { $0.lotNumber < $1.lotNumber }
        index.generated = generated
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            print("[CentralFilesIndexGenerator] ✓ FOLD_VOLUME_SOURCES: admitted "
                  + "\(decision.admitted.count) lot(s), \(before) → \(index.lotFiles.count), "
                  + "wrote \(outputPath)")
            for lf in decision.admitted {
                print("    + RG \(lf.recordGroup) \(lf.lotNumber) → naId \(lf.naId) “\(lf.title.prefix(40))”")
            }
            for row in decision.refused { print("    - \(row.lot) refused: \(row.reason)") }
        } catch {
            print("[CentralFilesIndexGenerator] ✗ FOLD_VOLUME_SOURCES: failed to write: \(error)")
            exit(1)
        }
    }

    /// One `lots` row of `volume-sources-index.json`, in the shape the fold reads.
    ///
    /// Declared here rather than importing `VolumeSourcesIndexGeneratorCore`'s `ResolvedNAID`:
    /// this generator depends on `GeneratorKit` alone, and a dependency edge added to read four
    /// strings would pull the whole front-matter pass into the harvester's build. Every field is
    /// optional because the fold's job is to *judge* a row, and a required field is a decode
    /// failure that would take the whole pass down over one malformed entry.
    struct VolumeSourceLotRow: Decodable, Sendable {
        let naId: String?
        let catalogURL: String?
        let title: String?
        let recordGroup: String?
        let matchType: String?
        let hmsMlrEntryNumbers: [String]?
        let levelOfDescription: String?
        let ancestryLacksRecordGroup: Bool?
    }

    /// The `lots` map of `volume-sources-index.json`; every other key is ignored.
    struct VolumeSourceLots: Decodable, Sendable {
        let lots: [String: VolumeSourceLotRow]?
    }

    /// Which volume-sources rows may cross into central-files, and why the rest may not.
    ///
    /// The pure half of ``foldVolumeSourceLots(outputPath:volumeSourcesPath:generated:)`` —
    /// the same seam `lotsToWrite` gives the fold's other side — so the admission rule can be
    /// driven directly instead of through a file round trip.
    ///
    /// Four refusals, in the order a row meets them:
    ///   - **already in central-files** — the fold never overwrites a harvested resolution with
    ///     a front-matter one; this is also what makes a second run a no-op.
    ///   - **`fileUnit`** (#351) and **`ancestryLacksRecordGroup`** (#321) — the two classes the
    ///     sibling prune drops. Admitting one here would re-add what that pass exists to remove.
    ///   - **incomplete** — a row missing any field `LotFileEntry` requires. `matchType` counts:
    ///     it is `control` or `phrase`, a claim about *how* the lot resolved, and defaulting an
    ///     absent one to `control` would manufacture confidence the source never asserted.
    ///
    /// Iterates the keys in sorted order so the log and the admitted array are stable.
    static func foldDecision(rows: [String: VolumeSourceLotRow], known: Set<String>)
        -> (admitted: [LotFileEntry], refused: [(lot: String, reason: String)]) {
        var known = known
        var admitted: [LotFileEntry] = []
        var refused: [(lot: String, reason: String)] = []
        for key in rows.keys.sorted() {
            guard let row = rows[key] else { continue }
            if known.contains(key) { refused.append((key, "already in central-files")); continue }
            if row.levelOfDescription == "fileUnit" {
                refused.append((key, "fileUnit (#351)")); continue
            }
            if row.ancestryLacksRecordGroup == true {
                refused.append((key, "null record group (#321)")); continue
            }
            guard let naId = row.naId, let recordGroup = row.recordGroup,
                  let title = row.title, let catalogURL = row.catalogURL,
                  let matchType = row.matchType else {
                refused.append((key, "incomplete row")); continue
            }
            admitted.append(LotFileEntry(
                lotNumber: key,
                recordGroup: recordGroup,
                naId: naId,
                title: title,
                catalogURL: catalogURL,
                matchType: matchType,
                hmsMlrEntryNumbers: row.hmsMlrEntryNumbers,
                levelOfDescription: row.levelOfDescription,
                ancestryLacksRecordGroup: nil))
            known.insert(key)
        }
        return (admitted, refused)
    }

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

    /// Merges a fresh lot harvest with the existing bundle's lots, **preserving valid old NAIDs
    /// against NARA control-number index drift** (#352). A lot that resolved in an earlier harvest
    /// but whose `variantControlNumber_is` search now returns nothing still holds a valid, stable
    /// NAID — the record exists; only NARA's search index moved (the same reason `fetchRecord` uses
    /// the NAID route, `NARACatalogHarvestClient.fetchRecord`). Seeds with the existing non-fileUnit
    /// / non-flagged lots, then overlays the harvest (updates + additions); a fileUnit / flagged old
    /// lot is dropped unless the harvest re-resolves it cleanly. Pure + deterministic (sorted
    /// output) so it is unit-testable without a network round trip.
    static func mergeLots(existing: [LotFileEntry], harvested: [LotFileEntry]) -> [LotFileEntry] {
        var merged: [String: LotFileEntry] = [:]
        for lf in existing
            where lf.levelOfDescription != "fileUnit" && lf.ancestryLacksRecordGroup != true {
            merged[lf.lotNumber] = lf
        }
        for lf in harvested { merged[lf.lotNumber] = lf }
        return merged.values.sorted { $0.lotNumber < $1.lotNumber }
    }

    /// Re-harvests only the lot files (#352 `RESOLVE_LOTS_ONLY`), preserving the existing Numerical
    /// File + country-series sections read from `outputPath`. Runs Phase 3 (`harvestLotFiles`, which
    /// applies the #352 post-validation) and nothing else — no Phase 1/2 enumeration, no golden
    /// checks — then **merges** the harvest with the existing lots (`mergeLots`, preserving valid old
    /// NAIDs through index drift) and writes the combined index. Fails loudly if there is no existing
    /// index to preserve (this mode augments a shipped bundle; it does not build one from scratch).
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
        let harvested = await harvestLotFiles(csvPath: csvPath, client: client)
        let lotFiles = mergeLots(existing: existing.lotFiles, harvested: harvested)
        let harvestedKeys = Set(harvested.map(\.lotNumber))
        let preservedLots = lotFiles.filter { !harvestedKeys.contains($0.lotNumber) }
        let index = CentralFilesIndex(
            generated: generatorDateStamp(override: ProcessInfo.processInfo.environment["GENERATED_DATE"]),
            numericalFile: existing.numericalFile,
            countrySeries: existing.countrySeries,
            lotFiles: lotFiles)
        do {
            try CentralFilesIndexWriter.write(index, to: outputPath)
            print("[CentralFilesIndexGenerator] ✓ RESOLVE_LOTS_ONLY wrote \(lotFiles.count) lot files "
                  + "(\(harvested.count) freshly harvested + \(preservedLots.count) preserved from the "
                  + "existing bundle — these retain their prior resolution, NOT re-post-validated this "
                  + "run — through control-number drift; Numerical File + "
                  + "\(existing.countrySeries.count) country series preserved) to \(outputPath)")
            // A preserved lot for which THIS run also rejected a fresh candidate is suspect: its
            // prior resolution may be the very record post-validation would now reject. Surface the
            // overlap so the owner can spot-check (the fileUnit class is still caught downstream by
            // ENRICH_LOTS → PRUNE_FLAGGED_LOTS; this covers the "no longer carries the lot" class).
            let preservedKeys = Set(preservedLots.map(\.lotNumber))
            let rejectedLots = Set(await client.lotPostValidationRejections
                .compactMap { $0.split(separator: " ").first.map(String.init) })
            let suspect = preservedKeys.intersection(rejectedLots).sorted()
            if !suspect.isEmpty {
                print("  ⚠︎ \(suspect.count) preserved lot(s) also had a fresh candidate rejected this "
                      + "run — their prior resolution may be stale; spot-check: \(suspect.joined(separator: ", "))")
            }
            print("  Next: run ENRICH_LOTS to re-attach #315/#351 fields, then PRUNE_FLAGGED_LOTS.")
        } catch {
            print("[CentralFilesIndexGenerator] ✗ RESOLVE_LOTS_ONLY: failed to write index: \(error)")
            exit(1)
        }
    }

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
            generated: generatorDateStamp(override: ProcessInfo.processInfo.environment["GENERATED_DATE"]),
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

    /// Runs the Phase 1 harvest. Calls `exit(1)` on a fatal error or golden-check failure.
    ///
    /// Also the entry point for the three offline, keyless modes the type header
    /// lists — `FOLD_VOLUME_SOURCES`, `PRUNE_FLAGGED_LOTS`, `ENRICH_LOTS` — each of
    /// which rewrites the existing index and returns before the API-key guard.
    public static func run() async {
        let env = ProcessInfo.processInfo.environment

        // Offline prune mode (#321): drop lot files flagged `ancestryLacksRecordGroup` and exit.
        // No API key — checked before the key guard because it needs none. A reproducible way to
        // apply the #321 policy (drop the candidate mis-resolutions the removed null-record-group
        // fallback let in) to an already-shipped index without a full re-harvest.
        if ["1", "true", "yes"].contains((env["PRUNE_FLAGGED_LOTS"] ?? "").lowercased()) {
            pruneFlaggedLots(outputPath: env["OUTPUT_PATH"] ?? defaultOutputPath,
                             generated: generatorDateStamp(override: ProcessInfo.processInfo.environment["GENERATED_DATE"]))
            return
        }

        // #372 item 1: fold the volume-sources orphans in. Keyless and checked here for the same
        // reason as the prune above — the rows are already resolved in a shipped artifact.
        if ["1", "true", "yes"].contains((env["SUPPLEMENT_FROM_HARVEST"] ?? "").lowercased()) {
            supplementFromHarvest(
                outputPath: env["OUTPUT_PATH"] ?? defaultOutputPath,
                authorityPath: env["COLLECTION_AUTHORITY"]
                    ?? "FRUSExplorer/Resources/collection-authority.json",
                curatedPath: env["CURATED_LOTS"]
                    ?? "FRUSExplorer/Resources/curated-lot-resolutions.json",
                harvestDir: env["HARVEST_DIR"]
                    ?? "/Users/jbotts/Development/nara-record-group-catalog",
                generated: generatorDateStamp(override: env["GENERATED_DATE"]))
            return
        }

        if ["1", "true", "yes"].contains((env["FOLD_VOLUME_SOURCES"] ?? "").lowercased()) {
            foldVolumeSourceLots(
                outputPath: env["OUTPUT_PATH"] ?? defaultOutputPath,
                volumeSourcesPath: env["VOLUME_SOURCES_INDEX"]
                    ?? "FRUSExplorer/Resources/volume-sources-index.json",
                generated: generatorDateStamp(override: env["GENERATED_DATE"]))
            return
        }

        // W-8: the consular-tail series, built OFFLINE from the record-group harvest —
        // keyless, because the bulk shard is measured complete at file-unit level for the
        // three chronological-run series (see ConsularTailFromHarvest's header).
        if ["1", "true", "yes"].contains((env["CONSULAR_TAIL_FROM_HARVEST"] ?? "").lowercased()) {
            ConsularTailFromHarvest.run(
                outputPath: env["OUTPUT_PATH"] ?? defaultOutputPath,
                harvestDir: env["HARVEST_DIR"]
                    ?? "/Users/jbotts/Development/nara-record-group-catalog",
                generated: generatorDateStamp(override: env["GENERATED_DATE"]))
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
            generated: generatorDateStamp(override: ProcessInfo.processInfo.environment["GENERATED_DATE"]),
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
            // Fatal: an unreadable/typo'd CITATIONS_CSV must never masquerade as a successful
            // zero-lot harvest (which would silently drop the whole lot set / partial-PRUNE a
            // dirty bundle). The caller was explicitly told to harvest from this file.
            print("[CentralFilesIndexGenerator] ✗ Could not read citations CSV at \(csvPath): \(error)")
            exit(1)
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

    // #270: isoToday() was a duplicate of GeneratorKit.generatorDateStamp (same format,
    // locale, UTC). Migrating also gives the harvest/enrich/resolve paths GENERATED_DATE
    // override coverage the PRUNE path alone had — byte-neutral for every existing
    // invocation, and what a reproducible re-run wants.
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
